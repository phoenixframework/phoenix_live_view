const { test, expect } = require("@playwright/test");
const { syncLV } = require("../../utils");

test("LiveComponent with static FC root is not reset", async ({ page }) => {
  const errors = [];
  page.on("pageerror", (err) => errors.push(err));

  await page.goto("/issues/3117");
  await syncLV(page);

  // clicking the button performs a live navigation
  await page.locator("#navigate").click();
  await syncLV(page);

  // the FC root should still be visible and not empty/skipped
  await expect(page.locator("#row-1 .static")).toBeVisible();
  await expect(page.locator("#row-2 .static")).toBeVisible();
  await expect(page.locator("#row-1 .static")).toHaveText("static content");
  await expect(page.locator("#row-2 .static")).toHaveText("static content");

  // no js errors should be thrown
  await expect(errors).toEqual([]);
});
