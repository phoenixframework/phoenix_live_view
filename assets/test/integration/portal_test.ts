import { Socket } from "phoenix";
import LiveSocket from "phoenix_live_view/live_socket";
import DOMPatch from "phoenix_live_view/dom_patch";
import { PHX_PORTAL, PHX_SKIP } from "phoenix_live_view/constants";
import { simulateJoinedView } from "../test_helpers";

// Helper functions
function createViewWithPortal(rootId = "root") {
  document.body.innerHTML = `
    <div data-phx-session="abc123"
         data-phx-root-id="${rootId}"
         data-phx-static="456"
         id="${rootId}">
      <div id="content"></div>
      <div id="portal-target"></div>
      <div id="portal-target-2"></div>
    </div>
  `;

  const rootEl = document.getElementById(rootId);
  const liveSocket = new LiveSocket("/live", Socket);
  const view = simulateJoinedView(rootEl, liveSocket);

  return { liveSocket, view };
}

function createHtmlWithPortal(id, targetId, content) {
  const portalHtml = `
    <template id="${id}" ${PHX_PORTAL}="#${targetId}">
      <div id="portal-content-${id}">
        ${content}
      </div>
    </template>
  `;
  return portalHtml;
}

function performPatch(view, container, htmlString) {
  const tempDiv = document.createElement("div");
  tempDiv.innerHTML = htmlString;

  const domPatch = new DOMPatch(view, container, view.id, tempDiv, [], null);
  domPatch.perform(false);
}

