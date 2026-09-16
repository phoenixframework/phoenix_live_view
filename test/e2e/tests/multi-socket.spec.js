import { test, expect } from "@playwright/test";
import { syncLV } from "../utils";

// the embedded app's two roots, each rendering a sticky root inside: embedded
// by the EmbeddedApp hook into the host view's ignored slot, and by the layout
// script into an ignored slot of the root layout
const nested = (page) => page.locator("#embed-slot [data-app=embedded]");

const outside = (page) =>
  page.locator("[data-app=embedded]:not(#embed-slot *)");

// main + 2 × (embedded root + its sticky)
const connectAll = async (page) => {
  await page.goto("/multi-socket");
  await syncLV(page);
  await expect(page.locator("[data-phx-session].phx-connected")).toHaveCount(5);
};

// which of the embedded LiveSockets are connected: { nested, outside }
const embeddedConnected = (page) =>
  page.evaluate(() =>
    Object.fromEntries(
      Object.entries(window.embeddedLiveSockets).map(([name, socket]) => [
        name,
        socket.isConnected(),
      ]),
    ),
  );

// the apps of the roots held by each embedded LiveSocket
const embeddedRoots = (page) =>
  page.evaluate(() =>
    Object.fromEntries(
      Object.entries(window.embeddedLiveSockets).map(([name, socket]) => [
        name,
        Object.values(socket.roots).map((view) => ({
          app: view.el.getAttribute("data-app"),
          inSlot: !!view.el.closest("#embed-slot"),
          attached: view.el.isConnected,
        })),
      ]),
    ),
  );

test("each socket joins exactly its own roots", async ({ page }) => {
  const websockets = [];
  page.on("websocket", (ws) => websockets.push(new URL(ws.url()).pathname));
  await connectAll(page);

  // the embedded LiveSockets connect to the embedded application's socket
  expect(websockets.sort()).toEqual([
    "/embedded/live/websocket",
    "/embedded/live/websocket",
    "/live/websocket",
  ]);

  // the page's LiveSocket also holds the dead view on body
  const mainIds = await page.evaluate(() =>
    Object.values(window.mainLiveSocket.roots)
      .filter((view) => !view.isDead)
      .map((view) => view.el.getAttribute("data-app")),
  );
  expect(mainIds).toEqual(["main"]);

  // one embedded root lives inside the host view's ignore slot; each
  // embedded socket also holds the sticky root its view renders
  expect(await embeddedRoots(page)).toEqual({
    nested: [
      { app: "embedded", inSlot: true, attached: true },
      { app: "sticky", inSlot: true, attached: true },
    ],
    outside: [
      { app: "embedded", inSlot: false, attached: true },
      { app: "sticky", inSlot: false, attached: true },
    ],
  });
  // the embedded sockets took their csrf token from the fetched fragment
  const tokens = await page.evaluate(() =>
    Object.values(window.embeddedLiveSockets).map(
      (socket) => typeof socket.getSocket().params()._csrf_token,
    ),
  );
  expect(tokens).toEqual(["string", "string"]);
});

test("clicks are handled only by the owning socket", async ({ page }) => {
  await connectAll(page);

  await page.locator("#main-click").click();
  await syncLV(page);
  await expect(page.locator("#main-clicks")).toHaveText("1");
  await expect(nested(page).locator("[data-role=clicks]")).toHaveText("0");
  await expect(outside(page).locator("[data-role=clicks]")).toHaveText("0");

  await nested(page).locator("[data-role=click]").click();
  await syncLV(page);
  await expect(nested(page).locator("[data-role=clicks]")).toHaveText("1");
  await expect(outside(page).locator("[data-role=clicks]")).toHaveText("0");
  await expect(page.locator("#main-clicks")).toHaveText("1");

  await outside(page).locator("[data-role=click]").click();
  await syncLV(page);
  await expect(outside(page).locator("[data-role=clicks]")).toHaveText("1");
  await expect(nested(page).locator("[data-role=clicks]")).toHaveText("1");
  await expect(page.locator("#main-clicks")).toHaveText("1");
});

test("window bindings fire once per socket for a single event", async ({
  page,
}) => {
  await connectAll(page);

  await page.locator("body").press("Escape");
  await syncLV(page);
  await expect(page.locator("#main-keys")).toHaveText("1");
  await expect(nested(page).locator("[data-role=keys]")).toHaveText("1");
  await expect(outside(page).locator("[data-role=keys]")).toHaveText("1");

  await nested(page).locator("[data-role=click]").press("Escape");
  await syncLV(page);
  await expect(page.locator("#main-keys")).toHaveText("2");
  await expect(nested(page).locator("[data-role=keys]")).toHaveText("2");
  await expect(outside(page).locator("[data-role=keys]")).toHaveText("2");
});

