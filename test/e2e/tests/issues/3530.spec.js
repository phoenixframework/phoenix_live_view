const {test, expect} = require("../../test-fixtures")
const {syncLV} = require("../../utils")

// https://github.com/phoenixframework/phoenix_live_view/issues/3530
test("hook is initialized properly when using a stream of nested LiveViews", async ({page}) => {
  let logs = []
  page.on("console", (e) => logs.push(e.text()))
  const errors = []
  page.on("pageerror", (err) => errors.push(err))

  await page.goto("/issues/3530")
  await syncLV(page)

  expect(errors).toEqual([])
  expect(logs.filter(e => e.includes("item-1 mounted"))).toHaveLength(1)
  expect(logs.filter(e => e.includes("item-2 mounted"))).toHaveLength(1)
  expect(logs.filter(e => e.includes("item-3 mounted"))).toHaveLength(1)
  logs = []

  await page.getByRole("link", {name: "patch a"}).click()
  await syncLV(page)

  expect(errors).toEqual([])
  expect(logs.filter(e => e.includes("item-2 destroyed"))).toHaveLength(1)
  expect(logs.filter(e => e.includes("item-1 destroyed"))).toHaveLength(0)
  expect(logs.filter(e => e.includes("item-3 destroyed"))).toHaveLength(0)
  logs = []

  await page.getByRole("link", {name: "patch b"}).click()
  await syncLV(page)

  expect(errors).toEqual([])
  expect(logs.filter(e => e.includes("item-1 destroyed"))).toHaveLength(1)
  expect(logs.filter(e => e.includes("item-2 destroyed"))).toHaveLength(0)
  expect(logs.filter(e => e.includes("item-3 destroyed"))).toHaveLength(0)
  expect(logs.filter(e => e.includes("item-2 mounted"))).toHaveLength(1)
  logs = []

  await page.locator("div[phx-click=inc]").click()
  await syncLV(page)
  expect(logs.filter(e => e.includes("item-4 mounted"))).toHaveLength(1)

  expect(logs).not.toEqual(expect.arrayContaining([expect.stringMatching("no hook found for custom element")]))
  // no uncaught exceptions
  expect(errors).toEqual([])
})
