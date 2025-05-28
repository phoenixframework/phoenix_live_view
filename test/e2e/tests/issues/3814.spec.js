import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/3814
test("submitter is sent when using phx-trigger-action", async ({ page }) => {
  await page.goto("/issues/3814");
  await syncLV(page);

  await page.locator("button").click();
  await expect(page.locator("body")).toContainText(
    '"i-am-the-submitter":"submitter-value"',
  );
});
