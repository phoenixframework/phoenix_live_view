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

test("global colocated CSS works", async ({ page }) => {
  await page.goto("/colocated");
  await syncLV(page);

  // the colocated CSS should apply to both elements regardless of the fact
  // that they are not in the sample template
  await expect(page.locator(".test-in-page.test-colocated-css")).toHaveCSS(
    "background-color",
    "rgb(102, 51, 153)",
  );

  await expect(page.locator(".test-in-component.test-colocated-css")).toHaveCSS(
    "background-color",
    "rgb(102, 51, 153)",
  );
});

test("scoped colocated CSS works", async ({ page }) => {
  await page.goto("/colocated");
  await syncLV(page);

  // the colocated CSS should only to the element in the component it is
  // scoped to
  await expect(page.locator(".test-in-page.test-colocated-css")).not.toHaveCSS(
    "width",
    "175px",
  );

  await expect(page.locator(".test-in-component.test-colocated-css")).toHaveCSS(
    "width",
    "175px",
  );
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
