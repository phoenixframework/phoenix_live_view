import {test, expect} from "../../test-fixtures"
import {syncLV} from "../../utils"

test("can rejoin with nested streams without errors", async ({page}) => {
  const errors = []
  page.on("pageerror", (err) => {
    errors.push(err)
  })

  await page.goto("/issues/3378")
  await syncLV(page)

  await expect(page.locator("#notifications")).toContainText("big")
  await page.evaluate(() => new Promise((resolve) => window.liveSocket.disconnect(resolve)))

  await page.evaluate(() => window.liveSocket.connect())
  await syncLV(page)

  // no js errors should be thrown
  expect(errors).toEqual([])
})
