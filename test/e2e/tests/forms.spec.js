import { test, expect } from "../test-fixtures";
import { syncLV, evalLV, evalPlug, attributeMutations } from "../utils";

for (const path of ["/form/nested", "/form"]) {
  // see also https://github.com/phoenixframework/phoenix_live_view/issues/1759
  // https://github.com/phoenixframework/phoenix_live_view/issues/2993
  test.describe("restores disabled and readonly states", () => {
    test(`${path} - readonly state is restored after submits`, async ({
      page,
    }) => {
      await page.goto(path);
      await syncLV(page);
      await expect(page.locator("input[name=a]")).toHaveAttribute("readonly");
      const changesA = attributeMutations(page, "input[name=a]");
      const changesB = attributeMutations(page, "input[name=b]");
      // can submit multiple times and readonly input stays readonly
      await page.locator("#submit").click();
      await syncLV(page);
      // a is readonly and should stay readonly
      expect(await changesA()).toEqual(
        expect.arrayContaining([
          { attr: "data-phx-readonly", oldValue: null, newValue: "true" },
          { attr: "readonly", oldValue: "", newValue: "" },
          { attr: "data-phx-readonly", oldValue: "true", newValue: null },
          { attr: "readonly", oldValue: "", newValue: "" },
        ]),
      );
      // b is not readonly, but LV will set it to readonly while submitting
      expect(await changesB()).toEqual(
        expect.arrayContaining([
          { attr: "data-phx-readonly", oldValue: null, newValue: "false" },
          { attr: "readonly", oldValue: null, newValue: "" },
          { attr: "data-phx-readonly", oldValue: "false", newValue: null },
          { attr: "readonly", oldValue: "", newValue: null },
        ]),
      );
      await expect(page.locator("input[name=a]")).toHaveAttribute("readonly");
      await page.locator("#submit").click();
      await syncLV(page);
      await expect(page.locator("input[name=a]")).toHaveAttribute("readonly");
    });

    test(`${path} - button disabled state is restored after submits`, async ({
      page,
    }) => {
      await page.goto(path);
      await syncLV(page);
      const changes = attributeMutations(page, "#submit");
      await page.locator("#submit").click();
      await syncLV(page);
      // submit button is disabled while submitting, but then restored
      expect(await changes()).toEqual(
        expect.arrayContaining([
          { attr: "data-phx-disabled", oldValue: null, newValue: "false" },
          { attr: "disabled", oldValue: null, newValue: "" },
          { attr: "class", oldValue: null, newValue: "phx-submit-loading" },
          { attr: "data-phx-disabled", oldValue: "false", newValue: null },
          { attr: "disabled", oldValue: "", newValue: null },
          { attr: "class", oldValue: "phx-submit-loading", newValue: null },
        ]),
      );
    });

    test(`${path} - non-form button (phx-disable-with) disabled state is restored after click`, async ({
      page,
    }) => {
      await page.goto(path);
      await syncLV(page);
      const changes = attributeMutations(page, "button[type=button]");
      await page.locator("button[type=button]").click();
      await syncLV(page);
      // submit button is disabled while submitting, but then restored
      expect(await changes()).toEqual(
        expect.arrayContaining([
          { attr: "data-phx-disabled", oldValue: null, newValue: "false" },
          { attr: "disabled", oldValue: null, newValue: "" },
          { attr: "class", oldValue: null, newValue: "phx-click-loading" },
          { attr: "data-phx-disabled", oldValue: "false", newValue: null },
          { attr: "disabled", oldValue: "", newValue: null },
          { attr: "class", oldValue: "phx-click-loading", newValue: null },
        ]),
      );
    });
  });

  for (const additionalParams of ["live-component", ""]) {
    const append = additionalParams.length ? ` ${additionalParams}` : "";
    test.describe(`${path}${append} - form recovery`, () => {
      test("form state is recovered when socket reconnects", async ({
        page,
      }) => {
        let webSocketEvents = [];
        page.on("websocket", (ws) => {
          ws.on("framesent", (event) =>
            webSocketEvents.push({ type: "sent", payload: event.payload }),
          );
          ws.on("framereceived", (event) =>
            webSocketEvents.push({ type: "received", payload: event.payload }),
          );
          ws.on("close", () => webSocketEvents.push({ type: "close" }));
        });

        await page.goto(path + "?" + additionalParams);
        await syncLV(page);

        await page.locator("input[name=b]").fill("test");
        await page.locator("input[name=c]").fill("hello world");
        await page.locator("select[name=d]").selectOption("bar");
        await expect(page.locator("input[name=c]")).toBeFocused();
        await syncLV(page);

        await page.evaluate(
          () => new Promise((resolve) => window.liveSocket.disconnect(resolve)),
        );
        await expect(page.locator(".phx-loading")).toHaveCount(1);

        expect(webSocketEvents).toEqual(
          expect.arrayContaining([
            { type: "sent", payload: expect.stringContaining("phx_join") },
            { type: "received", payload: expect.stringContaining("phx_reply") },
            { type: "close" },
          ]),
        );

        webSocketEvents = [];

        await page.evaluate(() => window.liveSocket.connect());
        await syncLV(page);
        await expect(page.locator(".phx-loading")).toHaveCount(0);

        await expect(page.locator("input[name=b]")).toHaveValue("test");
        // c should still be focused (at least when not using a nested LV)
        if (path === "/form") {
          await expect(page.locator("input[name=c]")).toBeFocused();
        }
        await expect(page.locator("select[name=d]")).toHaveValue("bar");

        expect(webSocketEvents).toEqual(
          expect.arrayContaining([
            { type: "sent", payload: expect.stringContaining("phx_join") },
            { type: "received", payload: expect.stringContaining("phx_reply") },
            {
              type: "sent",
              payload: expect.stringMatching(/event.*_unused_a=&a=foo&b=test/),
            },
          ]),
        );
      });

      test("JS command in phx-change works during recovery", async ({
        page,
      }) => {
        await page.goto(path + "?" + additionalParams + "&js-change=1");
        await syncLV(page);

        await page.locator("input[name=b]").fill("test");
        // blur, otherwise the input would not be morphed anyway
        await page.locator("input[name=b]").blur();
        await expect(page.locator("form")).toHaveAttribute(
          "phx-change",
          /push/,
        );
        await syncLV(page);

        await page.evaluate(
          () => new Promise((resolve) => window.liveSocket.disconnect(resolve)),
        );
        await expect(page.locator(".phx-loading")).toHaveCount(1);

        await page.evaluate(() => window.liveSocket.connect());
        await syncLV(page);
        await expect(page.locator(".phx-loading")).toHaveCount(0);
        await expect(page.locator("input[name=b]")).toHaveValue("test");
      });

      test("does not recover when form is missing id", async ({ page }) => {
        await page.goto(`${path}?no-id&${additionalParams}`);
        await syncLV(page);

        await page.locator("input[name=b]").fill("test");
        // blur, otherwise the input would not be morphed anyway
        await page.locator("input[name=b]").blur();
        await syncLV(page);

        await page.evaluate(
          () => new Promise((resolve) => window.liveSocket.disconnect(resolve)),
        );
        await expect(page.locator(".phx-loading")).toHaveCount(1);

        await page.evaluate(() => window.liveSocket.connect());
        await syncLV(page);
        await expect(page.locator(".phx-loading")).toHaveCount(0);

        await expect(page.locator("input[name=b]")).toHaveValue("bar");
      });

      test("does not recover when form is missing phx-change", async ({
        page,
      }) => {
        await page.goto(`${path}?no-change-event&${additionalParams}`);
        await syncLV(page);

        await page.locator("input[name=b]").fill("test");
        // blur, otherwise the input would not be morphed anyway
        await page.locator("input[name=b]").blur();
        await syncLV(page);

        await page.evaluate(
          () => new Promise((resolve) => window.liveSocket.disconnect(resolve)),
        );
        await expect(page.locator(".phx-loading")).toHaveCount(1);

        await page.evaluate(() => window.liveSocket.connect());
        await syncLV(page);
        await expect(page.locator(".phx-loading")).toHaveCount(0);

        await expect(page.locator("input[name=b]")).toHaveValue("bar");
      });

      test("phx-auto-recover", async ({ page }) => {
        await page.goto(
          `${path}?phx-auto-recover=custom-recovery&${additionalParams}`,
        );
        await syncLV(page);

        await page.locator("input[name=b]").fill("test");
        // blur, otherwise the input would not be morphed anyway
        await page.locator("input[name=b]").blur();
        await syncLV(page);

        await page.evaluate(
          () => new Promise((resolve) => window.liveSocket.disconnect(resolve)),
        );
        await expect(page.locator(".phx-loading")).toHaveCount(1);

        const webSocketEvents = [];
        page.on("websocket", (ws) => {
          ws.on("framesent", (event) =>
            webSocketEvents.push({ type: "sent", payload: event.payload }),
          );
          ws.on("framereceived", (event) =>
            webSocketEvents.push({ type: "received", payload: event.payload }),
          );
          ws.on("close", () => webSocketEvents.push({ type: "close" }));
        });

        await page.evaluate(() => window.liveSocket.connect());
        await syncLV(page);
        await expect(page.locator(".phx-loading")).toHaveCount(0);

        await expect(page.locator("input[name=b]")).toHaveValue(
          "custom value from server",
        );

        expect(webSocketEvents).toEqual(
          expect.arrayContaining([
            { type: "sent", payload: expect.stringContaining("phx_join") },
            { type: "received", payload: expect.stringContaining("phx_reply") },
            {
              type: "sent",
              payload: expect.stringMatching(/event.*_unused_a=&a=foo&b=test/),
            },
          ]),
        );
      });

      test("respects disabled state of a fieldset", async ({ page }) => {
        let webSocketEvents = [];
        page.on("websocket", (ws) => {
          ws.on("framesent", (event) =>
            webSocketEvents.push({ type: "sent", payload: event.payload }),
          );
          ws.on("framereceived", (event) =>
            webSocketEvents.push({ type: "received", payload: event.payload }),
          );
          ws.on("close", () => webSocketEvents.push({ type: "close" }));
        });

        await page.goto(path + "?disabled-fieldset=true&" + additionalParams);
        await syncLV(page);

        await page.locator("input[name=c]").fill("hello world");
        await page.locator("select[name=d]").selectOption("bar");
        await expect(page.locator("input[name=c]")).toBeFocused();
        await syncLV(page);

        await page.evaluate(
          () => new Promise((resolve) => window.liveSocket.disconnect(resolve)),
        );
        await expect(page.locator(".phx-loading")).toHaveCount(1);

        webSocketEvents = [];
        await page.evaluate(() => window.liveSocket.connect());
        await syncLV(page);
        await expect(page.locator(".phx-loading")).toHaveCount(0);

        expect(webSocketEvents).toEqual(
          expect.arrayContaining([
            { type: "sent", payload: expect.stringContaining("phx_join") },
            { type: "received", payload: expect.stringContaining("phx_reply") },
            {
              type: "sent",
              payload: expect.stringMatching(/event.*"c=hello\+world&d=bar"/),
            },
          ]),
        );
      });
    });
  }

  test(`${path} - can submit form with button that has phx-click`, async ({
    page,
  }) => {
    await page.goto(`${path}?phx-auto-recover=custom-recovery`);
    await syncLV(page);

    await expect(page.getByText("Form was submitted!")).toBeHidden();

    await page.getByRole("button", { name: "Submit with JS" }).click();
    await syncLV(page);

    await expect(page.getByText("Form was submitted!")).toBeVisible();
  });

  test(`${path} - loading and locked states with latency`, async ({
    page,
    request,
  }) => {
    const nested = !!path.match(/nested/);
    await page.goto(`${path}?phx-change=validate`);
    await syncLV(page);
    const { lv_pid } = await evalLV(
      page,
      `
      <<"#PID"::binary, pid::binary>> = inspect(self())

      pid_parts =
        pid
        |> String.trim_leading("<")
        |> String.trim_trailing(">")
        |> String.split(".")

      %{lv_pid: pid_parts}
    `,
      nested ? "#nested" : undefined,
    );
    const ack = (event) =>
      evalPlug(
        request,
        `send(IEx.Helpers.pid(${lv_pid[0]}, ${lv_pid[1]}, ${lv_pid[2]}), {:sync, "${event}"}); nil`,
      );
    // we serialize the test by letting each event handler wait for a {:sync, event} message
    await evalLV(
      page,
      `
      attach_hook(socket, :sync, :handle_event, fn event, _params, socket ->
        if event == "ping" do
          {:cont, socket}
        else
          receive do {:sync, ^event} -> {:cont, socket} end
        end
      end)
    `,
      nested ? "#nested" : undefined,
    );
    await expect(page.getByText("Form was submitted!")).toBeHidden();
    const testForm = page.locator("#test-form");
    const submitBtn = page.locator("#test-form #submit");
    await page.locator("#test-form input[name=b]").fill("test");
    await expect(testForm).toHaveClass("myformclass phx-change-loading");
    await expect(testForm).toHaveAttribute("data-phx-ref-loading");
    // form is locked on phx-change for any changed input
    await expect(testForm).toHaveAttribute("data-phx-ref-lock");
    await expect(testForm).toHaveAttribute("data-phx-ref-src");
    await submitBtn.click();
    // change-loading and submit-loading classes exist simultaneously
    await expect(testForm).toHaveClass(
      "myformclass phx-change-loading phx-submit-loading",
    );
    // phx-change ack arrives and is removed
    await ack("validate");
    await expect(testForm).toHaveClass("myformclass phx-submit-loading");
    await expect(submitBtn).toHaveClass("phx-submit-loading");
    await expect(submitBtn).toHaveAttribute(
      "data-phx-disable-with-restore",
      "Submit",
    );
    await expect(submitBtn).toHaveAttribute("data-phx-ref-loading");
    await expect(testForm).toHaveAttribute("data-phx-ref-loading");
    await expect(testForm).toHaveAttribute("data-phx-ref-src");
    await expect(submitBtn).toHaveAttribute("data-phx-ref-lock");
    // form is not locked on submit
    await expect(testForm).not.toHaveAttribute("data-phx-ref-lock");
    await expect(submitBtn).toHaveAttribute("data-phx-ref-src");
    await expect(submitBtn).toHaveAttribute("disabled", "");
    await expect(submitBtn).toHaveAttribute("phx-disable-with", "Submitting");
    await ack("save");
    await expect(page.getByText("Form was submitted!")).toBeVisible();
    // all refs are cleaned up
    await expect(testForm).toHaveClass("myformclass");
    await expect(submitBtn).toHaveClass("");
    await expect(submitBtn).not.toHaveAttribute(
      "data-phx-disable-with-restore",
    );
    await expect(submitBtn).not.toHaveAttribute("data-phx-ref-loading");
    await expect(submitBtn).not.toHaveAttribute("data-phx-ref-lock");
    await expect(submitBtn).not.toHaveAttribute("data-phx-ref-src");
    await expect(submitBtn).not.toHaveAttribute("data-phx-ref-loading");
    await expect(submitBtn).not.toHaveAttribute("data-phx-ref-lock");
    await expect(submitBtn).not.toHaveAttribute("data-phx-ref-src");
    await expect(submitBtn).not.toHaveAttribute("disabled");
    await expect(submitBtn).toHaveAttribute("phx-disable-with", "Submitting");
  });
}

