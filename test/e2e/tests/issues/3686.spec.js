const {test, expect} = require("../../test-fixtures")
const {syncLV} = require("../../utils")

// https://github.com/phoenixframework/phoenix_live_view/issues/3686
test("flash is copied across fallback redirect", async ({page}) => {
  await page.goto("/issues/3686/a")
  await syncLV(page)
  await expect(page.locator("#flash")).toHaveText("%{}")

  await page.getByRole("button", {name: "To B"}).click()
  await syncLV(page)
  await expect(page.locator("#flash")).toContainText("Flash from A")

  await page.getByRole("button", {name: "To C"}).click()
  await syncLV(page)
  await expect(page.locator("#flash")).toContainText("Flash from B")

  await page.getByRole("button", {name: "To A"}).click()
  await syncLV(page)
  await expect(page.locator("#flash")).toContainText("Flash from C")
})
