import { test, expect } from "../test-fixtures";
import { syncLV } from "../utils";

// this tests issue #2659
// https://github.com/phoenixframework/phoenix_live_view/pull/2659
test("select shows error when invalid option is selected", async ({ page }) => {
  await page.goto("/select");
  await syncLV(page);

  const select3 = page.locator("#select_form_select3");
  await expect(select3).toHaveValue("2");
  await expect(select3).not.toHaveClass("has-error");

  // 5 or below should be invalid
  await select3.selectOption("3");
  await syncLV(page);
  await expect(select3).toHaveClass("has-error");

  // 6 or above should be valid
  await select3.selectOption("6");
  await syncLV(page);
  await expect(select3).not.toHaveClass("has-error");
});
