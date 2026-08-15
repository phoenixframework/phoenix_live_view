import Hooks from "phoenix_live_view/hooks";

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
