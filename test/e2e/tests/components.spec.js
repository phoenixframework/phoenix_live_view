import {test, expect} from "../test-fixtures"
import {syncLV} from "../utils"

let consoleErrors = []
let jsErrors = []

test.beforeEach(async ({page}) => {
  consoleErrors = []
  jsErrors = []

  // Listen for console errors
  page.on("console", (msg) => {
    if(msg.type() === "error"){
      consoleErrors.push(msg.text())
    }
  })

  // Listen for JavaScript errors
  page.on("pageerror", (error) => {
    jsErrors.push(error.message)
  })
})

test.afterEach(async () => {
  // Assert no JavaScript errors occurred during the test
  expect(jsErrors).toEqual([])
  expect(consoleErrors).toEqual([])
})

test("dropdown menu focus wrapping works correctly", async ({
  page,
  browserName,
}) => {
  // skip if webkit, since it doesn't have tab focus enabled by default
  if(browserName === "webkit"){
    test.skip()
  }

  await page.goto("/components?tab=focus_wrap")
  await syncLV(page)

  await expect(page.locator("#dropdown-menu")).toBeHidden()
  await page.locator("#dropdown-button").click()
  await expect(page.locator("#dropdown-menu")).toBeVisible()

  const dropdownButtons = page.locator("#dropdown-content button")
  await expect(dropdownButtons.first()).toBeFocused()

  // Tab through dropdown items - focus should cycle within the dropdown
  await page.keyboard.press("Tab")
  await expect(dropdownButtons.nth(1)).toBeFocused()

  await page.keyboard.press("Tab")
  await expect(dropdownButtons.nth(2)).toBeFocused()

  // Tab again should cycle back to first item (focus wrap behavior)
  await page.keyboard.press("Tab")
  await expect(dropdownButtons.first()).toBeFocused()

  // Shift+Tab should go backwards
  await page.keyboard.press("Shift+Tab")
  await expect(dropdownButtons.nth(2)).toBeFocused()

  // Click a menu item to close dropdown
  await dropdownButtons.first().click()

  // Dropdown should be hidden again
  await expect(page.locator("#dropdown-menu")).toBeHidden()
})

test("simple focus container traps focus correctly", async ({
  page,
  browserName,
}) => {
  // skip if webkit, since it doesn't have tab focus enabled by default
  if(browserName === "webkit"){
    test.skip()
  }

  await page.goto("/components?tab=focus_wrap")
  await syncLV(page)

  // Click on first button in the focus container to start focus there
  const containerButtons = page.locator("#simple-focus-container button")
  const containerInput = page.locator("#simple-focus-container input")

  await containerButtons.first().click()
  await expect(containerButtons.first()).toBeFocused()

  // Tab should move to second button
  await page.keyboard.press("Tab")
  await expect(containerButtons.nth(1)).toBeFocused()

  // Tab should move to input
  await page.keyboard.press("Tab")
  await expect(containerInput).toBeFocused()

  // Tab should cycle back to first button (focus wrap behavior)
  await page.keyboard.press("Tab")
  await expect(containerButtons.first()).toBeFocused()

  // Shift+Tab should go backwards to input
  await page.keyboard.press("Shift+Tab")
  await expect(containerInput).toBeFocused()

  // Shift+Tab should go to second button
  await page.keyboard.press("Shift+Tab")
  await expect(containerButtons.nth(1)).toBeFocused()

  // Shift+Tab should go to first button
  await page.keyboard.press("Shift+Tab")
  await expect(containerButtons.first()).toBeFocused()
})

test("focus_wrap components have correct attributes", async ({page}) => {
  await page.goto("/components?tab=focus_wrap")
  await syncLV(page)

  // Check that focus_wrap components have the correct phx-hook attribute
  await expect(page.locator("#dropdown-content")).toHaveAttribute(
    "phx-hook",
    "Phoenix.FocusWrap",
  )
  await expect(page.locator("#simple-focus-container")).toHaveAttribute(
    "phx-hook",
    "Phoenix.FocusWrap",
  )

  // Check that focus sentinel spans are present
  await expect(page.locator("#dropdown-content-start")).toHaveAttribute(
    "tabindex",
    "0",
  )
  await expect(page.locator("#dropdown-content-start")).toHaveAttribute(
    "aria-hidden",
    "true",
  )
  await expect(page.locator("#dropdown-content-end")).toHaveAttribute(
    "tabindex",
    "0",
  )
  await expect(page.locator("#dropdown-content-end")).toHaveAttribute(
    "aria-hidden",
    "true",
  )

  await expect(page.locator("#simple-focus-container-start")).toHaveAttribute(
    "tabindex",
    "0",
  )
  await expect(page.locator("#simple-focus-container-start")).toHaveAttribute(
    "aria-hidden",
    "true",
  )
  await expect(page.locator("#simple-focus-container-end")).toHaveAttribute(
    "tabindex",
    "0",
  )
  await expect(page.locator("#simple-focus-container-end")).toHaveAttribute(
    "aria-hidden",
    "true",
  )
})
