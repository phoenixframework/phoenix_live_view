import { LiveSocket, isUsedInput, ViewHook } from "phoenix_live_view";
import * as LiveSocket2 from "phoenix_live_view/live_socket";
import ViewHook2 from "phoenix_live_view/view_hook";
import DOM from "phoenix_live_view/dom";

describe("Named Imports", () => {
  test("LiveSocket is equal to the actual LiveSocket", () => {
    expect(LiveSocket).toBe(LiveSocket2.default);
  });

  test("ViewHook is equal to the actual ViewHook", () => {
    expect(ViewHook).toBe(ViewHook2);
  });
});

describe("isUsedInput", () => {
  test("returns true if the input is used", () => {
    const input = document.createElement("input");
    input.type = "text";
    expect(isUsedInput(input)).toBeFalsy();
    DOM.putPrivate(input, "phx-has-focused", true);
    expect(isUsedInput(input)).toBe(true);
  });
});
