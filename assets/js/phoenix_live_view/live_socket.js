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
} from "./constants";

import {
  clone,
  closestPhxBinding,
  closure,
  debug,
  maybe,
  logError,
} from "./utils";

import Browser from "./browser";
import DOM from "./dom";
import Hooks from "./hooks";
import LiveUploader from "./live_uploader";
import View from "./view";
import JS from "./js";
import jsCommands from "./js_commands";

export const isUsedInput = (el) => DOM.isUsedInput(el);

export default class LiveSocket {
  constructor(url, phxSocket, opts = {}) {
    this.unloaded = false;
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
    this.opts = opts;
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
      parseInt(this.sessionStorage.getItem(PHX_LV_HISTORY_POSITION)) || 0;
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

  version() {
    return LV_VSN;
  }

  isProfileEnabled() {
    return this.sessionStorage.getItem(PHX_LV_PROFILE) === "true";
  }

  isDebugEnabled() {
    return this.sessionStorage.getItem(PHX_LV_DEBUG) === "true";
  }

  isDebugDisabled() {
    return this.sessionStorage.getItem(PHX_LV_DEBUG) === "false";
  }

  enableDebug() {
    this.sessionStorage.setItem(PHX_LV_DEBUG, "true");
  }

  enableProfiling() {
    this.sessionStorage.setItem(PHX_LV_PROFILE, "true");
  }

  disableDebug() {
    this.sessionStorage.setItem(PHX_LV_DEBUG, "false");
  }

  disableProfiling() {
    this.sessionStorage.removeItem(PHX_LV_PROFILE);
  }

  enableLatencySim(upperBoundMs) {
    this.enableDebug();
    console.log(
      "latency simulator enabled for the duration of this browser session. Call disableLatencySim() to disable",
    );
    this.sessionStorage.setItem(PHX_LV_LATENCY_SIM, upperBoundMs);
  }

  disableLatencySim() {
    this.sessionStorage.removeItem(PHX_LV_LATENCY_SIM);
  }

  getLatencySim() {
    const str = this.sessionStorage.getItem(PHX_LV_LATENCY_SIM);
    return str ? parseInt(str) : null;
  }

  getSocket() {
    return this.socket;
  }

  connect() {
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

  disconnect(callback) {
    clearTimeout(this.reloadWithJitterTimer);
    // remove the socket close listener to avoid trying to handle
    // a server close event when it is actually caused by us disconnecting
    if (this.serverCloseRef) {
      this.socket.off(this.serverCloseRef);
      this.serverCloseRef = null;
    }
    this.socket.disconnect(callback);
  }

  replaceTransport(transport) {
    clearTimeout(this.reloadWithJitterTimer);
    this.socket.replaceTransport(transport);
    this.connect();
  }

  execJS(el, encodedJS, eventType = null) {
    const e = new CustomEvent("phx:exec", { detail: { sourceElement: el } });
    this.owner(el, (view) => JS.exec(e, eventType, encodedJS, view, el));
  }

  /**
   * Returns an object with methods to manipluate the DOM and execute JavaScript.
   * The applied changes integrate with server DOM patching.
   *
   * @returns {import("./js_commands").LiveSocketJSCommands}
   */
  js() {
    return jsCommands(this, "js");
  }

  // private

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

  triggerDOM(kind, args) {
    this.domCallbacks[kind](...args);
  }

  time(name, func) {
    if (!this.isProfileEnabled() || !console.time) {
      return func();
    }
    console.time(name);
    const result = func();
    console.timeEnd(name);
    return result;
  }

  log(view, kind, msgCallback) {
    if (this.viewLogger) {
      const [msg, obj] = msgCallback();
      this.viewLogger(view, kind, msg, obj);
    } else if (this.isDebugEnabled()) {
      const [msg, obj] = msgCallback();
      debug(view, kind, msg, obj);
    }
  }

  requestDOMUpdate(callback) {
    this.transitions.after(callback);
  }

  asyncTransition(promise) {
    this.transitions.addAsyncTransition(promise);
  }

  transition(time, onStart, onDone = function () {}) {
    this.transitions.addTransition(time, onStart, onDone);
  }

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

  reloadWithJitter(view, log) {
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
      if (this.hasPendingLink()) {
        window.location = this.pendingLink;
      } else {
        window.location.reload();
      }
    }, afterMs);
  }

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

  maybeInternalHook(name) {
    return name && name.startsWith("Phoenix.") && Hooks[name.split(".")[1]];
  }

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

  isUnloaded() {
    return this.unloaded;
  }

  isConnected() {
    return this.socket.isConnected();
  }

  getBindingPrefix() {
    return this.bindingPrefix;
  }

  binding(kind) {
    return `${this.getBindingPrefix()}${kind}`;
  }

