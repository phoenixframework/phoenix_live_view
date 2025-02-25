const {test, expect} = require("../../test-fixtures")
const {syncLV} = require("../../utils")

// https://github.com/phoenixframework/phoenix_live_view/issues/3684
test("nested clones are correctly applied", async ({page}) => {
  await page.goto("/issues/3684")
  await syncLV(page)

  await expect(page.locator("#dewey")).not.toHaveAttribute("checked")

  await page.locator("#dewey").click();
  await syncLV(page);

  await expect(page.locator("#dewey")).toHaveAttribute("checked")
})
