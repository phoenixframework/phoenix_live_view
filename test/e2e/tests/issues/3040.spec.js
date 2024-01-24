const { test, expect } = require("@playwright/test");
const { syncLV } = require("../../utils");

test("click-away does not fire when triggering form submit", async ({ page }) => {
  await page.goto("/issues/3040");
  await syncLV(page);

  await page.getByRole("link", { name: "Add new" }).click();
  await syncLV(page);

  const modal = page.locator("#my-modal-container");
  await expect(modal).toBeVisible();

  // focusFirst should have focused the input
  await expect(page.locator("input[name='name']")).toBeFocused();

  // submit the form
  await page.keyboard.press("Enter");
  await syncLV(page);

  await expect(page.locator("form")).toHaveText("Form was submitted!");
  await expect(modal).toBeVisible();

  // now click outside
  await page.mouse.click(0, 0);
  await syncLV(page);

  await expect(modal).not.toBeVisible();
});

// see also https://github.com/phoenixframework/phoenix_live_view/issues/1920
test("does not close modal when moving mouse outside while held down", async ({ page }) => {
  await page.goto("/issues/3040");
  await syncLV(page);

  await page.getByRole("link", { name: "Add new" }).click();
  await syncLV(page);

  const modal = page.locator("#my-modal-container");
  await expect(modal).toBeVisible();

  await expect(page.locator("input[name='name']")).toBeFocused();
  await page.locator("input[name='name']").fill("test");

  // we move the mouse inside the input field and then drag it outside
  // while holding the mouse button down
  await page.mouse.move(434, 350);
  await page.mouse.down();
  await page.mouse.move(143, 350);
  await page.mouse.up();

  // we expect the modal to still be visible because the mousedown happended
  // inside, not triggering phx-click-away
  await expect(modal).toBeVisible();
  await page.keyboard.press("Backspace");

  await expect(page.locator("input[name='name']")).toHaveValue("");
  await expect(modal).toBeVisible();

  // close modal with escape
  await page.keyboard.press("Escape");
  await expect(modal).not.toBeVisible();
});
