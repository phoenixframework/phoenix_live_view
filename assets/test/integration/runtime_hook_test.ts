import { Socket } from "phoenix";
import { PHX_RUNTIME_HOOK } from "phoenix_live_view/constants";
import DOMPatch from "phoenix_live_view/dom_patch";
import LiveSocket from "phoenix_live_view/live_socket";
import { simulateJoinedView } from "../test_helpers";

describe("runtime hook patching", () => {
  afterEach(() => {
    document.body.innerHTML = "";
  });

  test("reports the replacement script as added", () => {
    document.body.innerHTML = `
      <div data-phx-session="abc123"
           data-phx-root-id="root"
           data-phx-static="456"
           id="root">
        <div id="content"></div>
      </div>
    `;
    const root = document.getElementById("root")!;
    const liveSocket = new LiveSocket("/live", Socket);
    const view = simulateJoinedView(root, liveSocket);
    const container = document.getElementById("content")!;
    const source = document.createElement("div");
    source.innerHTML = `<script ${PHX_RUNTIME_HOOK}="Example">window.example = true</script>`;
    const patch = new DOMPatch(view, container, source, new Set(), null);
    const added: Node[] = [];
    patch.afterAdded((el) => added.push(el));

    patch.perform(false);

    const script = container.querySelector("script")!;
    const addedScript = added.find(
      (el) =>
        el instanceof HTMLScriptElement &&
        el.getAttribute(PHX_RUNTIME_HOOK) === "Example",
    );
    expect(addedScript).toBe(script);
    expect(script.isConnected).toBe(true);
  });
});
