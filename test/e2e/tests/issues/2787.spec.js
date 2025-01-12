const {test, expect} = require("../../test-fixtures")
const {syncLV} = require("../../utils")

const selectOptions = (locator) => locator.evaluateAll(list => list.map(option => option.value))

test("select is properly cleared on submit", async ({page}) => {
  await page.goto("/issues/2787")
  await syncLV(page)

  const select1 = page.locator("#demo_select1")
  const select2 = page.locator("#demo_select2")

  // at the beginning, both selects are empty
  await expect(select1).toHaveValue("")
  expect(await selectOptions(select1.locator("option"))).toEqual(["", "greetings", "goodbyes"])
  await expect(select2).toHaveValue("")
  expect(await selectOptions(select2.locator("option"))).toEqual([""])

  // now we select greetings in the first select
  await select1.selectOption("greetings")
  await syncLV(page)
  // now the second select should have some greeting options
  expect(await selectOptions(select2.locator("option"))).toEqual(["", "hello", "hallo", "hei"])
  await select2.selectOption("hei")
  await syncLV(page)

  // now we submit the form
  await page.locator("button").click()

  // now, both selects should be empty again (this was the bug in #2787)
  await expect(select1).toHaveValue("")
  await expect(select2).toHaveValue("")

  // now we select goodbyes in the first select
  await select1.selectOption("goodbyes")
  await syncLV(page)
  expect(await selectOptions(select2.locator("option"))).toEqual(["", "goodbye", "auf wiedersehen", "ha det bra"])
})
