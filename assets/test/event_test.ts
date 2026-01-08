import { Socket } from "phoenix";
import LiveSocket from "phoenix_live_view/live_socket";
import View from "phoenix_live_view/view";

import { version as liveview_version } from "../../package.json";
import { HooksOptions } from "phoenix_live_viewview_hook";

let containerId = 0;

let simulateView = (liveSocket, events, innerHTML) => {
  let el = document.createElement("div");
  el.setAttribute("data-phx-session", "abc123");
  el.setAttribute("id", `container${containerId++}`);
  el.innerHTML = innerHTML;
  document.body.appendChild(el);

  let view = new View(el, liveSocket);
  view.onJoin({ rendered: { e: events, s: [innerHTML] }, liveview_version });
  view.isConnected = () => true;
  return view;
};

let stubNextChannelReply = (view, replyPayload) => {
  let oldPush = view.channel.push;
  view.channel.push = () => {
    return {
      receives: [],
      receive(kind, cb) {
        if (kind === "ok") {
          cb({ diff: { r: replyPayload } });
          view.channel.push = oldPush;
        }
        return this;
      },
    };
  };
};

let stubNextChannelReplyWithError = (view, reason) => {
  let oldPush = view.channel.push;
  view.channel.push = () => {
    return {
      receives: [],
      receive(kind, cb) {
        if (kind === "error") {
          cb(reason);
          view.channel.push = oldPush;
        }
        return this;
      },
    };
  };
};

describe("events", () => {
  let processedEvents;
  beforeEach(() => {
    document.body.innerHTML = "";
    processedEvents = [];
  });

  test("events on join", () => {
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: <HooksOptions>{
        Map: {
          mounted() {
            this.handleEvent("points", (data) =>
              processedEvents.push({ event: "points", data: data }),
            );
          },
        },
      },
    });
    let _view = simulateView(
      liveSocket,
      [["points", { values: [1, 2, 3] }]],
      `
      <div id="map" phx-hook="Map">
      </div>
    `,
    );

    expect(processedEvents).toEqual([
      { event: "points", data: { values: [1, 2, 3] } },
    ]);
  });

  test("events on update", () => {
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: <HooksOptions>{
        Game: {
          mounted() {
            this.handleEvent("scores", (data) =>
              processedEvents.push({ event: "scores", data: data }),
            );
          },
        },
      },
    });
    let view = simulateView(
      liveSocket,
      [],
      `
      <div id="game" phx-hook="Game">
      </div>
    `,
    );

    expect(processedEvents).toEqual([]);

    view.update({}, [["scores", { values: [1, 2, 3] }]]);
    expect(processedEvents).toEqual([
      { event: "scores", data: { values: [1, 2, 3] } },
    ]);
  });

  test("events handlers are cleaned up on destroy", () => {
    let destroyed: Array<string> = [];
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: <HooksOptions>{
        Handler: {
          mounted() {
            this.handleEvent("my-event", (data) =>
              processedEvents.push({
                id: this.el.id,
                event: "my-event",
                data: data,
              }),
            );
          },
          destroyed() {
            destroyed.push(this.el.id);
          },
        },
      },
    });
    let view = simulateView(
      liveSocket,
      [],
      `
      <div id="handler1" phx-hook="Handler"></div>
      <div id="handler2" phx-hook="Handler"></div>
    `,
    );

    expect(processedEvents).toEqual([]);

    view.update({}, [["my-event", { val: 1 }]]);
    expect(processedEvents).toEqual([
      { id: "handler1", event: "my-event", data: { val: 1 } },
      { id: "handler2", event: "my-event", data: { val: 1 } },
    ]);

    let newHTML = '<div id="handler1" phx-hook="Handler"></div>';
    view.update({ s: [newHTML] }, [["my-event", { val: 2 }]]);

    expect(destroyed).toEqual(["handler2"]);

    expect(processedEvents).toEqual([
      { id: "handler1", event: "my-event", data: { val: 1 } },
      { id: "handler2", event: "my-event", data: { val: 1 } },
      { id: "handler1", event: "my-event", data: { val: 2 } },
    ]);
  });

  test("removeHandleEvent", () => {
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: <HooksOptions>{
        Remove: {
          mounted() {
            let ref = this.handleEvent("remove", (data) => {
              this.removeHandleEvent(ref);
              processedEvents.push({ event: "remove", data: data });
            });
          },
        },
      },
    });
    let view = simulateView(
      liveSocket,
      [],
      `
      <div id="remove" phx-hook="Remove"></div>
    `,
    );

    expect(processedEvents).toEqual([]);

    view.update({}, [["remove", { val: 1 }]]);
    expect(processedEvents).toEqual([{ event: "remove", data: { val: 1 } }]);

    view.update({}, [["remove", { val: 1 }]]);
    expect(processedEvents).toEqual([{ event: "remove", data: { val: 1 } }]);
  });
});

