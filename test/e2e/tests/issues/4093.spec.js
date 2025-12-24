import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4093
// Verifies that JS.patch updates window.location BEFORE hooks' updated() is called.
test("hook updated() sees new URL after push_patch", async ({ page }) => {
  await page.goto("/issues/4093");
  await syncLV(page);

  // Verify initial state - no patched query param
  await expect(page).toHaveURL(/\/issues\/4093$/);
  await expect(page.locator("#tracker")).not.toHaveAttribute(
    "data-url-in-updated",
  );

  // Click button which triggers push_patch and updates the hook's content
  await page.locator("button").click();
  await syncLV(page);

  // URL should be updated
  await expect(page).toHaveURL(/\/issues\/4093\?patched=true/);

  // The hook's updated() callback should have seen the NEW URL, not the old one
  const urlInUpdated = await page
    .locator("#tracker")
    .getAttribute("data-url-in-updated");

  expect(urlInUpdated).toMatch(/\/issues\/4093\?patched=true/);
});
