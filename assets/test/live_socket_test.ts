import { Socket } from "phoenix";
import { type LiveViewDiagnostic } from "phoenix_live_view/diagnostics";
import { PHX_LV_DIAGNOSTIC_EVENT } from "phoenix_live_view/constants";
import LiveSocket from "phoenix_live_view/live_socket";
import {
  RenderingBuffer,
  ReportingBuffer,
} from "phoenix_live_view/rendered/buffer";
import JS from "phoenix_live_view/js";
import View from "phoenix_live_view/view";
import Browser from "phoenix_live_view/browser";
import { version as liveview_version } from "../../package.json";
import {
  liveViewDOM,
  simulateJoinedView,
  simulateVisibility,
  stubChannel,
} from "./test_helpers";

const container = (num) => global.document.getElementById(`container${num}`);

const prepareLiveViewDOM = (document) => {
  const div = document.createElement("div");
  div.setAttribute("data-phx-session", "abc123");
  div.setAttribute("data-phx-root-id", "container1");
  div.setAttribute("id", "container1");
  div.innerHTML = `
    <label for="plus">Plus</label>
    <input id="plus" value="1" />
    <button phx-click="inc_temperature">Inc Temperature</button>
  `;
  const button = div.querySelector("button");
  const input = div.querySelector("input");
  button.addEventListener("click", () => {
    setTimeout(() => {
      input.value += 1;
    }, 200);
  });
  document.body.appendChild(div);
};