test("loading and locked states with latent clone", async ({
  page,
  request,
}) => {
  await page.goto("/form/stream");
  const formHook = page.locator("#form-stream-hook");
  await syncLV(page);
  const { lv_pid } = await evalLV(
    page,
    `
    <<"#PID"::binary, pid::binary>> = inspect(self())

    pid_parts =
      pid
      |> String.trim_leading("<")
      |> String.trim_trailing(">")
      |> String.split(".")

    %{lv_pid: pid_parts}
  `,
  );
  const ack = (event) =>
    evalPlug(
      request,
      `send(IEx.Helpers.pid(${lv_pid[0]}, ${lv_pid[1]}, ${lv_pid[2]}), {:sync, "${event}"}); nil`,
    );
  // we serialize the test by letting each event handler wait for a {:sync, event} message
  // excluding the ping messages from our hook
  await evalLV(
    page,
    `
    attach_hook(socket, :sync, :handle_event, fn event, _params, socket ->
      if event == "ping" do
        {:cont, socket}
      else
        receive do {:sync, ^event} -> {:cont, socket} end
      end
    end)
  `,
  );
  await expect(formHook).toHaveText("pong");
  const testForm = page.locator("#test-form");
  const testInput = page.locator("#test-form input[name=myname]");
  const submitBtn = page.locator("#test-form button");
  // initial 3 stream items
  await expect(page.locator("#form-stream li")).toHaveCount(3);
  await testInput.fill("1");
  await testInput.fill("2");
  // form is locked on phx-change and stream remains unchanged
  await expect(testForm).toHaveClass("phx-change-loading");
  await expect(testInput).toHaveClass("phx-change-loading");
  await expect(testForm).toHaveAttribute("data-phx-ref-loading");
  await expect(testForm).toHaveAttribute("data-phx-ref-src");
  await expect(testInput).toHaveAttribute("data-phx-ref-loading");
  await expect(testInput).toHaveAttribute("data-phx-ref-src");
  // now we submit
  await submitBtn.click();
  await expect(testForm).toHaveClass("phx-change-loading phx-submit-loading");
  await expect(submitBtn).toHaveText("Saving...");
  await expect(testInput).toHaveClass("phx-change-loading");
  await expect(testForm).toHaveAttribute("data-phx-ref-loading");
  await expect(testForm).toHaveAttribute("data-phx-ref-src");
  await expect(testInput).toHaveAttribute("data-phx-ref-loading");
  await expect(testInput).toHaveAttribute("data-phx-ref-src");
  // now we ack the two change events
  await ack("validate");
  // the form is still locked, therefore we still have 3 elements
  await expect(page.locator("#form-stream li")).toHaveCount(3);
  await ack("validate");
  // on unlock, cloned stream items that are added on each phx-change are applied to DOM
  await expect(page.locator("#form-stream li")).toHaveCount(5);
  // after clones are applied, the stream item hooks are mounted
  // note that the form still awaits the submit ack, but it is not locked,
  // therefore the updates from the phx-change are already applied
  await expect(page.locator("#form-stream li")).toHaveText([
    "*%{id: 1}pong",
    "*%{id: 2}pong",
    "*%{id: 3}pong",
    "*%{id: 4}",
    "*%{id: 5}",
  ]);
  // still saving
  await expect(submitBtn).toHaveText("Saving...");
  await expect(testForm).toHaveClass("phx-submit-loading");
  await expect(testInput).toHaveAttribute("readonly", "");
  await expect(submitBtn).toHaveClass("phx-submit-loading");
  await expect(testForm).toHaveAttribute("data-phx-ref-loading");
  await expect(testForm).toHaveAttribute("data-phx-ref-src");
  await expect(testInput).toHaveAttribute("data-phx-ref-loading");
  await expect(testInput).toHaveAttribute("data-phx-ref-src");
  await expect(submitBtn).toHaveAttribute("data-phx-ref-loading");
  await expect(submitBtn).toHaveAttribute("data-phx-ref-src");
  // now we ack the submit
  await ack("save");
  // submit adds 1 more stream item and new hook is mounted
  await expect(page.locator("#form-stream li")).toHaveText([
    "*%{id: 1}pong",
    "*%{id: 2}pong",
    "*%{id: 3}pong",
    "*%{id: 4}pong",
    "*%{id: 5}pong",
    "*%{id: 6}pong",
  ]);
  await expect(submitBtn).toHaveText("Submit");
  await expect(submitBtn).toHaveAttribute("phx-disable-with", "Saving...");
  await expect(testForm).not.toHaveClass("phx-submit-loading");
  await expect(testInput).not.toHaveAttribute("readonly");
  await expect(submitBtn).not.toHaveClass("phx-submit-loading");
  await expect(testForm).not.toHaveAttribute("data-phx-ref");
  await expect(testForm).not.toHaveAttribute("data-phx-ref-src");
  await expect(testInput).not.toHaveAttribute("data-phx-ref");
  await expect(testInput).not.toHaveAttribute("data-phx-ref-src");
  await expect(submitBtn).not.toHaveAttribute("data-phx-ref");
  await expect(submitBtn).not.toHaveAttribute("data-phx-ref-src");
});

