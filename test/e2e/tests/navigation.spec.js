const { test, expect } = require("../test-fixtures");
const { syncLV } = require("../utils");

let webSocketEvents = [];
let networkEvents = [];

test.beforeEach(async ({ page }) => {
  networkEvents = [];
  webSocketEvents = [];

  page.on("request", request => networkEvents.push({ method: request.method(), url: request.url() }));

  page.on("websocket", ws => {
    ws.on("framesent", event => webSocketEvents.push({ type: "sent", payload: event.payload }));
    ws.on("framereceived", event => webSocketEvents.push({ type: "received", payload: event.payload }));
    ws.on("close", () => webSocketEvents.push({ type: "close" }));
  });
});

test("can navigate between LiveViews in the same live session over websocket", async ({ page }) => {
  await page.goto("/navigation/a");
  await syncLV(page);

  await expect(networkEvents).toEqual([
    { method: "GET", url: "http://localhost:4004/navigation/a" },
    { method: "GET", url: "http://localhost:4004/assets/phoenix/phoenix.min.js" },
    { method: "GET", url: "http://localhost:4004/assets/phoenix_live_view/phoenix_live_view.esm.js" },
  ]);

  await expect(webSocketEvents).toEqual([
    expect.objectContaining({ type: "sent", payload: expect.stringContaining("phx_join") }),
    expect.objectContaining({ type: "received", payload: expect.stringContaining("phx_reply") }),
  ]);

  // clear events
  networkEvents = [];
  webSocketEvents = [];

  // patch the LV
  const length = await page.evaluate(() => window.history.length);
  await page.getByRole("link", { name: "Patch this LiveView" }).click();
  await syncLV(page);
  await expect(networkEvents).toEqual([]);
  await expect(webSocketEvents).toEqual([
    expect.objectContaining({ type: "sent", payload: expect.stringContaining("live_patch") }),
    expect.objectContaining({ type: "received", payload: expect.stringContaining("phx_reply") }),
  ]);
  await expect(await page.evaluate(() => window.history.length)).toEqual(length + 1);

  webSocketEvents = [];

  // live navigation to other LV
  await page.getByRole("link", { name: "LiveView B" }).click();
  await syncLV(page);

  await expect(networkEvents).toEqual([]);
  // we don't assert the order of the events here, because they are not deterministic
  await expect(webSocketEvents).toEqual(expect.arrayContaining([
    { type: "sent", payload: expect.stringContaining("phx_leave") },
    { type: "sent", payload: expect.stringContaining("phx_join") },
    { type: "received", payload: expect.stringContaining("phx_close") },
    { type: "received", payload: expect.stringContaining("phx_reply") },
    { type: "received", payload: expect.stringContaining("phx_reply") },
  ]));
});

test("popstate", async ({ page }) => {
  await page.goto("/navigation/a");
  await syncLV(page);

  // clear network events
  networkEvents = [];

  await page.getByRole("link", { name: "Patch this LiveView" }).click();
  await syncLV(page);
  await expect(page).toHaveURL(/\/navigation\/a\?/);
  await expect(networkEvents).toEqual([]);

  await page.getByRole("link", { name: "LiveView B" }).click(),
  await syncLV(page);
  await expect(page).toHaveURL("/navigation/b");
  await expect(networkEvents).toEqual([]);

  await page.goBack();
  await syncLV(page);
  await expect(networkEvents).toEqual([]);
  await expect(page).toHaveURL(/\/navigation\/a\?/);

  await page.goBack();
  await syncLV(page);
  await expect(networkEvents).toEqual([]);
  await expect(page).toHaveURL("/navigation/a");

  // and forward again
  await page.goForward();
  await page.goForward();
  await syncLV(page);
  await expect(page).toHaveURL("/navigation/b");

  // everything was sent over the websocket, no network requests
  await expect(networkEvents).toEqual([]);
});

test("patch with replace replaces history", async ({ page }) => {
  await page.goto("/navigation/a");
  await syncLV(page);
  const url = page.url();

  const length = await page.evaluate(() => window.history.length);

  await page.getByRole("link", { name: "Patch (Replace)" }).click();
  await syncLV(page);

  await expect(await page.evaluate(() => window.history.length)).toEqual(length);
  await expect(page.url()).not.toEqual(url);
});

