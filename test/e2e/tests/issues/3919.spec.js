import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/3919
test("attribute defaults are properly considered as changed", async ({
  page,
}) => {
  await page.goto("/issues/3919");
  await syncLV(page);

  const styledDiv = page.locator("div[style]");

  await expect(styledDiv).toContainText("No red");
  await expect(styledDiv).not.toHaveAttribute(
    "style",
    "background-color: red;",
  );
  await page.getByRole("button", { name: "toggle" }).click();
  await syncLV(page);

  await expect(styledDiv).not.toContainText("No red");
  await expect(styledDiv).toHaveAttribute("style", "background-color: red;");
  await page.getByRole("button", { name: "toggle" }).click();
  await syncLV(page);

  // bug: previously, the red background remained
  await expect(styledDiv).toContainText("No red");
  await expect(styledDiv).not.toHaveAttribute(
    "style",
    "background-color: red;",
  );
});
