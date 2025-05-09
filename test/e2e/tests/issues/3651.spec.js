import {test, expect} from "../../test-fixtures"
import {syncLV} from "../../utils"

// https://github.com/phoenixframework/phoenix_live_view/issues/3651
test("locked hook with dynamic id is properly cleared", async ({page}) => {
  await page.goto("/issues/3651")
  await syncLV(page)

  await expect(page.locator("#notice")).toBeHidden()

  // we want to wait for some events to have been pushed
  await page.waitForTimeout(100)
  expect(await page.evaluate(() => parseInt(document.querySelector("#total").textContent))).toBeLessThanOrEqual(50)
})
