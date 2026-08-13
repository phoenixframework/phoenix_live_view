import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/3391
test("an invalid auto-upload cancels submit without locking the form", async ({
  page,
}) => {
  await page.goto("/issues/3391");
  await syncLV(page);

  const form = page.locator("#upload-form");
  const input = form.locator("input[type='file']");
  const submit = form.getByRole("button", { name: "Submit" });

  await input.setInputFiles({
    name: "invalid.html",
    mimeType: "text/html",
    buffer: Buffer.from("<h1>invalid</h1>"),
  });
  await syncLV(page);

  const failedEntry = form.locator(".upload-entry");
  await expect(failedEntry.locator(".upload-error")).toHaveText(
    ":not_accepted",
  );

  await submit.click();

  await expect(form).not.toHaveClass(/phx-submit-loading/);
  await expect(submit).toBeEnabled();
  await expect(
    failedEntry.getByRole("button", { name: "Cancel" }),
  ).toBeEnabled();
  await expect(failedEntry.locator(".upload-error")).toHaveText(
    ":not_accepted",
  );
  await expect(page.locator("#submitted")).toHaveText("submitted: false");

  await failedEntry.getByRole("button", { name: "Cancel" }).click();
  await expect(failedEntry).toHaveCount(0);

  await input.setInputFiles({
    name: "valid.txt",
    mimeType: "text/plain",
    buffer: Buffer.from("valid"),
  });
  await expect(page.locator("#uploaded")).toHaveText("uploaded: true");

  await submit.click();
  await expect(page.locator("#submitted")).toHaveText("submitted: true");
});