test("can dynamically add/remove inputs (ecto sort_param/drop_param)", async ({
  page,
}) => {
  await page.goto("/form/dynamic-inputs");
  await syncLV(page);

  const formData = () =>
    page
      .locator("form")
      .evaluate((form) => Object.fromEntries(new FormData(form).entries()));

  expect(await formData()).toEqual({
    "my_form[name]": "",
    "my_form[users_drop][]": "",
  });

  await page.locator("#my-form_name").fill("Test");
  await page.getByRole("button", { name: "add more" }).click();
  await syncLV(page);

  expect(await formData()).toEqual(
    expect.objectContaining({
      "my_form[name]": "Test",
      "my_form[users][0][name]": "",
    }),
  );

  await page.locator("#my-form_users_0_name").fill("User A");
  await page.getByRole("button", { name: "add more" }).click();
  await syncLV(page);
  await page.getByRole("button", { name: "add more" }).click();
  await syncLV(page);

  await page.locator("#my-form_users_1_name").fill("User B");
  await page.locator("#my-form_users_2_name").fill("User C");

  expect(await formData()).toEqual(
    expect.objectContaining({
      "my_form[name]": "Test",
      "my_form[users_drop][]": "",
      "my_form[users][0][name]": "User A",
      "my_form[users][1][name]": "User B",
      "my_form[users][2][name]": "User C",
    }),
  );

  // remove User B
  await page.locator('button[name="my_form[users_drop][]"][value="1"]').click();
  await syncLV(page);

  expect(await formData()).toEqual(
    expect.objectContaining({
      "my_form[name]": "Test",
      "my_form[users_drop][]": "",
      "my_form[users][0][name]": "User A",
      "my_form[users][1][name]": "User C",
    }),
  );
});

