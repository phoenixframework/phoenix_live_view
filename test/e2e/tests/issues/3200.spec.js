import {test, expect} from "../../test-fixtures"
import {syncLV} from "../../utils"

// https://github.com/phoenixframework/phoenix_live_view/issues/3200
test("phx-target='selector' is used correctly for form recovery", async ({page}) => {
  const errors = []
  page.on("pageerror", (err) => errors.push(err))

  await page.goto("/issues/3200/settings")
  await syncLV(page)

  await page.getByRole("button", {name: "Messages"}).click()
  await syncLV(page)
  await expect(page).toHaveURL("/issues/3200/messages")

  await page.locator("#new_message_input").fill("Hello")
  await syncLV(page)

  await page.evaluate(() => new Promise((resolve) => window.liveSocket.disconnect(resolve)))
  await expect(page.locator(".phx-loading")).toHaveCount(1)
  
  await page.evaluate(() => window.liveSocket.connect())
  await syncLV(page)

  await expect(page.locator("#new_message_input")).toHaveValue("Hello")
  expect(errors).toEqual([])
})
