const {test, expect} = require("../../test-fixtures")
const {syncLV} = require("../../utils")

// https://github.com/phoenixframework/phoenix_live_view/issues/3612
test("sticky LiveView stays connected when using push_navigate", async ({page}) => {
  await page.goto("/issues/3612/a")
  await syncLV(page)
  await expect(page.locator("h1")).toHaveText("Page A")
  await page.getByRole("link", {name: "Go to page B"}).click()
  await syncLV(page)
  await expect(page.locator("h1")).toHaveText("Page B")
  await page.getByRole("link", {name: "Go to page A"}).click()
  await syncLV(page)
  await expect(page.locator("h1")).toHaveText("Page A")
})
