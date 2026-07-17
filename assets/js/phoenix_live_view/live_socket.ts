import { type Socket } from "phoenix";

import {
  BINDING_PREFIX,
  CONSECUTIVE_RELOADS,
  DEFAULTS,
  FAILSAFE_JITTER,
  LOADER_TIMEOUT,
  DISCONNECTED_TIMEOUT,
  MAX_RELOADS,
  PHX_DEBOUNCE,
  PHX_DROP_TARGET,
  PHX_HAS_FOCUSED,
  PHX_KEY,
  PHX_LINK_STATE,
  PHX_LIVE_LINK,
  PHX_LV_DEBUG,
  PHX_LV_LATENCY_SIM,
  PHX_LV_PROFILE,
  PHX_LV_HISTORY_POSITION,
  PHX_MAIN,
  PHX_PARENT_ID,
  PHX_VIEW_SELECTOR,
  PHX_ROOT_ID,
  PHX_THROTTLE,
  PHX_TRACK_UPLOADS,
  PHX_SESSION,
  RELOAD_JITTER_MIN,
  RELOAD_JITTER_MAX,
  PHX_REF_SRC,
  PHX_RELOAD_STATUS,
  PHX_RUNTIME_HOOK,
  PHX_DROP_TARGET_ACTIVE_CLASS,
  PHX_TELEPORTED_SRC,
} from "./constants";

import {
  clone,
  closestPhxBinding,
  closure,
  debug,
  maybe,
  logError,
  eventContainsFiles,
} from "./utils";

import Browser from "./browser";
import DOM from "./dom";
import Hooks from "./hooks";
import LiveUploader from "./live_uploader";
import View from "./view";
import JS from "./js";
import jsCommands, { EncodedJS, LiveSocketJSCommands } from "./js_commands";
import { HooksOptions } from "./view_hook";

/**
 * Returns true if the given element was touched by a user.
 * @param {HTMLElement} el - The element to check.
 * @returns {boolean} True if the element was touched by a user, false otherwise.
 */
export const isUsedInput = (el) => DOM.isUsedInput(el);

/**
 * Options for configuring the LiveSocket instance.
 */
