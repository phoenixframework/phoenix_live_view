import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/3979
test("components destroyed check works properly", async ({ page }) => {
  const errors = [];
  page.on("pageerror", (err) => errors.push(err));

  await page.goto("/issues/3979");
  await syncLV(page);

  const bumpBtn = page.getByRole("button", { name: "Bump ID (and counter)" });
  for (let i = 0; i < 10; i++) {
    await bumpBtn.click();
    await syncLV(page);
  }

  for (let i = 0; i < 10; i++) {
    await expect(page.locator(`[data-phx-component="${i + 1}"]`)).toHaveText(
      "10",
    );
  }

  expect(errors).toEqual([]);
});
