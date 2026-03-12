import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4094
test("no errors when handle_params redirects", async ({ page }) => {
  const jsErrors = [];
  page.on("pageerror", (error) => {
    jsErrors.push(error.message);
  });

  await page.goto("/issues/4094");
  await syncLV(page);

  // Clicking a link that redirects in handle_params would throw an exception
  // on the client.
  await page.click("a");

  await expect(page).toHaveURL("/navigation/a");
  expect(jsErrors).toHaveLength(0);
});
