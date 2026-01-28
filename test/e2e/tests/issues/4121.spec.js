import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4121
test("stream teleported outside of LiveView can be reset", async ({ page }) => {
  await page.goto("/issues/4121");
  await syncLV(page);

  expect(await streamElements(page, "stream-in-lv")).toEqual([
    {
      id: "items-1",
      text: "Item 1",
    },
    { id: "items-2", text: "Item 2" },
  ]);

  await page.locator("button").click();
  await syncLV(page);

  expect(await streamElements(page, "stream-in-lv")).toHaveLength(1);
});

const streamElements = async (page, parent) => {
  return await page.locator(`#${parent} > *`).evaluateAll((list) =>
    list.map((el) => ({
      id: el.id,
      text: el.childNodes[0].nodeValue.trim(),
    })),
  );
};
