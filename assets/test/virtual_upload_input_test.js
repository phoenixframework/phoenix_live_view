import VirtualUploadInput from "phoenix_live_view/virtual_upload_input";
import { PHX_UPLOAD_REF } from "phoenix_live_view/constants";
import DOM from "phoenix_live_view/dom";
import LiveUploader from "phoenix_live_view/live_uploader";

describe("VirtualUploadInput", () => {
  const view = { el: document.createElement("div") };

  test("implements the input surface LiveUploader touches", () => {
    const input = new VirtualUploadInput(view, "octet", []);

    expect(input.form).toBe(view.el);
    expect(DOM.isAutoUpload(input)).toBe(true);
    expect(input.getAttribute(PHX_UPLOAD_REF)).toBe(null);

    input.adoptUploadRef("phx-ref-123");
    expect(input.getAttribute(PHX_UPLOAD_REF)).toBe("phx-ref-123");

    input.removeAttribute(PHX_UPLOAD_REF);
    expect(input.hasAttribute(PHX_UPLOAD_REF)).toBe(false);

    // inert listener surface used by UploadEntry
    expect(() => {
      input.addEventListener("phx:live-file:updated", () => {});
      input.removeEventListener("phx:live-file:updated", () => {});
      input.dispatchEvent(new Event("change"));
    }).not.toThrow();
  });

  test("tracks private file storage like a DOM input", () => {
    const files = [new File(["bytes"], "a.bin")];
    const input = new VirtualUploadInput(view, "octet", files);

    DOM.putPrivate(input, "files", files);
    expect(DOM.private(input, "files")).toBe(files);
  });

  test("generates unique default entry names", () => {
    expect(VirtualUploadInput.nextEntryName()).not.toBe(
      VirtualUploadInput.nextEntryName(),
    );
  });

  test("drives a real LiveUploader through preflight bookkeeping", () => {
    const files = [new File(["some bytes"], "payload.bin")];
    const input = new VirtualUploadInput(view, "octet", files);

    LiveUploader.trackFiles(input, files);
    const uploader = new LiveUploader(input, view, () => {});

    const entries = uploader.entries();
    expect(entries.length).toBe(1);
    expect(entries[0].toPreflightPayload().name).toBe("payload.bin");

    // marked in progress, so a second uploader sees nothing awaiting preflight
    expect(LiveUploader.filesAwaitingPreflight(input).length).toBe(0);
  });
});
