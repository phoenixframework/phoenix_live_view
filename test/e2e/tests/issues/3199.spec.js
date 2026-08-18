import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/3199
test.describe("Issue #3199", () => {
  test("runs an item's phx-remove transition when it is deleted from a stream", async ({
    page,
  }) => {
    await page.goto("/issues/3199");
    await syncLV(page);

    const item = page.locator("#items-1");
    await item.getByRole("button", { name: "Delete" }).click();

    await expect(item).toHaveClass(/item-removing/);
    await expect(item).toHaveCount(0);
    await expect(page.locator("#items-2")).toHaveCount(1);
  });

  test("also runs the item transitions when live navigation removes their container", async ({
    page,
  }) => {
    await page.goto("/issues/3199");
    await syncLV(page);

    await page.getByRole("link", { name: "Navigate away" }).click();

    // This is the behavior reported in #3199: replaceMain finds every
    // phx-remove element in the outgoing LiveView, so both item transitions
    // run and delay replacing the old page even though neither item was
    // individually deleted from the stream.
    await expect(page.locator("#items > li.item-removing")).toHaveCount(2);
    await expect(page.getByRole("heading", { name: "Items" })).toBeVisible();

    await expect(page.getByRole("heading", { name: "Away" })).toBeVisible();
    await syncLV(page);
  });

  test("can limit phx-remove to the LiveView container during navigation", async ({
    page,
  }) => {
    await page.goto("/issues/3199?cascadePhxRemoveOnNavigation=false");
    await syncLV(page);

    await page.getByRole("link", { name: "Navigate away" }).click();

    await expect(page.locator("[data-phx-main].view-removing")).toHaveCount(1);
    await expect(page.locator("#items > li.item-removing")).toHaveCount(0);
    await expect(page.getByRole("heading", { name: "Away" })).toBeVisible();
    await syncLV(page);
  });
});
