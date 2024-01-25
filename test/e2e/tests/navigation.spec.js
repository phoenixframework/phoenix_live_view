const { test, expect, request } = require("@playwright/test");
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
    { method: "GET", url: "http://localhost:4000/navigation/a" },
    { method: "GET", url: "http://localhost:4000/assets/phoenix/phoenix.min.js" },
    { method: "GET", url: "http://localhost:4000/assets/phoenix_live_view/phoenix_live_view.js" },
  ]);

  await expect(webSocketEvents).toEqual([
    expect.objectContaining({ type: "sent", payload: expect.stringContaining("phx_join") }),
    expect.objectContaining({ type: "received", payload: expect.stringContaining("phx_reply") }),
  ]);

  // clear events
  networkEvents = [];
  webSocketEvents = [];

  // patch the LV
  await page.getByRole("link", { name: "Patch this LiveView" }).click();
  await syncLV(page);
  await expect(networkEvents).toEqual([]);
  await expect(webSocketEvents).toEqual([
    expect.objectContaining({ type: "sent", payload: expect.stringContaining("live_patch") }),
    expect.objectContaining({ type: "received", payload: expect.stringContaining("phx_reply") }),
  ]);

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

test("falls back to http navigation when navigating between live sessions", async ({ page, browserName }) => {
  await page.goto("/navigation/a");
  await syncLV(page);

  networkEvents = [];
  webSocketEvents = [];

  // live navigation to page in another live session
  await page.getByRole("link", { name: "LiveView (other session)" }).click();
  await syncLV(page);

  await expect(networkEvents).toEqual(expect.arrayContaining([{ method: "GET", url: "http://localhost:4000/stream" }]));
  await expect(webSocketEvents).toEqual(expect.arrayContaining([
    { type: "sent", payload: expect.stringContaining("phx_leave") },
    { type: "sent", payload: expect.stringContaining("phx_join") },
    { type: "received", payload: expect.stringContaining("phx_close") },
    { type: "received", payload: expect.stringContaining("phx_reply") },
    { type: "received", payload: expect.stringMatching(/error.*unauthorized/) },
    { type: "sent", payload: expect.stringContaining("phx_join") },
    { type: "received", payload: expect.stringContaining("phx_reply") },
  ].concat(browserName === "webkit" ? [] : [{ type: "close" }])));
  // ^ webkit doesn't always seem to emit websocket close events
});

test("can prevent navigation with navigation guard", async ({ page }) => {
  await page.goto("/navigation/a");
  await syncLV(page);

  await page.getByRole("link", { name: "LiveView B" }).click();
  await syncLV(page);

  await expect(page.locator("form")).toBeVisible();
  await page.locator("input").fill("my text");
  await syncLV(page);

  networkEvents = [];
  webSocketEvents = [];

  // we expect a confirmation dialog
  page.once("dialog", dialog => dialog.dismiss());
  await page.getByRole("link", { name: "LiveView A" }).click();

  // we should not have navigated
  await expect(page).toHaveURL("/navigation/b");
  await expect(webSocketEvents).toEqual([]);
  await expect(page.locator("input")).toHaveValue("my text");

  // now we accept the dialog
  page.once("dialog", dialog => dialog.accept());
  await page.getByRole("link", { name: "LiveView A" }).click();
  await syncLV(page);

  // navigation should succeed
  await expect(page).toHaveURL("/navigation/a");
  await expect(networkEvents).toEqual([]);
});

test("history triggers navigation guard", async ({ page }) => {
  await page.goto("/navigation/a");
  await syncLV(page);

  await page.getByRole("link", { name: "LiveView B" }).click();
  await syncLV(page);

  await expect(page.locator("form")).toBeVisible();
  await page.locator("input").fill("my text");
  await syncLV(page);

  networkEvents = [];
  webSocketEvents = [];

  // we expect a confirmation dialog
  page.once("dialog", dialog => dialog.dismiss());
  await page.goBack();

  // we should not have navigated
  await expect(page).toHaveURL("/navigation/b");
  await expect(webSocketEvents).toEqual([]);
  await expect(page.locator("input")).toHaveValue("my text");

  // when we submitted the form navigation should succeed
  await page.getByRole("button", { name: "Submit" }).click();
  await syncLV(page);

  await page.goBack();
  await syncLV(page);
  await expect(page).toHaveURL("/navigation/a");
  await expect(networkEvents).toEqual([]);
});

test("navigation guard is triggered before and after navigation", async ({ page }) => {
  await page.goto("/navigation/a");
  await syncLV(page);

  await page.getByRole("link", { name: "LiveView B" }).click();
  await syncLV(page);

  const result = await page.evaluate(() => JSON.stringify(window.navigationEvents));
  await expect(JSON.parse(result)).toEqual([
    { type: "before", to: "http://localhost:4000/navigation/b", from: "http://localhost:4000/navigation/a" },
    { type: "after", to: "http://localhost:4000/navigation/b", from: "http://localhost:4000/navigation/a" },
  ])
});

test("restores scroll position after navigation", async ({ page }) => {
  await page.goto("/navigation/c");
  await syncLV(page);

  await expect(page.locator("#items")).toContainText("Item 42");

  await expect(await page.evaluate(() => document.body.scrollTop)).toEqual(0);
  await page.evaluate(() => window.scrollTo(0, 1200));
  // LiveView only updates the scroll position every 100ms
  await page.waitForTimeout(150);

  await page.getByRole("link", { name: "Item 42" }).click();
  await syncLV(page);

  await page.goBack();
  await syncLV(page);

  // scroll position is restored
  await expect.poll(
    async () => {
      return await page.evaluate(() => document.body.scrollTop);
    },
    { message: 'scrollTop not restored', timeout: 5000 }
  ).toBe(1200);
});

test("restores scroll position on custom container after navigation", async ({ page }) => {
  await page.goto("/navigation/c?container=1");
  await syncLV(page);

  await expect(page.locator("#items")).toContainText("Item 42");

  await expect(await page.locator("#my-scroll-container").evaluate((el) => el.scrollTop)).toEqual(0);
  await page.locator("#my-scroll-container").evaluate((el) => el.scrollTo(0, 1000));

  await page.getByRole("link", { name: "Item 42" }).click();
  await syncLV(page);

  await page.goBack();
  await syncLV(page);

  // scroll position is restored
  await expect(async () => {
    // in CI the scrolled value is somehow 1007 and not 1000
    // I'm not sure why, but it's consistent, so we just check for a range
    const position = await page.locator("#my-scroll-container").evaluate((el) => el.scrollTop)
    expect(position).toBeGreaterThanOrEqual(990);
    expect(position).toBeLessThanOrEqual(1010);
  },
    { message: 'scrollTop not restored', timeout: 5000 }
  ).toPass();
});
