const { test, expect } = require("@playwright/test");
const { syncLV, attributeMutations } = require("../utils");

test("readonly state is restored after submits", async ({ page }) => {
  await page.goto("/form");
  await syncLV(page);
  await expect(page.locator("input[name=a]")).toHaveAttribute("readonly");
  let changesA = attributeMutations(page, "input[name=a]");
  let changesB = attributeMutations(page, "input[name=b]");
  // can submit multiple times and readonly input stays readonly
  await page.locator("button[type=submit]").click();
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
  await page.locator("button[type=submit]").click();
  await syncLV(page);
  await expect(page.locator("input[name=a]")).toHaveAttribute("readonly");
});

test("button disabled state is restored after submits", async ({ page }) => {
  await page.goto("/form");
  await syncLV(page);
  let changes = attributeMutations(page, "button[type=submit]");
  await page.locator("button[type=submit]").click();
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
