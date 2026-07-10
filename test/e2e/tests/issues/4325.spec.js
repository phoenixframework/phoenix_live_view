import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4325
test("setting an id to its current value preserves the element across patches", async ({
  page,
}) => {
  await page.goto("/issues/4325");
  await syncLV(page);

  const hooked = page.locator("#hooked");
  const originalElement = await hooked.elementHandle();

  await expect(hooked).toHaveText("count is 0");
  await expect
    .poll(() => page.evaluate(() => window.issue4325Lifecycle))
    .toEqual({ mounted: 1, updated: 0, destroyed: 0 });

  await page.getByRole("button", { name: "Increment" }).click();
  await expect(hooked).toHaveText("count is 1");
  await syncLV(page);

  expect(await originalElement.evaluate((element) => element.isConnected)).toBe(
    true,
  );
  expect(await page.evaluate(() => window.issue4325Lifecycle)).toEqual({
    mounted: 1,
    updated: 1,
    destroyed: 0,
  });
});
