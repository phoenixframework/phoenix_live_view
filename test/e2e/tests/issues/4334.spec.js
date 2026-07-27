import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4334
test("hook is remounted when changing LC root id and content is properly patched", async ({
  page,
}) => {
  const logs = [];
  page.on("console", (e) => logs.push(e.text()));

  await page.goto("/issues/4334");
  await syncLV(page);

  expect(logs.filter((msg) => msg.indexOf("MyHook") !== -1)).toEqual([
    "MyHook mounted",
  ]);

  await page.getByRole("button", { name: "Change component root id" }).click();
  await syncLV(page);

  // Hook remounts
  expect(logs.filter((msg) => msg.indexOf("MyHook") !== -1)).toEqual([
    "MyHook mounted",
    "MyHook mounted",
  ]);

  await expect(page.getByText("NEW CHILD SHOULD REMAIN VISIBLE")).toBeVisible();
});
