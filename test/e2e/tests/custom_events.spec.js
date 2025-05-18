const {test, expect} = require("../test-fixtures")
const {syncLV} = require("../utils")

test("sending custom events", async ({page}) => {
  await page.goto("/custom-events")
  await syncLV(page)
  await page.locator("my-button").click()
  await expect(page.locator("#foo")).toHaveText("bar")
})
