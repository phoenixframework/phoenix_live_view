import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4290
test("events from the old view are not routed to the new view during live navigation", async ({
  page,
}) => {
  await page.goto("/issues/4290/a");
  await syncLV(page);

  await page.getByRole("button", { name: "Navigate" }).click();

  // The new LiveView is registered and joins immediately, but the DOM swap
  // is delayed by the phx-remove transition. The old page stays visible and
  // interactive during that window.
  await page.waitForTimeout(500);
  await expect(page.locator("h1")).toHaveText("A");

  // interact with the old form while the navigation is still in progress;
  // the resulting change event must not be pushed to the new LiveView
  await page.locator("input[name=name]").fill("hello");

  await expect(page.locator("h1")).toHaveText("B");
  await syncLV(page);

  await expect(page.locator("#event-count")).toHaveText("0");
});
