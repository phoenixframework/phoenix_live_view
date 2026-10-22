import { test, expect } from "../test-fixtures";
import { evalPlug, randomString, syncLV } from "../utils";

// Resumable LiveViews (`use Phoenix.LiveView, resumable: true`) survive a lost connection:
// the client resumes them on the next connection instead of mounting them again.
// The server keeps them for 5 seconds, see the socket options in test_helper.exs.
test.describe("resumable LiveViews", () => {
  test.beforeEach(async ({ request }) => {
    const supported = await evalPlug(
      request,
      "Code.ensure_loaded?(Phoenix.Socket.ResumeSession)",
    );
    test.skip(!supported, "requires a Phoenix version with resumable channels");
  });

  const newName = () => randomString(12).replace(/[^a-zA-Z0-9]/g, "x");

  const open = async (page, path, name, params = "") => {
    await page.goto(`${path}?resumable&name=${name}${params}`);
    await syncLV(page);
    return await page.locator("#mount-id").textContent();
  };

  // closes the connection from the server, the client reconnects right away
  const drop = (request, name, after = "") =>
    evalPlug(
      request,
      `alias Phoenix.LiveViewTest.E2E.Resume
      Resume.drop("${name}")
      ${after}
      :ok`,
    );

  const tick = (name, count = 1) =>
    `for _ <- 1..${count}, do: send(Resume.name("${name}"), :tick)`;

  const hookLog = (page) => page.locator("#hook-log li").allTextContents();

  // the frames each WebSocket sent, as decoded messages
  const recordWebSockets = (page) => {
    const sockets = [];
    page.on("websocket", (ws) => {
      const sent = [];
      sockets.push(sent);
      ws.on("framesent", ({ payload }) => sent.push(JSON.parse(payload)));
    });
    return sockets;
  };

  test("resumes the LiveView and replays the updates it missed", async ({
    page,
    request,
  }) => {
    const sockets = recordWebSockets(page);
    const name = newName();
    const mountId = await open(page, "/resume", name);
    await page.locator("#click").click();
    await expect(page.locator("#clicks")).toHaveText("1");

    // the ticks happen while the connection is down
    await drop(request, name, tick(name, 3));

    await expect(page.locator("#ticks")).toHaveText("3");
    await syncLV(page);
    await expect(page.locator("#mount-id")).toHaveText(mountId);
    await expect(page.locator("#clicks")).toHaveText("1");
    await expect
      .poll(() => hookLog(page))
      .toEqual(["mounted", "disconnected", "reconnected"]);

    // the new connection resumes instead of joining the LiveView again
    expect(sockets).toHaveLength(2);
    const events = sockets[1].map(([, , topic, event]) => [topic, event]);
    expect(events).toContainEqual(["phoenix", "phx_resume"]);
    expect(
      events.filter(([topic]) => topic.startsWith("lv:")),
    ).not.toContainEqual(expect.arrayContaining(["phx_join"]));

    await page.locator("#click").click();
    await expect(page.locator("#clicks")).toHaveText("2");
  });

  test("mounts a LiveView that did not opt in again", async ({
    page,
    request,
  }) => {
    const name = newName();
    const mountId = await open(page, "/resume/plain", name);

    await drop(request, name);

    await expect(page.locator("#mount-id")).not.toHaveText(mountId);
    await syncLV(page);
  });

  test("handles an event once when the connection drops before its reply", async ({
    page,
  }) => {
    const name = newName();
    const mountId = await open(page, "/resume", name);

    // the client sends the click again after resuming, as it got no reply
    await page.locator("#click-and-drop").click();
    await syncLV(page);
    await expect(page.locator("#clicks")).toHaveText("1");
    await expect(page.locator("#mount-id")).toHaveText(mountId);

    await page.waitForTimeout(500);
    await expect(page.locator("#clicks")).toHaveText("1");
  });

  test("follows a navigation that happened while disconnected", async ({
    page,
    request,
  }) => {
    const name = newName();
    await open(page, "/resume", name);

    // the LiveView navigates and stops while the connection is down,
    // the client gets the navigation when it resumes
    await drop(
      request,
      name,
      `send(Resume.name("${name}"), {:navigate, "/resume/other"})`,
    );

    await expect(page).toHaveURL(/\/resume\/other/);
    await expect(page.locator("#other")).toBeVisible();
  });

  test("mounts the LiveView again once it was not resumed in time", async ({
    page,
    request,
  }) => {
    const name = newName();
    const mountId = await open(page, "/resume", name, "&heartbeat=500");

    // the client cannot reconnect until the server gave up on the LiveView
    await page.context().setOffline(true);
    await drop(request, name);
    await page.waitForTimeout(6000);
    await page.context().setOffline(false);

    await expect(page.locator("#mount-id")).not.toHaveText(mountId, {
      timeout: 10000,
    });
    await syncLV(page);
  });

  test("survives lost long poll responses", async ({ page, request }) => {
    const name = newName();
    let lose = false;
    const lost = { GET: 0, POST: 0 };

    await page.route("**/live/longpoll**", async (route) => {
      if (!lose) return route.continue();
      // the server handles the request, but the client does not get the response
      try {
        await route.fetch();
      } catch {
        // the page may be gone already
      }
      lost[route.request().method()]++;
      await route.abort();
    });

    const mountId = await open(page, "/resume", name, "&longpoll");
    await page.locator("#click").click();
    await expect(page.locator("#clicks")).toHaveText("1");

    lose = true;
    await page.locator("#click").click();
    await evalPlug(
      request,
      `alias Phoenix.LiveViewTest.E2E.Resume
      ${tick(name, 2)}`,
    );
    await page.waitForTimeout(2000);
    lose = false;

    expect(lost.GET).toBeGreaterThan(0);
    expect(lost.POST).toBeGreaterThan(0);
    await expect(page.locator("#ticks")).toHaveText("2");
    await expect(page.locator("#clicks")).toHaveText("2");
    await syncLV(page);
    await expect(page.locator("#mount-id")).toHaveText(mountId);
    // the LiveView shows the interruption while the transport retries
    await expect
      .poll(() => hookLog(page))
      .toEqual(["mounted", "disconnected", "reconnected"]);
  });

  test("resumes over the long poll fallback after losing the network", async ({
    page,
    browserName,
  }) => {
    test.skip(
      browserName !== "chromium",
      "the offline emulation of other browsers keeps open WebSockets working",
    );
    const name = newName();
    const responses = [];
    page.on("response", async (response) => {
      if (response.url().includes("/live/longpoll")) {
        try {
          responses.push(await response.text());
        } catch {
          // the page may be gone already
        }
      }
    });

    const mountId = await open(
      page,
      "/resume",
      name,
      "&fallback&heartbeat=500",
    );
    await page.locator("#click").click();
    await expect(page.locator("#clicks")).toHaveText("1");
    expect(responses).toEqual([]);

    // the client notices when the heartbeat times out, and falls back to long polling
    // because it cannot tell whether WebSockets are blocked or the network is gone
    await page.context().setOffline(true);
    await expect(
      page.locator("[data-phx-main].phx-client-error"),
    ).toBeVisible();
    await page.waitForTimeout(2000);
    await page.context().setOffline(false);

    await syncLV(page);
    await expect(page.locator("#mount-id")).toHaveText(mountId);
    expect(responses.some((body) => body.includes("released"))).toBe(true);
    await page.locator("#click").click();
    await expect(page.locator("#clicks")).toHaveText("2");
  });
});
