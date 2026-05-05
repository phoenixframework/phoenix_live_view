import Hooks from "phoenix_live_view/hooks";

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

      expect(() => Hooks.InfiniteScroll.updated.call(ctx)).not.toThrow();
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

      Hooks.InfiniteScroll.updated.call(ctx);

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

      Hooks.InfiniteScroll.updated.call(ctx);

      expect(ctx.destroyed).not.toHaveBeenCalled();
      expect(ctx.mounted).not.toHaveBeenCalled();
    });
  });
});