  channel(topic, params) {
    return this.socket.channel(topic, params);
  }

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

  redirect(to, flash, reloadToken) {
    if (reloadToken) {
      Browser.setCookie(PHX_RELOAD_STATUS, reloadToken, 60);
    }
    this.unload();
    Browser.redirect(to, flash);
  }

  replaceMain(
    href,
    flash,
    callback = null,
    linkRef = this.setPendingLink(href),
  ) {
    const liveReferer = this.currentLocation.href;
    this.outgoingMainEl = this.outgoingMainEl || this.main.el;

    const stickies = DOM.findPhxSticky(document) || [];
    const removeEls = DOM.all(
      this.outgoingMainEl,
      `[${this.binding("remove")}]`,
    ).filter((el) => !DOM.isChildOfAny(el, stickies));

    const newMainEl = DOM.cloneNode(this.outgoingMainEl, "");
    this.main.showLoader(this.loaderTimeout);
    this.main.destroy();

    this.main = this.newRootView(newMainEl, flash, liveReferer);
    this.main.setRedirect(href);
    this.transitionRemoves(removeEls);
    this.main.join((joinCount, onDone) => {
      if (joinCount === 1 && this.commitPendingLink(linkRef)) {
        this.requestDOMUpdate(() => {
          // remove phx-remove els right before we replace the main element
          removeEls.forEach((el) => el.remove());
          stickies.forEach((el) => newMainEl.appendChild(el));
          this.outgoingMainEl.replaceWith(newMainEl);
          this.outgoingMainEl = null;
          callback && callback(linkRef);
          onDone();
        });
      }
    });
  }

