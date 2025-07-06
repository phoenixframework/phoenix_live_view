import { test, expect } from "../test-fixtures";
import { syncLV, evalLV } from "../utils";

for (let tab of ["all_keyed", "rows_keyed", "no_keyed"]) {
  test(`renders correctly - ${tab}`, async ({ page }) => {
    await page.goto(`/keyed-comprehension?tab=${tab}`);
    await syncLV(page);

    for (let i = 0; i < 10; i++) {
      await page.getByRole("button", { name: "randomize" }).click();
      await syncLV(page);
    }

    const order = await evalLV(page, `socket.assigns.items`);

    const theText = async (page, i, index) =>
      (
        await page
          .locator("table")
          .nth(i)
          .locator("tbody tr")
          .nth(index)
          .textContent()
      ).replace(/\s+/g, " ");

    await Promise.all(
      order.map(async (item, index) => {
        const text0 = await theText(page, 0, index);
        const text1 = await theText(page, 1, index);
        expect(text0).toEqual(` Count: 10 Name: ${item.entry.foo.bar} 1 10 `);
        expect(text1).toEqual(` Count: 10 Name: ${item.entry.foo.bar} 2 10 `);
      }),
    );
  });
}