describe("Portal handling", () => {
  beforeEach(() => {
    document.body.innerHTML = "";
  });

  test("basic portal teleporting", () => {
    const { view } = createViewWithPortal();
    const content = document.getElementById("content");
    const portalTarget = document.getElementById("portal-target")!;

    // Create HTML with portal template
    const html = `<div>${createHtmlWithPortal("portal1", "portal-target", "Hello from portal")}</div>`;

    // Perform the patch
    performPatch(view, content, html);

    // Verify portal content was teleported to target
    expect(portalTarget.innerHTML).toContain("Hello from portal");
    expect(
      portalTarget.querySelector("#portal-content-portal1"),
    ).not.toBeNull();

    // Verify portal element ID was tracked
    expect(view.portalElementIds.has("portal-content-portal1")).toBe(true);
  });

  test("updating portal content", () => {
    const { view } = createViewWithPortal();
    const content = document.getElementById("content");
    const portalTarget = document.getElementById("portal-target")!;

    // First patch to create portal
    const html1 = `<div>${createHtmlWithPortal("portal1", "portal-target", "Initial content")}</div>`;
    performPatch(view, content, html1);

    // Second patch to update portal content
    const html2 = `<div>${createHtmlWithPortal("portal1", "portal-target", "Updated content")}</div>`;
    performPatch(view, content, html2);

    // Verify content was updated
    expect(portalTarget.innerHTML).toContain("Updated content");
    expect(portalTarget.innerHTML).not.toContain("Initial content");
  });

  test("removing portal template removes teleported content", () => {
    const { view } = createViewWithPortal();
    const content = document.getElementById("content");
    const portalTarget = document.getElementById("portal-target")!;

    // First patch to create portal
    const html1 = `<div>${createHtmlWithPortal("portal1", "portal-target", "Portal content")}</div>`;
    performPatch(view, content, html1);

    // Verify portal was created
    expect(
      portalTarget.querySelector("#portal-content-portal1"),
    ).not.toBeNull();

    // Second patch to remove portal template
    const html2 = "<div></div>";
    performPatch(view, content, html2);

    // Verify teleported content was removed
    expect(portalTarget.querySelector("#portal-content-portal1")).toBeNull();
    expect(view.portalElementIds.size).toBe(0);
  });

  test("removing parent of portal template removes teleported content", () => {
    const { view } = createViewWithPortal();
    const content = document.getElementById("content");
    const portalTarget = document.getElementById("portal-target")!;

    // First patch - create a parent container with portal inside
    const html1 = `
      <div>
        <div id="parent-container">
          ${createHtmlWithPortal("portal1", "portal-target", "Nested portal content")}
        </div>
      </div>
    `;
    performPatch(view, content, html1);

    // Verify portal content was teleported
    expect(
      portalTarget.querySelector("#portal-content-portal1"),
    ).not.toBeNull();

    // Second patch - remove the parent container
    const html2 = "<div></div>";
    performPatch(view, content, html2);

    // Verify teleported content was removed
    expect(portalTarget.querySelector("#portal-content-portal1")).toBeNull();
    expect(view.portalElementIds.size).toBe(0);
  });

  test("teleporting to non-existent target throws error", () => {
    const { view } = createViewWithPortal();
    const content = document.getElementById("content");

    // Create template with invalid target
    const html = `<div>${createHtmlWithPortal("portal1", "non-existent-target", "Content")}</div>`;

    // Expect error when teleporting
    expect(() => {
      performPatch(view, content, html);
    }).toThrow("portal target with selector #non-existent-target not found");
  });

  test("portal template without id throws error", () => {
    const { view } = createViewWithPortal();
    const content = document.getElementById("content");

    // Create template with content that has no ID
    const html = `
      <div>
        <template id="invalid-portal" ${PHX_PORTAL}="#portal-target">
          <div>Content without ID</div>
        </template>
      </div>
    `;

    // Expect error when teleporting
    expect(() => {
      performPatch(view, content, html);
    }).toThrow("phx-portal template must have a single root element with ID");
  });

  test("cleans up teleported elements when view is destroyed", () => {
    const { view, liveSocket } = createViewWithPortal();
    const content = document.getElementById("content");
    const portalTarget = document.getElementById("portal-target")!;

    // Create portal
    const html = `<div>${createHtmlWithPortal("portal1", "portal-target", "Content")}</div>`;
    performPatch(view, content, html);

    // Verify content was teleported
    expect(
      portalTarget.querySelector("#portal-content-portal1"),
    ).not.toBeNull();

    // Destroy the view
    liveSocket.destroyViewByEl(view.el);

    // Verify teleported content was removed
    expect(portalTarget.querySelector("#portal-content-portal1")).toBeNull();
  });

  test("handles multiple portals to the same target", () => {
    const { view } = createViewWithPortal();
    const content = document.getElementById("content");
    const portalTarget = document.getElementById("portal-target")!;

    // Create HTML with two portal templates
    const html = `
      <div>
        ${createHtmlWithPortal("portal1", "portal-target", "First portal")}
        ${createHtmlWithPortal("portal2", "portal-target", "Second portal")}
      </div>
    `;

    // Perform the patch
    performPatch(view, content, html);

    // Verify both portals were teleported
    expect(
      portalTarget.querySelector("#portal-content-portal1"),
    ).not.toBeNull();
    expect(
      portalTarget.querySelector("#portal-content-portal2"),
    ).not.toBeNull();
    expect(portalTarget.innerHTML).toContain("First portal");
    expect(portalTarget.innerHTML).toContain("Second portal");
  });

  test("teleported elements are removed if source is removed", () => {
    const { view } = createViewWithPortal();
    const content = document.getElementById("content");
    const portalTarget = document.getElementById("portal-target")!;

    // First patch to create portals
    const html1 = `
      <div>
        ${createHtmlWithPortal("portal1", "portal-target", "First portal")}
        ${createHtmlWithPortal("portal2", "portal-target", "Second portal")}
      </div>
    `;
    performPatch(view, content, html1);

    // Verify both portals were teleported
    expect(portalTarget.querySelectorAll("div").length).toBe(2);

    // Second patch to remove one portal template
    const html2 = `<div>${createHtmlWithPortal("portal1", "portal-target", "First portal")}</div>`;
    performPatch(view, content, html2);

    // Verify only one portal remains
    expect(portalTarget.querySelectorAll("div").length).toBe(1);
    expect(
      portalTarget.querySelector("#portal-content-portal1"),
    ).not.toBeNull();
    expect(portalTarget.querySelector("#portal-content-portal2")).toBeNull();
    expect(view.portalElementIds.size).toBe(1);
    expect(view.portalElementIds.has("portal-content-portal1")).toBe(true);
    expect(view.portalElementIds.has("portal-content-portal2")).toBe(false);
  });

  test("teleported elements with PHX_SKIP are ignored", () => {
    const { view } = createViewWithPortal();
    const content = document.getElementById("content");
    const portalTarget = document.getElementById("portal-target")!;

    // Create template with skipped content
    const html = `
      <div>
        <template id="skipped-portal" ${PHX_PORTAL}="#portal-target">
          <div id="portal-content-skipped">Hello World!</div>
        </template>
      </div>
    `;

    // Perform the patch
    performPatch(view, content, html);

    // Verify the portal was not teleported because of PHX_SKIP
    expect(
      portalTarget.querySelector("#portal-content-skipped")!.innerHTML,
    ).toBe("Hello World!");

    const html2 = `
      <div>
        <template id="skipped-portal" ${PHX_PORTAL}="#portal-target">
          <div id="portal-content-skipped" ${PHX_SKIP}></div>
        </template>
      </div>
    `;

    performPatch(view, content, html2);
    // PHX_SKIP nodes are skipped
    expect(
      portalTarget.querySelector("#portal-content-skipped")!.innerHTML,
    ).toBe("Hello World!");
  });

  test("changing target of a portal moves content to new target", () => {
    const { view } = createViewWithPortal();
    const content = document.getElementById("content");
    const portalTarget1 = document.getElementById("portal-target")!;
    const portalTarget2 = document.getElementById("portal-target-2")!;

    // First patch to create portal with target1
    const html1 = `<div>${createHtmlWithPortal("portal1", "portal-target", "Portal content")}</div>`;
    performPatch(view, content, html1);

    // Verify content was teleported to first target
    expect(
      portalTarget1.querySelector("#portal-content-portal1"),
    ).not.toBeNull();
    expect(portalTarget2.querySelector("#portal-content-portal1")).toBeNull();

    // Second patch to change target
    const html2 = `<div>${createHtmlWithPortal("portal1", "portal-target-2", "Portal content")}</div>`;
    performPatch(view, content, html2);

    // Verify content was moved to second target
    expect(portalTarget1.querySelector("#portal-content-portal1")).toBeNull();
    expect(
      portalTarget2.querySelector("#portal-content-portal1"),
    ).not.toBeNull();
  });
});
