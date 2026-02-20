import { Socket } from "phoenix";
import LiveSocket from "phoenix_live_view/live_socket";
import ViewHook from "phoenix_live_view/view_hook";
import { simulateJoinedView, liveViewDOM } from "./test_helpers";

describe("phx-skip with JavaScript-set DOM IDs", () => {
  let liveSocket: LiveSocket | null;

  beforeEach(() => {
    global.Phoenix = { Socket };
    global.document.body.innerHTML = "";
  });

  afterEach(() => {
    liveSocket && liveSocket.destroyAllViews();
    liveSocket = null;
  });

  test("preserves element when JS sets ID and backend sends phx-skip", () => {
    liveSocket = new LiveSocket("/live", Socket);
    const initialContent = `
        <span data-phx-magic-id="span-magic">content</span>
    `;

    const el = liveViewDOM(initialContent);
    document.body.appendChild(el);

    const view = simulateJoinedView(el, liveSocket);
    const targetEl = el.querySelector('[data-phx-magic-id="span-magic"]');

    const hook = new ViewHook(view, targetEl as HTMLElement, {});
    hook.js().setAttribute(targetEl as HTMLElement, "id", "js-set-id");

    const updateDiff = {
      s: [
        `
        <span data-phx-skip data-phx-magic-id="span-magic">content</span>
    `,
      ],
      fingerprint: 124,
    };

    view.update(updateDiff, []);

    const afterUpdate = el.querySelector("#js-set-id");
    expect(afterUpdate).not.toBeNull();
    expect(afterUpdate!.id).toBe("js-set-id");
    expect(afterUpdate!.textContent).toBe("content");
  });
});
