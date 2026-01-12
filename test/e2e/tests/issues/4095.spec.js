import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4095
test("events for disconnected elements are ignored", async ({ page }) => {
  await page.goto("/issues/4095");
  await syncLV(page);

  await expect(page.locator("button")).toBeVisible();
  await page.evaluate(() => window.liveSocket.enableLatencySim(50));

  await page.locator("input").fill("1");
  await page.locator("input").fill("12");

  await syncLV(page);

  await expect(page.locator("button")).toHaveText("Show?");
  await expect(page.locator("button")).not.toHaveAttribute("data-phx-skip");
});
