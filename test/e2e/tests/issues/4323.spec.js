import { test, expect } from "../../test-fixtures";
import { evalLV, syncLV } from "../../utils";

const incrementCounter = async (page) => {
  await evalLV(
    page,
    "{:noreply, Phoenix.Component.assign(socket, :counter, socket.assigns.counter + 1)}",
  );
  await syncLV(page);
};

test.describe("phx-patch-focused", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/issues/4323");
    await syncLV(page);
  });

  test("preserves focused form-associated custom elements by default", async ({
    page,
  }) => {
    const control = page.locator("#face-default");
    await control.focus();
    await expect(control).toBeFocused();

    await incrementCounter(page);

    await expect(page.locator("#face-default-child")).toHaveText("count:0");
  });

  test("patches an opted-in focused form-associated custom element", async ({
    page,
  }) => {
    const control = page.locator("#face-opt-in");
    await control.focus();
    await expect(control).toBeFocused();

    await incrementCounter(page);

    await expect(page.locator("#face-opt-in-child")).toHaveText("count:1");
  });

  test("patches opted-in slotted children when focus is delegated", async ({
    page,
  }) => {
    await page.locator("#face-delegates").click();
    await expect
      .poll(() => page.evaluate(() => document.activeElement?.id))
      .toBe("face-delegates");

    await incrementCounter(page);

    await expect(page.locator("#face-delegates-child")).toHaveText("count:1");
  });

  test("preserves a focused native input by default", async ({ page }) => {
    const input = page.locator("#native-default");
    await input.fill("client");
    await expect(input).toBeFocused();

    await incrementCounter(page);

    await expect(input).toHaveValue("client");
  });

  test("patches an opted-in focused native input", async ({ page }) => {
    const input = page.locator("#native-opt-in");
    await input.fill("client");
    await expect(input).toBeFocused();

    await incrementCounter(page);

    await expect(input).toHaveValue("1");
  });
});
