import { test, expect } from "../../test-fixtures";
import { syncLV, attributeMutations } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/3656
test("phx-click-loading is removed from links in sticky LiveViews", async ({
  page,
}) => {
  await page.goto("/issues/3656");
  await syncLV(page);

  const changes = attributeMutations(page, "nav a");

  const link = page.getByRole("link", { name: "Link 1" });
  await link.click();

  await syncLV(page);
  await expect(link).not.toHaveClass("phx-click-loading");

  expect(await changes()).toEqual(
    expect.arrayContaining([
      { attr: "class", oldValue: null, newValue: "phx-click-loading" },
      { attr: "class", oldValue: "phx-click-loading", newValue: "" },
    ]),
  );
});
