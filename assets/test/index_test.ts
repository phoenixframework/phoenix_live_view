import {
  LiveSocket,
  isUsedInput,
  getFileURLForUpload,
  ViewHook,
} from "phoenix_live_view";
import * as LiveSocket2 from "phoenix_live_view/live_socket";
import ViewHook2 from "phoenix_live_view/view_hook";
import DOM from "phoenix_live_view/dom";
import LiveUploader from "phoenix_live_view/live_uploader";

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

function uploadInput(activeRefs: string = ""): HTMLInputElement {
  const input = document.createElement("input");
  input.type = "file";
  input.setAttribute("data-phx-active-refs", activeRefs);
  input.setAttribute("data-phx-done-refs", "");
  input.setAttribute("data-phx-preflighted-refs", "");
  return input;
}

describe("getFileURLForUpload", () => {
  beforeEach(() => {
    global.URL.createObjectURL = jest.fn(() => "blob:http://localhost/fake");
  });

  test("returns a URL for a file matching the ref", () => {
    const file = new File(["hello"], "test.txt", { type: "text/plain" });
    const ref = LiveUploader.genFileRef(file);
    const input = uploadInput(ref);
    DOM.putPrivate(input, "files", [file]);

    expect(getFileURLForUpload(input, ref)).toBe("blob:http://localhost/fake");
    expect(URL.createObjectURL).toHaveBeenCalledWith(file);
  });

  test("returns null when no file matches the ref", () => {
    const input = uploadInput();
    expect(getFileURLForUpload(input, "999")).toBeNull();
  });
});
