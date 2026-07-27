import { Socket } from "phoenix";
import DOM from "phoenix_live_view/dom";
import DOMPatch from "phoenix_live_view/dom_patch";
import LiveSocket from "phoenix_live_view/live_socket";
import { simulateJoinedView } from "../test_helpers";

const CUSTOM_ELEMENT_NAME = "lv-focused-form-control";

if (!customElements.get(CUSTOM_ELEMENT_NAME)) {
  customElements.define(
    CUSTOM_ELEMENT_NAME,
    class extends HTMLElement {
      static formAssociated = true;
    },
  );
}

function createView(content: string, bindingPrefix = "phx-") {
  document.body.innerHTML = `
    <div data-phx-session="abc123"
         data-phx-root-id="root"
         data-phx-static="456"
         id="root">
      <div id="content">${content}</div>
    </div>
  `;

  const root = document.getElementById("root")!;
  const liveSocket = new LiveSocket("/live", Socket, { bindingPrefix });
  const view = simulateJoinedView(root, liveSocket);
  const container = document.getElementById("content")!;

  return { liveSocket, view, container };
}

function buildPatch(view, container, html: string) {
  const source = document.createElement("div");
  source.innerHTML = html;
  return new DOMPatch(view, container, source, new Set(), null);
}

describe("focused form element patching", () => {
  const liveSockets: LiveSocket[] = [];

  afterEach(() => {
    liveSockets.forEach((liveSocket) => liveSocket.destroyAllViews());
    liveSockets.length = 0;
    document.body.innerHTML = "";
  });

  function setup(content: string, bindingPrefix?: string) {
    const result = createView(content, bindingPrefix);
    liveSockets.push(result.liveSocket);
    return result;
  }

  test("does not patch focused form-associated custom elements by default", () => {
    const { view, container } = setup(`
      <${CUSTOM_ELEMENT_NAME} id="control" tabindex="0">
        <span id="child">client</span>
      </${CUSTOM_ELEMENT_NAME}>
    `);
    const control = document.getElementById("control") as HTMLElement;
    control.focus();

    const patch = buildPatch(
      view,
      container,
      `
        <${CUSTOM_ELEMENT_NAME} id="control" tabindex="0">
          <span id="child">server</span>
        </${CUSTOM_ELEMENT_NAME}>
      `,
    );
    patch.perform(false);

    expect(document.activeElement).toBe(control);
    expect(document.getElementById("child")!.textContent).toBe("client");
  });

  test("phx-patch-focused patches a focused form-associated custom element", () => {
    const { view, container } = setup(`
      <${CUSTOM_ELEMENT_NAME} id="control" tabindex="0" phx-patch-focused>
        <span id="child">client</span>
      </${CUSTOM_ELEMENT_NAME}>
    `);
    const control = document.getElementById("control") as HTMLElement;
    control.focus();

    const patch = buildPatch(
      view,
      container,
      `
        <${CUSTOM_ELEMENT_NAME} id="control" tabindex="0" phx-patch-focused>
          <span id="child">server</span>
        </${CUSTOM_ELEMENT_NAME}>
      `,
    );
    patch.perform(false);

    expect(document.activeElement).toBe(control);
    expect(document.getElementById("child")!.textContent).toBe("server");
  });

  test("phx-patch-focused opts native inputs into server value updates", () => {
    const { view, container } = setup(
      '<input id="control" value="initial" phx-patch-focused>',
    );
    const control = document.getElementById("control") as HTMLInputElement;
    control.focus();
    control.value = "client";

    const patch = buildPatch(
      view,
      container,
      '<input id="control" value="server" phx-patch-focused>',
    );
    patch.perform(false);

    expect(document.activeElement).toBe(control);
    expect(control.value).toBe("server");
  });

  test("uses the configured binding prefix", () => {
    const { view, container } = setup(
      `
        <${CUSTOM_ELEMENT_NAME} id="control" tabindex="0" company-patch-focused>
          <span id="child">client</span>
        </${CUSTOM_ELEMENT_NAME}>
      `,
      "company-",
    );
    const control = document.getElementById("control") as HTMLElement;
    control.focus();

    const patch = buildPatch(
      view,
      container,
      `
        <${CUSTOM_ELEMENT_NAME} id="control" tabindex="0" company-patch-focused>
          <span id="child">server</span>
        </${CUSTOM_ELEMENT_NAME}>
      `,
    );
    patch.perform(false);

    expect(document.getElementById("child")!.textContent).toBe("server");
  });

  test("applies sticky operations and reports the focused element once", () => {
    const { view, container } = setup(`
      <${CUSTOM_ELEMENT_NAME}
        id="control"
        class="server"
        tabindex="0"
        phx-patch-focused
      >
        <span id="child">client</span>
      </${CUSTOM_ELEMENT_NAME}>
    `);
    const control = document.getElementById("control") as HTMLElement;
    control.focus();
    DOM.putSticky(control, "test-class", (el) =>
      el.classList.add("client-sticky"),
    );

    const patch = buildPatch(
      view,
      container,
      `
        <${CUSTOM_ELEMENT_NAME}
          id="control"
          class="server"
          tabindex="0"
          phx-patch-focused
        >
          <span id="child">server</span>
        </${CUSTOM_ELEMENT_NAME}>
      `,
    );
    let updates = 0;
    patch.afterUpdated((el) => {
      if (el.id === "control") updates++;
    });
    patch.perform(false);

    expect(control.classList.contains("client-sticky")).toBe(true);
    expect(updates).toBe(1);
  });
});
