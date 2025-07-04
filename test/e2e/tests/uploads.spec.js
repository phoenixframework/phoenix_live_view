import { test, expect } from "../test-fixtures";
import { syncLV, attributeMutations } from "../utils";

// https://stackoverflow.com/questions/10623798/how-do-i-read-the-contents-of-a-node-js-stream-into-a-string-variable
const readStream = (stream) =>
  new Promise((resolve) => {
    const chunks = [];

    stream.on("data", function (chunk) {
      chunks.push(chunk);
    });

    // Send the buffer or you can put it into a var
    stream.on("end", function () {
      resolve(Buffer.concat(chunks));
    });
  });

test("can upload a file", async ({ page }) => {
  await page.goto("/upload");
  await syncLV(page);

  const changesForm = attributeMutations(page, "#upload-form");
  const changesInput = attributeMutations(page, "#upload-form input");

  // wait for the change listeners to be ready
  await page.waitForTimeout(50);

  await page.locator("#upload-form input").setInputFiles({
    name: "file.txt",
    mimeType: "text/plain",
    buffer: Buffer.from("this is a test"),
  });
  await syncLV(page);
  await expect(page.locator("progress")).toHaveAttribute("value", "0");
  await page.getByRole("button", { name: "Upload" }).click();

  // we should see one uploaded file in the list
  await expect(page.locator("ul li")).toBeVisible();

  expect(await changesForm()).toEqual(
    expect.arrayContaining([
      { attr: "class", oldValue: null, newValue: "phx-submit-loading" },
      { attr: "class", oldValue: "phx-submit-loading", newValue: null },
    ]),
  );

  expect(await changesInput()).toEqual(
    expect.arrayContaining([
      { attr: "class", oldValue: null, newValue: "phx-change-loading" },
      { attr: "class", oldValue: "phx-change-loading", newValue: null },
    ]),
  );

  // now download the file to see if it contains the expected content
  const downloadPromise = page.waitForEvent("download");
  await page.locator("ul li a").click();
  const download = await downloadPromise;

  await expect(
    download
      .createReadStream()
      .then(readStream)
      .then((buf) => buf.toString()),
  ).resolves.toEqual("this is a test");
});

test("can drop a file", async ({ page }) => {
  await page.goto("/upload");
  await syncLV(page);

  // https://github.com/microsoft/playwright/issues/10667
  // Create the DataTransfer and File
  const dataTransfer = await page.evaluateHandle((data) => {
    const dt = new DataTransfer();
    // Convert the buffer to a hex array
    const file = new File([data], "file.txt", { type: "text/plain" });
    dt.items.add(file);
    return dt;
  }, "this is a test");

  // Now dispatch
  await page.dispatchEvent("section", "drop", { dataTransfer });

  await syncLV(page);
  await page.getByRole("button", { name: "Upload" }).click();

  // we should see one uploaded file in the list
  await expect(page.locator("ul li")).toBeVisible();

  // now download the file to see if it contains the expected content
  const downloadPromise = page.waitForEvent("download");
  await page.locator("ul li a").click();
  const download = await downloadPromise;

  await expect(
    download
      .createReadStream()
      .then(readStream)
      .then((buf) => buf.toString()),
  ).resolves.toEqual("this is a test");
});

test("can upload multiple files", async ({ page }) => {
  await page.goto("/upload");
  await syncLV(page);

  await page.locator("#upload-form input").setInputFiles([
    {
      name: "file.txt",
      mimeType: "text/plain",
      buffer: Buffer.from("this is a test"),
    },
    {
      name: "file.md",
      mimeType: "text/markdown",
      buffer: Buffer.from("## this is a markdown file"),
    },
  ]);
  await syncLV(page);
  await page.getByRole("button", { name: "Upload" }).click();

  // we should see two uploaded files in the list
  await expect(page.locator("ul li")).toHaveCount(2);
});

test("shows error when there are too many files", async ({ page }) => {
  await page.goto("/upload");
  await syncLV(page);

  await page.locator("#upload-form input").setInputFiles([
    {
      name: "file.txt",
      mimeType: "text/plain",
      buffer: Buffer.from("this is a test"),
    },
    {
      name: "file.md",
      mimeType: "text/markdown",
      buffer: Buffer.from("## this is a markdown file"),
    },
    {
      name: "file2.txt",
      mimeType: "text/plain",
      buffer: Buffer.from("another file"),
    },
  ]);
  await syncLV(page);

  await expect(page.locator(".alert")).toContainText(
    "You have selected too many files",
  );
});

