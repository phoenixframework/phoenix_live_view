const { test, expect } = require("../../test-fixtures");
const { syncLV } = require("../../utils");

// https://github.com/phoenixframework/phoenix_live_view/issues/3496
test("hook is initialized properly when reusing id between sticky and non sticky LiveViews", async ({ page }) => {
  const logs = [];
  page.on("console", (e) => logs.push(e.text()));
  const errors = [];
  page.on("pageerror", (err) => errors.push(err));

  await page.goto("/issues/3496/a");
  await syncLV(page);

  await page.getByRole("link", { name: "Go to page B" }).click();
  await syncLV(page);

  expect(logs.filter(e => e.includes("Hook mounted!"))).toHaveLength(2);
  expect(logs).not.toEqual(expect.arrayContaining([expect.stringMatching("no hook found for custom element")]));
  // no uncaught exceptions
  expect(errors).toEqual([]);
});
