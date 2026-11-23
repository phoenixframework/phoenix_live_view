import { Socket } from "phoenix";
import LiveSocket from "phoenix_live_view/live_socket";
import DOMPatch from "phoenix_live_view/dom_patch";
import DOM from "phoenix_live_view/dom";
import { rootContainer, simulateJoinedView } from "../test_helpers";

// Component diffs must follow all ancestor clones, even if the nearest live
// ancestor has no private clone or the component root is itself locked.
describe("component patches inside nested locks", () => {
  let socket: LiveSocket;
  afterEach(() => {
    socket.destroyAllViews();
    document.body.innerHTML = "";
  });

  test("ignores a component diff when a nested clone has already removed its target", () => {
    socket = new LiveSocket("/live", Socket);
    const root = rootContainer(
      '<div id="outer"><div id="inner"><div id="component" data-phx-component="1" data-phx-view="root">old</div></div></div>',
    );
    root.setAttribute("data-phx-session", "session");
    const view = simulateJoinedView(root, socket);
    const locks = [
      root.querySelector("#outer")!,
      root.querySelector("#inner")!,
    ];
    view.putRef(
      locks.map((el) => ({ el, lock: true, loading: true })),
      "hold",
      "click",
    );
    view.performPatch(
      new DOMPatch(
        view,
        root,
        '<div id="root"><div id="outer"><div id="inner"></div></div></div>',
        new Set(),
        null,
      ),
      false,
    );

    view.performPatch(
      new DOMPatch(
        view,
        root,
        '<div id="component" data-phx-component="1" data-phx-view="root">new</div>',
        new Set(),
        1,
      ),
      false,
    );
    expect(root.querySelector("#component")!.textContent).toBe("old");
    view.undoRefs(0, "hold");
    expect(root.querySelector("#component")).toBeNull();
  });

  for (const prepareClone of [false, true]) {
    for (const lockComponent of [false, true]) {
      test.each([
        [0, 0],
        [0, 1],
        [1, 0],
      ])(
        `defers component patches (existing clone=${prepareClone}, component locked=${lockComponent}, refs=%i/%i)`,
        (outerRef, innerRef) => {
          const html =
            '<div id="outer"><div id="inner"><div id="component" data-phx-component="1" data-phx-view="root">old</div></div></div>';
          socket = new LiveSocket("/live", Socket);
          const root = rootContainer(html);
          root.setAttribute("data-phx-session", "session");
          const view = simulateJoinedView(root, socket);
          const outer = root.querySelector("#outer")!;
          const inner = root.querySelector("#inner")!;
          const component = root.querySelector("#component")!;
          const locks = [outer, inner, ...(lockComponent ? [component] : [])];
          view.putRef(
            locks.map((el) => ({ el, lock: true, loading: true })),
            "hold",
            "click",
          );
          for (const el of locks) {
            const ref = el === outer ? outerRef : innerRef;
            el.setAttribute("data-phx-ref-lock", String(ref));
            el.setAttribute("data-phx-ref-loading", String(ref));
          }
          if (prepareClone) {
            view.performPatch(
              new DOMPatch(
                view,
                root,
                `<div id="root">${html}</div>`,
                new Set(),
                null,
              ),
              false,
            );
            expect(DOM.private(outer, "data-phx-ref-lock")).toBeDefined();
          }
          const patch = (label: string) =>
            view.performPatch(
              new DOMPatch(
                view,
                root,
                `<div id="component" data-phx-component="1" data-phx-view="root">${label}</div>`,
                new Set(),
                1,
              ),
              false,
            );
          patch("first");
          patch("new");
          expect(component.textContent).toBe("old");
          view.undoRefs(0, "hold");
          if (outerRef !== innerRef) expect(component.textContent).toBe("old");
          view.undoRefs(1, "hold");
          expect(component.textContent).toBe("new");
          expect(root.querySelector("[data-phx-ref-lock]")).toBeNull();
        },
      );
    }
  }
});
