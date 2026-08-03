import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4359
test("parent navigation succeeds while a child LiveView is mounting", async ({
  page,
}) => {
  await page.goto("/issues/4359");

  await expect(page).toHaveURL("/issues/4359?done=1");
  await syncLV(page);
  await expect(page.locator("#child")).toContainText("child");
  await expect(page.locator("#child")).toHaveClass(/phx-connected/);
});
