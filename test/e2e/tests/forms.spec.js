const { test, expect } = require("@playwright/test");
const { syncLV, attributeMutations } = require("../utils");

// see also https://github.com/phoenixframework/phoenix_live_view/issues/1759
// https://github.com/phoenixframework/phoenix_live_view/issues/2993
test.describe("restores disabled and readonly states", () => {
  test("readonly state is restored after submits", async ({ page }) => {
    await page.goto("/form");
    await syncLV(page);
    await expect(page.locator("input[name=a]")).toHaveAttribute("readonly");
    let changesA = attributeMutations(page, "input[name=a]");
    let changesB = attributeMutations(page, "input[name=b]");
    // can submit multiple times and readonly input stays readonly
    await page.locator("#submit").click();
    await syncLV(page);
    // a is readonly and should stay readonly
    await expect(await changesA()).toEqual(expect.arrayContaining([
      { attr: "data-phx-readonly", oldValue: null, newValue: "true" },
      { attr: "readonly", oldValue: "", newValue: "" },
      { attr: "data-phx-readonly", oldValue: "true", newValue: null },
      { attr: "readonly", oldValue: "", newValue: "" },
    ]));
    // b is not readonly, but LV will set it to readonly while submitting
    await expect(await changesB()).toEqual(expect.arrayContaining([
      { attr: "data-phx-readonly", oldValue: null, newValue: "false" },
      { attr: "readonly", oldValue: null, newValue: "" },
      { attr: "data-phx-readonly", oldValue: "false", newValue: null },
      { attr: "readonly", oldValue: "", newValue: null },
    ]));
    await expect(page.locator("input[name=a]")).toHaveAttribute("readonly");
    await page.locator("#submit").click();
    await syncLV(page);
    await expect(page.locator("input[name=a]")).toHaveAttribute("readonly");
  });

  test("button disabled state is restored after submits", async ({ page }) => {
    await page.goto("/form");
    await syncLV(page);
    let changes = attributeMutations(page, "#submit");
    await page.locator("#submit").click();
    await syncLV(page);
    // submit button is disabled while submitting, but then restored
    await expect(await changes()).toEqual(expect.arrayContaining([
      { attr: "data-phx-disabled", oldValue: null, newValue: "false" },
      { attr: "disabled", oldValue: null, newValue: "" },
      { attr: "class", oldValue: null, newValue: "phx-submit-loading" },
      { attr: "data-phx-disabled", oldValue: "false", newValue: null },
      { attr: "disabled", oldValue: "", newValue: null },
      { attr: "class", oldValue: "phx-submit-loading", newValue: null },
    ]));
  });

  test("non-form button (phx-disable-with) disabled state is restored after click", async ({ page }) => {
    await page.goto("/form");
    await syncLV(page);
    let changes = attributeMutations(page, "button[type=button]");
    await page.locator("button[type=button]").click();
    await syncLV(page);
    // submit button is disabled while submitting, but then restored
    await expect(await changes()).toEqual(expect.arrayContaining([
      { attr: "data-phx-disabled", oldValue: null, newValue: "false" },
      { attr: "disabled", oldValue: null, newValue: "" },
      { attr: "class", oldValue: null, newValue: "phx-click-loading" },
      { attr: "data-phx-disabled", oldValue: "false", newValue: null },
      { attr: "disabled", oldValue: "", newValue: null },
      { attr: "class", oldValue: "phx-click-loading", newValue: null },
    ]));
  });
});

