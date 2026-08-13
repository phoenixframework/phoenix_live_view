import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

const file = (name) => ({
  name,
  mimeType: "text/plain",
  buffer: Buffer.from(name),
});

const uploadState = async (page) => ({
  uploaded: (await page.locator("#uploaded-files li").allTextContents()).sort(),
  pending: (await page.locator(".upload-entry").allTextContents())
    .map((text) => text.split(":")[0].trim())
    .sort(),
  errors: (await page.locator(".upload-error").allTextContents()).map((text) =>
    text.trim(),
  ),
});

// https://github.com/phoenixframework/phoenix_live_view/issues/2835
test("max_entries includes files consumed by an auto upload", async ({
  page,
}) => {
  await page.goto("/issues/2835");
  await syncLV(page);

  const input = page.locator("#upload-form input[type='file']");

  await input.setInputFiles([
    file("first.txt"),
    file("second.txt"),
    file("third.txt"),
  ]);
  await syncLV(page);
  const afterInitialSelection = await uploadState(page);

  await input.setInputFiles(file("fourth.txt"));
  await syncLV(page);
  const afterAdditionalSelection = await uploadState(page);

  expect({ afterInitialSelection, afterAdditionalSelection }).toEqual({
    afterInitialSelection: {
      uploaded: ["first.txt", "second.txt"],
      pending: ["third.txt"],
      errors: [":too_many_files"],
    },
    afterAdditionalSelection: {
      uploaded: ["first.txt", "second.txt"],
      pending: ["fourth.txt", "third.txt"],
      errors: [":too_many_files"],
    },
  });
});
