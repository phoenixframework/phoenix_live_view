import { Socket } from "phoenix";
import { createHook } from "phoenix_live_view/index";
import LiveSocket from "phoenix_live_view/live_socket";
import DOM from "phoenix_live_view/dom";
import View from "phoenix_live_view/view";
import ViewHook from "phoenix_live_view/view_hook";

import { version as liveview_version } from "../../package.json";

import {
  PHX_LOADING_CLASS,
  PHX_ERROR_CLASS,
  PHX_SERVER_ERROR_CLASS,
  PHX_HAS_FOCUSED,
} from "phoenix_live_view/constants";

import {
  tag,
  simulateJoinedView,
  stubChannel,
  rootContainer,
  liveViewDOM,
  simulateVisibility,
  appendTitle,
} from "./test_helpers";

const simulateUsedInput = (input) => {
  DOM.putPrivate(input, PHX_HAS_FOCUSED, true);
};

describe("View + DOM", function () {
  let liveSocket;

  beforeEach(() => {
    submitBefore = HTMLFormElement.prototype.submit;
    global.Phoenix = { Socket };
    global.document.body.innerHTML = liveViewDOM().outerHTML;
  });

  afterEach(() => {
    liveSocket && liveSocket.destroyAllViews();
    liveSocket = null;
  });

  afterAll(() => {
    global.document.body.innerHTML = "";
  });

  test("update", async () => {
    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();
    const updateDiff = {
      s: ["<h2>", "</h2>"],
      fingerprint: 123,
    };

    const view = simulateJoinedView(el, liveSocket);
    view.update(updateDiff, []);

    expect(view.el.firstChild.tagName).toBe("H2");
    expect(view.rendered.get()).toEqual(updateDiff);
  });

  test("applyDiff with empty title uses default if present", async () => {
    appendTitle({}, "Foo");

    const titleEl = document.querySelector("title");
    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();
    const updateDiff = {
      s: ["<h2>", "</h2>"],
      fingerprint: 123,
      t: "",
    };

    const view = simulateJoinedView(el, liveSocket);
    view.applyDiff("mount", updateDiff, ({ diff, events }) =>
      view.update(diff, events),
    );

    expect(view.el.firstChild.tagName).toBe("H2");
    expect(view.rendered.get()).toEqual(updateDiff);

    await new Promise(requestAnimationFrame);
    expect(document.title).toBe("Foo");
    titleEl.setAttribute("data-default", "DEFAULT");
    view.applyDiff("mount", updateDiff, ({ diff, events }) =>
      view.update(diff, events),
    );
    await new Promise(requestAnimationFrame);
    expect(document.title).toBe("DEFAULT");
  });

  test("applyDiff with empty title does not use default for non-main views", async () => {
    appendTitle({}, "Foo");

    const titleEl = document.querySelector("title");
    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();
    const updateDiff = {
      s: ["<h2>", "</h2>"],
      fingerprint: 123,
      t: "",
    };

    const view = simulateJoinedView(el, liveSocket);
    view.el.removeAttribute("data-phx-main");
    view.applyDiff("mount", updateDiff, ({ diff, events }) =>
      view.update(diff, events),
    );

    expect(view.el.firstChild.tagName).toBe("H2");
    expect(view.rendered.get()).toEqual(updateDiff);

    await new Promise(requestAnimationFrame);
    expect(document.title).toBe("Foo");
    titleEl.setAttribute("data-default", "DEFAULT");
    view.applyDiff("mount", updateDiff, ({ diff, events }) =>
      view.update(diff, events),
    );
    await new Promise(requestAnimationFrame);
    expect(document.title).toBe("Foo");
  });

  test("pushWithReply", function () {
    expect.assertions(1);

    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();

    const view = simulateJoinedView(el, liveSocket);
    const channelStub = {
      leave() {
        return {
          receive(_status, _cb) {
            return this;
          },
        };
      },
      push(_evt, payload, _timeout) {
        expect(payload.value).toBe("increment=1");
        return {
          receive() {
            return this;
          },
        };
      },
    };
    view.channel = channelStub;

    view.pushWithReply(
      null,
      { target: el.querySelector("form") },
      { value: "increment=1" },
    );
  });

  test("pushWithReply with update", function () {
    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();

    const view = simulateJoinedView(el, liveSocket);
    const channelStub = {
      leave() {
        return {
          receive(_status, _cb) {
            return this;
          },
        };
      },
      push(_evt, payload, _timeout) {
        expect(payload.value).toBe("increment=1");
        return {
          receive(_status, cb) {
            const diff = {
              s: ["<h2>", "</h2>"],
              fingerprint: 123,
            };
            cb(diff);
            return this;
          },
        };
      },
    };
    view.channel = channelStub;

    view.pushWithReply(
      null,
      { target: el.querySelector("form") },
      { value: "increment=1" },
    );

    expect(view.el.querySelector("form")).toBeTruthy();
  });

  test("pushEvent", function () {
    expect.assertions(3);

    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();
    const input = el.querySelector("input");

    const view = simulateJoinedView(el, liveSocket);
    const channelStub = {
      leave() {
        return {
          receive(_status, _cb) {
            return this;
          },
        };
      },
      push(_evt, payload, _timeout) {
        expect(payload.type).toBe("keyup");
        expect(payload.event).toBeDefined();
        expect(payload.value).toEqual({ value: "1" });
        return {
          receive() {
            return this;
          },
        };
      },
    };
    view.channel = channelStub;

    view.pushEvent("keyup", input, el, "click", {});
  });

  test("pushEvent as checkbox not checked", function () {
    expect.assertions(1);

    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();
    const input = el.querySelector('input[type="checkbox"]');

    const view = simulateJoinedView(el, liveSocket);
    const channelStub = {
      leave() {
        return {
          receive(_status, _cb) {
            return this;
          },
        };
      },
      push(_evt, payload, _timeout) {
        expect(payload.value).toEqual({});
        return {
          receive() {
            return this;
          },
        };
      },
    };
    view.channel = channelStub;

    view.pushEvent("click", input, el, "toggle_me", {});
  });

  test("pushEvent as checkbox when checked", function () {
    expect.assertions(1);

    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();
    const input: HTMLInputElement = el.querySelector('input[type="checkbox"]');
    const view = simulateJoinedView(el, liveSocket);

    input.checked = true;

    const channelStub = {
      leave() {
        return {
          receive(_status, _cb) {
            return this;
          },
        };
      },
      push(_evt, payload, _timeout) {
        expect(payload.value).toEqual({ value: "on" });
        return {
          receive() {
            return this;
          },
        };
      },
    };
    view.channel = channelStub;

    view.pushEvent("click", input, el, "toggle_me", {});
  });

  test("pushEvent as checkbox with value", function () {
    expect.assertions(1);

    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();
    const input: HTMLInputElement = el.querySelector('input[type="checkbox"]');
    const view = simulateJoinedView(el, liveSocket);

    input.value = "1";
    input.checked = true;

    const channelStub = {
      leave() {
        return {
          receive(_status, _cb) {
            return this;
          },
        };
      },
      push(_evt, payload, _timeout) {
        expect(payload.value).toEqual({ value: "1" });
        return {
          receive() {
            return this;
          },
        };
      },
    };
    view.channel = channelStub;

    view.pushEvent("click", input, el, "toggle_me", {});
  });

  test("pushInput", function () {
    expect.assertions(4);

    const liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();
    const input = el.querySelector("input");
    simulateUsedInput(input);
    const view = simulateJoinedView(el, liveSocket);
    const channelStub = {
      leave() {
        return {
          receive(_status, _cb) {
            return this;
          },
        };
      },
      push(_evt, payload, _timeout) {
        expect(payload.type).toBe("form");
        expect(payload.event).toBeDefined();
        expect(payload.value).toBe("increment=1&_unused_note=&note=2");
        expect(payload.meta).toEqual({ _target: "increment" });
        return {
          receive() {
            return this;
          },
        };
      },
    };
    view.channel = channelStub;

    view.pushInput(input, el, null, "validate", { _target: input.name });
  });

  test("pushInput with with phx-value and JS command value", function () {
    expect.assertions(4);

    const liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM(`
      <form id="my-form" phx-value-attribute_value="attribute">
        <label for="plus">Plus</label>
        <input id="plus" value="1" name="increment" />
        <textarea id="note" name="note">2</textarea>
        <input type="checkbox" phx-click="toggle_me" />
        <button phx-click="inc_temperature">Inc Temperature</button>
      </form>
    `);
    const input = el.querySelector("input");
    simulateUsedInput(input);
    const view = simulateJoinedView(el, liveSocket);
    const channelStub = {
      push(_evt, payload, _timeout) {
        expect(payload.type).toBe("form");
        expect(payload.event).toBeDefined();
        expect(payload.value).toBe("increment=1&_unused_note=&note=2");
        expect(payload.meta).toEqual({
          _target: "increment",
          attribute_value: "attribute",
          nested: {
            command_value: "command",
            array: [1, 2],
          },
        });
        return {
          receive() {
            return this;
          },
        };
      },
    };
    view.channel = channelStub;
    const optValue = { nested: { command_value: "command", array: [1, 2] } };
    view.pushInput(input, el, null, "validate", {
      _target: input.name,
      value: optValue,
    });
  });

  test("pushInput with nameless input", function () {
    expect.assertions(4);

    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();
    const input = el.querySelector("input");
    input.removeAttribute("name");
    simulateUsedInput(input);
    const view = simulateJoinedView(el, liveSocket);
    const channelStub = {
      leave() {
        return {
          receive(_status, _cb) {
            return this;
          },
        };
      },
      push(_evt, payload, _timeout) {
        expect(payload.type).toBe("form");
        expect(payload.event).toBeDefined();
        expect(payload.value).toBe("_unused_note=&note=2");
        expect(payload.meta).toEqual({ _target: "undefined" });
        return {
          receive() {
            return this;
          },
        };
      },
    };
    view.channel = channelStub;

    view.pushInput(input, el, null, "validate", { _target: input.name });
  });

  test("getFormsForRecovery", function () {
    let view, html;
    liveSocket = new LiveSocket("/live", Socket);

    html = '<form id="my-form" phx-change="cg"><input name="foo"></form>';
    view = new View(liveViewDOM(html), liveSocket);
    expect(view.joinCount).toBe(0);
    expect(Object.keys(view.getFormsForRecovery()).length).toBe(0);

    view.joinCount++;
    expect(Object.keys(view.getFormsForRecovery()).length).toBe(1);

    view.joinCount++;
    expect(Object.keys(view.getFormsForRecovery()).length).toBe(1);

    html =
      '<form phx-change="cg" phx-auto-recover="ignore"><input name="foo"></form>';
    view = new View(liveViewDOM(html), liveSocket);
    view.joinCount = 2;
    expect(Object.keys(view.getFormsForRecovery()).length).toBe(0);

    html = '<form><input name="foo"></form>';
    view = new View(liveViewDOM(), liveSocket);
    view.joinCount = 2;
    expect(Object.keys(view.getFormsForRecovery()).length).toBe(0);

    html = '<form phx-change="cg"></form>';
    view = new View(liveViewDOM(html), liveSocket);
    view.joinCount = 2;
    expect(Object.keys(view.getFormsForRecovery()).length).toBe(0);

    html =
      '<form id=\'my-form\' phx-change=\'[["push",{"event":"update","target":1}]]\'><input name="foo" /></form>';
    view = new View(liveViewDOM(html), liveSocket);
    view.joinCount = 1;
    const newForms = view.getFormsForRecovery();
    expect(Object.keys(newForms).length).toBe(1);
    expect(newForms["my-form"].getAttribute("phx-change")).toBe(
      '[["push",{"event":"update","target":1}]]',
    );
  });

  describe("submitForm", function () {
    test("submits payload", function () {
      expect.assertions(3);

      const liveSocket = new LiveSocket("/live", Socket);
      const el = liveViewDOM();
      const form = el.querySelector("form");

      const view = simulateJoinedView(el, liveSocket);
      const channelStub = {
        push(_evt, payload, _timeout) {
          expect(payload.type).toBe("form");
          expect(payload.event).toBeDefined();
          expect(payload.value).toBe("increment=1&note=2");
          return {
            receive() {
              return this;
            },
          };
        },
      };
      view.channel = channelStub;
      view.submitForm(form, form, { target: form });
    });

    test("payload includes phx-value and JS command value", function () {
      expect.assertions(4);

      const liveSocket = new LiveSocket("/live", Socket);
      const el = liveViewDOM(`
        <form id="my-form" phx-value-attribute_value="attribute">
          <label for="plus">Plus</label>
          <input id="plus" value="1" name="increment" />
          <textarea id="note" name="note">2</textarea>
          <input type="checkbox" phx-click="toggle_me" />
          <button phx-click="inc_temperature">Inc Temperature</button>
        </form>
      `);
      const form = el.querySelector("form");

      const view = simulateJoinedView(el, liveSocket);
      const channelStub = {
        push(_evt, payload, _timeout) {
          expect(payload.type).toBe("form");
          expect(payload.event).toBeDefined();
          expect(payload.value).toBe("increment=1&note=2");
          expect(payload.meta).toEqual({
            attribute_value: "attribute",
            nested: {
              command_value: "command",
              array: [1, 2],
            },
          });
          return {
            receive() {
              return this;
            },
          };
        },
      };
      view.channel = channelStub;
      const opts = {
        value: { nested: { command_value: "command", array: [1, 2] } },
      };
      view.submitForm(form, form, { target: form }, undefined, opts);
    });

    test("payload includes submitter when name is provided", function () {
      const btn = document.createElement("button");
      btn.setAttribute("type", "submit");
      btn.setAttribute("name", "btnName");
      btn.setAttribute("value", "btnValue");
      submitWithButton(btn, "increment=1&note=2&btnName=btnValue");
    });

    test("payload includes submitter when name is provided (submitter outside form)", function () {
      const btn = document.createElement("button");
      btn.setAttribute("form", "my-form");
      btn.setAttribute("type", "submit");
      btn.setAttribute("name", "btnName");
      btn.setAttribute("value", "btnValue");
      submitWithButton(
        btn,
        "increment=1&note=2&btnName=btnValue",
        document.body,
      );
    });

    test("payload does not include submitter when name is not provided", function () {
      const btn = document.createElement("button");
      btn.setAttribute("type", "submit");
      btn.setAttribute("value", "btnValue");
      submitWithButton(btn, "increment=1&note=2");
    });

    function submitWithButton(
      btn,
      queryString,
      appendTo?: HTMLElement,
      opts = {},
    ) {
      const liveSocket = new LiveSocket("/live", Socket);
      const el = liveViewDOM();
      const form = el.querySelector("form");
      if (appendTo) {
        appendTo.appendChild(btn);
      } else {
        form.appendChild(btn);
      }

      const view = simulateJoinedView(el, liveSocket);
      const channelStub = {
        push(_evt, payload, _timeout) {
          expect(payload.type).toBe("form");
          expect(payload.event).toBeDefined();
          expect(payload.value).toBe(queryString);
          return {
            receive() {
              return this;
            },
          };
        },
      };

      view.channel = channelStub;
      view.submitForm(form, form, { target: form }, btn, opts);
    }

    test("disables elements after submission", function () {
      const liveSocket = new LiveSocket("/live", Socket);
      const el = liveViewDOM();
      const form = el.querySelector("form");

      const view = simulateJoinedView(el, liveSocket);
      stubChannel(view);

      view.submitForm(form, form, { target: form });
      expect(DOM.private(form, "phx-has-submitted")).toBeTruthy();
      Array.from(form.elements).forEach((input) => {
        expect(DOM.private(input, "phx-has-submitted")).toBeTruthy();
      });
      expect(form.classList.contains("phx-submit-loading")).toBeTruthy();
      expect(form.querySelector("button").dataset.phxDisabled).toBeTruthy();
      expect(form.querySelector("input").dataset.phxReadonly).toBeTruthy();
      expect(form.querySelector("textarea").dataset.phxReadonly).toBeTruthy();
    });

    test("disables elements outside form", function () {
      const liveSocket = new LiveSocket("/live", Socket);
      const el = liveViewDOM(`
      <form id="my-form">
      </form>
      <label for="plus">Plus</label>
      <input id="plus" value="1" name="increment" form="my-form"/>
      <textarea id="note" name="note" form="my-form">2</textarea>
      <input type="checkbox" phx-click="toggle_me" form="my-form"/>
      <button phx-click="inc_temperature" form="my-form">Inc Temperature</button>
      `);
      const form = el.querySelector("form");

      const view = simulateJoinedView(el, liveSocket);
      stubChannel(view);

      view.submitForm(form, form, { target: form });
      expect(DOM.private(form, "phx-has-submitted")).toBeTruthy();
      expect(form.classList.contains("phx-submit-loading")).toBeTruthy();
      expect(el.querySelector("button").dataset.phxDisabled).toBeTruthy();
      expect(el.querySelector("input").dataset.phxReadonly).toBeTruthy();
      expect(el.querySelector("textarea").dataset.phxReadonly).toBeTruthy();
    });

    test("disables elements", function () {
      const liveSocket = new LiveSocket("/live", Socket);
      const el = liveViewDOM(`
      <button phx-click="inc" phx-disable-with>+</button>
      `);
      const button = el.querySelector("button");

      const view = simulateJoinedView(el, liveSocket);
      stubChannel(view);

      expect(button.disabled).toEqual(false);
      view.pushEvent("click", button, el, "inc", {});
      expect(button.disabled).toEqual(true);
    });
  });

  describe("phx-trigger-action", () => {
    test("triggers external submit on updated DOM el", (done) => {
      const liveSocket = new LiveSocket("/live", Socket);
      const el = liveViewDOM();
      const view = simulateJoinedView(el, liveSocket);
      const html =
        '<form id="form" phx-submit="submit"><input type="text"></form>';

      stubChannel(view);
      view.onJoin({
        rendered: { s: [html], fingerprint: 123 },
        liveview_version,
      });
      expect(view.el.innerHTML).toBe(html);

      const formEl = document.getElementById("form");
      Object.getPrototypeOf(formEl).submit = done;
      const updatedHtml =
        '<form id="form" phx-submit="submit" phx-trigger-action><input type="text"></form>';
      view.update({ s: [updatedHtml] }, []);

      expect(liveSocket.socket.closeWasClean).toBe(true);
      expect(view.el.innerHTML).toBe(
        '<form id="form" phx-submit="submit" phx-trigger-action=""><input type="text"></form>',
      );
    });

    test("triggers external submit on added DOM el", (done) => {
      const liveSocket = new LiveSocket("/live", Socket);
      const el = liveViewDOM();
      const view = simulateJoinedView(el, liveSocket);
      const html = "<div>not a form</div>";
      HTMLFormElement.prototype.submit = done;

      stubChannel(view);
      view.onJoin({
        rendered: { s: [html], fingerprint: 123 },
        liveview_version,
      });
      expect(view.el.innerHTML).toBe(html);

      const updatedHtml =
        '<form id="form" phx-submit="submit" phx-trigger-action><input type="text"></form>';
      view.update({ s: [updatedHtml] }, []);

      expect(liveSocket.socket.closeWasClean).toBe(true);
      expect(view.el.innerHTML).toBe(
        '<form id="form" phx-submit="submit" phx-trigger-action=""><input type="text"></form>',
      );
    });
  });

  describe("phx-update", function () {
    const childIds = () =>
      Array.from(document.getElementById("list").children).map((child) =>
        parseInt(child.id),
      );
    const countChildNodes = () =>
      document.getElementById("list").childNodes.length;

    const createView = (updateType, initialEntries) => {
      const liveSocket = new LiveSocket("/live", Socket);
      const el = liveViewDOM();
      const view = simulateJoinedView(el, liveSocket);

      stubChannel(view);

      const joinDiff = {
        "0": { k: initialEntries, s: ['\n<div id="', '">', "</div>\n"] },
        s: [`<div id="list" phx-update="${updateType}">`, "</div>"],
      };

      view.onJoin({ rendered: joinDiff, liveview_version });

      return view;
    };

    const updateEntries = (view, entries) => {
      const updateDiff = {
        "0": {
          k: entries,
        },
      };

      view.update(updateDiff, []);
    };

    test("replace", async () => {
      const view = createView("replace", { 0: { 0: "1", 1: "1" }, kc: 1 });
      expect(childIds()).toEqual([1]);

      updateEntries(view, {
        0: { 0: "2", 1: "2" },
        1: { 0: "3", 1: "3" },
        kc: 2,
      });
      expect(childIds()).toEqual([2, 3]);
    });

    test("append", async () => {
      const view = createView("append", { 0: { 0: "1", 1: "1" }, kc: 1 });
      expect(childIds()).toEqual([1]);

      // Append two elements
      updateEntries(view, {
        0: { 0: "2", 1: "2" },
        1: { 0: "3", 1: "3" },
        kc: 2,
      });
      expect(childIds()).toEqual([1, 2, 3]);

      // Update the last element
      updateEntries(view, {
        0: { 0: "3", 1: "3" },
        kc: 1,
      });
      expect(childIds()).toEqual([1, 2, 3]);

      // Update the first element
      updateEntries(view, {
        0: { 0: "1", 1: "1" },
        kc: 1,
      });
      expect(childIds()).toEqual([1, 2, 3]);

      // Update before new elements
      updateEntries(view, {
        0: { 0: "4", 1: "4" },
        1: { 0: "5", 1: "5" },
        kc: 2,
      });
      expect(childIds()).toEqual([1, 2, 3, 4, 5]);

      // Update after new elements
      updateEntries(view, {
        0: { 0: "6", 1: "6" },
        1: { 0: "7", 1: "7" },
        2: { 0: "5", 1: "modified" },
        kc: 3,
      });
      expect(childIds()).toEqual([1, 2, 3, 4, 5, 6, 7]);

      // Sandwich an update between two new elements
      updateEntries(view, {
        0: { 0: "8", 1: "8" },
        1: { 0: "7", 1: "modified" },
        2: { 0: "9", 1: "9" },
        kc: 3,
      });
      expect(childIds()).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9]);

      // Update all elements in reverse order
      updateEntries(view, {
        0: { 0: "9", 1: "9" },
        1: { 0: "8", 1: "8" },
        2: { 0: "7", 1: "7" },
        3: { 0: "6", 1: "6" },
        4: { 0: "5", 1: "5" },
        5: { 0: "4", 1: "4" },
        6: { 0: "3", 1: "3" },
        7: { 0: "2", 1: "2" },
        8: { 0: "1", 1: "1" },
        kc: 9,
      });
      expect(childIds()).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9]);

      // Make sure we don't have a memory leak when doing updates
      const initialCount = countChildNodes();
      updateEntries(view, {
        0: { 0: "1", 1: "1" },
        1: { 0: "2", 1: "2" },
        2: { 0: "3", 1: "3" },
        kc: 3,
      });
      updateEntries(view, {
        0: { 0: "1", 1: "1" },
        1: { 0: "2", 1: "2" },
        2: { 0: "3", 1: "3" },
        kc: 3,
      });
      updateEntries(view, {
        0: { 0: "1", 1: "1" },
        1: { 0: "2", 1: "2" },
        2: { 0: "3", 1: "3" },
        kc: 3,
      });

      expect(countChildNodes()).toBe(initialCount);
    });

    test("prepend", async () => {
      const view = createView("prepend", { 0: { 0: "1", 1: "1" }, kc: 1 });
      expect(childIds()).toEqual([1]);

      // Append two elements
      updateEntries(view, {
        0: { 0: "2", 1: "2" },
        1: { 0: "3", 1: "3" },
        kc: 2,
      });
      expect(childIds()).toEqual([2, 3, 1]);

      // Update the last element
      updateEntries(view, {
        0: { 0: "3", 1: "3" },
        kc: 1,
      });
      expect(childIds()).toEqual([2, 3, 1]);

      // Update the first element
      updateEntries(view, {
        0: { 0: "1", 1: "1" },
        kc: 1,
      });
      expect(childIds()).toEqual([2, 3, 1]);

      // Update before new elements
      updateEntries(view, {
        0: { 0: "4", 1: "4" },
        1: { 0: "5", 1: "5" },
        kc: 2,
      });
      expect(childIds()).toEqual([4, 5, 2, 3, 1]);

      // Update after new elements
      updateEntries(view, {
        0: { 0: "6", 1: "6" },
        1: { 0: "7", 1: "7" },
        2: { 0: "5", 1: "modified" },
        kc: 3,
      });
      expect(childIds()).toEqual([6, 7, 4, 5, 2, 3, 1]);

      // Sandwich an update between two new elements
      updateEntries(view, {
        0: { 0: "8", 1: "8" },
        1: { 0: "7", 1: "modified" },
        2: { 0: "9", 1: "9" },
        kc: 3,
      });
      expect(childIds()).toEqual([8, 9, 6, 7, 4, 5, 2, 3, 1]);

      // Update all elements in reverse order
      updateEntries(view, {
        0: { 0: "9", 1: "9" },
        1: { 0: "8", 1: "8" },
        2: { 0: "7", 1: "7" },
        3: { 0: "6", 1: "6" },
        4: { 0: "5", 1: "5" },
        5: { 0: "4", 1: "4" },
        6: { 0: "3", 1: "3" },
        7: { 0: "2", 1: "2" },
        8: { 0: "1", 1: "1" },
        kc: 9,
      });
      expect(childIds()).toEqual([8, 9, 6, 7, 4, 5, 2, 3, 1]);

      // Make sure we don't have a memory leak when doing updates
      const initialCount = countChildNodes();
      updateEntries(view, {
        0: { 0: "1", 1: "1" },
        1: { 0: "2", 1: "2" },
        2: { 0: "3", 1: "3" },
        kc: 3,
      });
      updateEntries(view, {
        0: { 0: "1", 1: "1" },
        1: { 0: "2", 1: "2" },
        2: { 0: "3", 1: "3" },
        kc: 3,
      });
      updateEntries(view, {
        0: { 0: "1", 1: "1" },
        1: { 0: "2", 1: "2" },
        2: { 0: "3", 1: "3" },
        kc: 3,
      });
      updateEntries(view, {
        0: { 0: "1", 1: "1" },
        1: { 0: "2", 1: "2" },
        2: { 0: "3", 1: "3" },
        kc: 3,
      });

      expect(countChildNodes()).toBe(initialCount);
    });

    test("ignore", async () => {
      const view = createView("ignore", { 0: { 0: "1", 1: "1" }, kc: 1 });
      expect(childIds()).toEqual([1]);

      // Append two elements
      updateEntries(view, {
        0: { 0: "2", 1: "2" },
        1: { 0: "3", 1: "3" },
        kc: 2,
      });
      expect(childIds()).toEqual([1]);
    });
  });

  describe("JS integration", () => {
    test("ignore_attributes skips attributes on update", () => {
      let liveSocket = new LiveSocket("/live", Socket);
      let el = liveViewDOM();
      let updateDiff = {
        "0": ' phx-mounted="[[&quot;ignore_attrs&quot;,{&quot;attrs&quot;:[&quot;open&quot;]}]]"',
        "1": "0",
        s: [
          "<details",
          ">\n    <summary>A</summary>\n    <span>",
          "</span></details>",
        ],
      };

      let view = simulateJoinedView(el, liveSocket);
      view.applyDiff("update", updateDiff, ({ diff, events }) =>
        view.update(diff, events),
      );

      expect(view.el.firstChild.tagName).toBe("DETAILS");
      expect(view.el.firstChild.open).toBe(false);
      view.el.firstChild.open = true;
      view.el.firstChild.setAttribute("data-foo", "bar");

      // now update, the HTML patch would normally reset the open attribute
      view.applyDiff("update", { "1": "1" }, ({ diff, events }) =>
        view.update(diff, events),
      );
      // open is ignored, so it is kept as is
      expect(view.el.firstChild.open).toBe(true);
      // foo is not ignored, so it is reset
      expect(view.el.firstChild.getAttribute("data-foo")).toBe(null);
      expect(view.el.firstChild.textContent.replace(/\s+/g, "")).toEqual("A1");
    });

    test("ignore_attributes skips boolean attributes on update when not set", () => {
      let liveSocket = new LiveSocket("/live", Socket);
      let el = liveViewDOM();
      let updateDiff = {
        "0": ' phx-mounted="[[&quot;ignore_attrs&quot;,{&quot;attrs&quot;:[&quot;open&quot;]}]]"',
        "1": "0",
        s: [
          "<details open",
          ">\n    <summary>A</summary>\n    <span>",
          "</span></details>",
        ],
      };

      let view = simulateJoinedView(el, liveSocket);
      view.applyDiff("update", updateDiff, ({ diff, events }) =>
        view.update(diff, events),
      );

      expect(view.el.firstChild.tagName).toBe("DETAILS");
      expect(view.el.firstChild.open).toBe(true);
      view.el.firstChild.open = false;
      view.el.firstChild.setAttribute("data-foo", "bar");

      // now update, the HTML patch would normally reset the open attribute
      view.applyDiff("update", { "1": "1" }, ({ diff, events }) =>
        view.update(diff, events),
      );
      // open is ignored, so it is kept as is
      expect(view.el.firstChild.open).toBe(false);
      // foo is not ignored, so it is reset
      expect(view.el.firstChild.getAttribute("data-foo")).toBe(null);
      expect(view.el.firstChild.textContent.replace(/\s+/g, "")).toEqual("A1");
    });

    test("ignore_attributes wildcard", () => {
      let liveSocket = new LiveSocket("/live", Socket);
      let el = liveViewDOM();
      let updateDiff = {
        "0": ' phx-mounted="[[&quot;ignore_attrs&quot;,{&quot;attrs&quot;:[&quot;open&quot;,&quot;data-*&quot;]}]]"',
        "1": ' data-foo="foo" data-bar="bar"',
        "2": "0",
        s: [
          "<details",
          "",
          ">\n    <summary>A</summary>\n    <span>",
          "</span></details>",
        ],
      };

      let view = simulateJoinedView(el, liveSocket);
      view.applyDiff("update", updateDiff, ({ diff, events }) =>
        view.update(diff, events),
      );

      expect(view.el.firstChild.tagName).toBe("DETAILS");
      expect(view.el.firstChild.open).toBe(false);
      view.el.firstChild.open = true;
      view.el.firstChild.setAttribute("data-foo", "bar");
      view.el.firstChild.setAttribute("data-other", "also kept");
      // apply diff
      view.applyDiff(
        "update",
        { "1": 'data-foo="foo" data-bar="bar" data-new="new"', "2": "1" },
        ({ diff, events }) => view.update(diff, events),
      );
      expect(view.el.firstChild.open).toBe(true);
      expect(view.el.firstChild.getAttribute("data-foo")).toBe("bar");
      expect(view.el.firstChild.getAttribute("data-bar")).toBe("bar");
      expect(view.el.firstChild.getAttribute("data-other")).toBe("also kept");
      expect(view.el.firstChild.textContent.replace(/\s+/g, "")).toEqual("A1");

      // Not added for being ignored
      expect(view.el.firstChild.getAttribute("data-new")).toBe(null);
    });

    test("ignore_attributes *", () => {
      let liveSocket = new LiveSocket("/live", Socket);
      let el = liveViewDOM();
      let updateDiff = {
        "0": ' phx-mounted="[[&quot;ignore_attrs&quot;,{&quot;attrs&quot;:[&quot;open&quot;,&quot;*&quot;]}]]"',
        "1": ' data-foo="foo" data-bar="bar"',
        "2": "0",
        s: [
          "<details",
          "",
          ">\n    <summary>A</summary>\n    <span>",
          "</span></details>",
        ],
      };

      let view = simulateJoinedView(el, liveSocket);
      view.applyDiff("update", updateDiff, ({ diff, events }) =>
        view.update(diff, events),
      );

      expect(view.el.firstChild.tagName).toBe("DETAILS");
      expect(view.el.firstChild.open).toBe(false);
      view.el.firstChild.open = true;
      view.el.firstChild.setAttribute("data-foo", "bar");
      view.el.firstChild.setAttribute("data-other", "also kept");
      view.el.firstChild.setAttribute("something", "else");
      // apply diff
      view.applyDiff(
        "update",
        { "1": 'data-foo="foo" data-bar="bar" data-new="new"', "2": "1" },
        ({ diff, events }) => view.update(diff, events),
      );
      expect(view.el.firstChild.open).toBe(true);
      expect(view.el.firstChild.getAttribute("data-foo")).toBe("bar");
      expect(view.el.firstChild.getAttribute("data-bar")).toBe("bar");
      expect(view.el.firstChild.getAttribute("something")).toBe("else");
      expect(view.el.firstChild.getAttribute("data-other")).toBe("also kept");
      expect(view.el.firstChild.textContent.replace(/\s+/g, "")).toEqual("A1");

      // Not added for being ignored
      expect(view.el.firstChild.getAttribute("data-new")).toBe(null);
    });
  });
});

