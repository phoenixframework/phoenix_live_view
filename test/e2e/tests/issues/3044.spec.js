const { test, expect } = require("@playwright/test");
const { syncLV } = require("../../utils");

test("attributes on phx-update='ignore' can be toggled", async ({ page }) => {
  await page.goto("/issues/3044");
  await syncLV(page);

  await expect(page.locator("input")).not.toHaveAttribute("disabled");
  await page.locator("button").click();
  await syncLV(page);
  
  await expect(page.locator("input")).toHaveAttribute("disabled");
  await page.locator("button").click();
  await syncLV(page);

  await expect(page.locator("input")).not.toHaveAttribute("disabled");
});
