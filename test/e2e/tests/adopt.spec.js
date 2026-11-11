import { test, expect } from "../test-fixtures";
import { evalPlug, syncLV } from "../utils";

// Adoptable LiveViews mount once: the request mounts them in a socket session
// without a client, and the client attaches to that session when it connects.
test.describe("adoptable LiveView", () => {
  test.beforeEach(async ({ request }) => {
    const supported = await evalPlug(
      request,
      "Code.ensure_loaded?(Phoenix.Socket) and function_exported?(Phoenix.Socket, :start_detached, 3)",
    );
    test.skip(!supported, "requires a Phoenix version with detached sessions");
  });

  // the mount id the page was rendered with
  const goto = async (page, url) => {
    const response = await page.goto(url);
    const html = await response.text();
    return html.match(/id="mount-id">(\d+)</)[1];
  };

  const recordWebSockets = (page) => {
    const sockets = [];
    page.on("websocket", (ws) => {
      const socket = { url: ws.url(), sent: [] };
      ws.on("framesent", (frame) => socket.sent.push(frame.payload));
      sockets.push(socket);
    });
    return sockets;
  };

  const joins = (sockets) =>
    sockets
      .flatMap(({ sent }) => sent)
      .filter((message) => {
        const [, , topic, event] = JSON.parse(message);
        return topic.startsWith("lv:") && event === "phx_join";
      });

  test("adopts the LiveView that rendered the page", async ({ page }) => {
    const sockets = recordWebSockets(page);
    const mountId = await goto(page, "/adopt");
    await syncLV(page);

    await expect(page.locator("#mount-id")).toHaveText(mountId);
    await expect(page.locator("#connected")).toHaveText("true");
    // the update the LiveView sent before the client attached
    await expect(page.locator("#ticks")).toHaveText("1");
    await page.locator("#click").click();
    await expect(page.locator("#clicks")).toHaveText("1");

    // the client resumed the session instead of joining
    expect(sockets).toHaveLength(1);
    expect(new URL(sockets[0].url).searchParams.get("phx:resume")).toBe("1");
    expect(joins(sockets)).toEqual([]);
    await expect(page.locator("[data-phx-adopt]")).toHaveCount(0);
  });

  test("adopts the LiveView with long polling", async ({ page }) => {
    const mountId = await goto(page, "/adopt?longpoll");
    await syncLV(page);

    await expect(page.locator("#mount-id")).toHaveText(mountId);
    await expect(page.locator("#ticks")).toHaveText("1");
    await page.locator("#click").click();
    await expect(page.locator("#clicks")).toHaveText("1");
  });

  test("mounts again when the session expired before the client connected", async ({
    page,
  }) => {
    const sockets = recordWebSockets(page);
    // the session waits 1.5 seconds for its client, see test_helper.exs
    const mountId = await goto(page, "/adopt?connectAfter=2500");
    await syncLV(page);

    await expect(page.locator("#mount-id")).not.toHaveText(mountId);
    await expect(page.locator("#connected")).toHaveText("true");
    await page.locator("#click").click();
    await expect(page.locator("#clicks")).toHaveText("1");
    expect(joins(sockets)).toHaveLength(1);
  });
});
