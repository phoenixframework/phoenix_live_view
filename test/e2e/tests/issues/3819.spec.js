import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/3819
test("form recovery aborts early when form is empty", async ({ page }) => {
  await page.goto("/issues/3819");
  await syncLV(page);

  await page.evaluate(
    () => new Promise((resolve) => window.liveSocket.disconnect(resolve)),
  );
  await expect(page.locator(".phx-loading")).toHaveCount(1);
  await page.evaluate(() => {
    window.addEventListener("phx:page-loading-stop", () => {
      window.liveSocket.js().push(window.liveSocket.main.el, "reconnected");
    });
    window.liveSocket.connect();
  });

  await expect(page.locator(".phx-loading")).toHaveCount(0);
  await expect(page.locator("#reconnected")).toBeVisible();
});
