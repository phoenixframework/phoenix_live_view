import Hooks from "phoenix_live_view/hooks";
import LiveUploader from "phoenix_live_view/live_uploader";

describe("LiveFileUpload", () => {
  afterEach(() => {
    document.body.innerHTML = "";
  });

  test("cancels a scheduled submit when the upload becomes errored", () => {
    document.body.innerHTML = `
      <form>
        <input
          type="file"
          data-phx-active-refs="0"
          data-phx-preflighted-refs=""
        >
      </form>
    `;

    const input = document.querySelector("input")!;
    const cancelSubmit = jest.fn();
    const ctx = {
      ...Hooks.LiveFileUpload,
      el: input,
      js: () => ({ ignoreAttributes: jest.fn() }),
      __view: () => ({ cancelSubmit }),
    };

    Hooks.LiveFileUpload.mounted!.call(ctx as any);
    input.setAttribute("data-phx-error-refs", "0");
    Hooks.LiveFileUpload.updated!.call(ctx as any);

    expect(cancelSubmit).toHaveBeenCalledWith(input.form);
  });

  test("retries an if-valid auto upload when its errors are cleared", () => {
    document.body.innerHTML = `
      <form>
        <input
          type="file"
          multiple
          data-phx-upload-ref="upload-ref"
          data-phx-auto-upload="if_valid"
          data-phx-active-refs=""
          data-phx-preflighted-refs=""
          data-phx-error-refs="upload-ref"
        >
      </form>
    `;

    const input = document.querySelector("input")!;
    const file = new File(["valid"], "valid.jpg", { type: "image/jpeg" });
    const ref = LiveUploader.genFileRef(file);
    input.setAttribute("data-phx-active-refs", ref);
    LiveUploader.trackFiles(input, [file]);

    const ctx = {
      ...Hooks.LiveFileUpload,
      el: input,
      js: () => ({ ignoreAttributes: jest.fn() }),
      __view: () => ({ cancelSubmit: jest.fn() }),
    };
    const onInput = jest.fn();
    input.addEventListener("input", onInput);

    Hooks.LiveFileUpload.mounted!.call(ctx as any);
    input.setAttribute("data-phx-error-refs", "");
    Hooks.LiveFileUpload.updated!.call(ctx as any);

    expect(onInput).toHaveBeenCalledTimes(1);
  });
});

describe("InfiniteScroll", () => {
  describe("updated", () => {
    afterEach(() => {
      document.body.innerHTML = "";
    });

    // https://github.com/phoenixframework/phoenix_live_view/issues/4169
    test("does not throw when scrollContainer is null (window scrolls)", () => {
      const ctx = {
        scrollContainer: null,
        destroyed: jest.fn(),
        mounted: jest.fn(),
      };

      expect(() =>
        Hooks.InfiniteScroll.updated!.call(ctx as any),
      ).not.toThrow();
      expect(ctx.destroyed).not.toHaveBeenCalled();
      expect(ctx.mounted).not.toHaveBeenCalled();
    });

    test("re-mounts when scrollContainer was removed from the DOM", () => {
      const container = document.createElement("div");
      const ctx = {
        scrollContainer: container,
        destroyed: jest.fn(),
        mounted: jest.fn(),
      };

      Hooks.InfiniteScroll.updated!.call(ctx as any);

      expect(ctx.destroyed).toHaveBeenCalledTimes(1);
      expect(ctx.mounted).toHaveBeenCalledTimes(1);
    });

    test("does nothing when scrollContainer is still connected", () => {
      const container = document.createElement("div");
      document.body.appendChild(container);
      const ctx = {
        scrollContainer: container,
        destroyed: jest.fn(),
        mounted: jest.fn(),
      };

      Hooks.InfiniteScroll.updated!.call(ctx as any);

      expect(ctx.destroyed).not.toHaveBeenCalled();
      expect(ctx.mounted).not.toHaveBeenCalled();
    });
  });
});
