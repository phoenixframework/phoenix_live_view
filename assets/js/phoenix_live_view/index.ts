/*
================================================================================
Phoenix LiveView JavaScript Client
================================================================================

See the hexdocs at `https://hexdocs.pm/phoenix_live_view` for documentation.
*/

import OriginalLiveSocket, { isUsedInput } from "./live_socket";
import DOM from "./dom";
import { ViewHook } from "./view_hook";
import View from "./view";

import type { LiveSocketJSCommands } from "./js_commands";
import type { Hook, HooksOptions } from "./view_hook";
import type { Socket as PhoenixSocket } from "phoenix";

/**
 * Options for configuring the LiveSocket instance.
 */
export interface LiveSocketOptions {
  /**
   * Defaults for phx-debounce and phx-throttle.
   */
  defaults?: {
    /** The millisecond phx-debounce time. Defaults 300 */
    debounce?: number;
    /** The millisecond phx-throttle time. Defaults 300 */
    throttle?: number;
  };
  /**
   * An object or function for passing connect params.
   * The function receives the element associated with a given LiveView. For example:
   *
   *     (el) => {view: el.getAttribute("data-my-view-name", token: window.myToken}
   *
   */
  params?:
    | ((el: HTMLElement) => { [key: string]: any })
    | { [key: string]: any };
  /**
   * The optional prefix to use for all phx DOM annotations.
   *
   * Defaults to "phx-".
   */
  bindingPrefix?: string;
  /**
   * Callbacks for LiveView hooks.
   *
   * See [Client hooks via `phx-hook`](https://hexdocs.pm/phoenix_live_view/js-interop.html#client-hooks-via-phx-hook) for more information.
   */
  hooks?: HooksOptions;
  /** Callbacks for LiveView uploaders. */
  uploaders?: { [key: string]: any }; // TODO: define more specifically
  /** Delay in milliseconds before applying loading states. */
  loaderTimeout?: number;
  /** Delay in milliseconds before executing phx-disconnected commands. */
  disconnectedTimeout?: number;
  /** Maximum reloads before entering failsafe mode. */
  maxReloads?: number;
  /** Minimum time between normal reload attempts. */
  reloadJitterMin?: number;
  /** Maximum time between normal reload attempts. */
  reloadJitterMax?: number;
  /** Time between reload attempts in failsafe mode. */
  failsafeJitter?: number;
  /**
   * Function to log debug information. For example:
   *
   *     (view, kind, msg, obj) => console.log(`${view.id} ${kind}: ${msg} - `, obj)
   */
  viewLogger?: (view: View, kind: string, msg: string, obj: any) => void;
  /**
   * Object mapping event names to functions for populating event metadata.
   *
   *     metadata: {
   *       click: (e, el) => {
   *         return {
   *           ctrlKey: e.ctrlKey,
   *           metaKey: e.metaKey,
   *           detail: e.detail || 1,
   *         }
   *       },
   *       keydown: (e, el) => {
   *         return {
   *           key: e.key,
   *           ctrlKey: e.ctrlKey,
   *           metaKey: e.metaKey,
   *           shiftKey: e.shiftKey
   *         }
   *       }
   *     }
   *
   */
  metadata?: { [eventName: string]: (e: Event, el: HTMLElement) => object };
  /**
   * An optional Storage compatible object
   * Useful when LiveView won't have access to `sessionStorage`. For example, This could
   * happen if a site loads a cross-domain LiveView in an iframe.
   *
   * Example usage:
   *
   *     class InMemoryStorage {
   *       constructor() { this.storage = {} }
   *       getItem(keyName) { return this.storage[keyName] || null }
   *       removeItem(keyName) { delete this.storage[keyName] }
   *       setItem(keyName, keyValue) { this.storage[keyName] = keyValue }
   *     }
   */
  sessionStorage?: Storage;
  /**
   * An optional Storage compatible object
   * Useful when LiveView won't have access to `localStorage`.
   *
   * See `sessionStorage` for an example.
   */
  localStorage?: Storage;
  /**
   * If set to `true`, `phx-change` events will be blocked (will not fire)
   * while the user is composing input using an IME (Input Method Editor).
   * This is determined by the `e.isComposing` property on keyboard events,
   * which is `true` when the user is in the process of entering composed characters (for example,
   * when typing Japanese or Chinese using romaji or pinyin input methods).
   * By default, `phx-change` will not be blocked during a composition session,
   * but note that there were issues reported in older versions of Safari,
   * where a LiveView patch to the input caused unexpected behavior.
   *
   * For more information, see
   * - https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/isComposing
   * - https://github.com/phoenixframework/phoenix_live_view/issues/3322
   *
   * Defaults to `false`.
   */
  blockPhxChangeWhileComposing?: boolean;
  /** DOM callbacks. */
  dom?: {
    /**
     * An optional function to modify the behavior of querying elements in JS commands.
     * @param sourceEl - The source element, e.g. the button that was clicked.
     * @param query - The query value.
     * @param defaultQuery - A default query function that can be used if no custom query should be applied.
     * @returns A list of DOM elements.
     */
    jsQuerySelectorAll?: (
      sourceEl: HTMLElement,
      query: string,
      defaultQuery: () => Element[],
    ) => Element[];
    /**
     * Called immediately before a DOM patch is applied.
     */
    onPatchStart?: (container: HTMLElement) => void;
    /**
     * Called immediately after a DOM patch is applied.
     */
    onPatchEnd?: (container: HTMLElement) => void;
    /**
     * Called when a new DOM node is added.
     */
    onNodeAdded?: (node: Node) => void;
    /**
     * Called before an element is updated.
     */
    onBeforeElUpdated?: (fromEl: Element, toEl: Element) => void;
  };
  /** Allow passthrough of other options to the Phoenix Socket constructor. */
  [key: string]: any;
}

