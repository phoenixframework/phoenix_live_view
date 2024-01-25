const { test, expect } = require("@playwright/test");
const { syncLV, attributeMutations } = require("../utils");

// https://stackoverflow.com/questions/10623798/how-do-i-read-the-contents-of-a-node-js-stream-into-a-string-variable
const readStream = (stream) => new Promise((resolve) => {
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

  let changesForm = attributeMutations(page, "#upload-form");
  let changesInput = attributeMutations(page, "#upload-form input");

  // wait for the change listeners to be ready
  await page.waitForTimeout(50);

  await page.locator("#upload-form input").setInputFiles({
    name: "file.txt",
    mimeType: "text/plain",
    buffer: Buffer.from("this is a test")
  });
  await syncLV(page);
  await expect(page.locator("progress")).toHaveAttribute("value", "0");
  await page.getByRole("button", { name: "Upload" }).click();

  // we should see one uploaded file in the list
  await expect(page.locator("ul li")).toBeVisible();

  await expect(await changesForm()).toEqual(expect.arrayContaining([
    { attr: "class", oldValue: null, newValue: "phx-submit-loading" },
    { attr: "class", oldValue: "phx-submit-loading", newValue: null },
  ]));

  await expect(await changesInput()).toEqual(expect.arrayContaining([
    { attr: "class", oldValue: null, newValue: "phx-change-loading" },
    { attr: "class", oldValue: "phx-change-loading", newValue: null },
  ]));

  // now download the file to see if it contains the expected content
  const downloadPromise = page.waitForEvent("download");
  await page.locator("ul li a").click();
  const download = await downloadPromise;

  await expect(download.createReadStream().then(readStream).then(buf => buf.toString()))
    .resolves.toEqual("this is a test");
});

test("can drop a file", async ({ page }) => {
  await page.goto("/upload");
  await syncLV(page);

  // https://github.com/microsoft/playwright/issues/10667
  // Create the DataTransfer and File
  const dataTransfer = await page.evaluateHandle((data) => {
    const dt = new DataTransfer();
    // Convert the buffer to a hex array
    const file = new File([data], 'file.txt', { type: 'text/plain' });
    dt.items.add(file);
    return dt;
  }, "this is a test");

  // Now dispatch
  await page.dispatchEvent("section", 'drop', { dataTransfer });

  await syncLV(page);
  await page.getByRole("button", { name: "Upload" }).click();

  // we should see one uploaded file in the list
  await expect(page.locator("ul li")).toBeVisible();

  // now download the file to see if it contains the expected content
  const downloadPromise = page.waitForEvent("download");
  await page.locator("ul li a").click();
  const download = await downloadPromise;

  await expect(download.createReadStream().then(readStream).then(buf => buf.toString()))
    .resolves.toEqual("this is a test");
});

test("can upload multiple files", async ({ page }) => {
  await page.goto("/upload");
  await syncLV(page);

  await page.locator("#upload-form input").setInputFiles([
    {
      name: "file.txt",
      mimeType: "text/plain",
      buffer: Buffer.from("this is a test")
    },
    {
      name: "file.md",
      mimeType: "text/markdown",
      buffer: Buffer.from("## this is a markdown file")
    }
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
      buffer: Buffer.from("this is a test")
    },
    {
      name: "file.md",
      mimeType: "text/markdown",
      buffer: Buffer.from("## this is a markdown file")
    },
    {
      name: "file2.txt",
      mimeType: "text/plain",
      buffer: Buffer.from("another file")
    }
  ]);
  await syncLV(page);

  await expect(page.locator(".alert")).toContainText("You have selected too many files");
});

test("shows error for invalid mimetype", async ({ page }) => {
  await page.goto("/upload");
  await syncLV(page);

  await page.locator("#upload-form input").setInputFiles([
    {
      name: "file.html",
      mimeType: "text/html",
      buffer: Buffer.from("<h1>Hi</h1>")
    }
  ]);
  await syncLV(page);

  await expect(page.locator(".alert")).toContainText("You have selected an unacceptable file type");
});

test("auto upload", async ({ page }) => {
  await page.goto("/upload?auto_upload=1");
  await syncLV(page);

  let changes = attributeMutations(page, "#upload-form input");
  // wait for the change listeners to be ready
  await page.waitForTimeout(50);

  await page.locator("#upload-form input").setInputFiles([
    {
      name: "file.txt",
      mimeType: "text/plain",
      buffer: Buffer.from("this is a test")
    }
  ]);
  await syncLV(page);
  await expect(page.locator("progress")).toHaveAttribute("value", "100");

  await expect(await changes()).toEqual(expect.arrayContaining([
    { attr: "class", oldValue: null, newValue: "phx-change-loading" },
    { attr: "class", oldValue: "phx-change-loading", newValue: null },
  ]));

  await page.getByRole("button", { name: "Upload" }).click();

  await expect(page.locator("ul li")).toBeVisible();
});