test.describe("form recovery", () => {
  test("form state is recovered when socket reconnects", async ({ page }) => {
    let webSocketEvents = [];
    page.on("websocket", ws => {
      ws.on("framesent", event => webSocketEvents.push({ type: "sent", payload: event.payload }));
      ws.on("framereceived", event => webSocketEvents.push({ type: "received", payload: event.payload }));
      ws.on("close", () => webSocketEvents.push({ type: "close" }));
    });

    await page.goto("/form");
    await syncLV(page);

    await page.locator("input[name=b]").fill("test");
    await syncLV(page);

    await page.evaluate(() => new Promise((resolve) => window.liveSocket.disconnect(resolve)));
    await expect(page.locator(".phx-loading")).toHaveCount(1);

    await expect(webSocketEvents).toEqual(expect.arrayContaining([
      { type: "sent", payload: expect.stringContaining("phx_join") },
      { type: "received", payload: expect.stringContaining("phx_reply") },
      { type: "close" },
    ]))

    webSocketEvents = [];

    await page.evaluate(() => window.liveSocket.connect());
    await syncLV(page);
    await expect(page.locator(".phx-loading")).toHaveCount(0);

    await expect(page.locator("input[name=b]")).toHaveValue("test");

    await expect(webSocketEvents).toEqual(expect.arrayContaining([
      { type: "sent", payload: expect.stringContaining("phx_join") },
      { type: "received", payload: expect.stringContaining("phx_reply") },
      { type: "sent", payload: expect.stringMatching(/event.*a=foo&b=test/) },
    ]))
  });

  test("does not recover when form is missing id", async ({ page }) => {
    await page.goto("/form?no-id");
    await syncLV(page);

    await page.locator("input[name=b]").fill("test");
    await syncLV(page);

    await page.evaluate(() => new Promise((resolve) => window.liveSocket.disconnect(resolve)));
    await expect(page.locator(".phx-loading")).toHaveCount(1);

    await page.evaluate(() => window.liveSocket.connect());
    await syncLV(page);
    await expect(page.locator(".phx-loading")).toHaveCount(0);

    await expect(page.locator("input[name=b]")).toHaveValue("bar");
  });

  test("does not recover when form is missing phx-change", async ({ page }) => {
    await page.goto("/form?no-change-event");
    await syncLV(page);

    await page.locator("input[name=b]").fill("test");
    await syncLV(page);

    await page.evaluate(() => new Promise((resolve) => window.liveSocket.disconnect(resolve)));
    await expect(page.locator(".phx-loading")).toHaveCount(1);

    await page.evaluate(() => window.liveSocket.connect());
    await syncLV(page);
    await expect(page.locator(".phx-loading")).toHaveCount(0);

    await expect(page.locator("input[name=b]")).toHaveValue("bar");
  });

  test("phx-auto-recover", async ({ page }) => {
    await page.goto("/form?phx-auto-recover=custom-recovery");
    await syncLV(page);

    await page.locator("input[name=b]").fill("test");
    await syncLV(page);

    await page.evaluate(() => new Promise((resolve) => window.liveSocket.disconnect(resolve)));
    await expect(page.locator(".phx-loading")).toHaveCount(1);

    let webSocketEvents = [];
    page.on("websocket", ws => {
      ws.on("framesent", event => webSocketEvents.push({ type: "sent", payload: event.payload }));
      ws.on("framereceived", event => webSocketEvents.push({ type: "received", payload: event.payload }));
      ws.on("close", () => webSocketEvents.push({ type: "close" }));
    });

    await page.evaluate(() => window.liveSocket.connect());
    await syncLV(page);
    await expect(page.locator(".phx-loading")).toHaveCount(0);

    await expect(page.locator("input[name=b]")).toHaveValue("custom value from server");

    await expect(webSocketEvents).toEqual(expect.arrayContaining([
      { type: "sent", payload: expect.stringContaining("phx_join") },
      { type: "received", payload: expect.stringContaining("phx_reply") },
      { type: "sent", payload: expect.stringMatching(/event.*a=foo&b=test/) },
    ]))
  });
})

test("can submit form with button that has phx-click", async ({ page }) => {
  await page.goto("/form?phx-auto-recover=custom-recovery");
  await syncLV(page);

  await expect(page.getByText("Form was submitted!")).not.toBeVisible();

  await page.getByRole("button", { name: "Submit with JS" }).click();
  await syncLV(page);

  await expect(page.getByText("Form was submitted!")).toBeVisible();
});