export interface LiveSocketOptions {
  /**
   * Defaults for phx-debounce and phx-throttle.
   */
  defaults?: {
    /** The millisecond phx-debounce time. Defaults to `300`. */
    debounce?: number;
    /** The millisecond phx-throttle time. Defaults to `300`. */
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
   * Defaults to `"phx-"`.
   */
  bindingPrefix?: string;
  /**
   * Callbacks for LiveView hooks.
   *
   * See [Client hooks via `phx-hook`](https://phoenix-live-view.hexdocs.pm/js-interop.html#client-hooks-via-phx-hook) for more information.
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
  metadata?: {
    [K in keyof HTMLElementEventMap]?: (
      e: HTMLElementEventMap[K],
      el: HTMLElement,
    ) => object;
  };
  /**
   * An optional Storage-compatible object.
   * Useful when LiveView won't have access to `sessionStorage`. For example, this could
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
   * An optional Storage-compatible object.
   * Useful when LiveView won't have access to `localStorage`.
   *
   * See {@link sessionStorage} for an example.
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
     * When defined, called with a start callback that needs to be called
     * to perform the actual patch. Failing to call the start callback causes
     * the page to become stuck.
     *
     * This can be used to delay patches in order to perform view transitions,
     * for example:
     *
     * ```javascript
     * let liveSocket = new LiveSocket("/live", Socket, {
     *   dom: {
     *     onDocumentPatch(start) {
     *       document.startViewTransition(start);
     *     }
     *   }
     * })
     * ```
     *
     * It is strongly advised to call start as quickly as possible.
     */
    onDocumentPatch?: (start: () => void) => void;
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

export default class LiveSocket {
  socket: Socket;

  /** @internal */
  unloaded = false;
  private bindingPrefix: string;
  private viewLogger: any;
  private metadataCallbacks: any;
  private defaults: any;
  private prevActive: any;
  private silenced: boolean;
  /** @internal */
  main: View | null;
  private outgoingMainEl: Element | null;
  private clickStartedAtTarget: EventTarget | null;
  private linkRef: number;
  private roots: Record<string, View>;
  private href: string;
  private pendingLink: string | null;
  private currentLocation: Location;
  private hooks: HooksOptions;
  /** @internal */
  loaderTimeout: number;
  private reloadWithJitterTimer: ReturnType<typeof setTimeout> | null;
  private maxReloads: number;
  private reloadJitterMin: number;
  private reloadJitterMax: number;
  private failsafeJitter: number;
  /** @internal */
  localStorage: Storage;
  private sessionStorage: Storage;
  private boundTopLevelEvents: boolean;
  private boundEventNames: Set<string>;
  private blockPhxChangeWhileComposing: boolean;
  private serverCloseRef: string | null;
  /** @internal */
  domCallbacks: {
    jsQuerySelectorAll:
      | ((
          sourceEl: HTMLElement,
          query: string,
          defaultQuery: () => Element[],
        ) => Element[])
      | null;
    onDocumentPatch?: (start: () => void) => void;
    onPatchStart: (container: HTMLElement) => void;
    onPatchEnd: (container: HTMLElement) => void;
    onNodeAdded: (node: Node) => void;
    onBeforeElUpdated: (fromEl: Element, toEl: Element) => void;
  };
  private transitions: TransitionSet;
  /** @internal */
  currentHistoryPosition: number;

  /** @internal */
  params: (el: Element) => Record<string, unknown>;
  /** @internal */
  uploaders: any;
  /** @internal */
  disconnectedTimeout: number;

  /**
   * Creates a new LiveSocket instance.
   */
  constructor(
    /**
     * The WebSocket endpoint URL, e.g., `"wss://example.com/live"`, or `"/live"` to inherit the host and protocol.
     */
    url: string,
    /**
     * The required Phoenix Socket class imported from "phoenix". For example:
     *
     * ```javascript
     * import {Socket} from "phoenix"
     * import {LiveSocket} from "phoenix_live_view"
     * let liveSocket = new LiveSocket("/live", Socket, {...})
     * ```
     */
    phxSocket: typeof Socket,
    /**
     * Optional configuration.
     */
    opts: Partial<LiveSocketOptions> = {},
  ) {
    if (!phxSocket || phxSocket.constructor.name === "Object") {
      throw new Error(`
      a phoenix Socket must be provided as the second argument to the LiveSocket constructor. For example:

          import {Socket} from "phoenix"
          import {LiveSocket} from "phoenix_live_view"
          let liveSocket = new LiveSocket("/live", Socket, {...})
      `);
    }
    this.socket = new phxSocket(url, opts);
    this.bindingPrefix = opts.bindingPrefix || BINDING_PREFIX;
    this.params = closure(opts.params || {});
    this.viewLogger = opts.viewLogger;
    this.metadataCallbacks = opts.metadata || {};
    this.defaults = Object.assign(clone(DEFAULTS), opts.defaults || {});
    this.prevActive = null;
    this.silenced = false;
    this.main = null;
    this.outgoingMainEl = null;
    this.clickStartedAtTarget = null;
    this.linkRef = 1;
    this.roots = {};
    this.href = window.location.href;
    this.pendingLink = null;
    this.currentLocation = clone(window.location);
    this.hooks = opts.hooks || {};
    this.uploaders = opts.uploaders || {};
    this.loaderTimeout = opts.loaderTimeout || LOADER_TIMEOUT;
    this.disconnectedTimeout = opts.disconnectedTimeout || DISCONNECTED_TIMEOUT;
    /**
     * @type {ReturnType<typeof setTimeout> | null}
     */
    this.reloadWithJitterTimer = null;
    this.maxReloads = opts.maxReloads || MAX_RELOADS;
    this.reloadJitterMin = opts.reloadJitterMin || RELOAD_JITTER_MIN;
    this.reloadJitterMax = opts.reloadJitterMax || RELOAD_JITTER_MAX;
    this.failsafeJitter = opts.failsafeJitter || FAILSAFE_JITTER;
    this.localStorage = opts.localStorage || window.localStorage;
    this.sessionStorage = opts.sessionStorage || window.sessionStorage;
    this.boundTopLevelEvents = false;
    this.boundEventNames = new Set();
    this.blockPhxChangeWhileComposing =
      opts.blockPhxChangeWhileComposing || false;
    this.serverCloseRef = null;
    this.domCallbacks = Object.assign(
      {
        jsQuerySelectorAll: null,
        onPatchStart: closure(),
        onPatchEnd: closure(),
        onNodeAdded: closure(),
        onBeforeElUpdated: closure(),
      },
      opts.dom || {},
    );
    this.transitions = new TransitionSet();
    this.currentHistoryPosition =
      parseInt(this.sessionStorage.getItem(PHX_LV_HISTORY_POSITION) || "0") ||
      0;
    window.addEventListener("pagehide", (_e) => {
      this.unloaded = true;
    });
    this.socket.onOpen(() => {
      if (this.isUnloaded()) {
        // reload page if being restored from back/forward cache and browser does not emit "pageshow"
        window.location.reload();
      }
    });
  }

  // public

  /**
   * Returns the version of the LiveView client.
   */
  version(): string {
    return LV_VSN;
  }

  /**
   * Returns true if profiling is enabled. See {@link enableProfiling} and {@link disableProfiling}.
   */
  isProfileEnabled(): boolean {
    return this.sessionStorage.getItem(PHX_LV_PROFILE) === "true";
  }

  /**
   * Returns true if debugging is enabled. See {@link enableDebug} and {@link disableDebug}.
   */
  isDebugEnabled(): boolean {
    return this.sessionStorage.getItem(PHX_LV_DEBUG) === "true";
  }

  /**
   * Returns true if debugging is disabled. See {@link enableDebug} and {@link disableDebug}.
   */
  isDebugDisabled(): boolean {
    return this.sessionStorage.getItem(PHX_LV_DEBUG) === "false";
  }

  /**
   * Enables debugging.
   *
   * When debugging is enabled, the LiveView client will log debug information to the console.
   * See [Debugging client events](https://phoenix-live-view.hexdocs.pm/js-interop.html#debugging-client-events) for more information.
   */
  enableDebug(): void {
    this.sessionStorage.setItem(PHX_LV_DEBUG, "true");
  }

  /**
   * Enables profiling.
   *
   * When profiling is enabled, the LiveView client will log profiling information to the console.
   */
  enableProfiling(): void {
    this.sessionStorage.setItem(PHX_LV_PROFILE, "true");
  }

  /**
   * Disables debugging.
   */
  disableDebug(): void {
    this.sessionStorage.setItem(PHX_LV_DEBUG, "false");
  }

  /**
   * Disables profiling.
   */
  disableProfiling(): void {
    this.sessionStorage.removeItem(PHX_LV_PROFILE);
  }

  /**
   * Enables latency simulation.
   *
   * When latency simulation is enabled, the LiveView client will add a delay to requests and responses from the server.
   * See [Simulating Latency](https://phoenix-live-view.hexdocs.pm/js-interop.html#simulating-latency) for more information.
   */
  enableLatencySim(upperBoundMs: number): void {
    this.enableDebug();
    console.log(
      "latency simulator enabled for the duration of this browser session. Call disableLatencySim() to disable",
    );
    this.sessionStorage.setItem(PHX_LV_LATENCY_SIM, upperBoundMs.toString());
  }

  /**
   * Disables latency simulation.
   */
  disableLatencySim(): void {
    this.sessionStorage.removeItem(PHX_LV_LATENCY_SIM);
  }

  /**
   * Returns the current latency simulation upper bound.
   */
  getLatencySim(): number | null {
    const str = this.sessionStorage.getItem(PHX_LV_LATENCY_SIM);
    return str ? parseInt(str) : null;
  }

  /**
   * Returns the Phoenix Socket instance.
   */
  getSocket(): Socket {
    return this.socket;
  }

  /**
   * Connects to the LiveView server.
   */
  connect(): void {
    // enable debug by default if on localhost and not explicitly disabled
    if (window.location.hostname === "localhost" && !this.isDebugDisabled()) {
      this.enableDebug();
    }
    const doConnect = () => {
      this.resetReloadStatus();
      if (this.joinRootViews()) {
        this.bindTopLevelEvents();
        this.socket.connect();
      } else if (this.main) {
        this.socket.connect();
      } else {
        this.bindTopLevelEvents({ dead: true });
      }
      this.joinDeadView();
    };
    if (
      ["complete", "loaded", "interactive"].indexOf(document.readyState) >= 0
    ) {
      doConnect();
    } else {
      document.addEventListener("DOMContentLoaded", () => doConnect());
    }
  }

  /**
   * Disconnects from the LiveView server.
   */
  disconnect(callback?: () => void): void {
    this.reloadWithJitterTimer != null &&
      clearTimeout(this.reloadWithJitterTimer);
    // remove the socket close listener to avoid trying to handle
    // a server close event when it is actually caused by us disconnecting
    if (this.serverCloseRef) {
      this.socket.off([this.serverCloseRef]);
      this.serverCloseRef = null;
    }
    this.socket.disconnect(callback);
  }

  /**
   * Can be used to replace the transport used by the underlying Phoenix Socket.
   */
  replaceTransport(transport: any): void {
    this.reloadWithJitterTimer != null &&
      clearTimeout(this.reloadWithJitterTimer);
    this.socket.replaceTransport(transport);
    this.connect();
  }

  /**
   * Executes an encoded JS command, targeting the given element.
   *
   * See [`Phoenix.LiveView.JS`](https://phoenix-live-view.hexdocs.pm/Phoenix.LiveView.JS.html) for more information.
   */
  execJS(
    el: Element,
    encodedJS: EncodedJS,
    eventType: string | null = null,
  ): void {
    const e = new CustomEvent("phx:exec", { detail: { sourceElement: el } });
    this.owner(el, (view) => JS.exec(e, eventType, encodedJS, view, el));
  }

  /**
   * Returns an object with methods to manipulate the DOM and execute JavaScript.
   * The applied changes integrate with server DOM patching.
   *
   * See [JavaScript interoperability](https://phoenix-live-view.hexdocs.pm/js-interop.html) for more information.
   */
  js(): LiveSocketJSCommands {
    return jsCommands(this, "js");
  }

  // private

  /** @internal */
  unload() {
    if (this.unloaded) {
      return;
    }
    if (this.main && this.isConnected()) {
      this.log(this.main, "socket", () => ["disconnect for page nav"]);
    }
    this.unloaded = true;
    this.destroyAllViews();
    this.disconnect();
  }

  /** @internal */
  triggerDOM(kind, args) {
    this.domCallbacks[kind](...args);
  }

  /** @internal */
  time(name, func) {
    if (!this.isProfileEnabled() || !console.time) {
      return func();
    }
    console.time(name);
    const result = func();
    console.timeEnd(name);
    return result;
  }

  /** @internal */
  log(view, kind, msgCallback) {
    if (this.viewLogger) {
      const [msg, obj] = msgCallback();
      this.viewLogger(view, kind, msg, obj);
    } else if (this.isDebugEnabled()) {
      const [msg, obj] = msgCallback();
      debug(view, kind, msg, obj);
    }
  }

  /** @internal */
  requestDOMUpdate(callback) {
    this.transitions.after(callback);
  }

  /** @internal */
  asyncTransition(promise) {
    this.transitions.addAsyncTransition(promise);
  }

  /** @internal */
  transition(time, onStart, onDone = function () {}) {
    this.transitions.addTransition(time, onStart, onDone);
  }

  /** @internal */
  onChannel(channel, event, cb) {
    channel.on(event, (data) => {
      const latency = this.getLatencySim();
      if (!latency) {
        cb(data);
      } else {
        setTimeout(() => cb(data), latency);
      }
    });
  }

  /** @internal */
  reloadWithJitter(view, log?) {
    this.reloadWithJitterTimer != null &&
      clearTimeout(this.reloadWithJitterTimer);
    this.disconnect();
    const minMs = this.reloadJitterMin;
    const maxMs = this.reloadJitterMax;
    let afterMs = Math.floor(Math.random() * (maxMs - minMs + 1)) + minMs;
    const tries = Browser.updateLocal(
      this.localStorage,
      window.location.pathname,
      CONSECUTIVE_RELOADS,
      0,
      (count) => count + 1,
    );
    if (tries >= this.maxReloads) {
      afterMs = this.failsafeJitter;
    }
    this.reloadWithJitterTimer = setTimeout(() => {
      // if view has recovered, such as transport replaced, then cancel
      if (view.isDestroyed() || view.isConnected()) {
        return;
      }
      view.destroy();
      log
        ? log()
        : this.log(view, "join", () => [
            `encountered ${tries} consecutive reloads`,
          ]);
      if (tries >= this.maxReloads) {
        this.log(view, "join", () => [
          `exceeded ${this.maxReloads} consecutive reloads. Entering failsafe mode`,
        ]);
      }
      if (this.pendingLink !== null) {
        window.location.href = this.pendingLink;
      } else {
        window.location.reload();
      }
    }, afterMs);
  }

  /** @internal */
  getHookDefinition(name) {
    if (!name) {
      return;
    }
    return (
      this.maybeInternalHook(name) ||
      this.hooks[name] ||
      this.maybeRuntimeHook(name)
    );
  }

  /** @internal */
  maybeInternalHook(name) {
    return name && name.startsWith("Phoenix.") && Hooks[name.split(".")[1]];
  }

  /** @internal */
  maybeRuntimeHook(name) {
    const runtimeHook = document.querySelector(
      `script[${PHX_RUNTIME_HOOK}="${CSS.escape(name)}"]`,
    );
    if (!runtimeHook) {
      return;
    }
    let callbacks = window[`phx_hook_${name}`];
    if (!callbacks || typeof callbacks !== "function") {
      logError("a runtime hook must be a function", runtimeHook);
      return;
    }
    const hookDefiniton = callbacks();
    if (
      hookDefiniton &&
      (typeof hookDefiniton === "object" || typeof hookDefiniton === "function")
    ) {
      return hookDefiniton;
    }
    logError(
      "runtime hook must return an object with hook callbacks or an instance of ViewHook",
      runtimeHook,
    );
  }

  /** @internal */
  isUnloaded() {
    return this.unloaded;
  }

  /** @internal */
  isConnected() {
    return this.socket.isConnected();
  }

  /** @internal */
  getBindingPrefix() {
    return this.bindingPrefix;
  }

  /** @internal */
  binding(kind) {
    return `${this.getBindingPrefix()}${kind}`;
  }

  /** @internal */
  channel(topic, params) {
    return this.socket.channel(topic, params);
  }

  /** @internal */
  joinDeadView() {
    const body = document.body;
    if (
      body &&
      !this.isPhxView(body) &&
      !this.isPhxView(document.firstElementChild)
    ) {
      const view = this.newRootView(body);
      view.setHref(this.getHref());
      view.joinDead();
      if (!this.main) {
        this.main = view;
      }
      window.requestAnimationFrame(() => {
        view.execNewMounted();
        // restore scroll position when navigating from an external / non-live page
        this.maybeScroll(history.state?.scroll);
      });
    }
  }

  /** @internal */
  joinRootViews() {
    let rootsFound = false;
    DOM.all(
      document,
      `${PHX_VIEW_SELECTOR}:not([${PHX_PARENT_ID}])`,
      (rootEl) => {
        if (!this.getRootById(rootEl.id)) {
          const view = this.newRootView(rootEl);
          // stickies cannot be mounted at the router and therefore should not
          // get a href set on them
          if (!DOM.isPhxSticky(rootEl)) {
            view.setHref(this.getHref());
          }
          view.join();
          if (rootEl.hasAttribute(PHX_MAIN)) {
            this.main = view;
          }
        }
        rootsFound = true;
      },
    );
    return rootsFound;
  }

  /** @internal */
  redirect(to: string, flash: string | null, reloadToken: string | null) {
    if (reloadToken) {
      Browser.setCookie(PHX_RELOAD_STATUS, reloadToken, 60);
    }
    this.unload();
    Browser.redirect(to, flash);
  }

  /** @internal */
  replaceMain(
    href: string,
    flash: string | null,
    callback: ((linkRef: number) => void) | null = null,
    linkRef = this.setPendingLink(href),
  ) {
    if (!this.main) {
      return;
    }
    const liveReferer = this.currentLocation.href;
    this.outgoingMainEl = this.outgoingMainEl || this.main!.el;

    const stickies = DOM.findPhxSticky(document) || [];
    const removeEls = DOM.all(
      this.outgoingMainEl!,
      `[${this.binding("remove")}]`,
    ).filter((el) => !DOM.isChildOfAny(el, stickies));

    const newMainEl = DOM.cloneNode(this.outgoingMainEl, "");
    const oldMainView = this.main;
    oldMainView.showLoader(this.loaderTimeout);
    oldMainView.destroy();

    this.main = this.newRootView(newMainEl, flash, liveReferer);
    this.main.setRedirect(href);
    // the old view is destroyed at this point; pass it explicitly so the
    // phx-remove commands execute in the context of the outgoing view
    this.transitionRemoves(removeEls, oldMainView);
    this.main.join((joinCount, onDone) => {
      if (joinCount === 1 && this.commitPendingLink(linkRef)) {
        this.requestDOMUpdate(() => {
          // remove phx-remove els right before we replace the main element
          removeEls.forEach((el) => el.remove());
          stickies.forEach((el) => newMainEl.appendChild(el));
          this.outgoingMainEl!.replaceWith(newMainEl);
          this.outgoingMainEl = null;
          callback && callback(linkRef);
          onDone();
        });
      }
    });
  }

  /** @internal */
  transitionRemoves(elements, view: View, callback?) {
    const removeAttr = this.binding("remove");
    const silenceEvents = (e) => {
      e.preventDefault();
      e.stopImmediatePropagation();
    };
    elements.forEach((el) => {
      // prevent all listeners we care about from bubbling to window
      // since we are removing the element
      for (const event of this.boundEventNames) {
        el.addEventListener(event, silenceEvents, true);
      }
      const e = new CustomEvent("phx:exec", { detail: { sourceElement: el } });
      JS.exec(e, "remove", el.getAttribute(removeAttr), view, el);
    });
    // remove the silenced listeners when transitions are done in case the element is re-used
    // and call caller's callback as soon as we are done with transitions
    this.requestDOMUpdate(() => {
      elements.forEach((el) => {
        for (const event of this.boundEventNames) {
          el.removeEventListener(event, silenceEvents, true);
        }
      });
      callback && callback();
    });
  }

  /** @internal */
  isPhxView(el) {
    return el.getAttribute && el.getAttribute(PHX_SESSION) !== null;
  }

  /** @internal */
  newRootView(el, flash?, liveReferer?) {
    const view = new View(el, this, null, flash, liveReferer);
    this.roots[view.id] = view;
    return view;
  }

  /** @internal */
  owner(childEl: Element, callback?: (view: View) => any) {
    let view: View | undefined;
    const viewEl = DOM.closestViewEl(childEl);
    if (viewEl) {
      // resolve the view by element identity instead of id; during live
      // navigation the new view is registered under the same id while the
      // old DOM is still attached, and events from the old DOM must not be
      // routed to the new view. A destroyed view removes its element binding,
      // in which case we DO NOT want to fallback to the main element
      view = DOM.private(viewEl, "view");
    } else {
      if (!childEl.isConnected) {
        // if the element is not part of the DOM any more
        // there's no owner and we should not do fall back
        return null;
      }
      view = this.main!;
    }
    return view && callback ? callback(view) : view;
  }

  /** @internal */
  withinOwners(childEl, callback) {
    this.owner(childEl, (view) => callback(view, childEl));
  }

  /** @internal */
  getViewByEl(el) {
    const rootId = el.getAttribute(PHX_ROOT_ID);
    return maybe(this.getRootById(rootId), (root) =>
      root.getDescendentByEl(el),
    );
  }

  /** @internal */
  getRootById(id) {
    return this.roots[id];
  }

  /** @internal */
  destroyAllViews() {
    for (const id in this.roots) {
      this.roots[id].destroy();
      delete this.roots[id];
    }
    this.main = null;
  }

  /** @internal */
  destroyViewByEl(el) {
    const root = this.getRootById(el.getAttribute(PHX_ROOT_ID));
    if (root && root.id === el.id) {
      root.destroy();
      delete this.roots[root.id];
    } else if (root) {
      root.destroyDescendent(el.id);
    }
  }

  /** @internal */
  getActiveElement() {
    return document.activeElement;
  }

  /** @internal */
  dropActiveElement(view) {
    if (this.prevActive && view.ownsElement(this.prevActive)) {
      this.prevActive = null;
    }
  }

  /** @internal */
  restorePreviouslyActiveFocus() {
    if (
      this.prevActive &&
      this.prevActive !== document.body &&
      this.prevActive instanceof HTMLElement
    ) {
      this.prevActive.focus();
    }
  }

  /** @internal */
  blurActiveElement() {
    this.prevActive = this.getActiveElement();
    if (
      this.prevActive !== document.body &&
      this.prevActive instanceof HTMLElement
    ) {
      this.prevActive.blur();
    }
  }

  /** @internal */
  bindTopLevelEvents({ dead }: { dead?: boolean } = {}) {
    if (this.boundTopLevelEvents) {
      return;
    }

    this.boundTopLevelEvents = true;
    // enter failsafe reload if server has gone away intentionally, such as "disconnect" broadcast
    this.serverCloseRef = this.socket.onClose((event) => {
      // failsafe reload if normal closure and we still have a main LV
      if (event && event.code === 1000 && this.main) {
        return this.reloadWithJitter(this.main);
      }
    });
    document.body.addEventListener("click", function () {}); // ensure all click events bubble for mobile Safari
    window.addEventListener(
      "pageshow",
      (e) => {
        if (e.persisted) {
          // reload page if being restored from back/forward cache
          this.getSocket().disconnect();
          this.withPageLoading({ to: window.location.href, kind: "redirect" });
          window.location.reload();
        }
      },
      true,
    );
    if (!dead) {
      this.bindNav();
    }
    this.bindClicks();
    if (!dead) {
      this.bindForms();
    }
    this.bind(
      { keyup: "keyup", keydown: "keydown" },
      (e, type, view, targetEl, phxEvent, _phxTarget) => {
        const matchKey = targetEl.getAttribute(this.binding(PHX_KEY));
        const pressedKey = e.key && e.key.toLowerCase(); // chrome clicked autocompletes send a keydown without key
        if (matchKey && matchKey.toLowerCase() !== pressedKey) {
          return;
        }

        const data = { key: e.key, ...this.eventMeta(type, e, targetEl) };
        JS.exec(e, type, phxEvent, view, targetEl, ["push", { data }]);
      },
    );
    this.bind(
      { blur: "focusout", focus: "focusin" },
      (e, type, view, targetEl, phxEvent, phxTarget) => {
        if (!phxTarget) {
          const data = { ...this.eventMeta(type, e, targetEl) };
          JS.exec(e, type, phxEvent, view, targetEl, ["push", { data }]);
        }
      },
    );
    this.bind(
      { blur: "blur", focus: "focus" },
      (e, type, view, targetEl, phxEvent, phxTarget) => {
        // blur and focus are triggered on document and window. Discard one to avoid dups
        if (phxTarget === "window") {
          const data = this.eventMeta(type, e, targetEl);
          JS.exec(e, type, phxEvent, view, targetEl, ["push", { data }]);
        }
      },
    );
    this.on("dragover", (e) => e.preventDefault());
    this.on("dragenter", (e) => {
      let target = e.target && DOM.elementFromTarget(e.target);
      if (!target) {
        return;
      }
      const dropzone = closestPhxBinding(target, this.binding(PHX_DROP_TARGET));

      if (!dropzone || !(dropzone instanceof HTMLElement)) {
        return;
      }

      if (eventContainsFiles(e)) {
        this.js().addClass(dropzone, PHX_DROP_TARGET_ACTIVE_CLASS);
      }
    });
    this.on("dragleave", (e) => {
      let target = e.target && DOM.elementFromTarget(e.target);
      if (!target) {
        return;
      }
      const dropzone = closestPhxBinding(target, this.binding(PHX_DROP_TARGET));

      if (!dropzone || !(dropzone instanceof HTMLElement)) {
        return;
      }

      // Avoid add/remove jitter in the case that we drag into a new child and that child would
      // resolve their closest drop target to the current dropzone element
      const rect = dropzone.getBoundingClientRect();
      if (
        e.clientX <= rect.left ||
        e.clientX >= rect.right ||
        e.clientY <= rect.top ||
        e.clientY >= rect.bottom
      ) {
        this.js().removeClass(dropzone, PHX_DROP_TARGET_ACTIVE_CLASS);
      }
    });
    this.on("drop", (e) => {
      let target = e.target && DOM.elementFromTarget(e.target);
      if (!target) {
        return;
      }
      e.preventDefault();

      const dropzone = closestPhxBinding(target, this.binding(PHX_DROP_TARGET));
      if (!dropzone || !(dropzone instanceof HTMLElement)) {
        return;
      }
      this.js().removeClass(dropzone, PHX_DROP_TARGET_ACTIVE_CLASS);

      if (!e.dataTransfer) {
        return;
      }

      const dropTargetId = dropzone.getAttribute(this.binding(PHX_DROP_TARGET));
      const dropTarget = dropTargetId && document.getElementById(dropTargetId);
      const files = Array.from(e.dataTransfer.files || []);
      if (
        !dropTarget ||
        !(dropTarget instanceof HTMLInputElement) ||
        dropTarget.disabled ||
        files.length === 0 ||
        !(dropTarget.files instanceof FileList)
      ) {
        return;
      }

      LiveUploader.trackFiles(dropTarget, files, e.dataTransfer);
      dropTarget.dispatchEvent(new Event("input", { bubbles: true }));
    });
    this.on(PHX_TRACK_UPLOADS, (e) => {
      const uploadTarget = e.target && DOM.elementFromTarget(e.target);
      if (!DOM.isUploadInput(uploadTarget)) {
        return;
      }
      const files = Array.from(e.detail.files || []).filter(
        (f) => f instanceof File || f instanceof Blob,
      );
      LiveUploader.trackFiles(uploadTarget as HTMLInputElement, files);
      uploadTarget.dispatchEvent(new Event("input", { bubbles: true }));
    });
  }

  /** @internal */
  eventMeta(eventName, e, targetEl) {
    const callback = this.metadataCallbacks[eventName];
    return callback ? callback(e, targetEl) : {};
  }

  /** @internal */
  setPendingLink(href) {
    this.linkRef++;
    this.pendingLink = href;
    this.resetReloadStatus();
    return this.linkRef;
  }

  /**
   * @internal
   * anytime we are navigating or connecting, drop reload cookie in case
   * we issue the cookie but the next request was interrupted and the server never dropped it
   */
  resetReloadStatus() {
    Browser.deleteCookie(PHX_RELOAD_STATUS);
  }

  /** @internal */
  commitPendingLink(linkRef) {
    if (this.linkRef !== linkRef) {
      return false;
    }
    if (this.pendingLink !== null) {
      this.href = this.pendingLink;
      this.pendingLink = null;
    }
    return true;
  }

  /** @internal */
  getHref() {
    return this.href;
  }

  /** @internal */
  hasPendingLink() {
    return !!this.pendingLink;
  }

  /** @internal */
  bind<E extends Record<string, keyof HTMLElementEventMap>>(
    events: E,
    callback: (
      e: HTMLElementEventMap[E[keyof E]],
      type: keyof E & string,
      view: View,
      targetEl: Element,
      phxEvent: string,
      phxTarget: "window" | null,
    ) => void,
  ) {
    for (const event in events) {
      const browserEventName = events[event];

      this.on(browserEventName, (e) => {
        const binding = this.binding(event);
        const windowBinding = this.binding(`window-${event}`);
        const targetPhxEvent =
          e.target instanceof Element && e.target.getAttribute(binding);
        if (!(e.target instanceof Element)) {
          return;
        }
        if (targetPhxEvent) {
          this.debounce(e.target, e, browserEventName, () => {
            this.withinOwners(e.target, (view) => {
              callback(
                e as HTMLElementEventMap[E[keyof E]],
                event,
                view,
                e.target as Element,
                targetPhxEvent,
                null,
              );
            });
          });
        } else {
          DOM.all(document, `[${windowBinding}]`, (el) => {
            const phxEvent = el.getAttribute(windowBinding)!;
            this.debounce(el, e, browserEventName, () => {
              this.withinOwners(el, (view) => {
                callback(
                  e as HTMLElementEventMap[E[keyof E]],
                  event,
                  view,
                  el as Element,
                  phxEvent,
                  "window",
                );
              });
            });
          });
        }
      });
    }
  }

  /** @internal */
  bindClicks() {
    this.on("mousedown", (e) => (this.clickStartedAtTarget = e.target));
    this.bindClick();
  }

  /** @internal */
  bindClick() {
    const click = this.binding("click");
    window.addEventListener(
      "click",
      (e) => {
        let target = e.target && DOM.elementFromTarget(e.target);
        if (!target) {
          return;
        }
        // a synthetic click event (detail 0) will not have caused a mousedown event,
        // therefore the clickStartedAtTarget is stale
        if (e.detail === 0) this.clickStartedAtTarget = target;
        const clickStartedAtTarget = this.clickStartedAtTarget || target;
        // when searching the target for the click event, we always want to
        // use the actual event target, see #3372
        target = closestPhxBinding(target, click);
        this.dispatchClickAway(e, clickStartedAtTarget);
        this.clickStartedAtTarget = null;

        if (!target) {
          return;
        }

        const phxEvent = target.getAttribute(click);
        if (!phxEvent) {
          if (DOM.isNewPageClick(e, window.location)) {
            this.unload();
          }
          return;
        }

        if (target.getAttribute("href") === "#") {
          e.preventDefault();
        }

        // noop if we are in the middle of awaiting an ack for this el already
        if (target.hasAttribute(PHX_REF_SRC)) {
          return;
        }

        this.debounce(target, e, "click", () => {
          this.withinOwners(target, (view) => {
            JS.exec(e, "click", phxEvent, view, target, [
              "push",
              { data: this.eventMeta("click", e, target) },
            ]);
          });
        });
      },
      false,
    );
  }

  /** @internal */
  dispatchClickAway(e, clickStartedAt) {
    const phxClickAway = this.binding("click-away");
    const portal = clickStartedAt.closest(`[${PHX_TELEPORTED_SRC}]`);
    const portalStartedAt =
      portal && DOM.byId(portal.getAttribute(PHX_TELEPORTED_SRC));
    DOM.all(document, `[${phxClickAway}]`, (el) => {
      let startedAt = clickStartedAt;
      if (portal && !portal.contains(el)) {
        // If we have a portal and the click-away element is not inside it,
        // then treat the portal source as the starting point instead.
        startedAt = portalStartedAt;
      }
      if (
        !(
          el.isSameNode(startedAt) ||
          el.contains(startedAt) ||
          // When clicking a link with custom method,
          // phoenix_html triggers a click on a submit button
          // of a hidden form appended to the body. For such cases
          // where the clicked target is hidden, we skip click-away.
          //
          // Also, when we have a portal, we don't want to check the visibility
          // of the portal source, as it's a <template> that is always not visible.
          // Instead, check the visibility of the original click target.
          !JS.isVisible(clickStartedAt)
        )
      ) {
        this.withinOwners(el, (view) => {
          const phxEvent = el.getAttribute(phxClickAway);
          if (JS.isVisible(el) && JS.isInViewport(el)) {
            JS.exec(e, "click", phxEvent, view, el, [
              "push",
              { data: this.eventMeta("click", e, e.target) },
            ]);
          }
        });
      }
    });
  }

  /** @internal */
  bindNav() {
    if (!Browser.canPushState()) {
      return;
    }
    if (history.scrollRestoration) {
      history.scrollRestoration = "manual";
    }
    let scrollTimer: ReturnType<typeof setTimeout> | null = null;
    window.addEventListener("scroll", (_e) => {
      scrollTimer != null && clearTimeout(scrollTimer);
      scrollTimer = setTimeout(() => {
        Browser.updateCurrentState((state) =>
          Object.assign(state, { scroll: window.scrollY }),
        );
      }, 100);
    });
    window.addEventListener(
      "popstate",
      (event) => {
        if (!this.isNewLocation(window.location)) {
          return;
        }
        const { type, backType, id, scroll, position } = event.state || {};
        const href = window.location.href;

        // Compare positions to determine direction
        const isForward = position > this.currentHistoryPosition;
        const navType = isForward ? type : backType || type;
        const direction = isForward ? "forward" : "backward";
        const detail = {
          href,
          patch: navType === "patch",
          pop: true,
          direction,
        };

        if (!this.dispatchBeforeNavigate(detail)) {
          // Because we only register the new location afterwards,
          // the back / forward popstate event exits early in the isNewLocation check.
          if (isForward) {
            history.back();
          } else {
            history.forward();
          }
          return;
        }

        this.registerNewLocation(window.location);

        // Update current position
        this.currentHistoryPosition = position || 0;
        this.sessionStorage.setItem(
          PHX_LV_HISTORY_POSITION,
          this.currentHistoryPosition.toString(),
        );

        DOM.dispatchEvent(window, "phx:navigate", { detail });
        this.requestDOMUpdate(() => {
          const callback = () => {
            this.maybeScroll(scroll);
          };
          if (
            this.main &&
            this.main.isConnected() &&
            navType === "patch" &&
            id === this.main.id
          ) {
            this.main.pushLinkPatch(event, href, null, callback);
          } else {
            this.replaceMain(href, null, callback);
          }
        });
      },
      false,
    );
    window.addEventListener(
      "click",
      (e) => {
        let el = e.target && DOM.elementFromTarget(e.target);
        if (!el) {
          return;
        }
        const target = closestPhxBinding(
          el,
          PHX_LIVE_LINK,
        ) as HTMLAnchorElement | null;
        const type = target && target.getAttribute(PHX_LIVE_LINK);
        if (!type || !this.isConnected() || !this.main || DOM.wantsNewTab(e)) {
          return;
        }

        // When wrapping an SVG element in an anchor tag, the href can be an SVGAnimatedString
        const href =
          (target.href as unknown) instanceof SVGAnimatedString
            ? (target.href as unknown as SVGAnimatedString).baseVal
            : target.href;

        const linkState = target.getAttribute(PHX_LINK_STATE);
        if (linkState !== "replace" && linkState !== "push") {
          throw new Error(
            `expected ${PHX_LINK_STATE} to be "replace" or "push", got: ${linkState}`,
          );
        }
        if (type !== "patch" && type !== "redirect") {
          throw new Error(
            `expected ${PHX_LIVE_LINK} to be "patch" or "redirect", got: ${type}`,
          );
        }
        e.preventDefault();
        e.stopImmediatePropagation(); // do not bubble click to regular phx-click bindings
        if (this.pendingLink === href) {
          return;
        }

        const detail = {
          href,
          patch: type === "patch",
          pop: false,
          direction: "forward",
        };
        const phxClick = target.getAttribute(this.binding("click"));
        const execPhxClick = () => {
          if (phxClick) {
            this.requestDOMUpdate(() => this.execJS(target, phxClick, "click"));
          }
        };

        if (!this.dispatchBeforeNavigate(detail)) {
          execPhxClick();
          return;
        }

        this.requestDOMUpdate(() => {
          if (type === "patch") {
            this.pushHistoryPatch(e, href, linkState, target);
          } else {
            this.historyRedirect(e, href, linkState, null, target);
          }
          execPhxClick();
        });
      },
      false,
    );
  }

  /** @internal */
  maybeScroll(scroll) {
    if (typeof scroll === "number") {
      requestAnimationFrame(() => {
        window.scrollTo(0, scroll);
      }); // the body needs to render before we scroll.
    }
  }

  /** @internal */
  dispatchEvent(event, payload = {}) {
    DOM.dispatchEvent(window, `phx:${event}`, { detail: payload });
  }

  /** @internal */
  dispatchEvents(events) {
    events.forEach(([event, payload]) => this.dispatchEvent(event, payload));
  }

  /** @internal */
  withPageLoading(info, callback?) {
    DOM.dispatchEvent(window, "phx:page-loading-start", { detail: info });
    const done = () =>
      DOM.dispatchEvent(window, "phx:page-loading-stop", { detail: info });
    return callback ? callback(done) : done;
  }

  /** @internal */
  dispatchBeforeNavigate(detail) {
    return DOM.dispatchEvent(window, "phx:before-navigate", { detail });
  }

  /** @internal */
  pushHistoryPatch(e, href, linkState, targetEl) {
    if (!this.isConnected() || !(this.main && this.main.isMain())) {
      return Browser.redirect(href);
    }

    this.withPageLoading({ to: href, kind: "patch" }, (done) => {
      this.main!.pushLinkPatch(e, href, targetEl, (linkRef) => {
        this.historyPatch(href, linkState, linkRef);
        done();
      });
    });
  }

  /** @internal */
  historyPatch(href, linkState, linkRef = this.setPendingLink(href)) {
    if (!this.commitPendingLink(linkRef)) {
      return;
    }

    // Increment position for new state
    this.currentHistoryPosition++;
    this.sessionStorage.setItem(
      PHX_LV_HISTORY_POSITION,
      this.currentHistoryPosition.toString(),
    );

    // store the type for back navigation
    Browser.updateCurrentState((state) => ({ ...state, backType: "patch" }));

    Browser.pushState(
      linkState,
      {
        type: "patch",
        id: this.main!.id,
        position: this.currentHistoryPosition,
      },
      href,
    );

    DOM.dispatchEvent(window, "phx:navigate", {
      detail: { patch: true, href, pop: false, direction: "forward" },
    });
    this.registerNewLocation(window.location);
  }

  /** @internal */
  historyRedirect(
    e: Event,
    href: string,
    linkState: "replace" | "push",
    flash: string | null,
    targetEl?: Element | null,
  ) {
    const clickLoading = targetEl && e.isTrusted && e.type !== "popstate";
    if (clickLoading) {
      targetEl.classList.add("phx-click-loading");
    }
    if (!this.isConnected() || !(this.main && this.main.isMain())) {
      return Browser.redirect(href, flash);
    }

    // convert to full href if only path prefix
    if (/^\/$|^\/[^\/]+.*$/.test(href)) {
      const { protocol, host } = window.location;
      href = `${protocol}//${host}${href}`;
    }
    const scroll = window.scrollY;
    this.withPageLoading({ to: href, kind: "redirect" }, (done) => {
      this.replaceMain(href, flash, (linkRef) => {
        if (linkRef === this.linkRef) {
          // Increment position for new state
          this.currentHistoryPosition++;
          this.sessionStorage.setItem(
            PHX_LV_HISTORY_POSITION,
            this.currentHistoryPosition.toString(),
          );

          // store the type for back navigation
          Browser.updateCurrentState((state) => ({
            ...state,
            backType: "redirect",
          }));

          Browser.pushState(
            linkState,
            {
              type: "redirect",
              id: this.main!.id,
              scroll: scroll,
              position: this.currentHistoryPosition,
            },
            href,
          );

          DOM.dispatchEvent(window, "phx:navigate", {
            detail: { href, patch: false, pop: false, direction: "forward" },
          });
          this.registerNewLocation(window.location);
        }
        // explicitly undo click-loading class
        // (in case it originated in a sticky live view, otherwise it would be removed anyway)
        if (clickLoading) {
          targetEl.classList.remove("phx-click-loading");
        }
        done();
      });
    });
  }

  /** @internal */
  registerNewLocation(newLocation) {
    if (!this.isNewLocation(newLocation)) {
      return false;
    } else {
      this.currentLocation = clone(newLocation);
      return true;
    }
  }

  /** @internal */
  isNewLocation(newLocation) {
    const { pathname, search } = this.currentLocation;
    if (pathname + search === newLocation.pathname + newLocation.search) {
      return false;
    } else {
      return true;
    }
  }

  /** @internal */
  bindForms() {
    let iterations = 0;
    let externalFormSubmitted = false;

    // disable forms on submit that track phx-change but perform external submit
    this.on("submit", (e) => {
      if (!(e.target instanceof HTMLFormElement)) return;
      const phxSubmit = e.target.getAttribute(this.binding("submit"));
      const phxChange = e.target.getAttribute(this.binding("change"));
      if (!externalFormSubmitted && phxChange && !phxSubmit) {
        externalFormSubmitted = true;
        e.preventDefault();
        this.withinOwners(e.target, (view) => {
          view.disableForm(e.target);
          // safari needs next tick
          window.requestAnimationFrame(() => {
            if (DOM.isUnloadableFormSubmit(e)) {
              this.unload();
            }
            (e.target as HTMLFormElement).submit();
          });
        });
      }
    });

    this.on("submit", (e) => {
      if (!(e.target instanceof HTMLFormElement)) return;
      const phxEvent = e.target.getAttribute(this.binding("submit"));
      if (!phxEvent) {
        if (DOM.isUnloadableFormSubmit(e)) {
          this.unload();
        }
        return;
      }
      e.preventDefault();
      e.target.disabled = true;
      this.withinOwners(e.target, (view) => {
        JS.exec(e, "submit", phxEvent, view, e.target, [
          "push",
          { submitter: e.submitter },
        ]);
      });
    });

    for (const type of ["change" as const, "input" as const]) {
      this.on(type, (e) => {
        if (!DOM.isFormAssociated(e.target)) {
          return;
        }

        if (e instanceof CustomEvent && e.target.form === undefined) {
          // throw on invalid JS.dispatch target and noop if CustomEvent triggered outside JS.dispatch
          if (e.detail && e.detail.dispatcher) {
            throw new Error(
              `dispatching a custom ${type} event is only supported on input elements inside a form`,
            );
          }
          return;
        }

        const input = e.target;
        const phxChange = this.binding("change");
        if (
          this.blockPhxChangeWhileComposing &&
          e instanceof InputEvent &&
          e.isComposing
        ) {
          const key = `composition-listener-${type}`;
          if (!DOM.private(input, key)) {
            DOM.putPrivate(input, key, true);
            input.addEventListener(
              "compositionend",
              () => {
                // trigger a new input/change event
                input.dispatchEvent(new Event(type, { bubbles: true }));
                DOM.deletePrivate(input, key);
              },
              { once: true },
            );
          }
          return;
        }
        const inputEvent = input.getAttribute(phxChange);
        const formEvent = input.form && input.form.getAttribute(phxChange);
        const phxEvent = inputEvent || formEvent;
        if (!phxEvent) {
          return;
        }
        if (
          input.type === "number" &&
          input.validity &&
          input.validity.badInput
        ) {
          return;
        }

        const dispatcher = inputEvent ? input : input.form;
        const currentIterations = iterations;
        iterations++;
        const { at: at, type: lastType } =
          DOM.private(input, "prev-iteration") || {};
        // Browsers should always fire at least one "input" event before every "change"
        // Ignore "change" events, unless there was no prior "input" event.
        // This could happen if user code triggers a "change" event, or if the browser is non-conforming.
        if (
          at === currentIterations - 1 &&
          type === "change" &&
          lastType === "input"
        ) {
          return;
        }

        DOM.putPrivate(input, "prev-iteration", {
          at: currentIterations,
          type: type,
        });

        this.debounce(input, e, type, () => {
          this.withinOwners(dispatcher, (view) => {
            DOM.putPrivate(input, PHX_HAS_FOCUSED, true);
            JS.exec(e, "change", phxEvent, view, input, [
              "push",
              { _target: input.name, dispatcher: dispatcher },
            ]);
          });
        });
      });
    }
    this.on("reset", (e: Event) => {
      const form = e.target as HTMLFormElement;
      DOM.resetForm(form);
      const input = Array.from(form.elements).find(
        (el) => "type" in el && el.type === "reset",
      ) as HTMLInputElement | undefined;
      if (input) {
        // wait until next tick to get updated input value
        window.requestAnimationFrame(() => {
          input.dispatchEvent(
            new Event("input", { bubbles: true, cancelable: false }),
          );
        });
      }
    });
  }

  /** @internal */
  debounce(el, event, eventType, callback) {
    if (eventType === "blur" || eventType === "focusout") {
      return callback();
    }

    const phxDebounce = this.binding(PHX_DEBOUNCE);
    const phxThrottle = this.binding(PHX_THROTTLE);
    const defaultDebounce = this.defaults.debounce.toString();
    const defaultThrottle = this.defaults.throttle.toString();

    this.withinOwners(el, (view) => {
      const asyncFilter = () =>
        !view.isDestroyed() && document.body.contains(el);
      DOM.debounce(
        el,
        event,
        phxDebounce,
        defaultDebounce,
        phxThrottle,
        defaultThrottle,
        asyncFilter,
        () => {
          callback();
        },
      );
    });
  }

  /** @internal */
  silenceEvents(callback) {
    this.silenced = true;
    callback();
    this.silenced = false;
  }

  /** @internal */
  on<K extends string>(
    event: K,
    callback: (
      e: K extends keyof HTMLElementEventMap
        ? HTMLElementEventMap[K]
        : CustomEvent,
    ) => void,
  ) {
    this.boundEventNames.add(event);
    window.addEventListener(event, (e) => {
      if (!this.silenced) {
        callback(e as any);
      }
    });
  }

  /** @internal */
  jsQuerySelectorAll(sourceEl, query, defaultQuery) {
    const all = this.domCallbacks.jsQuerySelectorAll;
    return all ? all(sourceEl, query, defaultQuery) : defaultQuery();
  }
}

class TransitionSet {
  private transitions: Set<ReturnType<typeof setTimeout>>;
  private promises: Set<Promise<any>>;
  private pendingOps: Array<() => void>;

  constructor() {
    this.transitions = new Set();
    this.promises = new Set();
    this.pendingOps = [];
  }

  reset() {
    this.transitions.forEach((timer) => {
      clearTimeout(timer);
      this.transitions.delete(timer);
    });
    this.promises.clear();
    this.flushPendingOps();
  }

  after(callback) {
    if (this.size() === 0) {
      callback();
    } else {
      this.pushPendingOp(callback);
    }
  }

  addTransition(time, onStart, onDone) {
    onStart();
    const timer = setTimeout(() => {
      this.transitions.delete(timer);
      onDone();
      this.flushPendingOps();
    }, time);
    this.transitions.add(timer);
  }

  addAsyncTransition(promise) {
    this.promises.add(promise);
    promise.then(() => {
      this.promises.delete(promise);
      this.flushPendingOps();
    });
  }

  pushPendingOp(op) {
    this.pendingOps.push(op);
  }

  size() {
    return this.transitions.size + this.promises.size;
  }

  flushPendingOps() {
    if (this.size() > 0) {
      return;
    }
    const op = this.pendingOps.shift();
    if (op) {
      op();
      this.flushPendingOps();
    }
  }
}
