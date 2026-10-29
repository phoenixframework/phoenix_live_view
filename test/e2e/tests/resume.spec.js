import { test, expect } from "../test-fixtures";
import { evalPlug, randomString, syncLV } from "../utils";

// With `resumable: true`, the client resumes its socket over a new WebSocket
// when the connection fails. The LiveViews keep running on the server, so they
// don't mount again. Phoenix.LiveView.Socket only allows the resume when the
// session of the new connection has the same live_socket_id.
test.describe("resumable socket", () => {
  test.beforeEach(async ({ request }) => {
    const supported = await evalPlug(
      request,
      "Code.ensure_loaded?(Phoenix.Transports.WebSocket.Pipe)",
    );
    test.skip(!supported, "requires a Phoenix version with resumable sockets");
  });

  const newName = () => randomString(12).replace(/[^a-zA-Z0-9]/g, "x");

  // Routes the WebSockets of the page through Playwright, so we can drop them.
  // While blocked, new WebSockets fail right away.
  const routeWebSockets = async (page) => {
    const sockets = [];
    const state = { blocked: false };
    await page.routeWebSocket(/\/live\/websocket/, (ws) => {
      if (state.blocked) {
        ws.close({ code: 1011, reason: "blocked" });
        return;
      }
      const sent = [];
      const server = ws.connectToServer();
      ws.onMessage((message) => {
        sent.push(message);
        server.send(message);
      });
      server.onMessage((message) => ws.send(message));
      sockets.push({ url: ws.url(), sent, ws, server });
    });
    // Closes the current WebSocket on both ends with 1000, like a proxy can.
    const drop = async () => {
      const { ws, server } = sockets[sockets.length - 1];
      await server.close({ code: 1000, reason: "dropped" });
      await ws.close({ code: 1000, reason: "dropped" });
    };
    return { sockets, state, drop };
  };

  const setLiveSocketId = (page, id) =>
    page.request.get(`/resume/session?live_socket_id=${id}`);

  const joins = (sent) =>
    sent.filter((message) => {
      const [, , topic, event] = JSON.parse(message);
      return topic.startsWith("lv:") && event === "phx_join";
    });

  test("keeps the LiveView when the WebSocket drops", async ({
    page,
    request,
  }) => {
    const { sockets, state, drop } = await routeWebSockets(page);
    const name = newName();
    await setLiveSocketId(page, "users_socket:1");
    await page.goto(`/resume?resumable&name=${name}`);
    await syncLV(page);
    const mountId = await page.locator("#mount-id").textContent();
    await expect(page.locator("#live-socket-id")).toHaveText("users_socket:1");
    await page.locator("#click").click();
    await expect(page.locator("#clicks")).toHaveText("1");
    // a page reload would remove it
    await page.evaluate(() => (window.notReloaded = true));

    // the LiveView updates while the client cannot connect
    state.blocked = true;
    await drop();
    // the client shows that it is disconnected, after failing to resume
    await expect(page.locator("[data-phx-main]")).toHaveClass(
      /phx-client-error/,
    );
    await expect(page.locator("#status")).toBeVisible();
    // the client sends events after resuming, so the LiveView handles them
    await page.locator("#click").click();
    await evalPlug(
      request,
      `for _ <- 1..3 do
        Phoenix.PubSub.broadcast(Phoenix.LiveViewTest.E2E.PubSub, "resume:${name}", :tick)
      end`,
    );
    state.blocked = false;

    // the client receives the updates it missed after resuming
    await expect(page.locator("#ticks")).toHaveText("3");
    await expect(page.locator("[data-phx-main]")).toHaveClass(/phx-connected/);
    await expect(page.locator("#status")).toBeHidden();
    await expect(page.locator("#mount-id")).toHaveText(mountId);
    await expect(page.locator("#clicks")).toHaveText("2");
    expect(await page.evaluate(() => window.notReloaded)).toBe(true);

    // the new WebSocket resumes the session instead of joining the LiveView again
    expect(sockets).toHaveLength(2);
    expect(sockets[1].url).toContain("resume=1");
    expect(joins(sockets[1].sent)).toHaveLength(0);

    await page.locator("#click").click();
    await expect(page.locator("#clicks")).toHaveText("3");
  });

  test("mounts the LiveView again when the live_socket_id changed", async ({
    page,
  }) => {
    const { sockets, drop } = await routeWebSockets(page);
    const name = newName();
    await setLiveSocketId(page, "users_socket:1");
    await page.goto(`/resume?resumable&name=${name}`);
    await syncLV(page);
    const mountId = await page.locator("#mount-id").textContent();
    await page.locator("#click").click();
    await expect(page.locator("#clicks")).toHaveText("1");
    await page.evaluate(() => (window.notReloaded = true));

    // another user logs in, which changes the session cookie
    await setLiveSocketId(page, "users_socket:2");
    await drop();

    // the server rejects the resume, so the client connects again and mounts
    await expect(page.locator("#live-socket-id")).toHaveText("users_socket:2");
    await expect(page.locator("#mount-id")).not.toHaveText(mountId);
    await expect(page.locator("#clicks")).toHaveText("0");
    await syncLV(page);
    expect(await page.evaluate(() => window.notReloaded)).toBe(true);

    // the resume, then a new connection that joins the LiveView
    expect(sockets).toHaveLength(3);
    expect(sockets[1].url).toContain("resume=1");
    expect(sockets[2].url).not.toContain("resume=1");
    expect(joins(sockets[2].sent)).toHaveLength(1);
  });

  test("mounts the LiveView again when the user logged in", async ({
    page,
  }) => {
    const { sockets, drop } = await routeWebSockets(page);
    const name = newName();
    await page.goto(`/resume?resumable&name=${name}`);
    await syncLV(page);
    const mountId = await page.locator("#mount-id").textContent();
    await expect(page.locator("#live-socket-id")).toHaveText("");
    await page.evaluate(() => (window.notReloaded = true));

    // the user logs in, for example in another tab
    await setLiveSocketId(page, "users_socket:1");
    await drop();

    // the socket connects again, so it gets the live_socket_id as its id
    await expect(page.locator("#live-socket-id")).toHaveText("users_socket:1");
    await expect(page.locator("#mount-id")).not.toHaveText(mountId);
    await syncLV(page);
    expect(await page.evaluate(() => window.notReloaded)).toBe(true);
    expect(sockets).toHaveLength(3);
    expect(joins(sockets[2].sent)).toHaveLength(1);
  });
});
