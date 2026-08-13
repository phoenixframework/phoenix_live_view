import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/3319
test("required upload with multiple entries can be submitted", async ({
  page,
}) => {
  await page.goto("/issues/3319");
  await syncLV(page);

  const form = page.locator("#upload-form");
  const input = form.locator("input[type='file']");

  await input.setInputFiles([
    {
      name: "first.txt",
      mimeType: "text/plain",
      buffer: Buffer.from("first"),
    },
    {
      name: "second.txt",
      mimeType: "text/plain",
      buffer: Buffer.from("second"),
    },
  ]);
  await syncLV(page);

  await expect(form.locator(".upload-entry")).toHaveCount(2);
  await form.getByRole("button", { name: "Submit" }).click();
  await expect(page.locator("#submitted")).not.toBeEmpty();
  expect(
    (await page.locator("#submitted").textContent()).split(",").sort(),
  ).toEqual(["first.txt", "second.txt"]);
});
