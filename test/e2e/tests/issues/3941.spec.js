import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/3941
test("component-only patch in locked tree works", async ({ page }) => {
  await page.goto("/issues/3941");
  await syncLV(page);

  // the bug was that, because the parent container was locked,
  // the component only patch was applied and later on the (stale) locked
  // tree was applied, erasing the patch
  await expect(page.locator("#Item_1")).toContainText("I AM LOADED");
  await expect(page.locator("#Item_2")).toContainText("I AM LOADED");

  await page.locator("#select-Item_1").uncheck();
  await page.locator("#select-Item_2").uncheck();

  await expect(page.locator("#Item_1")).toHaveCount(0);
  await expect(page.locator("#Item_2")).toHaveCount(0);

  await page.locator("#select-Item_1").check();
  await expect(page.locator("#Item_1")).toContainText("I AM LOADED");
  await expect(page.locator("#Item_2")).toHaveCount(0);

  await page.locator("#select-Item_2").check();
  await expect(page.locator("#Item_1")).toContainText("I AM LOADED");
  await expect(page.locator("#Item_2")).toContainText("I AM LOADED");
});
