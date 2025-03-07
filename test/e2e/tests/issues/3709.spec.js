const {test, expect} = require("../../test-fixtures")
const {syncLV} = require("../../utils")

// https://github.com/phoenixframework/phoenix_live_view/issues/3709
test("pendingDiffs don't race with navigation", async ({page}) => {
  const logs = []
  page.on("console", (e) => logs.push(e.text()))
  const errors = []
  page.on("pageerror", (err) => errors.push(err))

  await page.goto("/issues/3709/1")
  await syncLV(page)
  await expect(page.locator("body")).toContainText("id: 1")

  await page.getByRole("button", {name: "Break Stuff"}).click()
  await syncLV(page)

  expect(logs).not.toEqual(expect.arrayContaining([expect.stringMatching("Cannot read properties of undefined (reading 's')")]))

  await page.getByRole("link", {name: "Link 5"}).click()
  await syncLV(page)
  await expect(page.locator("body")).toContainText("id: 5")

  expect(logs).not.toEqual(expect.arrayContaining([expect.stringMatching("Cannot set properties of undefined (setting 'newRender')")]))

  // no uncaught exceptions
  expect(errors).toEqual([])
})