test("can dynamically add/remove inputs using checkboxes", async ({ page }) => {
  await page.goto("/form/dynamic-inputs?checkboxes=1");
  await syncLV(page);

  const formData = () =>
    page
      .locator("form")
      .evaluate((form) => Object.fromEntries(new FormData(form).entries()));

  expect(await formData()).toEqual({
    "my_form[name]": "",
    "my_form[users_drop][]": "",
  });

  await page.locator("#my-form_name").fill("Test");
  await page.locator("label", { hasText: "add more" }).click();
  await syncLV(page);

  expect(await formData()).toEqual(
    expect.objectContaining({
      "my_form[name]": "Test",
      "my_form[users][0][name]": "",
    }),
  );

  await page.locator("#my-form_users_0_name").fill("User A");
  await page.locator("label", { hasText: "add more" }).click();
  await page.locator("label", { hasText: "add more" }).click();

  await page.locator("#my-form_users_1_name").fill("User B");
  await page.locator("#my-form_users_2_name").fill("User C");
  await syncLV(page);

  expect(await formData()).toEqual(
    expect.objectContaining({
      "my_form[name]": "Test",
      "my_form[users_drop][]": "",
      "my_form[users][0][name]": "User A",
      "my_form[users][1][name]": "User B",
      "my_form[users][2][name]": "User C",
    }),
  );

  // remove User B
  await page.locator('input[name="my_form[users_drop][]"][value="1"]').click();
  await syncLV(page);

  expect(await formData()).toEqual(
    expect.objectContaining({
      "my_form[name]": "Test",
      "my_form[users_drop][]": "",
      "my_form[users][0][name]": "User A",
      "my_form[users][1][name]": "User C",
    }),
  );
});

