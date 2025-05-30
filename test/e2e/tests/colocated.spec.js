import { test, expect } from "../test-fixtures";
import { syncLV } from "../utils";

test("colocated hooks works", async ({ page }) => {
  await page.goto("/colocated");
  await syncLV(page);

  await page.locator("input").fill("1234567890");
  await page.keyboard.press("Enter");
  // the hook formats the phone number with dashes, so if the dashes
  // are there, the hook works!
  await expect(page.locator("#phone")).toHaveText("123-456-7890");

  // test runtime hook
  await expect(page.locator("#runtime")).toBeVisible();
});

test("colocated JS works", async ({ page }) => {
  // our colocated JS provides a window event handler for executing JS commands
  // from the server; we have a button that triggers a toggle server side
  await page.goto("/colocated");
  await syncLV(page);

  await expect(page.locator("#hello")).toBeVisible();

  await page.locator("button").click();
  await expect(page.locator("#hello")).toBeHidden();

  await page.locator("button").click();
  await expect(page.locator("#hello")).toBeVisible();
});

test("custom macro component works (syntax highlighting)", async ({ page }) => {
  await page.goto("/colocated");
  await syncLV(page);
  // we check if the code has the makeup classes
  await expect(
    page.locator("pre").nth(1).getByText("button").first(),
  ).toHaveClass("nt");
  await expect(
    page.locator("pre").nth(1).getByText("@temperature"),
  ).toHaveClass("na");
});
