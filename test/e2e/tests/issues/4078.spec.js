import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4078
// live_file_input should respect changing assigns like disabled and class

test("live_file_input respects disabled attribute changes", async ({
  page,
}) => {
  await page.goto("/issues/4078");
  await syncLV(page);

  const input = page.locator("#upload-form input[type='file']");

  // Initially disabled
  await expect(input).toBeDisabled();

  // Click to enable
  await page.locator("#toggle-disabled").click();
  await syncLV(page);

  // Should now be enabled
  await expect(input).not.toBeDisabled();

  // Click to disable again
  await page.locator("#toggle-disabled").click();
  await syncLV(page);

  // Should be disabled again
  await expect(input).toBeDisabled();
});

test("live_file_input respects class attribute changes", async ({ page }) => {
  await page.goto("/issues/4078");
  await syncLV(page);

  const input = page.locator("#upload-form input[type='file']");

  // Initially has initial-class
  await expect(input).toHaveClass(/initial-class/);

  // Click to change class
  await page.locator("#toggle-class").click();
  await syncLV(page);

  // Should have updated-class
  await expect(input).toHaveClass(/updated-class/);

  // Click to change class back
  await page.locator("#toggle-class").click();
  await syncLV(page);

  // Should have initial-class again
  await expect(input).toHaveClass(/initial-class/);
});

test("live_file_input preserves files when attributes change", async ({
  page,
}) => {
  await page.goto("/issues/4078");
  await syncLV(page);

  // First enable the input
  await page.locator("#toggle-disabled").click();
  await syncLV(page);

  const input = page.locator("#upload-form input[type='file']");
  await expect(input).not.toBeDisabled();

  // Select a file
  await input.setInputFiles({
    name: "test.txt",
    mimeType: "text/plain",
    buffer: Buffer.from("test content"),
  });
  await syncLV(page);

  // Verify file is selected (entry should appear)
  await expect(page.locator(".upload-entry")).toBeVisible();
  await expect(page.locator(".entry-name")).toContainText("test.txt");

  // Change class attribute - file should remain selected
  await page.locator("#toggle-class").click();
  await syncLV(page);

  // Verify file is still selected after class change
  await expect(page.locator(".upload-entry")).toBeVisible();
  await expect(page.locator(".entry-name")).toContainText("test.txt");

  // Verify class was changed
  await expect(input).toHaveClass(/updated-class/);
});
