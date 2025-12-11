import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4066
test("events for disconnected elements are ignored", async ({ page }) => {
  // The test triggers an input event that triggers an event after a delay
  // and before the delay fires, the element is removed by a button press.
  // Previously, the event would bubble to the parent, crashing the LiveView.
  await page.goto("/issues/4066?delay=100");
  await syncLV(page);

  const renderTime = await page
    .locator("#render-time")
    .evaluate((el) => el.innerText);

  await page.locator("input").fill("123");
  await page.locator("button").click();
  await syncLV(page);
  await expect(page.locator("input")).toBeHidden();

  // The hook sets this attribute when the delay fires - we should not crash here
  await expect(page.locator("body")).toHaveAttribute("data-pushed", "yes");

  // We can show the input again
  await page.locator("button").click();
  await syncLV(page);
  await expect(page.locator("input")).toBeVisible();

  // LiveView did not remount
  await expect(page.locator("#render-time")).toHaveText(renderTime);
});
