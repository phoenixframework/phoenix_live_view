import { Socket } from "phoenix";
import {
  closestPhxBinding,
  detectDuplicateIds,
  detectInvalidStreamInserts,
} from "phoenix_live_view/utils";
import LiveSocket from "phoenix_live_view/live_socket";
import {
  simulateJoinedView,
  liveViewDOM,
  captureDiagnostics,
} from "./test_helpers";

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
      const element = global.document.querySelector("#innerContent")!;
      const parent = global.document.querySelector("#button");
      expect(closestPhxBinding(element, "phx-click")).toBe(parent);
    });

    test("if an element's parent is disabled, return null", () => {
      const _view = setupView(`
      <button id="button" phx-click="toggle" disabled>
        <span id="innerContent">This is a button</span>
      </button>
      `);
      const element = global.document.querySelector("#innerContent")!;
      expect(closestPhxBinding(element, "phx-click")).toBe(null);
    });
  });

  describe("diagnostics", () => {
    afterEach(() => jest.restoreAllMocks());

    test("duplicate ID diagnostics include both elements", () => {
      jest.spyOn(console, "error").mockImplementation(() => {});
      const { diagnostics, stop } = captureDiagnostics();
      const root = document.createElement("div");
      const id = "diagnostic-duplicate-id";
      root.innerHTML = `<div id="${id}"></div><div id="${id}"></div>`;
      document.body.appendChild(root);
      const elements = Array.from(root.children);

      try {
        detectDuplicateIds();
      } finally {
        root.remove();
        stop();
      }

      expect(
        diagnostics.find(
          ({ code, metadata }) =>
            code === "dom.duplicate-id" && metadata?.id === id,
        ),
      ).toMatchObject({
        version: 1,
        level: "error",
        code: "dom.duplicate-id",
        metadata: { id, elements },
      });
    });

    test("invalid stream diagnostics include the container", () => {
      jest.spyOn(console, "error").mockImplementation(() => {});
      const { diagnostics, stop } = captureDiagnostics();
      const container = document.createElement("div");
      const containerId = "diagnostic-stream-container";
      const itemId = "diagnostic-stream-item";
      container.id = containerId;
      container.innerHTML = `<div id="${itemId}"></div>`;
      document.body.appendChild(container);

      try {
        detectInvalidStreamInserts({ [itemId]: 0 });
      } finally {
        container.remove();
        stop();
      }

      expect(diagnostics).toEqual([
        {
          version: 1,
          level: "error",
          code: "dom.invalid-stream-container",
          message: `The stream container with id "${containerId}" is missing the phx-update="stream" attribute. Ensure it is set for streams to work properly.`,
          metadata: { id: containerId, container },
        },
      ]);
    });
  });
});
