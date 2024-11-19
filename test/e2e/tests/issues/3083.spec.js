const {test, expect} = require("@playwright/test")
const {syncLV, evalLV} = require("../../utils")

test("select multiple handles option updates properly", async ({page}) => {
  await page.goto("/issues/3083?auto=false")
  await syncLV(page)

  await expect(page.locator("select")).toHaveValues([])

  await evalLV(page, "send(self(), {:select, [1,2]}); nil")
  await expect(page.locator("select")).toHaveValues(["1", "2"])
  await evalLV(page, "send(self(), {:select, [2,3]}); nil")
  await expect(page.locator("select")).toHaveValues(["2", "3"])

  // now focus the select by interacting with it
  await page.locator("select").click({position: {x: 1, y: 1}})
  await expect(page.locator("select")).toHaveValues(["1"])
  await evalLV(page, "send(self(), {:select, [1,2]}); nil")
  // because the select is focused, we do not expect the values to change
  await expect(page.locator("select")).toHaveValues(["1"])
  // now blur the select by clicking on the body
  await page.locator("body").click()
  await expect(page.locator("select")).toHaveValues(["1"])
  // now update the selected values again
  await evalLV(page, "send(self(), {:select, [3,4]}); nil")
  // we had a bug here, where the select was focused, despite the blur
  await expect(page.locator("select")).not.toBeFocused()
  await expect(page.locator("select")).toHaveValues(["3", "4"])
  await page.waitForTimeout(1000)
})