describe("LiveSocket", () => {
  let liveSocket;

  beforeEach(() => {
    prepareLiveViewDOM(global.document);
  });

  afterEach(() => {
    liveSocket && liveSocket.destroyAllViews();
    liveSocket = null;
  });

  afterAll(() => {
    global.document.body.innerHTML = "";
  });

  test("sets defaults", async () => {
    liveSocket = new LiveSocket("/live", Socket);
    expect(liveSocket.socket).toBeDefined();
    expect(liveSocket.socket.onOpen).toBeDefined();
    expect(liveSocket.viewLogger).toBeUndefined();
    expect(liveSocket.unloaded).toBe(false);
    expect(liveSocket.bindingPrefix).toBe("phx-");
    expect(liveSocket.prevActive).toBe(null);
    expect(liveSocket.cascadePhxRemoveOnNavigation).toBe(true);
  });

  test("selects phx-remove elements for live navigation", () => {
    const mainEl = container(1)!;
    mainEl.setAttribute("phx-remove", "[]");
    mainEl.innerHTML = `
      <div id="remove-child" phx-remove="[]"></div>
      <div id="keep-child"></div>
    `;

    liveSocket = new LiveSocket("/live", Socket);
    expect(
      liveSocket.phxRemoveElementsForNavigation(mainEl).map((el) => el.id),
    ).toEqual(["container1", "remove-child"]);

    liveSocket = new LiveSocket("/live", Socket, {
      cascadePhxRemoveOnNavigation: false,
    });
    expect(
      liveSocket.phxRemoveElementsForNavigation(mainEl).map((el) => el.id),
    ).toEqual(["container1"]);
  });

  test("viewLogger", async () => {
    const viewLogger = jest.fn();
    liveSocket = new LiveSocket("/live", Socket, { viewLogger });
    expect(liveSocket.viewLogger).toBe(viewLogger);
    liveSocket.connect();
    const view = liveSocket.getViewByEl(container(1));
    const diagnostics: LiveViewDiagnostic[] = [];
    const listener = (event: Event) => {
      diagnostics.push((event as CustomEvent<LiveViewDiagnostic>).detail);
    };
    window.addEventListener(PHX_LV_DIAGNOSTIC_EVENT, listener);
    try {
      liveSocket.log(
        view,
        "update",
        () => ["received diff", JSON.stringify("<div>")],
        {
          code: "view.diff-update",
          metadata: () => ({ diff: "<div>" }),
        },
      );
    } finally {
      window.removeEventListener(PHX_LV_DIAGNOSTIC_EVENT, listener);
    }
    expect(viewLogger).toHaveBeenCalledWith(
      view,
      "update",
      "received diff",
      JSON.stringify("<div>"),
    );
    expect(diagnostics).toEqual([
      {
        version: 1,
        level: "debug",
        code: "view.diff-update",
        message: "received diff",
        viewId: view.id,
        metadata: { diff: "<div>" },
        attribution: "unknown",
      },
    ]);
  });

  test("view errors are always emitted and include the view ID", () => {
    liveSocket = new LiveSocket("/live", Socket);
    liveSocket.connect();
    liveSocket.disableDebug();
    const view = liveSocket.getViewByEl(container(1));
    const diagnostics: LiveViewDiagnostic[] = [];
    const listener = (event: Event) => {
      diagnostics.push((event as CustomEvent<LiveViewDiagnostic>).detail);
    };
    const consoleError = jest
      .spyOn(console, "error")
      .mockImplementation(() => {});
    window.addEventListener(PHX_LV_DIAGNOSTIC_EVENT, listener);

    try {
      view.logError("view.test-error", "test error", { reason: "test" });

      expect(consoleError).toHaveBeenCalledWith("test error", {
        reason: "test",
      });
      expect(diagnostics).toEqual([
        {
          version: 1,
          level: "error",
          code: "view.test-error",
          message: "test error",
          viewId: view.id,
          metadata: { reason: "test" },
          attribution: "unknown",
        },
      ]);
    } finally {
      window.removeEventListener(PHX_LV_DIAGNOSTIC_EVENT, listener);
      consoleError.mockRestore();
    }
  });

  test("does not dispatch debug diagnostics for viewLogger when debugging is disabled", () => {
    const viewLogger = jest.fn();
    liveSocket = new LiveSocket("/live", Socket, { viewLogger });
    liveSocket.disableDebug();
    const view = { id: "view-id" };
    const listener = jest.fn();
    const metadata = jest.fn(() => ({ value: 1 }));
    window.addEventListener(PHX_LV_DIAGNOSTIC_EVENT, listener);

    try {
      liveSocket.log(view, "update", () => ["message", { value: 1 }], {
        code: "view.diff-update",
        metadata,
      });
    } finally {
      window.removeEventListener(PHX_LV_DIAGNOSTIC_EVENT, listener);
    }

    expect(viewLogger).toHaveBeenCalledWith(view, "update", "message", {
      value: 1,
    });
    expect(metadata).not.toHaveBeenCalled();
    expect(listener).not.toHaveBeenCalled();
  });

  test("dispatches error-level log diagnostics without logging to the console when debugging is disabled", () => {
    liveSocket = new LiveSocket("/live", Socket);
    liveSocket.disableDebug();
    const view = { id: "view-id" };
    const diagnostics: LiveViewDiagnostic[] = [];
    const listener = (event: Event) => {
      diagnostics.push((event as CustomEvent<LiveViewDiagnostic>).detail);
    };
    const consoleLog = jest.spyOn(console, "log").mockImplementation(() => {});
    window.addEventListener(PHX_LV_DIAGNOSTIC_EVENT, listener);

    try {
      liveSocket.log(view, "error", () => ["unable to join", { reason: 1 }], {
        code: "view.join-failed",
        level: "error",
        metadata: () => ({ response: { reason: 1 } }),
        context: { attribution: "network" },
      });
    } finally {
      window.removeEventListener(PHX_LV_DIAGNOSTIC_EVENT, listener);
      consoleLog.mockRestore();
    }

    expect(consoleLog).not.toHaveBeenCalled();
    expect(diagnostics).toEqual([
      {
        version: 1,
        level: "error",
        code: "view.join-failed",
        message: "unable to join",
        viewId: "view-id",
        metadata: { response: { reason: 1 } },
        attribution: "network",
      },
    ]);
  });

  test("does not evaluate or dispatch debug logs when debugging is disabled", () => {
    liveSocket = new LiveSocket("/live", Socket);
    liveSocket.disableDebug();
    const view = { id: "view-id" };
    const msgCallback = jest.fn(() => ["message", { value: 1 }]);
    const listener = jest.fn();
    window.addEventListener(PHX_LV_DIAGNOSTIC_EVENT, listener);

    try {
      liveSocket.log(view, "update", msgCallback, {
        code: "view.diff-update",
      });
    } finally {
      window.removeEventListener(PHX_LV_DIAGNOSTIC_EVENT, listener);
    }

    expect(msgCallback).not.toHaveBeenCalled();
    expect(listener).not.toHaveBeenCalled();
  });

  test("dispatches enabled console debug logs as diagnostics", () => {
    liveSocket = new LiveSocket("/live", Socket);
    liveSocket.enableDebug();
    const view = { id: "view-id", liveSocket };
    const metadata = { value: 1 };
    const diagnostics: LiveViewDiagnostic[] = [];
    const listener = (event: Event) => {
      diagnostics.push((event as CustomEvent<LiveViewDiagnostic>).detail);
    };
    const consoleLog = jest.spyOn(console, "log").mockImplementation(() => {});
    window.addEventListener(PHX_LV_DIAGNOSTIC_EVENT, listener);

    try {
      liveSocket.log(view, "update", () => ["received diff", metadata], {
        code: "view.diff-update",
        metadata: () => metadata,
        context: { attribution: "unknown" },
      });

      expect(consoleLog).toHaveBeenCalledWith(
        "view-id update: received diff - ",
        metadata,
      );
      expect(diagnostics).toEqual([
        {
          version: 1,
          level: "debug",
          code: "view.diff-update",
          message: "received diff",
          viewId: "view-id",
          metadata,
          attribution: "unknown",
        },
      ]);
    } finally {
      window.removeEventListener(PHX_LV_DIAGNOSTIC_EVENT, listener);
      liveSocket.disableDebug();
      consoleLog.mockRestore();
    }
  });

  test("connect", async () => {
    liveSocket = new LiveSocket("/live", Socket);
    const _socket = liveSocket.connect();
    expect(liveSocket.getViewByEl(container(1))).toBeDefined();
  });

  test("disconnect", async () => {
    liveSocket = new LiveSocket("/live", Socket);

    liveSocket.connect();
    liveSocket.disconnect();

    expect(liveSocket.getViewByEl(container(1)).destroy).toBeDefined();
  });

  test("rebinds the server close failsafe after reconnecting", () => {
    liveSocket = new LiveSocket("/live", Socket);
    const onClose = jest.spyOn(liveSocket.socket, "onClose");
    const reloadWithJitter = jest.spyOn(liveSocket, "reloadWithJitter");

    liveSocket.connect();
    liveSocket.main = liveSocket.getViewByEl(container(1));
    expect(onClose).toHaveBeenCalledTimes(1);

    liveSocket.disconnect();
    liveSocket.connect();
    // onClose should be called during each connect(), hence two calls after reconnecting
    expect(onClose).toHaveBeenCalledTimes(2);

    const serverCloseHandler = onClose.mock.calls[1][0] as (event: {
      code: number;
    }) => void;
    serverCloseHandler({ code: 1000 });
    expect(reloadWithJitter).toHaveBeenCalledWith(liveSocket.main);
  });

  test("channel", async () => {
    liveSocket = new LiveSocket("/live", Socket);

    liveSocket.connect();
    const channel = liveSocket.channel(
      "lv:def456",
      function (this: { getSession(): string }) {
        return { session: this.getSession() };
      },
    );

    expect(channel).toBeDefined();
  });

  test("getViewByEl", async () => {
    liveSocket = new LiveSocket("/live", Socket);

    liveSocket.connect();

    expect(liveSocket.getViewByEl(container(1)).destroy).toBeDefined();
  });

  test("destroyAllViews", async () => {
    const secondLiveView = document.createElement("div");
    secondLiveView.setAttribute("data-phx-session", "def456");
    secondLiveView.setAttribute("data-phx-root-id", "container1");
    secondLiveView.setAttribute("id", "container2");
    secondLiveView.innerHTML = `
      <label for="plus">Plus</label>
      <input id="plus" value="1" />
      <button phx-click="inc_temperature">Inc Temperature</button>
    `;
    document.body.appendChild(secondLiveView);

    liveSocket = new LiveSocket("/live", Socket);
    liveSocket.connect();

    const el = container(1);
    expect(liveSocket.getViewByEl(el)).toBeDefined();

    liveSocket.destroyAllViews();
    expect(liveSocket.roots).toEqual({});

    // Simulate a race condition which may attempt to
    // destroy an element that no longer exists
    liveSocket.destroyViewByEl(el);
    expect(liveSocket.roots).toEqual({});
  });

  test("binding", async () => {
    liveSocket = new LiveSocket("/live", Socket);

    expect(liveSocket.binding("value")).toBe("phx-value");
  });

  test("getBindingPrefix", async () => {
    liveSocket = new LiveSocket("/live", Socket);

    expect(liveSocket.getBindingPrefix()).toEqual("phx-");
  });

  test("getBindingPrefix custom", async () => {
    liveSocket = new LiveSocket("/live", Socket, {
      bindingPrefix: "company-",
    });

    expect(liveSocket.getBindingPrefix()).toEqual("company-");
  });

  test("owner", async () => {
    liveSocket = new LiveSocket("/live", Socket);
    liveSocket.connect();

    const _view = liveSocket.getViewByEl(container(1));
    const btn = document.querySelector("button");
    const _callback = (view) => {
      expect(view.id).toBe(view.id);
    };
    liveSocket.owner(btn, (view) => view.id);
  });

  test("getActiveElement default before LiveSocket activeElement is set", async () => {
    liveSocket = new LiveSocket("/live", Socket);

    const input = document.querySelector("input")!;
    input.focus();

    expect(liveSocket.getActiveElement()).toEqual(input);
  });

  test("blurActiveElement", async () => {
    liveSocket = new LiveSocket("/live", Socket);

    const input = document.querySelector("input")!;
    input.focus();

    expect(liveSocket.prevActive).toBeNull();

    liveSocket.blurActiveElement();
    // sets prevActive
    expect(liveSocket.prevActive).toEqual(input);
    expect(liveSocket.getActiveElement()).not.toEqual(input);
  });

  test("restorePreviouslyActiveFocus", async () => {
    liveSocket = new LiveSocket("/live", Socket);

    const input = document.querySelector("input")!;
    input.focus();

    liveSocket.blurActiveElement();
    expect(liveSocket.prevActive).toEqual(input);
    expect(liveSocket.getActiveElement()).not.toEqual(input);

    // focus()
    liveSocket.restorePreviouslyActiveFocus();
    expect(liveSocket.prevActive).toEqual(input);
    expect(liveSocket.getActiveElement()).toEqual(input);
    expect(document.activeElement).toEqual(input);
  });

  test("dropActiveElement unsets prevActive", async () => {
    liveSocket = new LiveSocket("/live", Socket);

    liveSocket.connect();

    const input = document.querySelector("input")!;
    input.focus();
    liveSocket.blurActiveElement();
    expect(liveSocket.prevActive).toEqual(input);

    const view = liveSocket.getViewByEl(container(1));
    liveSocket.dropActiveElement(view);
    expect(liveSocket.prevActive).toBeNull();
    // this fails.  Is this correct?
    // expect(liveSocket.getActiveElement()).not.toEqual(input)
  });

  test("storage can be overridden", async () => {
    let getItemCalls = 0;
    const override = {
      getItem: function (_keyName) {
        getItemCalls = getItemCalls + 1;
      },
    } as Storage;

    liveSocket = new LiveSocket("/live", Socket, {
      sessionStorage: override,
    });
    liveSocket.getLatencySim();

    // liveSocket constructor reads nav history position from sessionStorage
    expect(getItemCalls).toEqual(2);
  });

  describe("embedded LiveSockets", () => {
    const root = (id, attrs = "") =>
      `<div id="${id}" data-phx-session="s" ${attrs}></div>`;
    const liveRootIds = (socket) =>
      Object.values(socket.roots as Record<string, View>)
        .filter((view) => !view.isDead)
        .map((view) => view.id)
        .sort();
    const slot = () => document.getElementById("slot")!;
    // embed() reports back through its callback
    const embed = (socket, container, source) =>
      new Promise<void>((resolve) => socket.embed(container, source, resolve));
    // lets an embed() that never calls back run its course
    const settled = () => new Promise((resolve) => setTimeout(resolve, 0));
    let embedded;
    let consoleError;

    beforeEach(() => {
      document.body.innerHTML =
        root("page", "data-phx-main") +
        `<div id="slot" phx-update="ignore"></div>` +
        root("other");
      liveSocket = new LiveSocket("/live", Socket);
      embedded = new LiveSocket("/live", Socket);
      consoleError = jest.spyOn(console, "error").mockImplementation(() => {});
    });

    afterEach(() => {
      consoleError.mockRestore();
      liveSocket.disconnect();
      embedded.disconnect();
    });

    test("place the produced roots in the container and join them", async () => {
      const bindNav = jest.spyOn(embedded, "bindNav");
      const connect = jest.spyOn(embedded.socket, "connect");

      await embed(embedded, slot(), () => root("nested"));

      expect(Object.keys(embedded.roots)).toEqual(["nested"]);
      expect(slot().firstElementChild!.id).toBe("nested");
      expect(embedded.main).toBeNull();
      expect(bindNav).not.toHaveBeenCalled();
      expect(connect).toHaveBeenCalledTimes(1);
    });

    test("leave a sticky root inside its root and join it from there", async () => {
      const sticky = root("sticky", "data-phx-sticky");
      const html = `<div id="nested" data-phx-session="s">${sticky}</div>`;

      await embed(embedded, slot(), () => html);

      expect(Object.keys(embedded.roots)).toEqual(["nested", "sticky"]);
      expect(slot().children.length).toBe(1);
      expect(slot().firstElementChild!.id).toBe("nested");
      expect(embedded.roots["sticky"].el.parentElement!.id).toBe("nested");
    });

    test("fetch the roots from a URL, taking the csrf token along", async () => {
      const fetch = jest.fn().mockResolvedValue({
        ok: true,
        text: async () =>
          `<meta name="csrf-token" content="tok">${root("nested")}<script>window.ran = true</script>`,
      });
      const original = global.fetch;
      global.fetch = fetch;

      try {
        await embed(embedded, slot(), "/embed");

        expect(fetch).toHaveBeenCalledWith(
          "/embed",
          expect.objectContaining({ credentials: "include" }),
        );
        expect(Object.keys(embedded.roots)).toEqual(["nested"]);
        expect(slot().children).toHaveLength(1);
        expect((window as any).ran).toBeUndefined();
        expect(embedded.socket.params()).toEqual({ _csrf_token: "tok" });
      } finally {
        global.fetch = original;
      }
    });

    test("keep the csrf token given in the params", async () => {
      const withToken = new LiveSocket("/live", Socket, {
        params: { _csrf_token: "mine" },
      });

      try {
        await embed(
          withToken,
          slot(),
          () => `<meta name="csrf-token" content="tok">${root("nested")}`,
        );

        expect((withToken.socket as any).params()._csrf_token).toBe("mine");
      } finally {
        withToken.disconnect();
      }
    });

    test("report HTML without a root LiveView", async () => {
      const callback = jest.fn();

      embedded.embed(slot(), () => "<div>nothing</div>", callback);
      await settled();

      expect(consoleError).toHaveBeenCalledWith(
        expect.stringContaining("no root LiveView"),
        expect.anything(),
      );
      expect(callback).not.toHaveBeenCalled();
      expect(embedded.roots).toEqual({});
      expect(slot().children).toHaveLength(0);
    });

    test("report a main LiveView", async () => {
      const callback = jest.fn();

      embedded.embed(slot(), () => root("home", "data-phx-main"), callback);
      await settled();

      expect(consoleError).toHaveBeenCalledWith(
        expect.stringContaining("cannot embed the main LiveView #home"),
        expect.anything(),
      );
      expect(callback).not.toHaveBeenCalled();
      expect(slot().children).toHaveLength(0);
    });

    test("refuse a container inside another view unless it is ignored", async () => {
      liveSocket.connect();
      document.getElementById("page")!.innerHTML =
        `<div id="bare"></div><div id="ignored" phx-update="ignore"></div>`;

      expect(() =>
        embedded.embed(document.getElementById("bare")!, () => root("nested")),
      ).toThrow('phx-update="ignore"');
      await embed(embedded, document.getElementById("ignored")!, () =>
        root("nested"),
      );

      expect(Object.keys(embedded.roots)).toEqual(["nested"]);
      expect(liveRootIds(liveSocket)).toEqual(["other", "page"]);
    });

    test("do nothing when the container left the document meanwhile", async () => {
      const connect = jest.spyOn(embedded.socket, "connect");
      const callback = jest.fn();

      embedded.embed(
        slot(),
        () => {
          slot().remove();
          return root("nested");
        },
        callback,
      );
      await settled();

      expect(embedded.roots).toEqual({});
      expect(connect).not.toHaveBeenCalled();
      expect(callback).not.toHaveBeenCalled();
      expect(consoleError).not.toHaveBeenCalled();
    });

    test("move to another container, leaving the previous roots", async () => {
      await embed(embedded, slot(), () => root("nested"));
      const first = embedded.roots["nested"];
      document.body.insertAdjacentHTML(
        "beforeend",
        `<div id="slot2" phx-update="ignore"></div>`,
      );

      await embed(embedded, document.getElementById("slot2")!, () =>
        root("moved"),
      );

      expect(Object.keys(embedded.roots)).toEqual(["moved"]);
      expect(first.isDestroyed()).toBe(true);
      expect(document.getElementById("slot2")!.firstElementChild!.id).toBe(
        "moved",
      );
    });

    test("are one thing or the other: the page's LiveSocket cannot be embedded", async () => {
      liveSocket.connect();

      expect(() => liveSocket.embed(slot(), () => root("nested"))).toThrow(
        "page's LiveSocket cannot be embedded",
      );
      await embed(embedded, slot(), () => root("nested"));
      embedded.connect(); // a reconnect

      expect(Object.keys(embedded.roots)).toEqual(["nested"]);
      expect(embedded.main).toBeNull();
      expect(liveSocket.main).toBe(liveSocket.roots["page"]);
    });

    test("keep their roots when the page's LiveSocket connects later", async () => {
      await embed(embedded, slot(), () => root("nested"));
      const bindNav = jest.spyOn(liveSocket, "bindNav");

      liveSocket.connect();

      expect(liveRootIds(liveSocket)).toEqual(["other", "page"]);
      expect(liveSocket.main).toBe(liveSocket.roots["page"]);
      expect(bindNav).toHaveBeenCalledTimes(1);
      expect(Object.keys(embedded.roots)).toEqual(["nested"]);
    });

    test("are left the roots under phx-update=ignore, whichever connects first", async () => {
      slot().innerHTML = root("nested");
      liveSocket.connect();
      expect(liveRootIds(liveSocket)).toEqual(["other", "page"]);

      await embed(embedded, slot(), () => root("nested"));

      expect(Object.keys(embedded.roots)).toEqual(["nested"]);
      expect(liveRootIds(liveSocket)).toEqual(["other", "page"]);
    });

    test("leave roots under a nested phx-update=ignore element alone as well", async () => {
      await embed(embedded, slot(), () => root("nested"));
      slot().insertAdjacentHTML(
        "beforeend",
        `<div phx-update="ignore">${root("deeper")}</div>`,
      );

      embedded.connect(); // rescans the container

      expect(Object.keys(embedded.roots)).toEqual(["nested"]);
    });

    test("route events to their own views only, without a main fallback", async () => {
      await embed(embedded, slot(), () => root("nested"));
      liveSocket.connect();
      const nested = document.getElementById("nested")!;
      const page = document.getElementById("page")!;
      const orphan = document.body.appendChild(document.createElement("div"));

      expect(embedded.owner(nested)).toBe(embedded.roots["nested"]);
      expect(liveSocket.owner(nested)).toBeNull();
      expect(liveSocket.owner(page)).toBe(liveSocket.main);
      expect(embedded.owner(page)).toBeNull();
      expect(liveSocket.owner(orphan)).toBe(liveSocket.main);
      expect(embedded.owner(orphan)).toBeNull();
    });

    test("refuse to navigate, redirect or reload the page for their views", async () => {
      const redirect = jest
        .spyOn(Browser, "redirect")
        .mockImplementation(() => {});
      await embed(embedded, slot(), () => root("nested"));
      const view = embedded.roots["nested"];

      try {
        view.onLiveRedirect({ to: "/away", kind: "push" });
        view.onRedirect({ to: "/away" });
        embedded.reloadWithJitter(view);

        expect(redirect).not.toHaveBeenCalled();
        expect(embedded.reloadWithJitterTimer).toBeNull();
        expect(view.el.classList.contains("phx-server-error")).toBe(true);
        expect(consoleError.mock.calls.map(([message]) => message)).toEqual([
          "an embedded LiveSocket cannot navigate the page",
          "an embedded LiveSocket cannot redirect the page",
          "an embedded LiveSocket cannot reload the page",
        ]);
      } finally {
        redirect.mockRestore();
      }
    });

    test("refuse page navigation issued from JS", async () => {
      const redirect = jest
        .spyOn(Browser, "redirect")
        .mockImplementation(() => {});
      await embed(embedded, slot(), () => root("nested"));

      try {
        embedded.historyRedirect(new Event("click"), "/away", "push", null);
        embedded.pushHistoryPatch(new Event("click"), "/away", "push", null);
        embedded.redirect("/away", null, null);

        expect(redirect).not.toHaveBeenCalled();
        expect(consoleError.mock.calls.map(([message]) => message)).toEqual([
          "an embedded LiveSocket cannot navigate the page",
          "an embedded LiveSocket cannot patch the page's URL",
          "an embedded LiveSocket cannot redirect the page",
        ]);
      } finally {
        redirect.mockRestore();
      }
    });

    test("complete a patch without touching the page's URL", async () => {
      const pushState = jest
        .spyOn(Browser, "pushState")
        .mockImplementation(() => {});
      await embed(embedded, slot(), () => root("nested"));
      const view = embedded.roots["nested"];

      try {
        view.onLivePatch({ to: "/nested?page=2", kind: "push" });

        expect(view.href).toMatch(/\/nested\?page=2$/);
        expect(pushState).not.toHaveBeenCalled();
        expect(consoleError).not.toHaveBeenCalled();
      } finally {
        pushState.mockRestore();
      }
    });

    test("have their links left to the browser by the page's LiveSocket", async () => {
      liveSocket.connect();
      liveSocket.isConnected = () => true;
      await embed(embedded, slot(), () => root("nested"));
      const link = (id) =>
        `<a id="${id}" data-phx-link="redirect" data-phx-link-state="push" href="#away">go</a>`;
      document.getElementById("nested")!.innerHTML = link("embedded-link");
      document.getElementById("page")!.innerHTML = link("page-link");
      const historyRedirect = jest
        .spyOn(liveSocket, "historyRedirect")
        .mockImplementation(() => {});
      const click = (id) => {
        const e = new MouseEvent("click", { bubbles: true, cancelable: true });
        document.getElementById(id)!.dispatchEvent(e);
        return e;
      };

      expect(click("embedded-link").defaultPrevented).toBe(false);
      expect(historyRedirect).not.toHaveBeenCalled();
      expect(click("page-link").defaultPrevented).toBe(true);
      expect(historyRedirect).toHaveBeenCalledTimes(1);
    });
  });

  describe("execJS", () => {
    let view, liveSocket;

    beforeEach(() => {
      global.document.body.innerHTML = "";
      prepareLiveViewDOM(global.document);
      jest.useFakeTimers();

      liveSocket = new LiveSocket("/live", Socket);
      view = simulateJoinedView(
        document.getElementById("container1"),
        liveSocket,
      );
    });

    afterEach(() => {
      liveSocket && liveSocket.destroyAllViews();
      liveSocket = null;
      jest.useRealTimers();
    });

    afterAll(() => {
      global.document.body.innerHTML = "";
    });

    test("accepts JSON-encoded command string", () => {
      const el = document.createElement("div");
      el.setAttribute("id", "test-exec");
      el.setAttribute(
        "data-test",
        '[["toggle_attr", {"attr": ["open", "true"]}]]',
      );
      view.el.appendChild(el);

      expect(el.getAttribute("open")).toBeNull();
      liveSocket.execJS(el, el.getAttribute("data-test"));
      jest.runAllTimers();
      expect(el.getAttribute("open")).toEqual("true");
    });

    test("accepts command array", () => {
      const el = document.createElement("div");
      el.setAttribute("id", "test-exec-array");
      view.el.appendChild(el);

      expect(el.getAttribute("open")).toBeNull();
      liveSocket.execJS(el, [["toggle_attr", { attr: ["open", "true"] }]]);
      jest.runAllTimers();
      expect(el.getAttribute("open")).toEqual("true");
    });
  });
});

