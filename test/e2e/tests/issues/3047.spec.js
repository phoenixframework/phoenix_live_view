const { test, expect } = require("@playwright/test");
const { syncLV } = require("../../utils");

const listItems = async (page) => page.locator('[phx-update="stream"] > span').evaluateAll(list => list.map(el => el.id));

test("streams are not cleared in sticky live views", async ({ page }) => {
  await page.goto("/issues/3047/a");
  await syncLV(page);
  await expect(page.locator("#page")).toContainText("Page A");

  await expect(await listItems(page)).toEqual([
    "items-1", "items-2", "items-3", "items-4", "items-5",
    "items-6", "items-7", "items-8", "items-9", "items-10"
  ]);

  await page.getByRole("button", { name: "Reset" }).click();
  await expect(await listItems(page)).toEqual([
    "items-5", "items-6", "items-7", "items-8", "items-9", "items-10",
    "items-11", "items-12", "items-13", "items-14", "items-15"
  ]);

  await page.getByRole("link", { name: "Page B" }).click();
  await syncLV(page);

  // stream items should still be visible
  await expect(page.locator("#page")).toContainText("Page B");
  await expect(await listItems(page)).toEqual([
    "items-5", "items-6", "items-7", "items-8", "items-9", "items-10",
    "items-11", "items-12", "items-13", "items-14", "items-15"
  ]);
});
