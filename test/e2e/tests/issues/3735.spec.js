import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

const file = (name, mimeType = "image/jpeg") => ({
  name,
  mimeType,
  buffer: Buffer.from(name),
});

const uploadedFiles = (page) =>
  page
    .locator("#uploaded-files li")
    .allTextContents()
    .then((names) => names.sort());

const expectNotUploaded = async (page, names) => {
  await expect.poll(() => uploadedFiles(page)).toEqual([]);

  for (const name of names) {
    await expect(
      page.locator(`.upload-entry[data-name="${name}"]`),
    ).toHaveAttribute("data-progress", "0");
  }
};

const cancel = async (page, name) => {
  await page.locator(`.upload-entry[data-name="${name}"] button`).click();
  await syncLV(page);
};

test.beforeEach(async ({ page }) => {
  await page.goto("/issues/3735");
  await syncLV(page);
});

// https://github.com/phoenixframework/phoenix_live_view/issues/3735
test("auto_upload :if_valid waits until an excess file is cancelled", async ({
  page,
}) => {
  const input = page.locator("#upload-form input[type='file']");

  await input.setInputFiles([
    file("first.jpg"),
    file("second.jpg"),
    file("third.jpg"),
  ]);
  await syncLV(page);

  await expect(page.locator(".upload-error")).toHaveText(":too_many_files");
  await expectNotUploaded(page, ["first.jpg", "second.jpg", "third.jpg"]);

  await cancel(page, "third.jpg");

  await expect(page.locator(".upload-error")).toHaveCount(0);
  await expect
    .poll(() => uploadedFiles(page))
    .toEqual(["first.jpg", "second.jpg"]);
});

test("auto_upload :if_valid waits until an invalid file is cancelled", async ({
  page,
}) => {
  const input = page.locator("#upload-form input[type='file']");

  await input.setInputFiles([
    file("valid.jpg"),
    file("invalid.mp4", "video/mp4"),
  ]);
  await syncLV(page);

  await expect(
    page.locator('.upload-entry[data-name="invalid.mp4"] .entry-error'),
  ).toHaveText(":not_accepted");
  await expectNotUploaded(page, ["valid.jpg", "invalid.mp4"]);

  await cancel(page, "invalid.mp4");

  await expect(page.locator(".entry-error")).toHaveCount(0);
  await expect.poll(() => uploadedFiles(page)).toEqual(["valid.jpg"]);
});