test("falls back to http navigation when navigating between live sessions", async ({ page, browserName }) => {
  await page.goto("/navigation/a");
  await syncLV(page);

  networkEvents = [];
  webSocketEvents = [];

  // live navigation to page in another live session
  await page.getByRole("link", { name: "LiveView (other session)" }).click();
  await syncLV(page);

  await expect(networkEvents).toEqual(expect.arrayContaining([{ method: "GET", url: "http://localhost:4004/stream" }]));
  await expect(webSocketEvents).toEqual(expect.arrayContaining([
    { type: "sent", payload: expect.stringContaining("phx_leave") },
    { type: "sent", payload: expect.stringContaining("phx_join") },
    { type: "received", payload: expect.stringMatching(/error.*unauthorized/) },
  ].concat(browserName === "webkit" ? [] : [{ type: "close" }])));
  // ^ webkit doesn't always seem to emit websocket close events
});

test("restores scroll position after navigation", async ({ page }) => {
  await page.goto("/navigation/b");
  await syncLV(page);

  await expect(page.locator("#items")).toContainText("Item 42");

  await expect(await page.evaluate(() => document.documentElement.scrollTop)).toEqual(0);
  const offset = (await page.locator("#items-item-42").evaluate((el) => el.offsetTop)) - 200;
  await page.evaluate((offset) => window.scrollTo(0, offset), offset);
  // LiveView only updates the scroll position every 100ms
  await page.waitForTimeout(150);

  await page.getByRole("link", { name: "Item 42" }).click();
  await syncLV(page);

  await page.goBack();
  await syncLV(page);

  // scroll position is restored
  await expect.poll(
    async () => {
      return await page.evaluate(() => document.documentElement.scrollTop);
    },
    { message: 'scrollTop not restored', timeout: 5000 }
  ).toBe(offset);
});

test("does not restore scroll position on custom container after navigation", async ({ page }) => {
  await page.goto("/navigation/b?container=1");
  await syncLV(page);

  await expect(page.locator("#items")).toContainText("Item 42");

  await expect(await page.locator("#my-scroll-container").evaluate((el) => el.scrollTop)).toEqual(0);
  const offset = (await page.locator("#items-item-42").evaluate((el) => el.offsetTop)) - 200;
  await page.locator("#my-scroll-container").evaluate((el, offset) => el.scrollTo(0, offset), offset);

  await page.getByRole("link", { name: "Item 42" }).click();
  await syncLV(page);

  await page.goBack();
  await syncLV(page);

  // scroll position is not restored
  await expect.poll(
    async () => {
      return await page.locator("#my-scroll-container").evaluate((el) => el.scrollTop);
    },
    { message: 'scrollTop not restored', timeout: 5000 }
  ).toBe(0);
});

test("scrolls hash el into view", async ({ page }) => {
  await page.goto("/navigation/b");
  await syncLV(page);

  await expect(page.locator("#items")).toContainText("Item 42");

  await expect(await page.locator("#my-scroll-container").evaluate((el) => el.scrollTop)).toEqual(0);
  const offset = (await page.locator("#items-item-42").evaluate((el) => el.offsetTop)) - 200;

  await page.getByRole("link", { name: "Go to 42" }).click();
  await expect(page).toHaveURL("/navigation/b#items-item-42");

  let scrollTop = await page.evaluate(() => document.documentElement.scrollTop)
  await expect(scrollTop).not.toBe(0);
  await expect(scrollTop).toBeGreaterThanOrEqual(offset - 500);
  await expect(scrollTop).toBeLessThanOrEqual(offset + 500);

  await page.goto("/navigation/a");
  await page.goto("/navigation/b#items-item-42");

  scrollTop = await page.evaluate(() => document.documentElement.scrollTop)
  await expect(scrollTop).not.toBe(0);
  await expect(scrollTop).toBeGreaterThanOrEqual(offset - 500);
  await expect(scrollTop).toBeLessThanOrEqual(offset + 500);
});
