import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/3681
test("streams in nested LiveViews are not reset when they share the same stream ref", async ({
  page,
  request,
}) => {
  // this was a separate bug where child LiveViews accidentally shared the parent streams
  // check that the initial render does not contain the messages-4 element twice
  expect(
    (await (await request.get("/issues/3681/away")).text()).match(/messages-4/g)
      .length,
  ).toBe(1);

  await page.goto("/issues/3681");
  await syncLV(page);

  await expect(page.locator("#msgs-sticky > div")).toHaveCount(3);

  await page
    .getByRole("link", { name: "Go to a different LV with a (funcky) stream" })
    .click();
  await syncLV(page);
  await expect(page.locator("#msgs-sticky > div")).toHaveCount(3);

  await page
    .getByRole("link", {
      name: "Go back to (the now borked) LV without a stream",
    })
    .click();
  await syncLV(page);
  await expect(page.locator("#msgs-sticky > div")).toHaveCount(3);
});
