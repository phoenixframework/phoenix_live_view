const {test, expect} = require("../../test-fixtures")
const {syncLV} = require("../../utils")

// https://github.com/phoenixframework/phoenix_live_view/issues/3647
test("upload works when input event follows immediately afterwards", async ({page}) => {
  await page.goto("/issues/3647")
  await syncLV(page)

  await expect(page.locator("ul li")).toHaveCount(0)
  await expect(page.locator("input[name=\"user[name]\"]")).toHaveValue("")

  await page.getByRole("button", {name: "Upload then Input"}).click()
  await syncLV(page)

  await expect(page.locator("ul li")).toHaveCount(1)
  await expect(page.locator("input[name=\"user[name]\"]")).toHaveValue("0")
})
