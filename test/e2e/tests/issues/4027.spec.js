import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4027
for (let c of ["first", "second"]) {
  test(`keyed comprehensions are merged properly in LiveComponents - case ${c}`, async ({
    page,
  }) => {
    const errors = [];
    page.on("pageerror", (err) => errors.push(err));
    await page.goto(`/issues/4027?case=${c}`);
    await syncLV(page);

    await page.getByRole("button", { name: "Load data" }).click();
    await expect(page.locator("#result p")).toHaveCount(3);

    await page.getByRole("button", { name: "Remove first entry" }).click();
    await expect(page.locator("#result p")).toHaveCount(2);

    await expect(page.locator("#result")).not.toContainText("First");
    await expect(page.locator("#result")).toContainText("Second");
    await expect(page.locator("#result")).toContainText("Third");

    expect(errors).toEqual([]);
  });
}