describe("liveSocket.js()", () => {
  let view, liveSocket, js;

  beforeEach(() => {
    global.document.body.innerHTML = "";
    prepareLiveViewDOM(global.document);
    jest.useFakeTimers();

    liveSocket = new LiveSocket("/live", Socket);
    view = simulateJoinedView(
      document.getElementById("container1"),
      liveSocket,
    );
    js = liveSocket.js();
  });

  afterEach(() => {
    liveSocket && liveSocket.destroyAllViews();
    liveSocket = null;
    jest.useRealTimers();
  });

  afterAll(() => {
    global.document.body.innerHTML = "";
  });

  test("exec", () => {
    const el = document.createElement("div");
    el.setAttribute("id", "test-exec");
    el.setAttribute(
      "data-test",
      '[["toggle_attr", {"attr": ["open", "true"]}]]',
    );
    view.el.appendChild(el);

    expect(el.getAttribute("open")).toBeNull();
    js.exec(el, el.getAttribute("data-test"));
    jest.runAllTimers();
    expect(el.getAttribute("open")).toEqual("true");
  });

  test("exec with command array", () => {
    const el = document.createElement("div");
    el.setAttribute("id", "test-exec-array");
    view.el.appendChild(el);

    expect(el.getAttribute("open")).toBeNull();
    js.exec(el, [["toggle_attr", { attr: ["open", "true"] }]]);
    jest.runAllTimers();
    expect(el.getAttribute("open")).toEqual("true");
  });

  test("show and hide", (done) => {
    const el = document.createElement("div");
    el.setAttribute("id", "test-visibility");
    view.el.appendChild(el);
    simulateVisibility(el);

    expect(el.style.display).toBe("");
    js.hide(el);
    jest.runAllTimers();
    expect(el.style.display).toBe("none");

    js.show(el);
    jest.runAllTimers();
    expect(el.style.display).toBe("block");
    done();
  });

  test("toggle", (done) => {
    const el = document.createElement("div");
    el.setAttribute("id", "test-toggle");
    view.el.appendChild(el);
    simulateVisibility(el);

    expect(el.style.display).toBe("");
    js.toggle(el);
    jest.runAllTimers();
    expect(el.style.display).toBe("none");

    js.toggle(el);
    jest.runAllTimers();
    expect(el.style.display).toBe("block");
    done();
  });

  test("addClass, removeClass and toggleClass", (done) => {
    const el = document.createElement("div");
    el.setAttribute("id", "test-classes");
    el.className = "initial-class";
    view.el.appendChild(el);

    js.addClass(el, "test-class");
    jest.runAllTimers();
    expect(el.classList.contains("test-class")).toBe(true);
    expect(el.classList.contains("initial-class")).toBe(true);

    js.addClass(el, ["multiple", "classes"]);
    jest.runAllTimers();
    expect(el.classList.contains("multiple")).toBe(true);
    expect(el.classList.contains("classes")).toBe(true);

    js.removeClass(el, "test-class");
    jest.runAllTimers();
    expect(el.classList.contains("test-class")).toBe(false);
    expect(el.classList.contains("initial-class")).toBe(true);

    js.removeClass(el, ["multiple", "classes"]);
    jest.runAllTimers();
    expect(el.classList.contains("multiple")).toBe(false);
    expect(el.classList.contains("classes")).toBe(false);

    js.toggleClass(el, "toggle-class");
    jest.runAllTimers();
    expect(el.classList.contains("toggle-class")).toBe(true);

    js.toggleClass(el, "toggle-class");
    jest.runAllTimers();
    expect(el.classList.contains("toggle-class")).toBe(false);
    done();
  });

  test("transition", (done) => {
    const el = document.createElement("div");
    el.setAttribute("id", "test-transition");
    view.el.appendChild(el);

    js.transition(el, "fade-in");
    jest.advanceTimersByTime(100);
    expect(el.classList.contains("fade-in")).toBe(true);

    js.transition(el, ["ease-out duration-300", "opacity-0", "opacity-100"]);
    jest.advanceTimersByTime(100);
    expect(el.classList.contains("ease-out")).toBe(true);
    expect(el.classList.contains("duration-300")).toBe(true);
    expect(el.classList.contains("opacity-100")).toBe(true);
    done();
  });

  test("setAttribute, removeAttribute and toggleAttribute", () => {
    const el = document.createElement("div");
    el.setAttribute("id", "test-attributes");
    view.el.appendChild(el);

    js.setAttribute(el, "data-test", "value");
    expect(el.getAttribute("data-test")).toBe("value");

    js.removeAttribute(el, "data-test");
    expect(el.getAttribute("data-test")).toBeNull();

    js.toggleAttribute(el, "aria-expanded", "true", "false");
    expect(el.getAttribute("aria-expanded")).toBe("true");

    js.toggleAttribute(el, "aria-expanded", "true", "false");
    expect(el.getAttribute("aria-expanded")).toBe("false");
  });

  test("push", () => {
    const el = document.createElement("div");
    el.setAttribute("id", "test-push");
    view.el.appendChild(el);

    const originalWithinOwners = liveSocket.withinOwners;
    liveSocket.withinOwners = (el, callback) => {
      callback(view);
    };

    const originalExec = JS.exec;
    JS.exec = jest.fn();

    js.push(el, "custom-event", { value: { key: "value" } });

    expect(JS.exec).toHaveBeenCalled();

    liveSocket.withinOwners = originalWithinOwners;
    JS.exec = originalExec;
  });

  test("push does not mutate reusable options", () => {
    const el = document.createElement("div");
    const opts = { value: { key: "value" }, target: "#target" };
    view.el.appendChild(el);

    const originalWithinOwners = liveSocket.withinOwners;
    liveSocket.withinOwners = (_el, callback) => {
      callback(view);
    };

    const originalExec = JS.exec;
    JS.exec = jest.fn();

    js.push(el, "custom-event", opts);
    js.push(el, "custom-event", opts);

    expect(opts).toEqual({ value: { key: "value" }, target: "#target" });
    expect((JS.exec as jest.Mock).mock.calls[0][5][1]).toEqual({
      data: { key: "value" },
      target: "#target",
    });
    expect((JS.exec as jest.Mock).mock.calls[1][5][1]).toEqual({
      data: { key: "value" },
      target: "#target",
    });

    liveSocket.withinOwners = originalWithinOwners;
    JS.exec = originalExec;
  });

  test("navigate", () => {
    const originalHistoryRedirect = liveSocket.historyRedirect;
    liveSocket.historyRedirect = jest.fn();

    js.navigate("/test-url");
    expect(liveSocket.historyRedirect).toHaveBeenCalledWith(
      expect.any(CustomEvent),
      "/test-url",
      "push",
      null,
      null,
    );

    js.navigate("/test-url", { replace: true });
    expect(liveSocket.historyRedirect).toHaveBeenCalledWith(
      expect.any(CustomEvent),
      "/test-url",
      "replace",
      null,
      null,
    );

    liveSocket.historyRedirect = originalHistoryRedirect;
  });

  test("patch", () => {
    const originalPushHistoryPatch = liveSocket.pushHistoryPatch;
    liveSocket.pushHistoryPatch = jest.fn();

    js.patch("/test-url");
    expect(liveSocket.pushHistoryPatch).toHaveBeenCalledWith(
      expect.any(CustomEvent),
      "/test-url",
      "push",
      null,
    );

    js.patch("/test-url", { replace: true });
    expect(liveSocket.pushHistoryPatch).toHaveBeenCalledWith(
      expect.any(CustomEvent),
      "/test-url",
      "replace",
      null,
    );

    liveSocket.pushHistoryPatch = originalPushHistoryPatch;
  });
});

