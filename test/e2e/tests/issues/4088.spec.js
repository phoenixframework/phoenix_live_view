import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4088
test("locked LiveComponent container can be patched properly", async ({
  page,
}) => {
  const errors = [];
  page.on("pageerror", (err) => {
    errors.push(err);
  });

  await page.goto("/issues/4088");
  await syncLV(page);

  expect(errors).toHaveLength(0);
});
