const { test, expect } = require("@playwright/test");
const { syncLV } = require("../../utils");

const inputVals = async (page) => {
  return page.locator(`input[type="text"]`).evaluateAll(list => list.map(i => i.value));
}

test("updates which add cids back on page are properly magic id change tracked", async ({ page }) => {
  await page.goto("/issues/3169");
  await syncLV(page);

  await page.locator("#select-a").click()
  await syncLV(page);
  await expect(page.locator("body")).toContainText("FormColumn (c3)");
  await expect(await inputVals(page)).toEqual(["Record a", "Record a", "Record a"]);

  await page.locator("#select-b").click()
  await syncLV(page);
  await expect(page.locator("body")).toContainText("FormColumn (c3)");
  await expect(await inputVals(page)).toEqual(["Record b", "Record b", "Record b"]);

  await page.locator("#select-z").click()
  await syncLV(page);
  await expect(page.locator("body")).toContainText("FormColumn (c3)");
  await expect(await inputVals(page)).toEqual(["Record z", "Record z", "Record z"]);
});