  transitionRemoves(elements, callback) {
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
      this.execJS(el, el.getAttribute(removeAttr), "remove");
    });
    // remove the silenced listeners when transitions are done incase the element is re-used
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

  isPhxView(el) {
    return el.getAttribute && el.getAttribute(PHX_SESSION) !== null;
  }

  newRootView(el, flash, liveReferer) {
    const view = new View(el, this, null, flash, liveReferer);
    this.roots[view.id] = view;
    return view;
  }

  owner(childEl, callback) {
    let view;
    const viewEl = DOM.closestViewEl(childEl);
    if (viewEl) {
      // it can happen that we find a view that is already destroyed;
      // in that case we DO NOT want to fallback to the main element
      view = this.getViewByEl(viewEl);
    } else {
      view = this.main;
    }
    return view && callback ? callback(view) : view;
  }

  withinOwners(childEl, callback) {
    this.owner(childEl, (view) => callback(view, childEl));
  }

  getViewByEl(el) {
    const rootId = el.getAttribute(PHX_ROOT_ID);
    return maybe(this.getRootById(rootId), (root) =>
      root.getDescendentByEl(el),
    );
  }

  getRootById(id) {
    return this.roots[id];
  }

  destroyAllViews() {
    for (const id in this.roots) {
      this.roots[id].destroy();
      delete this.roots[id];
    }
    this.main = null;
  }

  destroyViewByEl(el) {
    const root = this.getRootById(el.getAttribute(PHX_ROOT_ID));
    if (root && root.id === el.id) {
      root.destroy();
      delete this.roots[root.id];
    } else if (root) {
      root.destroyDescendent(el.id);
    }
  }

  getActiveElement() {
    return document.activeElement;
  }

  dropActiveElement(view) {
    if (this.prevActive && view.ownsElement(this.prevActive)) {
      this.prevActive = null;
    }
  }

  restorePreviouslyActiveFocus() {
    if (
      this.prevActive &&
      this.prevActive !== document.body &&
      this.prevActive instanceof HTMLElement
    ) {
      this.prevActive.focus();
    }
  }

  blurActiveElement() {
    this.prevActive = this.getActiveElement();
    if (
      this.prevActive !== document.body &&
      this.prevActive instanceof HTMLElement
    ) {
      this.prevActive.blur();
    }
  }

  /**
   * @param {{dead?: boolean}} [options={}]
   */
  bindTopLevelEvents({ dead } = {}) {
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
          const data = { key: e.key, ...this.eventMeta(type, e, targetEl) };
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
    this.on("drop", (e) => {
      e.preventDefault();
      const dropTargetId = maybe(
        closestPhxBinding(e.target, this.binding(PHX_DROP_TARGET)),
        (trueTarget) => {
          return trueTarget.getAttribute(this.binding(PHX_DROP_TARGET));
        },
      );
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
      const uploadTarget = e.target;
      if (!DOM.isUploadInput(uploadTarget)) {
        return;
      }
      const files = Array.from(e.detail.files || []).filter(
        (f) => f instanceof File || f instanceof Blob,
      );
      LiveUploader.trackFiles(uploadTarget, files);
      uploadTarget.dispatchEvent(new Event("input", { bubbles: true }));
    });
  }

  eventMeta(eventName, e, targetEl) {
    const callback = this.metadataCallbacks[eventName];
    return callback ? callback(e, targetEl) : {};
  }

  setPendingLink(href) {
    this.linkRef++;
    this.pendingLink = href;
    this.resetReloadStatus();
    return this.linkRef;
  }

  // anytime we are navigating or connecting, drop reload cookie in case
  // we issue the cookie but the next request was interrupted and the server never dropped it
  resetReloadStatus() {
    Browser.deleteCookie(PHX_RELOAD_STATUS);
  }

  commitPendingLink(linkRef) {
    if (this.linkRef !== linkRef) {
      return false;
    } else {
      this.href = this.pendingLink;
      this.pendingLink = null;
      return true;
    }
  }

  getHref() {
    return this.href;
  }

  hasPendingLink() {
    return !!this.pendingLink;
  }

  bind(events, callback) {
    for (const event in events) {
      const browserEventName = events[event];

      this.on(browserEventName, (e) => {
        const binding = this.binding(event);
        const windowBinding = this.binding(`window-${event}`);
        const targetPhxEvent =
          e.target.getAttribute && e.target.getAttribute(binding);
        if (targetPhxEvent) {
          this.debounce(e.target, e, browserEventName, () => {
            this.withinOwners(e.target, (view) => {
              callback(e, event, view, e.target, targetPhxEvent, null);
            });
          });
        } else {
          DOM.all(document, `[${windowBinding}]`, (el) => {
            const phxEvent = el.getAttribute(windowBinding);
            this.debounce(el, e, browserEventName, () => {
              this.withinOwners(el, (view) => {
                callback(e, event, view, el, phxEvent, "window");
              });
            });
          });
        }
      });
    }
  }

  bindClicks() {
    this.on("mousedown", (e) => (this.clickStartedAtTarget = e.target));
    this.bindClick("click", "click");
  }

  bindClick(eventName, bindingName) {
    const click = this.binding(bindingName);
    window.addEventListener(
      eventName,
      (e) => {
        let target = null;
        // a synthetic click event (detail 0) will not have caused a mousedown event,
        // therefore the clickStartedAtTarget is stale
        if (e.detail === 0) this.clickStartedAtTarget = e.target;
        const clickStartedAtTarget = this.clickStartedAtTarget || e.target;
        // when searching the target for the click event, we always want to
        // use the actual event target, see #3372
        target = closestPhxBinding(e.target, click);
        this.dispatchClickAway(e, clickStartedAtTarget);
        this.clickStartedAtTarget = null;
        const phxEvent = target && target.getAttribute(click);
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

  dispatchClickAway(e, clickStartedAt) {
    const phxClickAway = this.binding("click-away");
    DOM.all(document, `[${phxClickAway}]`, (el) => {
      if (!(el.isSameNode(clickStartedAt) || el.contains(clickStartedAt))) {
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

  bindNav() {
    if (!Browser.canPushState()) {
      return;
    }
    if (history.scrollRestoration) {
      history.scrollRestoration = "manual";
    }
    let scrollTimer = null;
    window.addEventListener("scroll", (_e) => {
      clearTimeout(scrollTimer);
      scrollTimer = setTimeout(() => {
        Browser.updateCurrentState((state) =>
          Object.assign(state, { scroll: window.scrollY }),
        );
      }, 100);
    });
    window.addEventListener(
      "popstate",
      (event) => {
        if (!this.registerNewLocation(window.location)) {
          return;
        }
        const { type, backType, id, scroll, position } = event.state || {};
        const href = window.location.href;

        // Compare positions to determine direction
        const isForward = position > this.currentHistoryPosition;
        const navType = isForward ? type : backType || type;

        // Update current position
        this.currentHistoryPosition = position || 0;
        this.sessionStorage.setItem(
          PHX_LV_HISTORY_POSITION,
          this.currentHistoryPosition.toString(),
        );

        DOM.dispatchEvent(window, "phx:navigate", {
          detail: {
            href,
            patch: navType === "patch",
            pop: true,
            direction: isForward ? "forward" : "backward",
          },
        });
        this.requestDOMUpdate(() => {
          const callback = () => {
            this.maybeScroll(scroll);
          };
          if (
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
        const target = closestPhxBinding(e.target, PHX_LIVE_LINK);
        const type = target && target.getAttribute(PHX_LIVE_LINK);
        if (!type || !this.isConnected() || !this.main || DOM.wantsNewTab(e)) {
          return;
        }

        // When wrapping an SVG element in an anchor tag, the href can be an SVGAnimatedString
        const href =
          target.href instanceof SVGAnimatedString
            ? target.href.baseVal
            : target.href;

        const linkState = target.getAttribute(PHX_LINK_STATE);
        e.preventDefault();
        e.stopImmediatePropagation(); // do not bubble click to regular phx-click bindings
        if (this.pendingLink === href) {
          return;
        }

        this.requestDOMUpdate(() => {
          if (type === "patch") {
            this.pushHistoryPatch(e, href, linkState, target);
          } else if (type === "redirect") {
            this.historyRedirect(e, href, linkState, null, target);
          } else {
            throw new Error(
              `expected ${PHX_LIVE_LINK} to be "patch" or "redirect", got: ${type}`,
            );
          }
          const phxClick = target.getAttribute(this.binding("click"));
          if (phxClick) {
            this.requestDOMUpdate(() => this.execJS(target, phxClick, "click"));
          }
        });
      },
      false,
    );
  }

  maybeScroll(scroll) {
    if (typeof scroll === "number") {
      requestAnimationFrame(() => {
        window.scrollTo(0, scroll);
      }); // the body needs to render before we scroll.
    }
  }

  dispatchEvent(event, payload = {}) {
    DOM.dispatchEvent(window, `phx:${event}`, { detail: payload });
  }

  dispatchEvents(events) {
    events.forEach(([event, payload]) => this.dispatchEvent(event, payload));
  }

  withPageLoading(info, callback) {
    DOM.dispatchEvent(window, "phx:page-loading-start", { detail: info });
    const done = () =>
      DOM.dispatchEvent(window, "phx:page-loading-stop", { detail: info });
    return callback ? callback(done) : done;
  }

  pushHistoryPatch(e, href, linkState, targetEl) {
    if (!this.isConnected() || !this.main.isMain()) {
      return Browser.redirect(href);
    }

    this.withPageLoading({ to: href, kind: "patch" }, (done) => {
      this.main.pushLinkPatch(e, href, targetEl, (linkRef) => {
        this.historyPatch(href, linkState, linkRef);
        done();
      });
    });
  }

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
        id: this.main.id,
        position: this.currentHistoryPosition,
      },
      href,
    );

    DOM.dispatchEvent(window, "phx:navigate", {
      detail: { patch: true, href, pop: false, direction: "forward" },
    });
    this.registerNewLocation(window.location);
  }

  historyRedirect(e, href, linkState, flash, targetEl) {
    const clickLoading = targetEl && e.isTrusted && e.type !== "popstate";
    if (clickLoading) {
      targetEl.classList.add("phx-click-loading");
    }
    if (!this.isConnected() || !this.main.isMain()) {
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
              id: this.main.id,
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

  registerNewLocation(newLocation) {
    const { pathname, search } = this.currentLocation;
    if (pathname + search === newLocation.pathname + newLocation.search) {
      return false;
    } else {
      this.currentLocation = clone(newLocation);
      return true;
    }
  }

  bindForms() {
    let iterations = 0;
    let externalFormSubmitted = false;

    // disable forms on submit that track phx-change but perform external submit
    this.on("submit", (e) => {
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
            e.target.submit();
          });
        });
      }
    });

    this.on("submit", (e) => {
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

    for (const type of ["change", "input"]) {
      this.on(type, (e) => {
        if (
          e instanceof CustomEvent &&
          (e.target instanceof HTMLInputElement ||
            e.target instanceof HTMLSelectElement ||
            e.target instanceof HTMLTextAreaElement) &&
          e.target.form === undefined
        ) {
          // throw on invalid JS.dispatch target and noop if CustomEvent triggered outside JS.dispatch
          if (e.detail && e.detail.dispatcher) {
            throw new Error(
              `dispatching a custom ${type} event is only supported on input elements inside a form`,
            );
          }
          return;
        }
        const phxChange = this.binding("change");
        const input = e.target;
        if (this.blockPhxChangeWhileComposing && e.isComposing) {
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
              { _target: e.target.name, dispatcher: dispatcher },
            ]);
          });
        });
      });
    }
    this.on("reset", (e) => {
      const form = e.target;
      DOM.resetForm(form);
      const input = Array.from(form.elements).find((el) => el.type === "reset");
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

  silenceEvents(callback) {
    this.silenced = true;
    callback();
    this.silenced = false;
  }

  on(event, callback) {
    this.boundEventNames.add(event);
    window.addEventListener(event, (e) => {
      if (!this.silenced) {
        callback(e);
      }
    });
  }

  jsQuerySelectorAll(sourceEl, query, defaultQuery) {
    const all = this.domCallbacks.jsQuerySelectorAll;
    return all ? all(sourceEl, query, defaultQuery) : defaultQuery();
  }
}

class TransitionSet {
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
