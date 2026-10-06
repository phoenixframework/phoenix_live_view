import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/pull/4465

const file = (name, contents) => ({
  name,
  mimeType: "text/plain",
  buffer: Buffer.from(contents),
});

const setup = async (page, query) => {
  await page.goto(`/issues/4465?${query}`);
  await syncLV(page);
  const form = page.locator("#upload-form");
  return {
    // used to ensure that the form is not only released because the LiveView remounted
    pid: await page.locator("#pid").textContent(),
    form,
    input: form.locator("input[type='file']"),
    submit: form.getByRole("button", { name: "Submit" }),
  };
};

const expectUnlocked = async ({ form, input, submit }) => {
  await expect(form).not.toHaveClass(/phx-submit-loading/);
  await expect(submit).toBeEnabled();
  await expect(submit).not.toHaveAttribute("data-phx-ref-lock");
  await expect(input).toBeEnabled();
  await expect(input).not.toHaveAttribute("data-phx-ref-lock");
};

const cancelAndResubmit = async (page, { input, submit, pid }) => {
  await page
    .locator('.upload-entry[data-name="bad.txt"]')
    .getByRole("button", { name: "Cancel" })
    .click();
  await syncLV(page);
  await input.setInputFiles([file("good2.txt", "0000000000")]);
  await submit.click();
  await expect(page.locator("#submitted")).toContainText("good2.txt");
  await expect(page.locator("#pid")).toHaveText(pid);
};

test.describe("external uploader calling entry.error()", () => {
  for (const files of [
    [file("bad.txt", "0000000000")],
    [file("good.txt", "0000000000"), file("bad.txt", "0000000000")],
  ]) {
    test(`releases the submit lock (${files.map((f) => f.name).join(", ")})`, async ({
      page,
    }) => {
      const ctx = await setup(page, "uploader=external");
      await ctx.input.setInputFiles(files);
      await ctx.submit.click();
      // locked while the external uploader is running
      await expect(ctx.form).toHaveClass(/phx-submit-loading/);
      await expect(ctx.submit).toBeDisabled();

      await expectUnlocked(ctx);
      await expect(page.locator("#submitted")).toHaveText("submitted: nil");
      await expect(
        page.locator('.upload-entry[data-name="bad.txt"] .upload-error'),
      ).toHaveText(":external_client_failure");

      await cancelAndResubmit(page, ctx);
    });
  }

  test("auto upload: a submit scheduled during upload is released", async ({
    page,
  }) => {
    const ctx = await setup(page, "uploader=external&auto=true");
    await ctx.input.setInputFiles([file("bad.txt", "0000000000")]);
    await ctx.submit.click();

    await expectUnlocked(ctx);
    await expect(page.locator("#submitted")).toHaveText("submitted: nil");
    await expect(page.locator("#pid")).toHaveText(ctx.pid);
  });
});

test("channel uploader: writer error releases the submit lock", async ({
  page,
}) => {
  const ctx = await setup(page, "uploader=channel");
  await ctx.input.setInputFiles([file("bad.txt", "error")]);
  await ctx.submit.click();

  await expectUnlocked(ctx);
  await expect(
    page.locator('.upload-entry[data-name="bad.txt"] .upload-error'),
  ).toHaveText("{:writer_failure, :boom}");
  await expect(page.locator("#submitted")).toHaveText("submitted: nil");

  await cancelAndResubmit(page, ctx);
});
