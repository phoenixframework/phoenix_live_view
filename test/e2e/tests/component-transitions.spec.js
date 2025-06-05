import { test, expect } from "@playwright/test";

test.describe("Component Transitions", () => {
  test("single-root components should not vanish during phx-remove transitions", async ({
    page,
  }) => {
    await page.goto("/component-transition");

    // Wait for the page to load and components to be visible
    await expect(page.locator("#single-root-component")).toBeVisible();
    await expect(page.locator("#multi-root-component")).toBeVisible();

    // Verify initial state - both components should be visible
    const singleRootBefore = await page
      .locator("#single-root-component")
      .isVisible();
    const multiRootBefore = await page
      .locator("#multi-root-component")
      .isVisible();

    expect(singleRootBefore).toBe(true);
    expect(multiRootBefore).toBe(true);

    // Click the button that triggers phx-remove transitions
    await page.click("button[phx-click='remove_components']");

    // Wait a short moment to let the transition start
    await page.waitForTimeout(100);

    // During the transition, both components should still be visible
    // (they should fade out gracefully, not vanish immediately)
    const singleRootDuringTransition = await page
      .locator("#single-root-component")
      .isVisible();
    const multiRootDuringTransition = await page
      .locator("#multi-root-component")
      .isVisible();

    // This is the key test - single-root components should NOT vanish immediately
    // They should behave the same as multi-root components during transitions
    expect(singleRootDuringTransition).toBe(true);
    expect(multiRootDuringTransition).toBe(true);

    // Wait for the transition to complete
    await page.waitForTimeout(1000);

    // After the transition completes, both should be removed
    await expect(page.locator("#single-root-component")).not.toBeVisible();
    await expect(page.locator("#multi-root-component")).not.toBeVisible();
  });

  test("components should properly handle transitions with our fix", async ({
    page,
  }) => {
    await page.goto("/component-transition");

    // Get initial count of visible elements
    const initialSingleRoot = await page
      .locator("#single-root-component")
      .count();
    const initialMultiRoot = await page
      .locator("#multi-root-component")
      .count();

    expect(initialSingleRoot).toBe(1);
    expect(initialMultiRoot).toBe(1);

    // Trigger the removal
    await page.click("button[phx-click='remove_components']");

    // After full transition, elements should be gone
    await page.waitForTimeout(1500);

    const finalSingleRoot = await page
      .locator("#single-root-component")
      .count();
    const finalMultiRoot = await page.locator("#multi-root-component").count();

    expect(finalSingleRoot).toBe(0);
    expect(finalMultiRoot).toBe(0);
  });
});
