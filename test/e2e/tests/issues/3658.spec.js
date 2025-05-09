import {test, expect} from "../../test-fixtures"
import {syncLV} from "../../utils"

// https://github.com/phoenixframework/phoenix_live_view/issues/3658
test("phx-remove elements inside sticky LiveViews are not removed when navigating", async ({page}) => {
  await page.goto("/issues/3658")
  await syncLV(page)

  await expect(page.locator("#foo")).toBeVisible()
  await page.getByRole("link", {name: "Link 1"}).click()

  await syncLV(page)
  // the bug would remove the element
  await expect(page.locator("#foo")).toBeVisible()
})
