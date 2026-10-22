import { Socket } from "phoenix";
import LiveSocket from "phoenix_live_view/live_socket";
import View from "phoenix_live_view/view";
import EntryUploader from "phoenix_live_view/entry_uploader";
import { version as liveview_version } from "../../package.json";

// A never-networked transport, the shape a client-side LiveView runtime
// (a Wasm VM, a worker, a service worker) would hand to a Phoenix Socket.
const fakeTransport = () => {
  const sent: any[] = [];
  let instance: any = null;
  const track = (transport: any) => {
    instance = transport;
  };
  class FakeTransport {
    readyState = 0;
    onopen: () => void = () => {};
    onerror: (e: unknown) => void = () => {};
    onmessage: (e: { data: any }) => void = () => {};
    onclose: (e: unknown) => void = () => {};
    constructor(_url: string) {
      track(this);
      this.readyState = 1;
      queueMicrotask(() => this.onopen());
    }
    send(frame: any) {
      sent.push(frame);
    }
    close() {
      this.readyState = 3;
    }
  }
  return {
    FakeTransport,
    sent,
    reply: (frame: any) => instance.onmessage({ data: frame }),
  };
};

const rootEl = (id: string, attrs: Record<string, string> = {}) => {
  const div = document.createElement("div");
  div.setAttribute("data-phx-session", "abc123");
  div.setAttribute("id", id);
  for (const key in attrs) {
    div.setAttribute(key, attrs[key]);
  }
  document.body.appendChild(div);
  return div;
};

describe("socketFor", () => {
  let localSocket: Socket;
  let liveSocket: LiveSocket;

  beforeEach(() => {
    document.body.innerHTML = "";
    localSocket = new Socket("/local");
    liveSocket = new LiveSocket("/live", Socket, {
      socketFor: (el) => (el.hasAttribute("data-local") ? localSocket : null),
    });
  });

  test("a root the callback does not claim stays on the LiveSocket's socket", () => {
    const view = new View(rootEl("remote"), liveSocket, null);

    expect(view.socket()).toBe(liveSocket.getSocket());
    expect(view.socket()).not.toBe(localSocket);
  });

  test("a root the callback claims gets its channel on the returned socket", () => {
    const ownSpy = jest.spyOn(liveSocket.getSocket(), "channel");
    const localSpy = jest.spyOn(localSocket, "channel");

    const view = new View(
      rootEl("local", { "data-local": "" }),
      liveSocket,
      null,
    );

    expect(view.socket()).toBe(localSocket);
    expect(localSpy).toHaveBeenCalledWith("lv:local", expect.any(Function));
    expect(ownSpy).not.toHaveBeenCalled();
  });

  test("the callback is asked once per root, not per child view", () => {
    const socketFor = jest.fn(() => localSocket);
    liveSocket = new LiveSocket("/live", Socket, { socketFor });

    const parent = new View(rootEl("parent"), liveSocket, null);
    const child = new View(rootEl("child"), liveSocket, parent);

    expect(socketFor).toHaveBeenCalledTimes(1);
    expect(child.socket()).toBe(parent.socket());
    expect(child.socket()).toBe(localSocket);
  });

  test("a child of an unclaimed root stays on the LiveSocket's socket", () => {
    const parent = new View(rootEl("remote"), liveSocket, null);
    const child = new View(rootEl("remote-child"), liveSocket, parent);

    expect(child.socket()).toBe(liveSocket.getSocket());
  });

  test("uploads ride the socket of the view that owns the entry", () => {
    const localSpy = jest.spyOn(localSocket, "channel");
    const view = new View(
      rootEl("local", { "data-local": "" }),
      liveSocket,
      null,
    );
    localSpy.mockClear();

    const entry = {
      ref: "0",
      view,
      fileEl: { form: {} },
      metadata: () => ({ token: "t" }),
      error: jest.fn(),
    };
    new EntryUploader(
      entry,
      { chunk_size: 1024, chunk_timeout: 5000 },
      liveSocket,
    );

    expect(localSpy).toHaveBeenCalledWith("lvu:0", { token: { token: "t" } });
  });

  test("uploads of an unclaimed view stay on the LiveSocket's socket", () => {
    const ownSpy = jest.spyOn(liveSocket.getSocket(), "channel");
    const view = new View(rootEl("remote"), liveSocket, null);
    ownSpy.mockClear();

    const entry = {
      ref: "1",
      view,
      fileEl: { form: {} },
      metadata: () => ({}),
      error: jest.fn(),
    };
    new EntryUploader(
      entry,
      { chunk_size: 1024, chunk_timeout: 5000 },
      liveSocket,
    );

    expect(ownSpy).toHaveBeenCalledWith("lvu:1", { token: {} });
  });

  test("a view on a foreign socket never reloads the page", () => {
    const disconnect = jest.spyOn(liveSocket, "disconnect");
    const local = new View(
      rootEl("local", { "data-local": "" }),
      liveSocket,
      null,
    );

    liveSocket.reloadWithJitter(local);

    expect(disconnect).not.toHaveBeenCalled();
  });

  test("a view on the LiveSocket's own socket still reloads the page", () => {
    const disconnect = jest.spyOn(liveSocket, "disconnect");
    const remote = new View(rootEl("remote"), liveSocket, null);

    liveSocket.reloadWithJitter(remote);

    expect(disconnect).toHaveBeenCalled();
  });
});

describe("socketFor end to end", () => {
  test("a claimed root joins and renders over the foreign socket", async () => {
    document.body.innerHTML = "";
    const { FakeTransport, sent, reply } = fakeTransport();
    const local = new Socket("/local", {
      transport: FakeTransport as any,
      encode: (payload, cb) => cb(payload),
      decode: (payload, cb) => cb(payload),
    } as any);
    local.connect();

    const liveSocket = new LiveSocket("/live", Socket, {
      socketFor: (el) => (el.hasAttribute("data-local") ? local : null),
    });

    const el = document.createElement("div");
    el.setAttribute("data-phx-session", "local-session");
    el.setAttribute("data-local", "");
    el.id = "phx-local";
    el.innerHTML = "<span>placeholder</span>";
    document.body.appendChild(el);

    liveSocket.connect();
    // let the fake transport open and flush the buffered join
    await new Promise((resolve) => setTimeout(resolve, 0));

    const join = sent.find((f) => f.event === "phx_join");
    expect(join).toBeDefined();
    expect(join.topic).toBe("lv:phx-local");
    expect(join.payload.session).toBe("local-session");

    reply({
      topic: join.topic,
      event: "phx_reply",
      ref: join.ref,
      join_ref: join.join_ref,
      payload: {
        status: "ok",
        response: {
          rendered: { s: ["<div><span>rendered locally</span></div>"] },
          liveview_version,
        },
      },
    });
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(document.getElementById("phx-local")!.textContent).toContain(
      "rendered locally",
    );
    // nothing about this view went over the page's socket
    expect(liveSocket.getSocket().isConnected()).toBe(false);
  });
});