/**
 * Interface describing the public API of a LiveSocket instance.
 */
export interface LiveSocketInstanceInterface {
  /**
   * Returns the version of the LiveView client.
   */
  version(): string;
  /**
   * Returns true if profiling is enabled. See `enableProfiling` and `disableProfiling`.
   */
  isProfileEnabled(): boolean;
  /**
   * Returns true if debugging is enabled. See `enableDebug` and `disableDebug`.
   */
  isDebugEnabled(): boolean;
  /**
   * Returns true if debugging is disabled. See `enableDebug` and `disableDebug`.
   */
  isDebugDisabled(): boolean;
  /**
   * Enables debugging.
   *
   * When debugging is enabled, the LiveView client will log debug information to the console.
   * See [Debugging client events](https://hexdocs.pm/phoenix_live_view/js-interop.html#debugging-client-events) for more information.
   */
  enableDebug(): void;
  /**
   * Enables profiling.
   *
   * When profiling is enabled, the LiveView client will log profiling information to the console.
   */
  enableProfiling(): void;
  /**
   * Disables debugging.
   */
  disableDebug(): void;
  /**
   * Disables profiling.
   */
  disableProfiling(): void;
  /**
   * Enables latency simulation.
   *
   * When latency simulation is enabled, the LiveView client will add a delay to requests and responses from the server.
   * See [Simulating Latency](https://hexdocs.pm/phoenix_live_view/js-interop.html#simulating-latency) for more information.
   */
  enableLatencySim(upperBoundMs: number): void;
  /**
   * Disables latency simulation.
   */
  disableLatencySim(): void;
  /**
   * Returns the current latency simulation upper bound.
   */
  getLatencySim(): number | null;
  /**
   * Returns the Phoenix Socket instance.
   */
  getSocket(): PhoenixSocket;
  /**
   * Connects to the LiveView server.
   */
  connect(): void;
  /**
   * Disconnects from the LiveView server.
   */
  disconnect(callback?: () => void): void;
  /**
   * Can be used to replace the transport used by the underlying Phoenix Socket.
   */
  replaceTransport(transport: any): void;
  /**
   * Executes an encoded JS command, targeting the given element.
   *
   * See [`Phoenix.LiveView.JS`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.JS.html) for more information.
   */
  execJS(el: HTMLElement, encodedJS: string, eventType?: string | null): void;
  /**
   * Returns an object with methods to manipluate the DOM and execute JavaScript.
   * The applied changes integrate with server DOM patching.
   *
   * See [JavaScript interoperability](https://hexdocs.pm/phoenix_live_view/js-interop.html) for more information.
   */
  js(): LiveSocketJSCommands;
}

/**
 * Interface describing the LiveSocket constructor.
 */
export interface LiveSocketConstructor {
  /**
   * Creates a new LiveSocket instance.
   *
   * @param endpoint - The string WebSocket endpoint, ie, `"wss://example.com/live"`,
   *                                               `"/live"` (inherited host & protocol)
   * @param socket - the required Phoenix Socket class imported from "phoenix". For example:
   *
   *     import {Socket} from "phoenix"
   *     import {LiveSocket} from "phoenix_live_view"
   *     let liveSocket = new LiveSocket("/live", Socket, {...})
   *
   * @param opts - Optional configuration.
   */
  new (
    endpoint: string,
    socket: typeof PhoenixSocket,
    opts?: LiveSocketOptions,
  ): LiveSocketInstanceInterface;
}

// because LiveSocket is in JS (for now), we cast it to our defined TypeScript constructor.
const LiveSocket = OriginalLiveSocket as unknown as LiveSocketConstructor;

/** Creates a hook instance for the given element and callbacks.
 *
 * @param el - The element to associate with the hook.
 * @param callbacks - The list of hook callbacks, such as mounted,
 *   updated, destroyed, etc.
 *
 * *Note*: `createHook` must be called from the `connectedCallback` lifecycle
 * which is triggered after the element has been added to the DOM. If you try
 * to call `createHook` from the constructor, an error will be logged.
 *
 * @example
 *
 * class MyComponent extends HTMLElement {
 *   connectedCallback(){
 *     let onLiveViewMounted = () => this.hook.pushEvent(...))
 *     this.hook = createHook(this, {mounted: onLiveViewMounted})
 *   }
 * }
 *
 * @returns Returns the Hook instance for the custom element.
 */
function createHook(el: HTMLElement, callbacks: Hook): ViewHook {
  let existingHook = DOM.getCustomElHook(el);
  if (existingHook) {
    return existingHook;
  }

  let hook = new ViewHook(View.closestView(el), el, callbacks);
  DOM.putCustomElHook(el, hook);
  return hook;
}

export { LiveSocket, isUsedInput, createHook, ViewHook, Hook, HooksOptions };
