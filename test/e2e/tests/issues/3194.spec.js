const {test, expect} = require("../../test-fixtures")
const {syncLV} = require("../../utils")

test("does not send event to wrong LV when submitting form with debounce blur", async ({page}) => {
  const logs = []
  page.on("console", (e) => logs.push(e.text()))

  await page.goto("/issues/3194")
  await syncLV(page)

  await page.locator("input").focus()
  await page.keyboard.type("hello")
  await page.keyboard.press("Enter")
  await expect(page).toHaveURL("/issues/3194/other")
  
  // give it some time for old events to reach the new LV
  // (this is the failure case!)
  await page.waitForTimeout(50)

  // we navigated to another LV
  expect(logs).toEqual(expect.arrayContaining([expect.stringMatching("destroyed: the child has been removed from the parent")]))
  // it should not have crashed
  expect(logs).not.toEqual(expect.arrayContaining([expect.stringMatching("view crashed")]))
})
