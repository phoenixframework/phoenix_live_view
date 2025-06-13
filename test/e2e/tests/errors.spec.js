import { test, expect } from "../test-fixtures";
import { syncLV } from "../utils";

/**
 * https://hexdocs.pm/phoenix_live_view/error-handling.html
 */
test.describe("exception handling", () => {
  let webSocketEvents = [];
  let networkEvents = [];
  let consoleMessages = [];

  test.beforeEach(async ({ page }) => {
    networkEvents = [];
    webSocketEvents = [];
    consoleMessages = [];

    page.on("request", (request) =>
      networkEvents.push({ method: request.method(), url: request.url() }),
    );

    page.on("websocket", (ws) => {
      ws.on("framesent", (event) =>
        webSocketEvents.push({ type: "sent", payload: event.payload }),
      );
      ws.on("framereceived", (event) =>
        webSocketEvents.push({ type: "received", payload: event.payload }),
      );
      ws.on("close", () => webSocketEvents.push({ type: "close" }));
    });

    page.on("console", (msg) => consoleMessages.push(msg.text()));
  });

  test.describe("during HTTP mount", () => {
    test("500 error when dead mount fails", async ({ page }) => {
      page.on("response", (response) => {
        expect(response.status()).toBe(500);
      });
      await page.goto("/errors?dead-mount=raise");
    });
  });

  test.describe("during connected mount", () => {
    /**
     * When the connected mount fails, the page is reloaded. The hope here is
     * that the next time the page is loaded, either the connected mount will
     * succeed, or the same error will be triggered during the dead mount as well,
     * rendering an error page.
     *
     * In the unlikely case that the dead mount succeeds, but the connected mount
     * fails repeatedly, the liveSocket enters failsafe mode. This still means that
     * the page will be reloaded without giving up, but the duration is set to 30s
     * by default.
     */
    test("reloads the page when connected mount fails", async ({ page }) => {
      await page.goto("/errors?connected-mount=raise");

      // the page was loaded once
      expect(
        networkEvents.filter((e) =>
          e.url.includes("http://localhost:4004/errors?connected-mount=raise"),
        ),
      ).toHaveLength(1);

      networkEvents = [];

      await page.waitForTimeout(2000);

      // the page was reloaded 5 times
      expect(networkEvents).toEqual(
        expect.arrayContaining([
          {
            method: "GET",
            url: "http://localhost:4004/errors?connected-mount=raise",
          },
          {
            method: "GET",
            url: "http://localhost:4004/errors?connected-mount=raise",
          },
          {
            method: "GET",
            url: "http://localhost:4004/errors?connected-mount=raise",
          },
          {
            method: "GET",
            url: "http://localhost:4004/errors?connected-mount=raise",
          },
          {
            method: "GET",
            url: "http://localhost:4004/errors?connected-mount=raise",
          },
          {
            method: "GET",
            url: "http://localhost:4004/errors?connected-mount=raise",
          },
          {
            method: "GET",
            url: "http://localhost:4004/errors?connected-mount=raise",
          },
        ]),
      );

      expect(consoleMessages).toEqual(
        expect.arrayContaining([
          expect.stringMatching(/consecutive reloads. Entering failsafe mode/),
        ]),
      );
    });

    /**
     * TBD: if the connected mount of the main LV succeeds, but a child LV fails
     * on mount, we only try to rejoin the child LV instead of reloading the page.
     */
    test("rejoin instead of reload when child LV fails on connected mount", async ({
      page,
    }) => {
      await page.goto("/errors?connected-child-mount-raise=2");
      await page.waitForTimeout(2000);

      expect(consoleMessages).toEqual(
        expect.arrayContaining([
          expect.stringMatching(/mount/),
          expect.stringMatching(/child error: unable to join/),
          expect.stringMatching(/child error: unable to join/),
          // third time's the charm
          expect.stringMatching(/child mount/),
        ]),
      );

      // page was not reloaded
      expect(
        networkEvents.filter((e) =>
          e.url.includes("http://localhost:4004/errors?"),
        ),
      ).toHaveLength(1);
    });

    /**
     * TBD: if the connected mount of the main LV succeeds, but a child LV fails
     * repeatedly, we reload the page. Maybe we should give up without reloading the page?
     */
    test("abandons child remount if child LV fails multiple times", async ({
      page,
    }) => {
      await page.goto("/errors?connected-child-mount-raise=5");
      // maybe we can find a better way than waiting for a fixed amount of time
      await page.waitForTimeout(1000);

      expect(consoleMessages.filter((m) => m.startsWith("child "))).toEqual([
        expect.stringContaining("child error: unable to join"),
        expect.stringContaining("child error: unable to join"),
        expect.stringContaining("child error: unable to join"),
        // maxChildJoinTries is 3, we count from 0, so the 4th try is the last
        expect.stringContaining("child error: giving up"),
        expect.stringContaining("child destroyed"),
      ]);

      // page remained loaded without parent failsafe reload
      expect(
        networkEvents.filter((e) =>
          e.url.includes(
            "http://localhost:4004/errors?connected-child-mount-raise=5",
          ),
        ),
      ).toHaveLength(1);
    });
  });

  test.describe("after connected mount", () => {
    /**
     * When a child LV crashes after the connected mount, the parent LV is not
     * affected. The child LV is simply remounted.
     */
    test("page does not reload if child LV crashes (handle_event)", async ({
      page,
    }) => {
      await page.goto("/errors?child");
      await syncLV(page);

      const parentTime = await page.locator("#render-time").innerText();
      const childTime = await page.locator("#child-render-time").innerText();

      // both lvs mounted, no other messages
      expect(consoleMessages).toEqual(
        expect.arrayContaining([
          expect.stringMatching(/mount/),
          expect.stringMatching(/child mount/),
        ]),
      );
      consoleMessages = [];

      await page.getByRole("button", { name: "Crash child" }).click();
      await syncLV(page);

      // child crashed and re-rendered
      const newChildTime = page.locator("#child-render-time");
      await expect(newChildTime).not.toHaveText(childTime);
      expect(consoleMessages).toEqual([
        expect.stringMatching(/child error: view crashed/),
        expect.stringMatching(/child mount/),
      ]);

      // parent did not re-render
      const newParentTiem = page.locator("#render-time");
      await expect(newParentTiem).toHaveText(parentTime);

      // page was not reloaded
      expect(
        networkEvents.filter((e) =>
          e.url.includes("http://localhost:4004/errors?child"),
        ),
      ).toHaveLength(1);
    });

    /**
     * When the main LV crashes after the connected mount, the page is not reloaded.
     * The main LV is simply remounted over the existing transport.
     */
    test("page does not reload if main LV crashes (handle_event)", async ({
      page,
    }) => {
      await page.goto("/errors?child");
      await syncLV(page);

      const parentTime = await page.locator("#render-time").innerText();
      const childTime = await page.locator("#child-render-time").innerText();

      // both lvs mounted, no other messages
      expect(consoleMessages).toEqual(
        expect.arrayContaining([
          expect.stringMatching(/mount/),
          expect.stringMatching(/child mount/),
        ]),
      );
      consoleMessages = [];

      await page.getByRole("button", { name: "Crash main" }).click();
      await syncLV(page);

      // main and child re-rendered (full page refresh)
      const newChildTime = page.locator("#child-render-time");
      await expect(newChildTime).not.toHaveText(childTime);
      const newParentTiem = page.locator("#render-time");
      await expect(newParentTiem).not.toHaveText(parentTime);

      expect(consoleMessages).toEqual([
        expect.stringMatching(/child destroyed/),
        expect.stringMatching(/error: view crashed/),
        expect.stringMatching(/mount/),
        expect.stringMatching(/child mount/),
      ]);

      // page was not reloaded
      expect(
        networkEvents.filter((e) =>
          e.url.includes("http://localhost:4004/errors?child"),
        ),
      ).toHaveLength(1);
    });

    /**
     * When the main LV mounts successfully, but a child LV crashes which is linked
     * to the parent, the parent LV crashed too, triggering a remount of both.
     */
    test("parent crashes and reconnects when linked child LV crashes", async ({
      page,
    }) => {
      await page.goto("/errors?connected-child-mount-raise=link");
      await syncLV(page);

      // child crashed on mount, linked to parent -> parent crashed too
      // second mounts are successful
      expect(consoleMessages).toEqual(
        expect.arrayContaining([
          expect.stringMatching(/mount/),
          expect.stringMatching(/child error: unable to join/),
          expect.stringMatching(/child destroyed/),
          expect.stringMatching(/error: view crashed/),
          expect.stringMatching(/mount/),
          expect.stringMatching(/child mount/),
        ]),
      );
      consoleMessages = [];

      const parentTime = await page.locator("#render-time").innerText();
      const childTime = await page.locator("#child-render-time").innerText();

      // the processes are still linked, crashing the child again crashes the parent
      await page.getByRole("button", { name: "Crash child" }).click();
      await syncLV(page);

      // main and child re-rendered (full page refresh)
      const newChildTime = page.locator("#child-render-time");
      await expect(newChildTime).not.toHaveText(childTime);
      const newParentTiem = page.locator("#render-time");
      await expect(newParentTiem).not.toHaveText(parentTime);

      expect(consoleMessages).toEqual([
        expect.stringMatching(/child error: view crashed/),
        expect.stringMatching(/child destroyed/),
        expect.stringMatching(/error: view crashed/),
        expect.stringMatching(/mount/),
        expect.stringMatching(/child mount/),
      ]);

      // page was not reloaded
      expect(
        networkEvents.filter((e) =>
          e.url.includes(
            "http://localhost:4004/errors?connected-child-mount-raise=link",
          ),
        ),
      ).toHaveLength(1);
    });
  });
});