// this happened from v1.0.17 when the sort_params field is nested in a fieldset
test("form recovery does not create duplicates of dynamically added fields", async ({
  page,
}) => {
  await page.goto("/form/dynamic-inputs");
  await syncLV(page);

  const formData = () =>
    page
      .locator("form")
      .evaluate((form) => Object.fromEntries(new FormData(form).entries()));

  expect(await formData()).toEqual({
    "my_form[name]": "",
    "my_form[users_drop][]": "",
  });

  await page.locator("#my-form_name").fill("Test");
  await page.getByRole("button", { name: "add more" }).click();
  await syncLV(page);

  expect(await formData()).toEqual(
    expect.objectContaining({
      "my_form[name]": "Test",
      "my_form[users][0][name]": "",
    }),
  );

  await page.evaluate(
    () => new Promise((resolve) => window.liveSocket.disconnect(resolve)),
  );

  await page.evaluate(() => window.liveSocket.connect());
  await syncLV(page);

  const data = await formData();

  expect("my_form[users][1][name]" in data).toBe(false);
});

// phx-feedback-for was removed in LiveView 1.0, but we still test the shim applied in
// test_helper.exs layout for backwards compatibility
test("phx-no-feedback is applied correctly for backwards-compatible-shims", async ({
  page,
}) => {
  await page.goto("/form/feedback");
  await syncLV(page);

  await expect(page.locator("[phx-feedback-for=myfeedback]")).toBeHidden();
  await page.getByRole("button", { name: "+" }).click();
  await syncLV(page);
  await expect(page.locator("[phx-feedback-for=myfeedback]")).toBeHidden();
  await expect(page.getByText("Validate count")).toContainText("0");

  await page.locator("input[name=name]").fill("Test");
  await syncLV(page);
  await expect(page.locator("[phx-feedback-for=myfeedback]")).toBeHidden();
  await expect(page.getByText("Validate count")).toContainText("1");

  await page.locator("input[name=myfeedback]").fill("Test");
  await syncLV(page);
  await expect(page.getByText("Validate count")).toContainText("2");
  await expect(page.locator("[phx-feedback-for=myfeedback]")).toBeVisible();

  // feedback appears on submit
  await page.reload();
  await syncLV(page);
  await expect(page.locator("[phx-feedback-for=myfeedback]")).toBeHidden();

  await page.getByRole("button", { name: "Submit" }).click();
  await syncLV(page);
  await expect(page.getByText("Submit count")).toContainText("1");
  await expect(page.locator("[phx-feedback-for=myfeedback]")).toBeVisible();

  // feedback hides on reset
  await page.getByRole("button", { name: "Reset" }).click();
  await syncLV(page);
  await expect(page.locator("[phx-feedback-for=myfeedback]")).toBeHidden();

  // can toggle feedback visibility
  await page.reload();
  await syncLV(page);
  await expect(page.locator("[data-feedback-container]")).toBeHidden();

  await page.getByRole("button", { name: "Toggle feedback" }).click();
  await syncLV(page);
  await expect(page.locator("[data-feedback-container]")).toBeVisible();

  await page.getByRole("button", { name: "Toggle feedback" }).click();
  await syncLV(page);
  await expect(page.locator("[data-feedback-container]")).toBeHidden();
});

