import {test, expect} from "../test-fixtures"
import {syncLV, attributeMutations} from "../utils"

test("toggle_attribute", async ({page}) => {
  await page.goto("/js")
  await syncLV(page)

  await expect(page.locator("#my-modal")).toBeHidden()

  let changes = attributeMutations(page, "#my-modal")
  await page.getByRole("button", {name: "toggle modal"}).click()
  // wait for the transition time (set to 50)
  await page.waitForTimeout(100)
  expect(await changes()).toEqual(expect.arrayContaining([
    {attr: "style", oldValue: "display: none;", newValue: "display: block;"},
    {attr: "aria-expanded", oldValue: "false", newValue: "true"},
    {attr: "open", oldValue: null, newValue: "true"},
    // chrome and firefox first transition from null to "" and then to "fade-in";
    // safari goes straight from null to "fade-in", therefore we do not perform an exact match
    expect.objectContaining({attr: "class", newValue: "fade-in"}),
    expect.objectContaining({attr: "class", oldValue: "fade-in"}),
  ]))
  await expect(page.locator("#my-modal")).not.toHaveClass("fade-in")
  await expect(page.locator("#my-modal")).toHaveAttribute("aria-expanded", "true")
  await expect(page.locator("#my-modal")).toHaveAttribute("open", "true")
  await expect(page.locator("#my-modal")).toBeVisible()

  changes = attributeMutations(page, "#my-modal")
  await page.getByRole("button", {name: "toggle modal"}).click()
  // wait for the transition time (set to 50)
  await page.waitForTimeout(100)
  expect(await changes()).toEqual(expect.arrayContaining([
    {attr: "style", oldValue: "display: block;", newValue: "display: none;"},
    {attr: "aria-expanded", oldValue: "true", newValue: "false"},
    {attr: "open", oldValue: "true", newValue: null},
    expect.objectContaining({attr: "class", newValue: "fade-out"}),
    expect.objectContaining({attr: "class", oldValue: "fade-out"}),
  ]))
  await expect(page.locator("#my-modal")).not.toHaveClass("fade-out")
  await expect(page.locator("#my-modal")).toHaveAttribute("aria-expanded", "false")
  await expect(page.locator("#my-modal")).not.toHaveAttribute("open")
  await expect(page.locator("#my-modal")).toBeHidden()
})

test("set and remove_attribute", async ({page}) => {
  await page.goto("/js")
  await syncLV(page)

  await expect(page.locator("#my-modal")).toBeHidden()

  let changes = attributeMutations(page, "#my-modal")
  await page.getByRole("button", {name: "show modal"}).click()
  // wait for the transition time (set to 50)
  await page.waitForTimeout(100)
  expect(await changes()).toEqual(expect.arrayContaining([
    {attr: "style", oldValue: "display: none;", newValue: "display: block;"},
    {attr: "aria-expanded", oldValue: "false", newValue: "true"},
    {attr: "open", oldValue: null, newValue: "true"},
    expect.objectContaining({attr: "class", newValue: "fade-in"}),
    expect.objectContaining({attr: "class", oldValue: "fade-in"}),
  ]))
  await expect(page.locator("#my-modal")).not.toHaveClass("fade-in")
  await expect(page.locator("#my-modal")).toHaveAttribute("aria-expanded", "true")
  await expect(page.locator("#my-modal")).toHaveAttribute("open", "true")
  await expect(page.locator("#my-modal")).toBeVisible()

  changes = attributeMutations(page, "#my-modal")
  await page.getByRole("button", {name: "hide modal"}).click()
  // wait for the transition time (set to 50)
  await page.waitForTimeout(100)
  expect(await changes()).toEqual(expect.arrayContaining([
    {attr: "style", oldValue: "display: block;", newValue: "display: none;"},
    {attr: "aria-expanded", oldValue: "true", newValue: "false"},
    {attr: "open", oldValue: "true", newValue: null},
    expect.objectContaining({attr: "class", newValue: "fade-out"}),
    expect.objectContaining({attr: "class", oldValue: "fade-out"}),
  ]))
  await expect(page.locator("#my-modal")).not.toHaveClass("fade-out")
  await expect(page.locator("#my-modal")).toHaveAttribute("aria-expanded", "false")
  await expect(page.locator("#my-modal")).not.toHaveAttribute("open")
  await expect(page.locator("#my-modal")).toBeHidden()
})

test("ignore_attributes", async ({page}) => {
  await page.goto("/js")
  await syncLV(page)
  await expect(page.locator("details")).not.toHaveAttribute("open")
  await page.locator("details").click()
  await expect(page.locator("details")).toHaveAttribute("open")
  // without ignore_attributes, the open attribute would be reset to false
  await page.locator("details button").click()
  await syncLV(page)
  await expect(page.locator("details")).toHaveAttribute("open")
})
