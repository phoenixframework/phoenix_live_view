import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

const dropFiles = async (page, names) => {
  const dataTransfer = await page.evaluateHandle((fileNames) => {
    const dt = new DataTransfer();
    fileNames.forEach((name) => {
      dt.items.add(new File([name], name, { type: "image/png" }));
    });
    return dt;
  }, names);

  await page.dispatchEvent("#dropzone", "drop", { dataTransfer });
  await dataTransfer.dispose();
  await syncLV(page);
};

// https://github.com/phoenixframework/phoenix_live_view/issues/3368
test("a new drop replaces entries after too_many_files", async ({ page }) => {
  await page.goto("/issues/3368");
  await syncLV(page);

  await dropFiles(page, ["first.png", "second.png"]);
  await expect(page.locator(".upload-error")).toHaveText(":too_many_files");

  await dropFiles(page, ["replacement.png"]);

  await expect(page.locator(".upload-error")).toHaveCount(0);
  await expect(page.locator(".upload-entry")).toHaveText("replacement.png");
});
