import { test, expect } from "../../test-fixtures";
import { syncLV, evalLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/pull/4323
//
// Form-Associated Custom Elements (FACEs) store their value in
// ElementInternals (via setFormValue), not in DOM children. When a FACE
// host has focus, morphdom should still descend into its light-DOM children
// to patch them normally. These tests cover the fix and verify no
// regressions for related scenarios.

const incrementCounter = async (page) => {
  await evalLV(
    page,
    "{:noreply, Phoenix.Component.assign(socket, :counter, socket.assigns.counter + 1)}",
  );
  await syncLV(page);
};

test.describe("FACE children patching", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/issues/4323");
    await syncLV(page);
  });

  test("FACE host focused: light DOM children are patched", async ({
    page,
  }) => {
    await expect(page.locator("#case1-child")).toHaveText("count:0");

    await page.locator("#case1").focus();
    await expect(page.locator("#case1")).toBeFocused();

    await incrementCounter(page);

    await expect(page.locator("#case1-child")).toHaveText("count:1");
  });

  test("FACE host focused with input child: children are patched", async ({
    page,
  }) => {
    await expect(page.locator("#case2-child")).toHaveText("count:0");

    // Focus the FACE host, NOT the input inside it
    await page.locator("#case2").focus();
    await expect(page.locator("#case2")).toBeFocused();

    await incrementCounter(page);

    await expect(page.locator("#case2-child")).toHaveText("count:1");
  });

  test("FACE with slotted input focused: input is protected, siblings patched", async ({
    page,
  }) => {
    await expect(page.locator("#case3-child")).toHaveText("count:0");

    // Focus the slotted input (not the FACE host)
    await page.locator("#case3-input").focus();
    await expect(page.locator("#case3-input")).toBeFocused();
    await page.locator("#case3-input").fill("user-typed");

    await incrementCounter(page);

    // Input value is preserved by normal focus-skip
    await expect(page.locator("#case3-input")).toHaveValue("user-typed");
    // Sibling children are still patched (FACE host is not focused)
    await expect(page.locator("#case3-child")).toHaveText("count:1");
  });

  test("FACE with delegatesFocus: light DOM children are patched", async ({
    page,
  }) => {
    await expect(page.locator("#case4-child")).toHaveText("count:0");

    // Click the FACE host; delegatesFocus sends focus to the shadow input,
    // but document.activeElement still returns the shadow host
    await page.locator("#case4").click();
    const activeId = await page.evaluate(() => document.activeElement?.id);
    expect(activeId).toBe("case4");

    await incrementCounter(page);

    await expect(page.locator("#case4-child")).toHaveText("count:1");
  });

  test("FACE with slot + delegatesFocus: slotted children are patched", async ({
    page,
  }) => {
    await expect(page.locator("#case6-child")).toHaveText("count:0");

    // Click the FACE host; delegatesFocus sends focus to the shadow input,
    // but document.activeElement returns the shadow host
    await page.locator("#case6").click();
    const activeId = await page.evaluate(() => document.activeElement?.id);
    expect(activeId).toBe("case6");

    await incrementCounter(page);

    // Slotted light DOM children should be patched (FACE branch descends)
    await expect(page.locator("#case6-child")).toHaveText("count:1");
  });

  test("non-FACE custom element: children are patched normally", async ({
    page,
  }) => {
    await expect(page.locator("#case5-child")).toHaveText("count:0");

    await page.locator("#case5").focus();
    await expect(page.locator("#case5")).toBeFocused();

    await incrementCounter(page);

    // Non-FACE elements are not treated as editable inputs,
    // so morphdom patches them normally regardless of focus
    await expect(page.locator("#case5-child")).toHaveText("count:1");
  });
});
