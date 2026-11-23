import { test, expect } from "../../test-fixtures";
import { evalLV, syncLV } from "../../utils";

// Both the form and input are locked. The first reply arrives after "si"
// has been typed, creating a form clone and a nested input clone. Unlocking
// must not apply the form clone's stale value/attributes before the input clone.
for (const patchFocused of ["empty", "always", "never"]) {
  test(`nested input clones respect phx-patch-focused=${patchFocused}`, async ({
    page,
  }) => {
    await page.goto(`/issues/4504?patch_focused=${patchFocused}`);
    await syncLV(page);
    const input = page.locator("#q");
    await input.focus();
    await page.keyboard.type("si", { delay: 30 });
    await expect(page.locator("#server")).toHaveText("s");
    await page.keyboard.type("lk", { delay: 30 });
    await expect(page.locator("#server")).toHaveText("silk");
    await syncLV(page);
    await expect(input).toHaveValue("silk");
    await expect(input).toBeFocused();
    await expect(page.locator("[data-phx-ref-lock]")).toHaveCount(0);

    // A fresh server render must still be able to clear the focused input
    // when it opts in, including when the attribute was absent before the patch.
    await evalLV(page, '{:noreply, Phoenix.Component.assign(socket, :q, "")}');
    await syncLV(page);
    await expect(input).toHaveValue(patchFocused === "never" ? "silk" : "");
  });
}