let submitBefore;
describe("View", function () {
  let liveSocket;

  beforeEach(() => {
    submitBefore = HTMLFormElement.prototype.submit;
    global.Phoenix = { Socket };
    global.document.body.innerHTML = liveViewDOM().outerHTML;
  });

  afterEach(() => {
    liveSocket && liveSocket.destroyAllViews();
    liveSocket = null;
    HTMLFormElement.prototype.submit = submitBefore;
    jest.useRealTimers();
  });

  afterAll(() => {
    global.document.body.innerHTML = "";
  });

  test("sets defaults", async () => {
    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();
    const view = simulateJoinedView(el, liveSocket);
    expect(view.liveSocket).toBe(liveSocket);
    expect(view.parent).toBeUndefined();
    expect(view.el).toBe(el);
    expect(view.id).toEqual("container");
    expect(view.getSession).toBeDefined();
    expect(view.channel).toBeDefined();
    expect(view.loaderTimer).toBeDefined();
  });

  test("binding", async () => {
    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();
    const view = simulateJoinedView(el, liveSocket);
    expect(view.binding("submit")).toEqual("phx-submit");
  });

  test("getSession", async () => {
    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();
    const view = simulateJoinedView(el, liveSocket);
    expect(view.getSession()).toEqual("abc123");
  });

  test("getStatic", async () => {
    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();
    let view = simulateJoinedView(el, liveSocket);
    expect(view.getStatic()).toEqual(null);
    view.destroy();

    el.setAttribute("data-phx-static", "foo");
    view = simulateJoinedView(el, liveSocket);
    expect(view.getStatic()).toEqual("foo");
  });

  test("showLoader and hideLoader", async () => {
    liveSocket = new LiveSocket("/live", Socket);
    const el = document.querySelector("[data-phx-session]");

    const view = simulateJoinedView(el, liveSocket);
    view.showLoader();
    expect(el.classList.contains("phx-loading")).toBeTruthy();
    expect(el.classList.contains("phx-connected")).toBeFalsy();
    expect(el.classList.contains("user-implemented-class")).toBeTruthy();

    view.hideLoader();
    expect(el.classList.contains("phx-loading")).toBeFalsy();
    expect(el.classList.contains("phx-connected")).toBeTruthy();
  });

  test("displayError and hideLoader", (done) => {
    jest.useFakeTimers();
    liveSocket = new LiveSocket("/live", Socket);
    const loader = document.createElement("span");
    const phxView = document.querySelector("[data-phx-session]");
    phxView.parentNode.insertBefore(loader, phxView.nextSibling);
    const el = document.querySelector("[data-phx-session]");
    const status: HTMLElement = el.querySelector("#status");

    const view = simulateJoinedView(el, liveSocket);

    expect(status.style.display).toBe("none");
    view.displayError([
      PHX_LOADING_CLASS,
      PHX_ERROR_CLASS,
      PHX_SERVER_ERROR_CLASS,
    ]);
    expect(el.classList.contains("phx-loading")).toBeTruthy();
    expect(el.classList.contains("phx-error")).toBeTruthy();
    expect(el.classList.contains("phx-connected")).toBeFalsy();
    expect(el.classList.contains("user-implemented-class")).toBeTruthy();
    jest.runAllTimers();
    expect(status.style.display).toBe("block");
    simulateVisibility(status);
    view.hideLoader();
    jest.runAllTimers();
    expect(status.style.display).toBe("none");
    done();
  });

  test("join", async () => {
    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();
    const _view = simulateJoinedView(el, liveSocket);

    // view.join()
    // still need a few tests
  });

  test("sends _track_static and _mounts on params", () => {
    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();
    const view = new View(el, liveSocket);
    stubChannel(view);

    expect(view.channel.params()).toEqual({
      flash: undefined,
      params: { _mounts: 0, _mount_attempts: 0, _live_referer: undefined },
      session: "abc123",
      static: null,
      url: undefined,
      redirect: undefined,
      sticky: false,
    });

    el.innerHTML +=
      '<link rel="stylesheet" href="/css/app-123.css?vsn=d" phx-track-static="">';
    el.innerHTML += '<link rel="stylesheet" href="/css/nontracked.css">';
    el.innerHTML += '<img src="/img/tracked.png" phx-track-static>';
    el.innerHTML += '<img src="/img/untracked.png">';

    expect(view.channel.params()).toEqual({
      flash: undefined,
      session: "abc123",
      static: null,
      url: undefined,
      redirect: undefined,
      params: {
        _mounts: 0,
        _mount_attempts: 1,
        _live_referer: undefined,
        _track_static: [
          "http://localhost/css/app-123.css?vsn=d",
          "http://localhost/img/tracked.png",
        ],
      },
      sticky: false,
    });
  });
});

