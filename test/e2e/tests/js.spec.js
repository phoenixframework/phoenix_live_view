const { test, expect } = require("@playwright/test");
const { syncLV, attributeMutations } = require("../utils");

test("toggle_attribute", async ({ page }) => {
  await page.goto("/js");
  await syncLV(page);

  await expect(page.locator("#my-modal")).not.toBeVisible();

  let changes = attributeMutations(page, "#my-modal");
  await page.getByRole("button", { name: "toggle modal" }).click();
  // wait for the transition time (set to 50)
  await page.waitForTimeout(100);
  await expect(await changes()).toEqual(expect.arrayContaining([
    { attr: "style", oldValue: "display: none;", newValue: "display: block;" },
    { attr: "aria-expanded", oldValue: "false", newValue: "true" },
    { attr: "open", oldValue: null, newValue: "true" },
    // chrome and firefox first transition from null to "" and then to "fade-in";
    // safari goes straight from null to "fade-in", therefore we do not perform an exact match
    expect.objectContaining({ attr: "class", newValue: "fade-in" }),
    expect.objectContaining({ attr: "class", oldValue: "fade-in" }),
  ]));
  await expect(page.locator("#my-modal")).not.toHaveClass("fade-in");
  await expect(page.locator("#my-modal")).toHaveAttribute("aria-expanded", "true");
  await expect(page.locator("#my-modal")).toHaveAttribute("open", "true");
  await expect(page.locator("#my-modal")).toBeVisible();

  changes = attributeMutations(page, "#my-modal");
  await page.getByRole("button", { name: "toggle modal" }).click();
  // wait for the transition time (set to 50)
  await page.waitForTimeout(100);
  await expect(await changes()).toEqual(expect.arrayContaining([
    { attr: "style", oldValue: "display: block;", newValue: "display: none;" },
    { attr: "aria-expanded", oldValue: "true", newValue: "false" },
    { attr: "open", oldValue: "true", newValue: null },
    expect.objectContaining({ attr: "class", newValue: "fade-out" }),
    expect.objectContaining({ attr: "class", oldValue: "fade-out" }),
  ]));
  await expect(page.locator("#my-modal")).not.toHaveClass("fade-out");
  await expect(page.locator("#my-modal")).toHaveAttribute("aria-expanded", "false");
  await expect(page.locator("#my-modal")).not.toHaveAttribute("open");
  await expect(page.locator("#my-modal")).not.toBeVisible();
});

test("set and remove_attribute", async ({ page }) => {
  await page.goto("/js");
  await syncLV(page);

  await expect(page.locator("#my-modal")).not.toBeVisible();

  let changes = attributeMutations(page, "#my-modal");
  await page.getByRole("button", { name: "show modal" }).click();
  // wait for the transition time (set to 50)
  await page.waitForTimeout(100);
  await expect(await changes()).toEqual(expect.arrayContaining([
    { attr: "style", oldValue: "display: none;", newValue: "display: block;" },
    { attr: "aria-expanded", oldValue: "false", newValue: "true" },
    { attr: "open", oldValue: null, newValue: "true" },
    expect.objectContaining({ attr: "class", newValue: "fade-in" }),
    expect.objectContaining({ attr: "class", oldValue: "fade-in" }),
  ]));
  await expect(page.locator("#my-modal")).not.toHaveClass("fade-in");
  await expect(page.locator("#my-modal")).toHaveAttribute("aria-expanded", "true");
  await expect(page.locator("#my-modal")).toHaveAttribute("open", "true");
  await expect(page.locator("#my-modal")).toBeVisible();

  changes = attributeMutations(page, "#my-modal");
  await page.getByRole("button", { name: "hide modal" }).click();
  // wait for the transition time (set to 50)
  await page.waitForTimeout(100);
  await expect(await changes()).toEqual(expect.arrayContaining([
    { attr: "style", oldValue: "display: block;", newValue: "display: none;" },
    { attr: "aria-expanded", oldValue: "true", newValue: "false" },
    { attr: "open", oldValue: "true", newValue: null },
    expect.objectContaining({ attr: "class", newValue: "fade-out" }),
    expect.objectContaining({ attr: "class", oldValue: "fade-out" }),
  ]));
  await expect(page.locator("#my-modal")).not.toHaveClass("fade-out");
  await expect(page.locator("#my-modal")).toHaveAttribute("aria-expanded", "false");
  await expect(page.locator("#my-modal")).not.toHaveAttribute("open");
  await expect(page.locator("#my-modal")).not.toBeVisible();
});
