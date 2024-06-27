const { test, expect } = require("../test-fixtures");
const { syncLV, attributeMutations } = require("../utils");

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

for (let path of ["/form/nested", "/form"]) {
  // see also https://github.com/phoenixframework/phoenix_live_view/issues/1759
  // https://github.com/phoenixframework/phoenix_live_view/issues/2993
  test.describe("restores disabled and readonly states", () => {
    test(`${path} - readonly state is restored after submits`, async ({ page }) => {
      await page.goto(path);
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

    test(`${path} - button disabled state is restored after submits`, async ({ page }) => {
      await page.goto(path);
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

    test(`${path} - non-form button (phx-disable-with) disabled state is restored after click`, async ({ page }) => {
      await page.goto(path);
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

  for (let additionalParams of ["live-component", ""]) {
    let append = additionalParams.length ? ` ${additionalParams}` : "";
    test.describe(`${path}${append} - form recovery`, () => {
      test("form state is recovered when socket reconnects", async ({ page }) => {
        let webSocketEvents = [];
        page.on("websocket", ws => {
          ws.on("framesent", event => webSocketEvents.push({ type: "sent", payload: event.payload }));
          ws.on("framereceived", event => webSocketEvents.push({ type: "received", payload: event.payload }));
          ws.on("close", () => webSocketEvents.push({ type: "close" }));
        });

        await page.goto(path + "?" + additionalParams);
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
          { type: "sent", payload: expect.stringMatching(/event.*_unused_a=&a=foo&_unused_b=&b=test/) },
        ]))
      });

      test("does not recover when form is missing id", async ({ page }) => {
        await page.goto(`${path}?no-id&${additionalParams}`);
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
        await page.goto(`${path}?no-change-event&${additionalParams}`);
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
        await page.goto(`${path}?phx-auto-recover=custom-recovery&${additionalParams}`);
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
          { type: "sent", payload: expect.stringMatching(/event.*_unused_a=&a=foo&_unused_b=&b=test/) },
        ]))
      });
    })
  }

  test(`${path} - can submit form with button that has phx-click`, async ({ page }) => {
    await page.goto(`${path}?phx-auto-recover=custom-recovery`);
    await syncLV(page);

    await expect(page.getByText("Form was submitted!")).not.toBeVisible();

    await page.getByRole("button", { name: "Submit with JS" }).click();
    await syncLV(page);

    await expect(page.getByText("Form was submitted!")).toBeVisible();
  });

  test(`${path} - loading and locked states with latency`, async ({ page }) => {
    await page.goto(`${path}?phx-change=validate`);
    await syncLV(page);
    await page.evaluate(() => window.liveSocket.enableLatencySim(2000));
    await expect(page.getByText("Form was submitted!")).not.toBeVisible();
    let testForm = page.locator("#test-form");
    let submitBtn = page.locator("#test-form #submit");
    await page.locator("#test-form input[name=b]").fill("test");
    await expect(testForm).toHaveClass("myformclass phx-change-loading");
    await expect(testForm).toHaveAttribute("data-phx-ref-loading");
    await expect(testForm).toHaveAttribute("data-phx-ref-lock");
    await expect(testForm).toHaveAttribute("data-phx-ref-src");
    // we need to sleep to ensure the phx-change ref arrives sufficiently before the phx-submit ref
    // to make our assertions about the intermediate states
    await sleep(1000)
    await submitBtn.click();
    await expect(testForm).toHaveClass("myformclass phx-change-loading phx-submit-loading");
    await sleep(1000)
    // phx-change ack arrives and is removed
    await expect(testForm).toHaveClass("myformclass phx-submit-loading");
    await expect(submitBtn).toHaveClass("phx-submit-loading");
    await expect(submitBtn).toHaveAttribute("data-phx-disable-with-restore", "Submit");
    await expect(submitBtn).toHaveAttribute("data-phx-ref-loading");
    await expect(testForm).toHaveAttribute("data-phx-ref-loading");
    await expect(testForm).toHaveAttribute("data-phx-ref-src");
    await expect(submitBtn).toHaveAttribute("data-phx-ref-lock");
    await expect(testForm).not.toHaveAttribute("data-phx-ref-lock");
    await expect(submitBtn).toHaveAttribute("data-phx-ref-src");
    await expect(submitBtn).toHaveAttribute("disabled", "");
    await expect(submitBtn).toHaveAttribute("phx-disable-with", "Submitting");
    await expect(page.getByText("Form was submitted!")).toBeVisible();
    // all refs are cleaned up
    await expect(testForm).toHaveClass("myformclass");
    await expect(submitBtn).toHaveClass("");
    await expect(submitBtn).not.toHaveAttribute("data-phx-disable-with-restore");
    await expect(submitBtn).not.toHaveAttribute("data-phx-ref-loading");
    await expect(submitBtn).not.toHaveAttribute("data-phx-ref-lock");
    await expect(submitBtn).not.toHaveAttribute("data-phx-ref-src");
    await expect(submitBtn).not.toHaveAttribute("data-phx-ref-loading");
    await expect(submitBtn).not.toHaveAttribute("data-phx-ref-lock");
    await expect(submitBtn).not.toHaveAttribute("data-phx-ref-src");
    await expect(submitBtn).not.toHaveAttribute("disabled");
    await expect(submitBtn).toHaveAttribute("phx-disable-with", "Submitting");
    await page.evaluate(() => window.liveSocket.disableLatencySim());
  });
}

test("can dynamically add/remove inputs (ecto sort_param/drop_param)", async ({ page }) => {
  await page.goto("/form/dynamic-inputs");
  await syncLV(page);

  const formData = () => page.locator("form").evaluate(form => Object.fromEntries(new FormData(form).entries()));

  await expect(await formData()).toEqual({
    "my_form[name]": "",
    "my_form[users_drop][]": ""
  });

  await page.locator("#my-form_name").fill("Test");
  await page.getByRole("button", { name: "add more" }).click();

  await expect(await formData()).toEqual(expect.objectContaining({
    "my_form[name]": "Test",
    "my_form[users][0][name]": "",
  }));

  await page.locator("#my-form_users_0_name").fill("User A");
  await page.getByRole("button", { name: "add more" }).click();
  await page.getByRole("button", { name: "add more" }).click();

  await page.locator("#my-form_users_1_name").fill("User B");
  await page.locator("#my-form_users_2_name").fill("User C");

  await expect(await formData()).toEqual(expect.objectContaining({
    "my_form[name]": "Test",
    "my_form[users_drop][]": "",
    "my_form[users][0][name]": "User A",
    "my_form[users][1][name]": "User B",
    "my_form[users][2][name]": "User C"
  }));

  // remove User B
  await page.locator("button[name=\"my_form[users_drop][]\"][value=\"1\"]").click();

  await expect(await formData()).toEqual(expect.objectContaining({
    "my_form[name]": "Test",
    "my_form[users_drop][]": "",
    "my_form[users][0][name]": "User A",
    "my_form[users][1][name]": "User C"
  }));
});

test("can dynamically add/remove inputs using checkboxes", async ({ page }) => {
  await page.goto("/form/dynamic-inputs?checkboxes=1");
  await syncLV(page);

  const formData = () => page.locator("form").evaluate(form => Object.fromEntries(new FormData(form).entries()));

  await expect(await formData()).toEqual({
    "my_form[name]": "",
    "my_form[users_drop][]": ""
  });

  await page.locator("#my-form_name").fill("Test");
  await page.locator("label", { hasText: "add more" }).click();

  await expect(await formData()).toEqual(expect.objectContaining({
    "my_form[name]": "Test",
    "my_form[users][0][name]": "",
  }));

  await page.locator("#my-form_users_0_name").fill("User A");
  await page.locator("label", { hasText: "add more" }).click();
  await page.locator("label", { hasText: "add more" }).click();

  await page.locator("#my-form_users_1_name").fill("User B");
  await page.locator("#my-form_users_2_name").fill("User C");

  await expect(await formData()).toEqual(expect.objectContaining({
    "my_form[name]": "Test",
    "my_form[users_drop][]": "",
    "my_form[users][0][name]": "User A",
    "my_form[users][1][name]": "User B",
    "my_form[users][2][name]": "User C"
  }));

  // remove User B
  await page.locator("input[name=\"my_form[users_drop][]\"][value=\"1\"]").click();

  await expect(await formData()).toEqual(expect.objectContaining({
    "my_form[name]": "Test",
    "my_form[users_drop][]": "",
    "my_form[users][0][name]": "User A",
    "my_form[users][1][name]": "User C"
  }));
});

// phx-feedback-for was removed in LiveView 1.0, but we still test the shim applied in
// test_helper.exs layout for backwards compatibility
test("phx-no-feedback is applied correctly for backwards-compatible-shims", async ({ page }) => {
  await page.goto("/form/feedback");
  await syncLV(page);

  await expect(page.locator("[phx-feedback-for=myfeedback]")).not.toBeVisible();
  await page.getByRole("button", { name: "+" }).click();
  await syncLV(page);
  await expect(page.locator("[phx-feedback-for=myfeedback]")).not.toBeVisible();
  await expect(page.getByText("Validate count")).toContainText("0");

  await page.locator("input[name=name]").fill("Test");
  await syncLV(page);
  await expect(page.locator("[phx-feedback-for=myfeedback]")).not.toBeVisible();
  await expect(page.getByText("Validate count")).toContainText("1");

  await page.locator("input[name=myfeedback]").fill("Test");
  await syncLV(page);
  await expect(page.getByText("Validate count")).toContainText("2");
  await expect(page.locator("[phx-feedback-for=myfeedback]")).toBeVisible();

  // feedback appears on submit
  await page.reload();
  await syncLV(page);
  await expect(page.locator("[phx-feedback-for=myfeedback]")).not.toBeVisible();

  await page.getByRole("button", { name: "Submit" }).click();
  await syncLV(page);
  await expect(page.getByText("Submit count")).toContainText("1");
  await expect(page.locator("[phx-feedback-for=myfeedback]")).toBeVisible();

  // feedback hides on reset
  await page.getByRole("button", { name: "Reset" }).click();
  await syncLV(page);
  await expect(page.locator("[phx-feedback-for=myfeedback]")).not.toBeVisible();

  // can toggle feedback visibility
  await page.reload();
  await syncLV(page);
  await expect(page.locator("[data-feedback-container]")).not.toBeVisible();

  await page.getByRole("button", { name: "Toggle feedback" }).click();
  await syncLV(page);
  await expect(page.locator("[data-feedback-container]")).toBeVisible();

  await page.getByRole("button", { name: "Toggle feedback" }).click();
  await syncLV(page);
  await expect(page.locator("[data-feedback-container]")).not.toBeVisible();
});

