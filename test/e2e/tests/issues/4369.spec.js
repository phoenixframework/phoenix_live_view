import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4369
test("file inputs are disabled until their LiveView is connected", async ({
  page,
}) => {
  await page.goto("/issues/4369", { waitUntil: "domcontentloaded" });

  const liveView = page.locator("[data-phx-main]");
  const input = page.locator("#upload-form input[type='file']");

  await expect(liveView).not.toHaveClass(/phx-connected/);
  await expect(input).toBeDisabled();

  await syncLV(page);
  await expect(input).toBeEnabled();

  await input.setInputFiles({
    name: "selected.txt",
    mimeType: "text/plain",
    buffer: Buffer.from("selected"),
  });
  await expect(page.locator(".upload-entry")).toHaveText("selected.txt");

  await page.evaluate(
    () => new Promise((resolve) => window.liveSocket.disconnect(resolve)),
  );
  await expect(input).toBeDisabled();

  await page.evaluate(() => window.liveSocket.connect());
  await syncLV(page);
  await expect(input).toBeEnabled();
});

test("restored file selections are cleared on mount", async ({ page }) => {
  await page.goto("/issues/4369");
  await syncLV(page);

  const input = page.locator("#upload-form input[type='file']");
  await input.setInputFiles({
    name: "restored.txt",
    mimeType: "text/plain",
    buffer: Buffer.from("restored"),
  });
  await expect(input).toHaveValue(/restored\.txt$/);

  await page.reload({ waitUntil: "domcontentloaded" });
  await expect(input).toBeDisabled();
  await syncLV(page);

  await expect(input).toBeEnabled();
  await expect(input).toHaveValue("");
  expect(await input.evaluate((element) => element.files.length)).toBe(0);
});
