import { Socket } from "phoenix";
import LiveSocket from "phoenix_live_view/live_socket";

const stubViewPushEvent = (view, callback) => {
  view.pushEvent = (type, el, targetCtx, phxEvent, meta, opts = {}) => {
    return callback(type, el, targetCtx, phxEvent, meta, opts);
  };
};

const prepareLiveViewDOM = (document, rootId) => {
  document.body.innerHTML = `
    <div data-phx-session="abc123"
         data-phx-root-id="${rootId}"
         id="${rootId}">
      <label for="plus">Plus</label>
      <input id="plus" value="1" />
      <button id="btn" phx-click="inc_temperature">Inc Temperature</button>
    </div>
  `;
};

describe("metadata", () => {
  beforeEach(() => {
    prepareLiveViewDOM(global.document, "root");
  });

  test("is empty by default", () => {
    const liveSocket = new LiveSocket("/live", Socket);
    liveSocket.connect();
    const view = liveSocket.getViewByEl(document.getElementById("root"));
    const btn = view.el.querySelector("button");
    let meta = {};
    stubViewPushEvent(
      view,
      (type, el, target, targetCtx, phxEvent, metadata) => {
        meta = metadata;
      },
    );
    btn.dispatchEvent(new Event("click", { bubbles: true }));

    expect(meta).toEqual({});
  });

  test("can be user defined", () => {
    const liveSocket = new LiveSocket("/live", Socket, {
      metadata: {
        click: (e, el) => {
          return {
            id: el.id,
            altKey: e.altKey,
          };
        },
      },
    });
    liveSocket.connect();
    liveSocket.isConnected = () => true;
    const view = liveSocket.getViewByEl(document.getElementById("root"));
    view.isConnected = () => true;
    const btn = view.el.querySelector("button");
    let meta = {};
    stubViewPushEvent(view, (type, el, target, phxEvent, metadata, _opts) => {
      meta = metadata;
    });
    btn.dispatchEvent(new Event("click", { bubbles: true }));

    expect(meta).toEqual({
      id: "btn",
      altKey: undefined,
    });
  });
});
