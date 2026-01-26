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

test("global colocated css works", async ({ page }) => {
  await page.goto("/colocated");
  await syncLV(page);

  await expect(page.locator('[data-test="global"]')).toHaveCSS(
    "background-color",
    "rgb(255, 0, 0)",
  );
});

test("scoped colocated css works", async ({ page }) => {
  await page.goto("/colocated");
  await syncLV(page);

  await expect(page.locator('[data-test="scoped"]')).toHaveCSS(
    "background-color",
    "rgba(0, 0, 0, 0)",
  );

  const blueLocator = page.locator('[data-test-scoped="blue"]');

  await expect(blueLocator).toHaveCount(6);

  for (const shouldBeBlue in blueLocator.all()) {
    await expect(shouldBeBlue).toHaveCSS("background-color", "rgb(0, 0, 255)");
  }

  const noneLocator = page.locator('[data-test-scoped="none"]');

  await expect(noneLocator).toHaveCount(5);

  for (const shouldBeTransparent in noneLocator.all()) {
    await expect(shouldBeTransparent).toHaveCSS(
      "background-color",
      "rgba(0, 0, 0, 0)",
    );
  }

  await expect(page.locator('[data-test-scoped="yellow"]')).toHaveCSS(
    "background-color",
    "rgb(255, 255, 0)",
  );

  await expect(page.locator('[data-test-scoped="green"]')).toHaveCSS(
    "background-color",
    "rgb(0, 255, 0)",
  );
});

test("scoped colocated css lower bound inclusive/exclusive works", async ({
  page,
}) => {
  await page.goto("/colocated");
  await syncLV(page);

  const lowerBoundContainerLocator = page.locator(
    "[data-test-lower-bound-container]",
  );

  await expect(lowerBoundContainerLocator).toHaveCount(2);

  for (const shouldBeFlex in lowerBoundContainerLocator.all()) {
    await expect(shouldBeFlex).toHaveCSS("display", "flex");
  }

  const inclusiveFlexItemsLocator = page.locator('[data-test-inclusive="yes"]');

  await expect(inclusiveFlexItemsLocator).toHaveCount(3);

  for (const shouldFlex in inclusiveFlexItemsLocator.all()) {
    await expect(shouldFlex).toHaveCSS("flex", "1");
  }

  const exclusiveFlexItemsLocator = page.locator('[data-test-inclusive="yes"]');

  await expect(exclusiveFlexItemsLocator).toHaveCount(3);

  for (const shouldntFlex in exclusiveFlexItemsLocator.all()) {
    await expect(shouldntFlex).not().toHaveCSS("flex", "1");
  }
});