describe("liveSocket debug buffers", () => {
  let liveSocket;

  // A joined view rendering one dynamic, so an update has something to report.
  const joinView = () => {
    const view = new View(liveViewDOM(), liveSocket, null, null, null);
    stubChannel(view);
    liveSocket.roots[view.id] = view;
    view.isConnected = () => true;
    view.onJoin({
      rendered: { 0: "first", s: ["<div>", "</div>"] },
      liveview_version,
    });
    return view;
  };

  // A buffer class in the shape a debug tool would install one, reporting what
  // each render was told about the dynamic it wrote.
  const recordingBuffer = () => {
    const changed: boolean[] = [];
    class Recording extends ReportingBuffer {
      onExit(frame) {
        changed.push(frame.changed);
      }
    }
    return { Recording, changed };
  };

  beforeEach(() => {
    liveSocket = new LiveSocket("/live", Socket);
  });

  afterEach(() => {
    liveSocket && liveSocket.destroyAllViews();
  });

  test("hands out the buffer base classes without an import", () => {
    // What tooling holding only a LiveSocket handle needs, since the classes
    // are not otherwise reachable from a page it did not bundle.
    expect(liveSocket.buffers).toEqual({ RenderingBuffer, ReportingBuffer });
  });

  test("returns the class installed until now, to restore it with", () => {
    const { Recording } = recordingBuffer();

    expect(liveSocket.attachDebugBuffer(Recording)).toBe(RenderingBuffer);
    expect(liveSocket.attachDebugBuffer(RenderingBuffer)).toBe(Recording);
    expect(liveSocket.RenderingBuffer).toBe(RenderingBuffer);
  });

  test("a buffer attached before a view joins renders that join", () => {
    const { Recording, changed } = recordingBuffer();
    liveSocket.attachDebugBuffer(Recording);

    joinView();

    // The join has no previous render to compare against, so nothing counts
    // as changed.
    expect(changed).toEqual([false]);
  });

  test("a buffer attached after a view joined is shown its next update", () => {
    // Nothing is re-rendered to install it, so it sees the page as later
    // patches reach it — starting with this one.
    const view = joinView();
    const { Recording, changed } = recordingBuffer();
    liveSocket.attachDebugBuffer(Recording);

    view.update({ 0: "second" }, []);

    expect(changed).toEqual([true]);
    expect(view.el.innerHTML).toContain("second");
  });

  test("leaves the default buffer in place when nobody attaches one", () => {
    const view = joinView();
    view.update({ 0: "second" }, []);

    expect(liveSocket.RenderingBuffer).toBe(RenderingBuffer);
    expect((view as any).rendered.bufferClass()).toBe(RenderingBuffer);
  });
});
