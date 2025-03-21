const {test, expect} = require("../../test-fixtures")
const {syncLV} = require("../../utils")

// https://github.com/phoenixframework/phoenix_live_view/issues/3719
test("target is properly decoded", async ({page}) => {
  const logs = []
  page.on("console", (e) => logs.push(e.text()))

  await page.goto("/issues/3719")
  await syncLV(page)
  await page.locator("#a").fill("foo")
  await syncLV(page)
  await expect(page.locator("#target")).toHaveText("[\"foo\"]")

  await page.locator("#b").fill("foo")
  await syncLV(page)
  await expect(page.locator("#target")).toHaveText("[\"foo\", \"bar\"]")

  expect(logs).not.toEqual(expect.arrayContaining([expect.stringMatching("view crashed")]))
})
