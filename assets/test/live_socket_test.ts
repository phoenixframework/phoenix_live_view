import { Socket } from "phoenix";
import LiveSocket from "phoenix_live_view/live_socket";
import JS from "phoenix_live_view/js";
import { simulateJoinedView, simulateVisibility } from "./test_helpers";

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
  });

  test("sets defaults with socket", async () => {
    liveSocket = new LiveSocket(new Socket("//example.org/chat"), Socket);
    expect(liveSocket.socket).toBeDefined();
    expect(liveSocket.socket.onOpen).toBeDefined();
    expect(liveSocket.unloaded).toBe(false);
    expect(liveSocket.bindingPrefix).toBe("phx-");
    expect(liveSocket.prevActive).toBe(null);
  });

  test("viewLogger", async () => {
    const viewLogger = jest.fn();
    liveSocket = new LiveSocket("/live", Socket, { viewLogger });
    expect(liveSocket.viewLogger).toBe(viewLogger);
    liveSocket.connect();
    const view = liveSocket.getViewByEl(container(1));
    liveSocket.log(view, "updated", () => ["", JSON.stringify("<div>")]);
    expect(viewLogger).toHaveBeenCalledWith(
      view,
      "updated",
      "",
      JSON.stringify("<div>"),
    );
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
    };

    liveSocket = new LiveSocket("/live", Socket, {
      sessionStorage: override,
    });
    liveSocket.getLatencySim();

    // liveSocket constructor reads nav history position from sessionStorage
    expect(getItemCalls).toEqual(2);
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