describe("View Hooks", function () {
  let liveSocket;

  beforeEach(() => {
    global.document.body.innerHTML = liveViewDOM().outerHTML;
  });

  afterEach(() => {
    liveSocket && liveSocket.destroyAllViews();
    liveSocket = null;
  });

  afterAll(() => {
    global.document.body.innerHTML = "";
  });

  test("phx-mounted", (done) => {
    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();

    const html =
      '<h2 id="test" phx-mounted="[[&quot;add_class&quot;,{&quot;names&quot;:[&quot;new-class&quot;],&quot;time&quot;:200,&quot;to&quot;:null,&quot;transition&quot;:[[],[],[]]}]]">test mounted</h2>';
    el.innerHTML = html;

    const view = simulateJoinedView(el, liveSocket);

    view.onJoin({
      rendered: {
        s: [html],
        fingerprint: 123,
      },
      liveview_version,
    });
    window.requestAnimationFrame(() => {
      expect(document.getElementById("test").getAttribute("class")).toBe(
        "new-class",
      );
      view.update(
        {
          s: [
            html +
              '<h2 id="test2" phx-mounted="[[&quot;add_class&quot;,{&quot;names&quot;:[&quot;new-class2&quot;],&quot;time&quot;:200,&quot;to&quot;:null,&quot;transition&quot;:[[],[],[]]}]]">test mounted</h2>',
          ],
          fingerprint: 123,
        },
        [],
      );
      window.requestAnimationFrame(() => {
        expect(document.getElementById("test").getAttribute("class")).toBe(
          "new-class",
        );
        expect(document.getElementById("test2").getAttribute("class")).toBe(
          "new-class2",
        );
        done();
      });
    });
  });

  test("hooks", async () => {
    let upcaseWasDestroyed = false;
    let upcaseBeforeUpdate = false;
    let hookLiveSocket;
    const Hooks = {
      Upcase: {
        mounted() {
          hookLiveSocket = this.liveSocket;
          this.el.innerHTML = this.el.innerHTML.toUpperCase();
        },
        beforeUpdate() {
          upcaseBeforeUpdate = true;
        },
        updated() {
          this.el.innerHTML = this.el.innerHTML + " updated";
        },
        disconnected() {
          this.el.innerHTML = "disconnected";
        },
        reconnected() {
          this.el.innerHTML = "connected";
        },
        destroyed() {
          upcaseWasDestroyed = true;
        },
      },
    };
    liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks });
    const el = liveViewDOM();

    const view = simulateJoinedView(el, liveSocket);

    view.onJoin({
      rendered: {
        s: ['<h2 id="up" phx-hook="Upcase">test mount</h2>'],
        fingerprint: 123,
      },
      liveview_version,
    });
    expect(view.el.firstChild.innerHTML).toBe("TEST MOUNT");
    expect(Object.keys(view.viewHooks)).toHaveLength(1);

    view.update(
      {
        s: ['<h2 id="up" phx-hook="Upcase">test update</h2>'],
        fingerprint: 123,
      },
      [],
    );
    expect(upcaseBeforeUpdate).toBe(true);
    expect(view.el.firstChild.innerHTML).toBe("test update updated");

    view.showLoader();
    expect(view.el.firstChild.innerHTML).toBe("disconnected");

    view.triggerReconnected();
    expect(view.el.firstChild.innerHTML).toBe("connected");

    view.update({ s: ["<div></div>"], fingerprint: 123 }, []);
    expect(upcaseWasDestroyed).toBe(true);
    expect(hookLiveSocket).toBeDefined();
    expect(Object.keys(view.viewHooks)).toEqual([]);
  });

  test("class based hook", async () => {
    let upcaseWasDestroyed = false;
    let upcaseBeforeUpdate = false;
    let hookLiveSocket;
    const Hooks = {
      Upcase: class extends ViewHook {
        mounted() {
          hookLiveSocket = this.liveSocket;
          this.el.innerHTML = this.el.innerHTML.toUpperCase();
        }
        beforeUpdate() {
          upcaseBeforeUpdate = true;
        }
        updated() {
          this.el.innerHTML = this.el.innerHTML + " updated";
        }
        disconnected() {
          this.el.innerHTML = "disconnected";
        }
        reconnected() {
          this.el.innerHTML = "connected";
        }
        destroyed() {
          upcaseWasDestroyed = true;
        }
      },
    };
    const liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks });
    const el = liveViewDOM();

    const view = simulateJoinedView(el, liveSocket);

    view.onJoin({
      rendered: {
        s: ['<h2 id="up" phx-hook="Upcase">test mount</h2>'],
        fingerprint: 123,
      },
      liveview_version,
    });
    expect(view.el.firstChild.innerHTML).toBe("TEST MOUNT");
    expect(Object.keys(view.viewHooks)).toHaveLength(1);

    view.update(
      {
        s: ['<h2 id="up" phx-hook="Upcase">test update</h2>'],
        fingerprint: 123,
      },
      [],
    );
    expect(upcaseBeforeUpdate).toBe(true);
    expect(view.el.firstChild.innerHTML).toBe("test update updated");

    view.showLoader();
    expect(view.el.firstChild.innerHTML).toBe("disconnected");

    view.triggerReconnected();
    expect(view.el.firstChild.innerHTML).toBe("connected");

    view.update({ s: ["<div></div>"], fingerprint: 123 }, []);
    expect(upcaseWasDestroyed).toBe(true);
    expect(hookLiveSocket).toBeDefined();
    expect(Object.keys(view.viewHooks)).toEqual([]);
  });

  test("createHook", (done) => {
    const liveSocket = new LiveSocket("/live", Socket, {});
    const el = liveViewDOM();
    customElements.define(
      "custom-el",
      class extends HTMLElement {
        hook: ViewHook;
        connectedCallback() {
          this.hook = createHook(this, {
            mounted: () => {
              expect(this.hook.liveSocket).toBeTruthy();
              done();
            },
          });
          expect(this.hook.liveSocket).toBe(null);
        }
      },
    );
    const customEl = document.createElement("custom-el");
    el.appendChild(customEl);
    simulateJoinedView(el, liveSocket);
  });

  test("view destroyed", async () => {
    const values = [];
    const Hooks = {
      Check: {
        destroyed() {
          values.push("destroyed");
        },
      },
    };
    const liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks });
    const el = liveViewDOM();

    const view = simulateJoinedView(el, liveSocket);

    view.onJoin({
      rendered: {
        s: ['<h2 id="check" phx-hook="Check">test mount</h2>'],
        fingerprint: 123,
      },
      liveview_version,
    });
    expect(view.el.firstChild.innerHTML).toBe("test mount");

    view.destroy();

    expect(values).toEqual(["destroyed"]);
  });

  test("view reconnected", async () => {
    const values = [];
    const Hooks = {
      Check: {
        mounted() {
          values.push("mounted");
        },
        disconnected() {
          values.push("disconnected");
        },
        reconnected() {
          values.push("reconnected");
        },
      },
    };
    const liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks });
    const el = liveViewDOM();

    const view = simulateJoinedView(el, liveSocket);

    view.onJoin({
      rendered: {
        s: ['<h2 id="check" phx-hook="Check"></h2>'],
        fingerprint: 123,
      },
      liveview_version,
    });
    expect(values).toEqual(["mounted"]);

    view.triggerReconnected();
    // The hook hasn't disconnected, so it shouldn't receive "reconnected" message
    expect(values).toEqual(["mounted"]);

    view.showLoader();
    expect(values).toEqual(["mounted", "disconnected"]);

    view.triggerReconnected();
    expect(values).toEqual(["mounted", "disconnected", "reconnected"]);
  });

  test("dispatches uploads", async () => {
    const hooks = { Recorder: {} };
    const liveSocket = new LiveSocket("/live", Socket, { hooks });
    const el = liveViewDOM();
    const view = simulateJoinedView(el, liveSocket);

    const template = `
    <form id="rec" phx-hook="Recorder" phx-change="change">
    <input accept="*" data-phx-active-refs="" data-phx-done-refs="" data-phx-preflighted-refs="" data-phx-update="ignore" data-phx-upload-ref="0" id="uploads0" name="doc" phx-hook="Phoenix.LiveFileUpload" type="file">
    </form>
    `;
    view.onJoin({
      rendered: {
        s: [template],
        fingerprint: 123,
      },
      liveview_version,
    });

    const recorderHook = view.getHook(view.el.querySelector("#rec"));
    const fileEl = view.el.querySelector("#uploads0");
    const dispatchEventSpy = jest.spyOn(fileEl, "dispatchEvent");

    const contents = { hello: "world" };
    const blob = new Blob([JSON.stringify(contents, null, 2)], {
      type: "application/json",
    });
    recorderHook.upload("doc", [blob]);

    expect(dispatchEventSpy).toHaveBeenCalledWith(
      new CustomEvent("track-uploads", {
        bubbles: true,
        cancelable: true,
        detail: { files: [blob] },
      }),
    );
  });

  test("dom hooks", async () => {
    let fromHTML,
      toHTML = null;
    const liveSocket = new LiveSocket("/live", Socket, {
      dom: {
        onBeforeElUpdated(from, to) {
          fromHTML = from.innerHTML;
          toHTML = to.innerHTML;
        },
      },
    });
    const el = liveViewDOM();
    const view = simulateJoinedView(el, liveSocket);

    view.onJoin({
      rendered: { s: ["<div>initial</div>"], fingerprint: 123 },
      liveview_version,
    });
    expect(view.el.firstChild.innerHTML).toBe("initial");

    view.update({ s: ["<div>updated</div>"], fingerprint: 123 }, []);
    expect(fromHTML).toBe("initial");
    expect(toHTML).toBe("updated");
    expect(view.el.firstChild.innerHTML).toBe("updated");
  });

  test("can overwrite property", async () => {
    let customHandleEventCalled = false;
    const Hooks = {
      Upcase: {
        mounted() {
          this.handleEvent = () => {
            customHandleEventCalled = true;
          };
          this.el.innerHTML = this.el.innerHTML.toUpperCase();
        },
        updated() {
          this.handleEvent();
        },
      },
    };
    liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks });
    const el = liveViewDOM();

    const view = simulateJoinedView(el, liveSocket);

    view.onJoin({
      rendered: {
        s: ['<h2 id="up" phx-hook="Upcase">test mount</h2>'],
        fingerprint: 123,
      },
      liveview_version,
    });
    expect(view.el.firstChild.innerHTML).toBe("TEST MOUNT");
    expect(Object.keys(view.viewHooks)).toHaveLength(1);

    expect(customHandleEventCalled).toBe(false);
    view.update(
      {
        s: ['<h2 id="up" phx-hook="Upcase">test update</h2>'],
        fingerprint: 123,
      },
      [],
    );
    expect(customHandleEventCalled).toBe(true);
  });
});

