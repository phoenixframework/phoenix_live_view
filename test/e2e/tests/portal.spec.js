const { test, expect } = require("../test-fixtures");
const { syncLV, evalLV } = require("../utils");

test("renders modal inside portal location", async ({ page }) => {
  await page.goto("/portal?tick=false");
  await syncLV(page);

  await expect(page.locator("#my-modal")).toHaveCount(1);
  await expect(page.locator("#my-modal-content")).not.toBeVisible();
  // no modal inside the main element (rendered in the layout)
  await expect(page.locator("main #my-modal")).toHaveCount(0);

  await page.getByRole("button", { name: "Open modal" }).click();
  await expect(page.locator("#my-modal-content")).toBeVisible();

  await expect(page.locator("#my-modal-content")).toContainText("DOM patching works as expected: 0");
  await evalLV(page, `send(self(), :tick)`);
  await expect(page.locator("#my-modal-content")).toContainText("DOM patching works as expected: 1");
});