test("shows error for invalid mimetype", async ({ page }) => {
  await page.goto("/upload");
  await syncLV(page);

  await page.locator("#upload-form input").setInputFiles([
    {
      name: "file.html",
      mimeType: "text/html",
      buffer: Buffer.from("<h1>Hi</h1>"),
    },
  ]);
  await syncLV(page);

  await expect(page.locator(".alert")).toContainText(
    "You have selected an unacceptable file type",
  );
});

test("auto upload", async ({ page }) => {
  await page.goto("/upload?auto_upload=1");
  await syncLV(page);

  const changes = attributeMutations(page, "#upload-form input");
  // wait for the change listeners to be ready
  await page.waitForTimeout(50);
  await page.locator("#upload-form input").setInputFiles([
    {
      name: "file.txt",
      mimeType: "text/plain",
      buffer: Buffer.from("this is a test"),
    },
  ]);
  await syncLV(page);
  await expect(page.locator("progress")).toHaveAttribute("value", "100");

  expect(await changes()).toEqual(
    expect.arrayContaining([
      { attr: "class", oldValue: null, newValue: "phx-change-loading" },
      { attr: "class", oldValue: "phx-change-loading", newValue: null },
    ]),
  );

  await page.getByRole("button", { name: "Upload" }).click();

  await expect(page.locator("ul li")).toBeVisible();
});

test("issue 3115 - cancelled upload is not re-added", async ({ page }) => {
  await page.goto("/upload");
  await syncLV(page);

  await page.locator("#upload-form input").setInputFiles([
    {
      name: "file.txt",
      mimeType: "text/plain",
      buffer: Buffer.from("this is a test"),
    },
  ]);
  await syncLV(page);
  // cancel the file
  await page.getByLabel("cancel").click();

  // add other file
  await page.locator("#upload-form input").setInputFiles([
    {
      name: "file.md",
      mimeType: "text/markdown",
      buffer: Buffer.from("## this is a markdown file"),
    },
  ]);
  await syncLV(page);
  await page.getByRole("button", { name: "Upload" }).click();
  await syncLV(page);

  // we should see one uploaded file in the list
  await expect(page.locator("ul li")).toHaveCount(1);
});

test("submitting invalid form multiple times doesn't crash", async ({
  page,
}) => {
  // https://github.com/phoenixframework/phoenix_live_view/pull/3133#issuecomment-1962439904
  await page.goto("/upload");
  await syncLV(page);

  const logs = [];
  page.on("console", (e) => logs.push(e.text()));

  await page.locator("#upload-form input").setInputFiles([
    {
      name: "file.txt",
      mimeType: "text/plain",
      buffer: Buffer.from("this is a test"),
    },
    {
      name: "file.md",
      mimeType: "text/markdown",
      buffer: Buffer.from("## this is a markdown file"),
    },
    {
      name: "file2.md",
      mimeType: "text/markdown",
      buffer: Buffer.from("## this is another markdown file"),
    },
  ]);
  await syncLV(page);
  await page.getByRole("button", { name: "Upload" }).click();
  await page.getByRole("button", { name: "Upload" }).click();
  await syncLV(page);

  expect(logs).not.toEqual(
    expect.arrayContaining([expect.stringMatching("view crashed")]),
  );
  await expect(page.locator(".alert")).toContainText(
    "You have selected too many files",
  );
});

test("auto upload - can submit files after fixing too many files error", async ({
  page,
}) => {
  // https://github.com/phoenixframework/phoenix_live_view/commit/80ddf356faaded097358a784c2515c50c345713e
  await page.goto("/upload?auto_upload=1");
  await syncLV(page);

  const logs = [];
  page.on("console", (e) => logs.push(e.text()));

  await page.locator("#upload-form input").setInputFiles([
    {
      name: "file.txt",
      mimeType: "text/plain",
      buffer: Buffer.from("this is a test"),
    },
    {
      name: "file.md",
      mimeType: "text/markdown",
      buffer: Buffer.from("## this is a markdown file"),
    },
    {
      name: "file2.md",
      mimeType: "text/markdown",
      buffer: Buffer.from("## this is another markdown file"),
    },
  ]);
  // before the fix, this already failed because the phx-change-loading class was not removed
  // because undoRefs failed
  await syncLV(page);
  expect(logs).not.toEqual(
    expect.arrayContaining([
      expect.stringMatching("no preflight upload response returned with ref"),
    ]),
  );

  // too many files
  await expect(page.locator("ul li")).toHaveCount(0);
  await expect(page.locator(".alert")).toContainText(
    "You have selected too many files",
  );
  // now remove the file that caused the error
  await page
    .locator("article")
    .filter({ hasText: "file2.md" })
    .getByLabel("cancel")
    .click();
  // now we can upload the files
  await page.getByRole("button", { name: "Upload" }).click();
  await syncLV(page);

  await expect(page.locator(".alert")).toBeHidden();
  await expect(page.locator("ul li")).toHaveCount(2);
});