test("form input is dispatched only to the owning socket", async ({ page }) => {
  await connectAll(page);

  await nested(page).locator("input[name=text]").fill("hello");
  await expect(nested(page).locator("[data-role=text]")).toHaveText("hello");
  await expect(outside(page).locator("[data-role=text]")).toBeEmpty();
  await expect(page.locator("#main-text")).toBeEmpty();

  await page.locator("#main-input").fill("world");
  await expect(page.locator("#main-text")).toHaveText("world");
  await expect(nested(page).locator("[data-role=text]")).toHaveText("hello");
  await expect(outside(page).locator("[data-role=text]")).toBeEmpty();
});

test("live navigation rebuilds the embedded app inside the host and leaves the one outside alone", async ({
  page,
}) => {
  await connectAll(page);
  await nested(page).locator("[data-role=click]").click();
  await outside(page).locator("[data-role=click]").click();
  await outside(page).locator("[data-role=sticky-click]").click();
  await syncLV(page);
  await expect(nested(page).locator("[data-role=clicks]")).toHaveText("1");
  await expect(outside(page).locator("[data-role=clicks]")).toHaveText("1");
  await expect(outside(page).locator("[data-role=sticky-clicks]")).toHaveText(
    "1",
  );
  expect(await embeddedConnected(page)).toEqual({
    nested: true,
    outside: true,
  });

  await page.locator("#to-other").click();
  await expect(page).toHaveURL(/\/multi-socket\/other$/);
  await expect(page.locator("[data-phx-session].phx-connected")).toHaveCount(5);
  await page.locator("#other-click").click();
  await syncLV(page);
  await expect(page.locator("#other-clicks")).toHaveText("1");

  // the slot went away with the old main view; the new page's slot
  // re-embedded the same LiveSocket, which kept its connection and left
  // the old roots behind
  expect(await embeddedConnected(page)).toEqual({
    nested: true,
    outside: true,
  });
  expect((await embeddedRoots(page)).nested).toEqual([
    { app: "embedded", inSlot: true, attached: true },
    { app: "sticky", inSlot: true, attached: true },
  ]);
  await expect(nested(page)).toHaveCount(1);
  await expect(nested(page).locator("[data-role=clicks]")).toHaveText("0");
  await expect(nested(page).locator("[data-role=sticky-clicks]")).toHaveText(
    "0",
  );
  await nested(page).locator("[data-role=click]").click();
  await syncLV(page);
  await expect(nested(page).locator("[data-role=clicks]")).toHaveText("1");
  await expect(page.locator("#other-clicks")).toHaveText("1");

  // the root outside the main view is untouched by the page's navigation,
  // and so is its sticky root: the new main view did not adopt it
  await expect(outside(page)).toHaveCount(1);
  await expect(outside(page).locator("[data-role=clicks]")).toHaveText("1");
  await expect(outside(page).locator("[data-role=sticky-clicks]")).toHaveText(
    "1",
  );
  await expect(page.locator("#sticky-outside")).toHaveCount(1);
  await expect(outside(page).locator("#sticky-outside")).toHaveCount(1);
  await expect(page.locator("[data-app=main] #sticky-outside")).toHaveCount(0);
  await expect(page.locator("[data-app=sticky]")).toHaveCount(2);
  await outside(page).locator("[data-role=click]").click();
  await outside(page).locator("[data-role=sticky-click]").click();
  await syncLV(page);
  await expect(outside(page).locator("[data-role=clicks]")).toHaveText("2");
  await expect(outside(page).locator("[data-role=sticky-clicks]")).toHaveText(
    "2",
  );
});

test("push_navigate from an embedded view is refused and reported", async ({
  page,
}) => {
  const errors = [];
  page.on(
    "console",
    (msg) => msg.type() === "error" && errors.push(msg.text()),
  );
  await connectAll(page);

  await nested(page).locator("[data-role=navigate]").click();

  await expect(nested(page)).toHaveClass(/phx-server-error/);
  await expect
    .poll(() =>
      errors.some((text) => text.includes("cannot navigate the page")),
    )
    .toBe(true);
  await expect(page).toHaveURL(/\/multi-socket$/);
  // the host and the other embedded root carry on
  await page.locator("#main-click").click();
  await expect(page.locator("#main-clicks")).toHaveText("1");
  await outside(page).locator("[data-role=click]").click();
  await expect(outside(page).locator("[data-role=clicks]")).toHaveText("1");
});

test("a navigate link inside embedded content is followed as a plain link", async ({
  page,
}) => {
  await connectAll(page);
  await page.evaluate(() => {
    window.__samePage = true;
  });

  await nested(page).locator("[data-role=navigate-link]").click();

  await expect(page).toHaveURL(/\/multi-socket\/other$/);
  // a full page load, not a live navigation of the host: main + nested + its sticky
  expect(await page.evaluate(() => window.__samePage)).toBeUndefined();
  await expect(page.locator("[data-phx-session].phx-connected")).toHaveCount(3);
});
