import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/pull/4368
test("a custom writer failure remains visible until it is cancelled", async ({
  page,
}) => {
  await page.goto("/issues/4368");
  await syncLV(page);

  const input = page.locator("#upload-form input[type='file']");

  await input.setInputFiles([
    {
      name: "good.pdf",
      mimeType: "application/pdf",
      buffer: Buffer.from("0000000000"),
    },
    {
      name: "bad.pdf",
      mimeType: "application/pdf",
      buffer: Buffer.from("00000error"),
    },
  ]);

  const failedEntry = page.locator('.upload-entry[data-name="bad.pdf"]');
  await expect(failedEntry.locator(".upload-error")).toHaveText(
    "{:writer_failure, :invalid_pdf}",
  );
  await expect(page.locator("#consumed")).toHaveText("consumed: good.pdf");
  await expect(page.locator("#submitted")).toHaveText("submitted: false");
  await expect(page.locator("[data-phx-main]")).toHaveClass(/phx-connected/);

  const failedRef = await input.getAttribute("data-phx-active-refs");
  // eslint-disable-next-line playwright/prefer-web-first-assertions
  expect(failedRef).not.toBe("");
  await expect(input).toHaveAttribute("data-phx-preflighted-refs", failedRef);
  await expect(input).toHaveAttribute("data-phx-done-refs", "");

  await failedEntry.getByRole("button", { name: "Cancel" }).click();
  await expect(failedEntry).toHaveCount(0);
  await syncLV(page);

  await page.getByRole("button", { name: "Submit" }).click();
  await syncLV(page);
  await expect(page.locator("#submitted")).toHaveText("submitted: true");
});
