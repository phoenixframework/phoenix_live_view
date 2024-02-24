const { test, expect } = require("@playwright/test");
const { syncLV } = require("../../utils");
const { randomBytes } = require("crypto");

test("can upload files with custom chunk hook", async ({ page }) => {
  await page.goto("/issues/2965");
  await syncLV(page);

  const files = [];
  for (let i = 1; i <= 20; i++) {
    files.push({
      name: `file${i}.txt`,
      mimeType: "text/plain",
      // random 100 kb
      buffer: randomBytes(100 * 1024),
    });
  }

  await page.locator("#fileinput").setInputFiles(files);
  await syncLV(page);

  // wait for uploads to finish
  for (let i = 0; i < 20; i++) {
    const row = page.locator(`tbody tr`).nth(i);
    await expect(row).toContainText(`file${i + 1}.txt`);
    await expect(row.locator("progress")).toHaveAttribute("value", "100");
  }

  // all uploads are finished!
});
