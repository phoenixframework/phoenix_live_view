import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/3636
test("focus_wrap - focuses first element when entering focus from outside", async ({
  page,
  browserName,
}) => {
  // skip if webkit, since it doesn't have tab focus enabled by default
  if (browserName === "webkit") {
    test.skip();
  }
  await page.goto("/issues/3636");
  await syncLV(page);
  // put focus next to the third button
  await page.mouse.click(250, 37.5);
  await page.keyboard.press("Tab");
  await expect(page.getByRole("button", { name: "One" })).toBeFocused();
});
