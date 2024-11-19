const {test, expect} = require("../../test-fixtures")
const {syncLV} = require("../../utils")

// https://github.com/phoenixframework/phoenix_live_view/issues/3448
test("focus is handled correctly when patching locked form", async ({page}) => {
  await page.goto("/issues/3448")
  await syncLV(page)

  await page.evaluate(() => window.liveSocket.enableLatencySim(500))

  await page.locator("input[type=checkbox]").first().check()
  await expect(page.locator("input#search")).toBeFocused()
  await syncLV(page)

  // after the patch is applied, the input should still be focused
  await expect(page.locator("input#search")).toBeFocused()
})