function liveViewComponent() {
  const div = document.createElement("div");
  div.setAttribute("data-phx-session", "abc123");
  div.setAttribute("id", "container");
  div.setAttribute("class", "user-implemented-class");
  div.innerHTML = `
    <article class="form-wrapper" data-phx-component="0">
      <form>
        <label for="plus">Plus</label>
        <input id="plus" value="1" name="increment" phx-target=".form-wrapper" />
        <input type="checkbox" phx-click="toggle_me" phx-target=".form-wrapper" />
        <button phx-click="inc_temperature">Inc Temperature</button>
      </form>
    </article>
  `;
  return div;
}

describe("View + Component", function () {
  let liveSocket;

  beforeEach(() => {
    global.Phoenix = { Socket };
    global.document.body.innerHTML = liveViewComponent().outerHTML;
  });

  afterEach(() => {
    liveSocket && liveSocket.destroyAllViews();
    liveSocket = null;
  });

  afterAll(() => {
    global.document.body.innerHTML = "";
  });

  test("targetComponentID", async () => {
    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewComponent();
    const view = simulateJoinedView(el, liveSocket);
    const form = el.querySelector('input[type="checkbox"]');
    const targetCtx = el.querySelector(".form-wrapper");
    expect(view.targetComponentID(el, targetCtx)).toBe(null);
    expect(view.targetComponentID(form, targetCtx)).toBe(0);
  });

  test("pushEvent", (done) => {
    expect.assertions(17);

    liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewComponent();
    const targetCtx = el.querySelector(".form-wrapper");

    const view = simulateJoinedView(el, liveSocket);
    const input = view.el.querySelector("input[id=plus]");
    const channelStub = {
      leave() {
        return {
          receive(_status, _cb) {
            return this;
          },
        };
      },
      push(_evt, payload, _timeout) {
        expect(payload.type).toBe("keyup");
        expect(payload.event).toBeDefined();
        expect(payload.value).toEqual({ value: "1" });
        expect(payload.cid).toEqual(0);
        return {
          receive(_status, cb) {
            cb({ ref: payload.ref });
            return this;
          },
        };
      },
    };
    view.channel = channelStub;

    input.addEventListener("phx:push:myevent", (e) => {
      const { ref, lockComplete, loadingComplete } = e.detail;
      expect(ref).toBe(0);
      expect(e.target).toBe(input);
      loadingComplete.then((detail) => {
        expect(detail.event).toBe("myevent");
        expect(detail.ref).toBe(0);
        lockComplete.then((detail) => {
          expect(detail.event).toBe("myevent");
          expect(detail.ref).toBe(0);
          done();
        });
      });
    });
    input.addEventListener("phx:push", (e) => {
      const { lock, unlock, lockComplete } = e.detail;
      expect(typeof lock).toBe("function");
      expect(view.el.getAttribute("data-phx-ref-lock")).toBe(null);
      // lock accepts unlock function to fire, which will done() the test
      lockComplete.then((detail) => {
        expect(detail.event).toBe("myevent");
      });
      lock(view.el).then((detail) => {
        expect(detail.event).toBe("myevent");
      });
      expect(e.target).toBe(input);
      expect(input.getAttribute("data-phx-ref-lock")).toBe("0");
      expect(view.el.getAttribute("data-phx-ref-lock")).toBe("0");
      unlock(view.el);
      expect(view.el.getAttribute("data-phx-ref-lock")).toBe(null);
    });

    view.pushEvent("keyup", input, targetCtx, "myevent", {});
  });

  test("pushInput", function (done) {
    const html = `<form id="form" phx-change="validate">
      <label for="first_name">First Name</label>
      <input id="first_name" value="" name="user[first_name]" />

      <label for="last_name">Last Name</label>
      <input id="last_name" value="" name="user[last_name]" />
    </form>`;
    const liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM(html);
    const view = simulateJoinedView(el, liveSocket);
    Array.from(view.el.querySelectorAll("input")).forEach((input) =>
      simulateUsedInput(input),
    );
    const channelStub = {
      validate: "",
      nextValidate(payload, meta) {
        this.meta = meta;
        this.validate = Object.entries(payload)
          .map(
            ([key, value]) =>
              `${encodeURIComponent(key)}=${value ? encodeURIComponent(value as string) : ""}`,
          )
          .join("&");
      },
      push(_evt, payload, _timeout) {
        expect(payload.value).toBe(this.validate);
        expect(payload.meta).toEqual(this.meta);
        return {
          receive(status, cb) {
            if (status === "ok") {
              const diff = {
                s: [
                  `
                <form id="form" phx-change="validate">
                  <label for="first_name">First Name</label>
                  <input id="first_name" value="" name="user[first_name]" />
                  <span class="feedback">can't be blank</span>

                  <label for="last_name">Last Name</label>
                  <input id="last_name" value="" name="user[last_name]" />
                  <span class="feedback">can't be blank</span>
                </form>
                `,
                ],
                fingerprint: 345,
              };
              cb({ diff: diff });
              return this;
            } else {
              return this;
            }
          },
        };
      },
    };
    view.channel = channelStub;

    const first_name = view.el.querySelector("#first_name");
    const last_name = view.el.querySelector("#last_name");
    view.channel.nextValidate(
      { "user[first_name]": null, "user[last_name]": null },
      { _target: "user[first_name]" },
    );
    // we have to set this manually since it's set by a change event that would require more plumbing with the liveSocket in the test to hook up
    DOM.putPrivate(first_name, "phx-has-focused", true);
    view.pushInput(first_name, el, null, "validate", {
      _target: first_name.name,
    });
    window.requestAnimationFrame(() => {
      view.channel.nextValidate(
        { "user[first_name]": null, "user[last_name]": null },
        { _target: "user[last_name]" },
      );
      view.pushInput(last_name, el, null, "validate", {
        _target: last_name.name,
      });
      window.requestAnimationFrame(() => {
        done();
      });
    });
  });

  test("adds auto ID to prevent teardown/re-add", () => {
    const liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();
    const view = simulateJoinedView(el, liveSocket);

    stubChannel(view);

    const joinDiff = {
      "0": { "0": "", "1": 0, s: ["", "", "<h2>2</h2>\n"] },
      c: {
        "0": { s: ['<div phx-click="show-rect">Menu</div>\n'], r: 1 },
      },
      s: ["", ""],
    };

    const updateDiff = {
      "0": {
        "0": { s: ["  <h1>1</h1>\n"], r: 1 },
      },
    };

    view.onJoin({ rendered: joinDiff, liveview_version });
    expect(view.el.innerHTML.trim()).toBe(
      '<div data-phx-id="c0-container" data-phx-component="0" data-phx-view="container" phx-click="show-rect">Menu</div>\n<h2>2</h2>',
    );

    view.update(updateDiff, []);
    expect(view.el.innerHTML.trim().replace("\n", "")).toBe(
      '<h1 data-phx-id="m1-container">1</h1><div data-phx-id="c0-container" data-phx-component="0" data-phx-view="container" phx-click="show-rect">Menu</div>\n<h2>2</h2>',
    );
  });

  test("respects nested components", () => {
    const liveSocket = new LiveSocket("/live", Socket);
    const el = liveViewDOM();
    const view = simulateJoinedView(el, liveSocket);

    stubChannel(view);

    const joinDiff = {
      "0": 0,
      c: {
        "0": { "0": 1, s: ["<div>Hello</div>", ""], r: 1 },
        "1": { s: ["<div>World</div>"], r: 1 },
      },
      s: ["", ""],
    };

    view.onJoin({ rendered: joinDiff, liveview_version });
    expect(view.el.innerHTML.trim()).toBe(
      '<div data-phx-id="c0-container" data-phx-component="0" data-phx-view="container">Hello</div><div data-phx-id="c1-container" data-phx-component="1" data-phx-view="container">World</div>',
    );
  });

  test("destroys children when they are removed by an update", () => {
    const id = "root";
    const childHTML = `<div data-phx-parent-id="${id}" data-phx-session="" data-phx-static="" id="bar" data-phx-root-id="${id}"></div>`;
    const newChildHTML = `<div data-phx-parent-id="${id}" data-phx-session="" data-phx-static="" id="baz" data-phx-root-id="${id}"></div>`;
    const el = document.createElement("div");
    el.setAttribute("data-phx-session", "abc123");
    el.setAttribute("id", id);
    document.body.appendChild(el);

    const liveSocket = new LiveSocket("/live", Socket);

    const view = simulateJoinedView(el, liveSocket);

    const joinDiff = { s: [childHTML] };

    const updateDiff = { s: [newChildHTML] };

    view.onJoin({ rendered: joinDiff, liveview_version });
    expect(view.el.innerHTML.trim()).toEqual(childHTML);
    expect(view.getChildById("bar")).toBeDefined();

    view.update(updateDiff, []);
    expect(view.el.innerHTML.trim()).toEqual(newChildHTML);
    expect(view.getChildById("baz")).toBeDefined();
    expect(view.getChildById("bar")).toBeUndefined();
  });

  describe("undoRefs", () => {
    test("restores phx specific attributes awaiting a ref", () => {
      const content = `
        <span data-phx-ref-loading="1" data-phx-ref-src="root"></span>
        <form phx-change="suggest" phx-submit="search" class="phx-submit-loading" data-phx-ref-loading="38" data-phx-ref-src="root">
          <input type="text" name="q" value="ddsdsd" placeholder="Live dependency search" list="results" autocomplete="off" data-phx-readonly="false" readonly="" class="phx-submit-loading" data-phx-ref-loading="38" data-phx-ref-src="root">
          <datalist id="results">
          </datalist>
          <button type="submit" phx-disable-with="Searching..." data-phx-disabled="false" disabled="" class="phx-submit-loading" data-phx-ref-loading="38" data-phx-ref-src="root" data-phx-disable-with-restore="GO TO HEXDOCS">Searching...</button>
        </form>
      `.trim();
      const liveSocket = new LiveSocket("/live", Socket);
      const el = rootContainer(content);
      const view = simulateJoinedView(el, liveSocket);

      view.undoRefs(1);
      expect(el.innerHTML).toBe(
        `
        <span></span>
        <form phx-change="suggest" phx-submit="search" class="phx-submit-loading" data-phx-ref-src="root" data-phx-ref-loading="38">
          <input type="text" name="q" value="ddsdsd" placeholder="Live dependency search" list="results" autocomplete="off" data-phx-readonly="false" readonly="" class="phx-submit-loading" data-phx-ref-src="root" data-phx-ref-loading="38">
          <datalist id="results">
          </datalist>
          <button type="submit" phx-disable-with="Searching..." data-phx-disabled="false" disabled="" class="phx-submit-loading" data-phx-disable-with-restore="GO TO HEXDOCS" data-phx-ref-src="root" data-phx-ref-loading="38">Searching...</button>
        </form>
      `.trim(),
      );

      view.undoRefs(38);
      expect(el.innerHTML).toBe(
        `
        <span></span>
        <form phx-change="suggest" phx-submit="search">
          <input type="text" name="q" value="ddsdsd" placeholder="Live dependency search" list="results" autocomplete="off">
          <datalist id="results">
          </datalist>
          <button type="submit" phx-disable-with="Searching...">GO TO HEXDOCS</button>
        </form>
      `.trim(),
      );
    });

    test("replaces any previous applied component", () => {
      const liveSocket = new LiveSocket("/live", Socket);
      const el = rootContainer("");

      const fromEl = tag(
        "span",
        { "data-phx-ref-src": el.id, "data-phx-ref-lock": "1" },
        "hello",
      );
      const toEl = tag("span", { class: "new" }, "world");

      DOM.putPrivate(fromEl, "data-phx-ref-lock", toEl);

      el.appendChild(fromEl);
      const view = simulateJoinedView(el, liveSocket);

      view.undoRefs(1);
      expect(el.innerHTML).toBe('<span class="new">world</span>');
    });

    test("triggers beforeUpdate and updated hooks", () => {
      global.document.body.innerHTML = "";
      let beforeUpdate = false;
      let updated = false;
      const Hooks = {
        MyHook: {
          beforeUpdate() {
            beforeUpdate = true;
          },
          updated() {
            updated = true;
          },
        },
      };
      const liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks });
      const el = liveViewDOM();
      const view = simulateJoinedView(el, liveSocket);
      stubChannel(view);
      view.onJoin({
        rendered: { s: ['<span id="myhook" phx-hook="MyHook">Hello</span>'] },
        liveview_version,
      });

      view.update(
        {
          s: [
            '<span id="myhook" data-phx-ref-loading="1" data-phx-ref-lock="2" data-phx-ref-src="container" phx-hook="MyHook" class="phx-change-loading">Hello</span>',
          ],
        },
        [],
      );

      const toEl = tag("span", { id: "myhook", "phx-hook": "MyHook" }, "world");
      DOM.putPrivate(el.querySelector("#myhook"), "data-phx-ref-lock", toEl);

      view.undoRefs(1);

      expect(el.querySelector("#myhook").outerHTML).toBe(
        '<span id="myhook" phx-hook="MyHook" data-phx-ref-src="container" data-phx-ref-lock="2" data-phx-ref-loading="1">Hello</span>',
      );
      view.undoRefs(2);
      expect(el.querySelector("#myhook").outerHTML).toBe(
        '<span id="myhook" phx-hook="MyHook">world</span>',
      );
      expect(beforeUpdate).toBe(true);
      expect(updated).toBe(true);
    });
  });
});

describe("DOM", function () {
  it("mergeAttrs attributes", function () {
    const target = document.createElement("input");
    target.type = "checkbox";
    target.id = "foo";
    target.setAttribute("checked", "true");

    const source = document.createElement("input");
    source.type = "checkbox";
    source.id = "bar";

    expect(target.getAttribute("checked")).toEqual("true");
    expect(target.id).toEqual("foo");

    DOM.mergeAttrs(target, source);

    expect(target.getAttribute("checked")).toEqual(null);
    expect(target.id).toEqual("bar");
  });

  it("mergeAttrs with properties", function () {
    const target = document.createElement("input");
    target.type = "checkbox";
    target.id = "foo";
    target.checked = true;

    const source = document.createElement("input");
    source.type = "checkbox";
    source.id = "bar";

    expect(target.checked).toEqual(true);
    expect(target.id).toEqual("foo");

    DOM.mergeAttrs(target, source);

    expect(target.checked).toEqual(true);
    expect(target.id).toEqual("bar");
  });
});
