import { test, expect } from "../test-fixtures";
import { syncLV } from "../utils";

test("beforeUpdate hook can be used to update attribute before dom-patch", async ({
  page,
}) => {
  await page.goto("/beforeupdate");
  await syncLV(page);

  const hook = page.locator("#hook-beforeupdate");
  // aria-hidden attribute is set on client side hook mounted
  await expect(hook).toHaveAttribute("aria-hidden", "false");

  // Click the button will trigger live view update from server
  await page.locator("button").click();

  // when the liveview updated from server aria-hidden attribute will be removed
  // since on server side does not have the attribute
  // hook expect to set aria-hidden attribute to match previous value
  await expect(hook).toHaveAttribute("aria-hidden", "false");
});
