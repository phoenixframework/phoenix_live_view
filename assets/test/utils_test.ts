import { Socket } from "phoenix";
import { closestPhxBinding } from "phoenix_live_view/utils";
import LiveSocket from "phoenix_live_view/live_socket";
import { simulateJoinedView, liveViewDOM } from "./test_helpers";

const setupView = (content) => {
  const el = liveViewDOM(content);
  global.document.body.appendChild(el);
  const liveSocket = new LiveSocket("/live", Socket);
  return simulateJoinedView(el, liveSocket);
};

describe("utils", () => {
  describe("closestPhxBinding", () => {
    test("if an element's parent has a phx-click binding and is not disabled, return the parent", () => {
      const _view = setupView(`
      <button id="button" phx-click="toggle">
        <span id="innerContent">This is a button</span>
      </button>
      `);
      const element = global.document.querySelector("#innerContent");
      const parent = global.document.querySelector("#button");
      expect(closestPhxBinding(element, "phx-click")).toBe(parent);
    });

    test("if an element's parent is disabled, return null", () => {
      const _view = setupView(`
      <button id="button" phx-click="toggle" disabled>
        <span id="innerContent">This is a button</span>
      </button>
      `);
      const element = global.document.querySelector("#innerContent");
      expect(closestPhxBinding(element, "phx-click")).toBe(null);
    });
  });
});
