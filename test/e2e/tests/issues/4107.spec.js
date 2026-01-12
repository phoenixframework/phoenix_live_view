import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4107
test("debounce works for inputs outside of the form", async ({ page }) => {
  await page.goto("/issues/4107");
  await syncLV(page);

  await page.locator("button").click();

  // With the bug, the form would not be submitted, because
  // the form element was not part of the DOM any more.
  await expect(page).toHaveURL("/api/test");
});
