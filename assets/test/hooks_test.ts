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
          required
          data-phx-active-refs=""
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
    expect(input.required).toBe(false);
  });

  test("removes required while the upload has selected files", () => {
    document.body.innerHTML = `
      <form>
        <input
          type="file"
          required
          data-phx-active-refs="0"
          data-phx-preflighted-refs=""
        >
      </form>
    `;

    const input = document.querySelector("input")!;
    const ctx = {
      ...Hooks.LiveFileUpload,
      el: input,
      js: () => ({ ignoreAttributes: jest.fn() }),
    };

    Hooks.LiveFileUpload.mounted!.call(ctx as any);

    expect(input.required).toBe(false);

    input.setAttribute("required", "");
    input.setAttribute("data-phx-active-refs", "");
    Hooks.LiveFileUpload.updated!.call(ctx as any);

    expect(input.required).toBe(true);
  });

  test("leaves required in place when the upload has no selected files", () => {
    document.body.innerHTML = `
      <form>
        <input
          type="file"
          required
          data-phx-active-refs=""
          data-phx-preflighted-refs=""
        >
      </form>
    `;

    const input = document.querySelector("input")!;
    const ctx = {
      ...Hooks.LiveFileUpload,
      el: input,
      js: () => ({ ignoreAttributes: jest.fn() }),
    };

    Hooks.LiveFileUpload.mounted!.call(ctx as any);

    expect(input.required).toBe(true);
  });

  test("does not discard programmatically tracked files when removing required", () => {
    document.body.innerHTML = `
      <form>
        <input
          type="file"
          name="documents"
          multiple
          required
          data-phx-upload-ref="upload-ref"
          data-phx-active-refs=""
          data-phx-preflighted-refs=""
        >
      </form>
    `;

    const input = document.querySelector("input")!;
    const ctx = {
      ...Hooks.LiveFileUpload,
      el: input,
      js: () => ({ ignoreAttributes: jest.fn() }),
    };

    Hooks.LiveFileUpload.mounted!.call(ctx as any);
    LiveUploader.trackFiles(input, [new File(["first"], "first.txt")]);
    input.dispatchEvent(new Event("input"));

    expect(input.required).toBe(false);
    expect(LiveUploader.serializeUploads(input)).toMatchObject({
      "upload-ref": [{ name: "first.txt" }],
    });
  });
});

describe("InfiniteScroll", () => {
  afterEach(() => {
    jest.useRealTimers();
    document.body.innerHTML = "";
  });

  describe("updated", () => {
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

  test("cancels pending throttle timers when destroyed", () => {
    jest.useFakeTimers();
    jest.setSystemTime(0);

    const scrollContainer = document.createElement("div");
    scrollContainer.style.overflowY = "scroll";
    const hookEl = document.createElement("div");
    hookEl.setAttribute("phx-viewport-bottom", "load-more");
    hookEl.appendChild(document.createElement("div"));
    scrollContainer.appendChild(hookEl);
    document.body.appendChild(scrollContainer);
    Object.defineProperty(scrollContainer, "scrollTop", {
      configurable: true,
      writable: true,
      value: 0,
    });

    const push = jest.fn();
    const ctx = {
      el: hookEl,
      liveSocket: {
        binding: (name: string) => `phx-${name}`,
        js: () => ({ push }),
      },
      findOverrunTarget: Hooks.InfiniteScroll.findOverrunTarget,
      throttle: Hooks.InfiniteScroll.throttle,
    };

    Hooks.InfiniteScroll.mounted!.call(ctx as any);
    scrollContainer.scrollTop = 1;
    (ctx as any).onScroll(new Event("scroll"));
    Hooks.InfiniteScroll.destroyed!.call(ctx as any);

    jest.runAllTimers();

    expect(push).not.toHaveBeenCalled();
  });
});