describe("pushEvent replies", () => {
  let processedReplies;
  beforeEach(() => {
    processedReplies = [];
  });

  test("reply", (done) => {
    let view;
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: <HooksOptions>{
        Gateway: {
          mounted() {
            stubNextChannelReply(view, { transactionID: "1001" });
            this.pushEvent("charge", { amount: 123 }, (resp, ref) => {
              processedReplies.push({ resp, ref });
              view.el.dispatchEvent(
                new CustomEvent("replied", { detail: { resp, ref } }),
              );
            });
          },
        },
      },
    });
    view = simulateView(liveSocket, [], "");
    view.update(
      {
        s: [
          `
      <div id="gateway" phx-hook="Gateway">
      </div>
    `,
        ],
      },
      [],
    );

    view.el.addEventListener("replied", () => {
      expect(processedReplies).toEqual([
        { resp: { transactionID: "1001" }, ref: 0 },
      ]);
      done();
    });
  });

  test("promise", (done) => {
    let view;
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: <HooksOptions>{
        Gateway: {
          mounted() {
            stubNextChannelReply(view, { transactionID: "1001" });
            this.pushEvent("charge", { amount: 123 }).then((reply) => {
              processedReplies.push(reply);
              view.el.dispatchEvent(
                new CustomEvent("replied", { detail: reply }),
              );
            });
          },
        },
      },
    });
    view = simulateView(liveSocket, [], "");
    view.update(
      {
        s: [
          `
      <div id="gateway" phx-hook="Gateway">
      </div>
    `,
        ],
      },
      [],
    );

    view.el.addEventListener("replied", () => {
      expect(processedReplies).toEqual([{ transactionID: "1001" }]);
      done();
    });
  });

  test("rejects with error", (done) => {
    let view;
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: <HooksOptions>{
        Gateway: {
          mounted() {
            stubNextChannelReplyWithError(view, "error");
            this.pushEvent("charge", { amount: 123 }).catch((error) => {
              expect(error).toEqual(expect.any(Error));
              done();
            });
          },
        },
      },
    });
    view = simulateView(liveSocket, [], "");
    view.update(
      {
        s: [
          `
      <div id="gateway" phx-hook="Gateway">
      </div>
    `,
        ],
      },
      [],
    );
  });

  test("pushEventTo - promise with multiple targets", (done) => {
    let view;
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: <HooksOptions>{
        Gateway: {
          mounted() {
            stubNextChannelReply(view, { transactionID: "1001" });
            this.pushEventTo("[data-foo]", "charge", { amount: 123 }).then(
              (result) => {
                expect(result).toEqual([
                  {
                    status: "fulfilled",
                    value: { ref: 0, reply: { transactionID: "1001" } },
                  },
                  // we only stubbed one reply
                  { status: "rejected", reason: expect.any(Error) },
                ]);
                done();
              },
            );
          },
        },
      },
    });
    view = simulateView(liveSocket, [], "");
    liveSocket.main = view;
    liveSocket.roots[view.id] = view;
    view.update(
      {
        s: [
          `
      <div id="${view.id}" data-phx-session="abc123" data-phx-root-id="${view.id}">
        <div id="gateway" phx-hook="Gateway">
          <div data-foo="bar"></div>
          <div data-foo="baz"></div>
        </div>
      </div>
    `,
        ],
      },
      [],
    );
  });

  test("pushEvent without connection noops", (done) => {
    let view;
    const spy = jest.fn();
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: <HooksOptions>{
        Gateway: {
          mounted() {
            stubNextChannelReply(view, { transactionID: "1001" });
            this.pushEvent("charge", { amount: 1233433 })
              .then(spy)
              .catch(() => {
                view.el.dispatchEvent(new CustomEvent("pushed"));
              });
          },
        },
      },
    });
    view = simulateView(liveSocket, [], "");
    view.isConnected = () => false;
    view.update(
      {
        s: [
          `
      <div id="gateway" phx-hook="Gateway">
      </div>
    `,
        ],
      },
      [],
    );

    view.el.addEventListener("pushed", () => {
      expect(spy).not.toHaveBeenCalled();
      done();
    });
  });
});
