import { Socket } from "phoenix";
import LiveSocket from "phoenix_live_view/live_socket";
import DOMPatch from "phoenix_live_view/dom_patch";

import { liveViewDOM, simulateJoinedView } from "./test_helpers";

describe("DOMPatch", () => {
  test("preserves new children when a component root id changes", () => {
    const root = liveViewDOM(`
      <div id="old-component" data-phx-component="1" data-phx-view="container">
        <span id="old-child">old</span>
      </div>
    `);
    const liveSocket = new LiveSocket("/live", Socket);
    const view = simulateJoinedView(root, liveSocket);
    const added: Node[] = [];

    const patch = new DOMPatch(
      view,
      root,
      '<div id="new-component" data-phx-component="1" data-phx-view="container"><span id="new-child"><strong>new</strong></span></div>',
      new Set(),
      1,
    );
    patch.afterAdded((node) => added.push(node));

    patch.perform(false);

    const component = root.querySelector("#new-component")!;
    expect(component.innerHTML).toContain(
      '<span id="new-child"><strong>new</strong></span>',
    );
    expect(added).toEqual([
      component,
      component.querySelector("#new-child"),
      component.querySelector("strong"),
      component.querySelector("strong")!.firstChild,
    ]);
  });
});
