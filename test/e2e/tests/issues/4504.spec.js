import { test, expect } from "../../test-fixtures";
import { evalLV, syncLV } from "../../utils";

// Both the form and input are locked. Release the first reply after "si"
// has been typed, creating a form clone and a nested input clone. Unlocking
// must not apply the form clone's stale value/attributes before the input clone.
for (const patchFocused of ["empty", "always", "never"]) {
  test(`nested input clones respect phx-patch-focused=${patchFocused}`, async ({
    page,
  }) => {
    let holdReplies = false;
    const replies = [];
    await page.routeWebSocket(/\/live\/websocket(?:\?|$)/, (socket) => {
      const server = socket.connectToServer();
      server.onMessage((message) => {
        if (holdReplies && JSON.parse(message.toString())[3] === "phx_reply") {
          replies.push(() => socket.send(message));
        } else {
          socket.send(message);
        }
      });
    });
    await page.goto(`/issues/4504?patch_focused=${patchFocused}`);
    await syncLV(page);
    const input = page.locator("#q");
    await input.focus();
    holdReplies = true;
    await page.keyboard.type("si");
    await expect.poll(() => replies.length).toBe(2);
    replies.shift()();
    await expect(page.locator("#server")).toHaveText("s");
    await page.keyboard.type("lk");
    await expect.poll(() => replies.length).toBe(3);
    holdReplies = false;
    replies.splice(0).forEach((release) => release());
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