test("phx-no-usage-tracking on a form is applied correctly and no unused fields are sent", async ({
  page,
}) => {
  const webSocketEvents = [];

  page.on("websocket", (ws) => {
    ws.on("framesent", (event) =>
      webSocketEvents.push({ type: "sent", payload: event.payload }),
    );
  });

  await page.goto("/form?phx-no-usage-tracking-form");
  await syncLV(page);

  await page.locator("input[name=b]").fill("test");
  // blur, otherwise the input would not be morphed anyway
  await page.locator("input[name=b]").blur();
  await syncLV(page);

  // With phx-no-usage-tracking on the form, no _unused_ parameters should be sent
  expect(webSocketEvents).toEqual(
    expect.arrayContaining([
      {
        type: "sent",
        payload: expect.stringMatching(/event.*a=foo&b=test&c=baz&d=foo/),
      },
    ]),
  );

  // Ensure no _unused_ parameters are present in any sent events
  const sentEvents = webSocketEvents.filter((event) => event.type === "sent");
  sentEvents.forEach((event) => {
    expect(event.payload).not.toMatch(/_unused_/);
  });
});

test("phx-no-usage-tracking on an input is applied correctly and no unused fields are sent for that specific input", async ({
  page,
}) => {
  const webSocketEvents = [];

  page.on("websocket", (ws) => {
    ws.on("framesent", (event) =>
      webSocketEvents.push({ type: "sent", payload: event.payload }),
    );
  });

  await page.goto("/form?phx-no-usage-tracking-input");
  await syncLV(page);

  await page.locator("input[name=b]").fill("test");
  // blur, otherwise the input would not be morphed anyway
  await page.locator("input[name=b]").blur();
  await syncLV(page);

  // Check that the form data and unused parameters are sent correctly
  expect(webSocketEvents).toEqual(
    expect.arrayContaining([
      {
        type: "sent",
        payload: expect.stringMatching(
          /event.*_unused_a=&a=foo&b=test&c=baz&_unused_d=&d=foo/,
        ),
      },
    ]),
  );

  // Verify specific unused parameter behavior
  const sentEvents = webSocketEvents.filter((event) => event.type === "sent");
  const formDataEvent = sentEvents.find((event) =>
    event.payload.includes("a=foo"),
  );

  // a and d should have _unused_ parameters (untouched, no phx-no-usage-tracking)
  expect(formDataEvent.payload).toMatch(/_unused_a=/);
  expect(formDataEvent.payload).toMatch(/_unused_d=/);
  // b and c should NOT have _unused_ parameters (b touched, c has phx-no-usage-tracking)
  expect(formDataEvent.payload).not.toMatch(/_unused_b=/);
  expect(formDataEvent.payload).not.toMatch(/_unused_c=/);
});
