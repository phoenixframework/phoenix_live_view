import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/3953
test("component destroy messages respect the parent", async ({ page }) => {
  await page.goto("/issues/3953");
  await syncLV(page);
  await expect(
    page.locator("#nested_view [data-phx-component='1']"),
  ).toHaveCount(0);

  // the first render works fine
  await page.getByRole("button", { name: "Show" }).click();
  await syncLV(page);
  await expect(
    page.locator("#nested_view [data-phx-component='1']"),
  ).toHaveCount(1);

  // the bug was that a cids_destroyed message was sent to the parent view
  await page.getByRole("button", { name: "Show" }).click();
  await syncLV(page);
  await expect(
    page.locator("#nested_view [data-phx-component='1']"),
  ).toHaveCount(0);

  // so this failed, as CID 1 was not found when rendering
  await page.getByRole("button", { name: "Show" }).click();
  await syncLV(page);
  await expect(
    page.locator("#nested_view [data-phx-component='1']"),
  ).toHaveCount(1);
});
