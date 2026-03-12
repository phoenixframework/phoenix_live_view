import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4102
test("debounce works for inputs outside of the form", async ({ page }) => {
  const errors = [];
  page.on("pageerror", (err) => {
    errors.push(err);
  });

  await page.goto("/issues/4102");
  await syncLV(page);

  await page.locator("input").fill("123");
  await page.locator("button").click();
  await syncLV(page);

  expect(errors).toHaveLength(0);
});
