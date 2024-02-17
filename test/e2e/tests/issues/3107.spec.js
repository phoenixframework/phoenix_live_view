const { test, expect } = require("@playwright/test");
const { syncLV } = require("../../utils");

test("keeps value when updating select", async ({ page }) => {
  await page.goto("/issues/3107");
  await syncLV(page);

  await expect(page.locator("select")).toHaveValue("ONE");
  // focus the element and change the value, like a user would
  await page.locator("select").focus();
  await page.locator("select").selectOption("TWO");
  await syncLV(page);
  await expect(page.locator("select")).toHaveValue("TWO");
});
