var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

// js/phoenix_live_view/index.ts
var phoenix_live_view_exports = {};
__export(phoenix_live_view_exports, {
  LiveSocket: () => LiveSocket2,
  ViewHook: () => ViewHook,
  createHook: () => createHook,
  isUsedInput: () => isUsedInput
});
module.exports = __toCommonJS(phoenix_live_view_exports);

// js/phoenix_live_view/constants.js
var CONSECUTIVE_RELOADS = "consecutive-reloads";
var MAX_RELOADS = 10;
var RELOAD_JITTER_MIN = 5e3;
var RELOAD_JITTER_MAX = 1e4;
var FAILSAFE_JITTER = 3e4;
var PHX_EVENT_CLASSES = [
  "phx-click-loading",
  "phx-change-loading",
  "phx-submit-loading",
  "phx-keydown-loading",
  "phx-keyup-loading",
  "phx-blur-loading",
  "phx-focus-loading",
  "phx-hook-loading"
];
var PHX_COMPONENT = "data-phx-component";
var PHX_VIEW_REF = "data-phx-view";
var PHX_LIVE_LINK = "data-phx-link";
var PHX_TRACK_STATIC = "track-static";
var PHX_LINK_STATE = "data-phx-link-state";
var PHX_REF_LOADING = "data-phx-ref-loading";
var PHX_REF_SRC = "data-phx-ref-src";
var PHX_REF_LOCK = "data-phx-ref-lock";
var PHX_PENDING_REFS = "phx-pending-refs";
var PHX_TRACK_UPLOADS = "track-uploads";
var PHX_UPLOAD_REF = "data-phx-upload-ref";
var PHX_PREFLIGHTED_REFS = "data-phx-preflighted-refs";
var PHX_DONE_REFS = "data-phx-done-refs";
var PHX_DROP_TARGET = "drop-target";
var PHX_ACTIVE_ENTRY_REFS = "data-phx-active-refs";
var PHX_LIVE_FILE_UPDATED = "phx:live-file:updated";
var PHX_SKIP = "data-phx-skip";
var PHX_MAGIC_ID = "data-phx-id";
var PHX_PRUNE = "data-phx-prune";
var PHX_CONNECTED_CLASS = "phx-connected";
var PHX_LOADING_CLASS = "phx-loading";
var PHX_ERROR_CLASS = "phx-error";
var PHX_CLIENT_ERROR_CLASS = "phx-client-error";
var PHX_SERVER_ERROR_CLASS = "phx-server-error";
var PHX_PARENT_ID = "data-phx-parent-id";
var PHX_MAIN = "data-phx-main";
var PHX_ROOT_ID = "data-phx-root-id";
var PHX_VIEWPORT_TOP = "viewport-top";
var PHX_VIEWPORT_BOTTOM = "viewport-bottom";
var PHX_TRIGGER_ACTION = "trigger-action";
var PHX_HAS_FOCUSED = "phx-has-focused";
var FOCUSABLE_INPUTS = [
  "text",
  "textarea",
  "number",
  "email",
  "password",
  "search",
  "tel",
  "url",
  "date",
  "time",
  "datetime-local",
  "color",
  "range"
];
var CHECKABLE_INPUTS = ["checkbox", "radio"];
var PHX_HAS_SUBMITTED = "phx-has-submitted";
var PHX_SESSION = "data-phx-session";
var PHX_VIEW_SELECTOR = `[${PHX_SESSION}]`;
var PHX_STICKY = "data-phx-sticky";
var PHX_STATIC = "data-phx-static";
var PHX_READONLY = "data-phx-readonly";
var PHX_DISABLED = "data-phx-disabled";
var PHX_DISABLE_WITH = "disable-with";
var PHX_DISABLE_WITH_RESTORE = "data-phx-disable-with-restore";
var PHX_HOOK = "hook";
var PHX_DEBOUNCE = "debounce";
var PHX_THROTTLE = "throttle";
var PHX_UPDATE = "update";
var PHX_STREAM = "stream";
var PHX_STREAM_REF = "data-phx-stream";
var PHX_PORTAL = "data-phx-portal";
var PHX_TELEPORTED_REF = "data-phx-teleported";
var PHX_TELEPORTED_SRC = "data-phx-teleported-src";
var PHX_RUNTIME_HOOK = "data-phx-runtime-hook";
var PHX_LV_PID = "data-phx-pid";
var PHX_KEY = "key";
var PHX_PRIVATE = "phxPrivate";
var PHX_AUTO_RECOVER = "auto-recover";
var PHX_LV_DEBUG = "phx:live-socket:debug";
var PHX_LV_PROFILE = "phx:live-socket:profiling";
var PHX_LV_LATENCY_SIM = "phx:live-socket:latency-sim";
var PHX_LV_HISTORY_POSITION = "phx:nav-history-position";
var PHX_PROGRESS = "progress";
var PHX_MOUNTED = "mounted";
var PHX_RELOAD_STATUS = "__phoenix_reload_status__";
var LOADER_TIMEOUT = 1;
var MAX_CHILD_JOIN_ATTEMPTS = 3;
var BEFORE_UNLOAD_LOADER_TIMEOUT = 200;
var DISCONNECTED_TIMEOUT = 500;
var BINDING_PREFIX = "phx-";
var PUSH_TIMEOUT = 3e4;
var DEBOUNCE_TRIGGER = "debounce-trigger";
var THROTTLED = "throttled";
var DEBOUNCE_PREV_KEY = "debounce-prev-key";
var DEFAULTS = {
  debounce: 300,
  throttle: 300
};
var PHX_PENDING_ATTRS = [PHX_REF_LOADING, PHX_REF_SRC, PHX_REF_LOCK];
var STATIC = "s";
var ROOT = "r";
var COMPONENTS = "c";
var KEYED = "k";
var KEYED_COUNT = "kc";
var EVENTS = "e";
var REPLY = "r";
var TITLE = "t";
var TEMPLATES = "p";
var STREAM = "stream";

// js/phoenix_live_view/entry_uploader.js
var EntryUploader = class {
  constructor(entry, config, liveSocket) {
    const { chunk_size, chunk_timeout } = config;
    this.liveSocket = liveSocket;
    this.entry = entry;
    this.offset = 0;
    this.chunkSize = chunk_size;
    this.chunkTimeout = chunk_timeout;
    this.chunkTimer = null;
    this.errored = false;
    this.uploadChannel = liveSocket.channel(`lvu:${entry.ref}`, {
      token: entry.metadata()
    });
  }
  error(reason) {
    if (this.errored) {
      return;
    }
    this.uploadChannel.leave();
    this.errored = true;
    clearTimeout(this.chunkTimer);
    this.entry.error(reason);
  }
  upload() {
    this.uploadChannel.onError((reason) => this.error(reason));
    this.uploadChannel.join().receive("ok", (_data) => this.readNextChunk()).receive("error", (reason) => this.error(reason));
  }
  isDone() {
    return this.offset >= this.entry.file.size;
  }
  readNextChunk() {
    const reader = new window.FileReader();
    const blob = this.entry.file.slice(
      this.offset,
      this.chunkSize + this.offset
    );
    reader.onload = (e) => {
      if (e.target.error === null) {
        this.offset += /** @type {ArrayBuffer} */
        e.target.result.byteLength;
        this.pushChunk(
          /** @type {ArrayBuffer} */
          e.target.result
        );
      } else {
        return logError("Read error: " + e.target.error);
      }
    };
    reader.readAsArrayBuffer(blob);
  }
  pushChunk(chunk) {
    if (!this.uploadChannel.isJoined()) {
      return;
    }
    this.uploadChannel.push("chunk", chunk, this.chunkTimeout).receive("ok", () => {
      this.entry.progress(this.offset / this.entry.file.size * 100);
      if (!this.isDone()) {
        this.chunkTimer = setTimeout(
          () => this.readNextChunk(),
          this.liveSocket.getLatencySim() || 0
        );
      }
    }).receive("error", ({ reason }) => this.error(reason));
  }
};

// js/phoenix_live_view/utils.js
var logError = (msg, obj) => console.error && console.error(msg, obj);
var isCid = (cid) => {
  const type = typeof cid;
  return type === "number" || type === "string" && /^(0|[1-9]\d*)$/.test(cid);
};
function detectDuplicateIds() {
  const ids = /* @__PURE__ */ new Set();
  const elems = document.querySelectorAll("*[id]");
  for (let i = 0, len = elems.length; i < len; i++) {
    if (ids.has(elems[i].id)) {
      console.error(
        `Multiple IDs detected: ${elems[i].id}. Ensure unique element ids.`
      );
    } else {
      ids.add(elems[i].id);
    }
  }
}
function detectInvalidStreamInserts(inserts) {
  const errors = /* @__PURE__ */ new Set();
  Object.keys(inserts).forEach((id) => {
    const streamEl = document.getElementById(id);
    if (streamEl && streamEl.parentElement && streamEl.parentElement.getAttribute("phx-update") !== "stream") {
      errors.add(
        `The stream container with id "${streamEl.parentElement.id}" is missing the phx-update="stream" attribute. Ensure it is set for streams to work properly.`
      );
    }
  });
  errors.forEach((error) => console.error(error));
}
var debug = (view, kind, msg, obj) => {
  if (view.liveSocket.isDebugEnabled()) {
    console.log(`${view.id} ${kind}: ${msg} - `, obj);
  }
};
var closure = (val) => typeof val === "function" ? val : function() {
  return val;
};
var clone = (obj) => {
  return JSON.parse(JSON.stringify(obj));
};
var closestPhxBinding = (el, binding, borderEl) => {
  do {
    if (el.matches(`[${binding}]`) && !el.disabled) {
      return el;
    }
    el = el.parentElement || el.parentNode;
  } while (el !== null && el.nodeType === 1 && !(borderEl && borderEl.isSameNode(el) || el.matches(PHX_VIEW_SELECTOR)));
  return null;
};
var isObject = (obj) => {
  return obj !== null && typeof obj === "object" && !(obj instanceof Array);
};
var isEqualObj = (obj1, obj2) => JSON.stringify(obj1) === JSON.stringify(obj2);
var isEmpty = (obj) => {
  for (const x in obj) {
    return false;
  }
  return true;
};
var maybe = (el, callback) => el && callback(el);
var channelUploader = function(entries, onError, resp, liveSocket) {
  entries.forEach((entry) => {
    const entryUploader = new EntryUploader(entry, resp.config, liveSocket);
    entryUploader.upload();
  });
};

// js/phoenix_live_view/browser.js
var Browser = {
  canPushState() {
    return typeof history.pushState !== "undefined";
  },
  dropLocal(localStorage, namespace, subkey) {
    return localStorage.removeItem(this.localKey(namespace, subkey));
  },
  updateLocal(localStorage, namespace, subkey, initial, func) {
    const current = this.getLocal(localStorage, namespace, subkey);
    const key = this.localKey(namespace, subkey);
    const newVal = current === null ? initial : func(current);
    localStorage.setItem(key, JSON.stringify(newVal));
    return newVal;
  },
  getLocal(localStorage, namespace, subkey) {
    return JSON.parse(localStorage.getItem(this.localKey(namespace, subkey)));
  },
  updateCurrentState(callback) {
    if (!this.canPushState()) {
      return;
    }
    history.replaceState(
      callback(history.state || {}),
      "",
      window.location.href
    );
  },
  pushState(kind, meta, to) {
    if (this.canPushState()) {
      if (to !== window.location.href) {
        if (meta.type == "redirect" && meta.scroll) {
          const currentState = history.state || {};
          currentState.scroll = meta.scroll;
          history.replaceState(currentState, "", window.location.href);
        }
        delete meta.scroll;
        history[kind + "State"](meta, "", to || null);
        window.requestAnimationFrame(() => {
          const hashEl = this.getHashTargetEl(window.location.hash);
          if (hashEl) {
            hashEl.scrollIntoView();
          } else if (meta.type === "redirect") {
            window.scroll(0, 0);
          }
        });
      }
    } else {
      this.redirect(to);
    }
  },
  setCookie(name, value, maxAgeSeconds) {
    const expires = typeof maxAgeSeconds === "number" ? ` max-age=${maxAgeSeconds};` : "";
    document.cookie = `${name}=${value};${expires} path=/`;
  },
  getCookie(name) {
    return document.cookie.replace(
      new RegExp(`(?:(?:^|.*;s*)${name}s*=s*([^;]*).*$)|^.*$`),
      "$1"
    );
  },
  deleteCookie(name) {
    document.cookie = `${name}=; max-age=-1; path=/`;
  },
  redirect(toURL, flash, navigate = (url) => {
    window.location.href = url;
  }) {
    if (flash) {
      this.setCookie("__phoenix_flash__", flash, 60);
    }
    navigate(toURL);
  },
  localKey(namespace, subkey) {
    return `${namespace}-${subkey}`;
  },
  getHashTargetEl(maybeHash) {
    const hash = maybeHash.toString().substring(1);
    if (hash === "") {
      return;
    }
    return document.getElementById(hash) || document.querySelector(`a[name="${hash}"]`);
  }
};
var browser_default = Browser;

// js/phoenix_live_view/dom.js
var DOM = {
  byId(id) {
    return document.getElementById(id) || logError(`no id found for ${id}`);
  },
  removeClass(el, className) {
    el.classList.remove(className);
    if (el.classList.length === 0) {
      el.removeAttribute("class");
    }
  },
  all(node, query, callback) {
    if (!node) {
      return [];
    }
    const array = Array.from(node.querySelectorAll(query));
    if (callback) {
      array.forEach(callback);
    }
    return array;
  },
  childNodeLength(html) {
    const template = document.createElement("template");
    template.innerHTML = html;
    return template.content.childElementCount;
  },
  isUploadInput(el) {
    return el.type === "file" && el.getAttribute(PHX_UPLOAD_REF) !== null;
  },
  isAutoUpload(inputEl) {
    return inputEl.hasAttribute("data-phx-auto-upload");
  },
  findUploadInputs(node) {
    const formId = node.id;
    const inputsOutsideForm = this.all(
      document,
      `input[type="file"][${PHX_UPLOAD_REF}][form="${formId}"]`
    );
    return this.all(node, `input[type="file"][${PHX_UPLOAD_REF}]`).concat(
      inputsOutsideForm
    );
  },
  findComponentNodeList(viewId, cid, doc2 = document) {
    return this.all(
      doc2,
      `[${PHX_VIEW_REF}="${viewId}"][${PHX_COMPONENT}="${cid}"]`
    );
  },
  isPhxDestroyed(node) {
    return node.id && DOM.private(node, "destroyed") ? true : false;
  },
  wantsNewTab(e) {
    const wantsNewTab = e.ctrlKey || e.shiftKey || e.metaKey || e.button && e.button === 1;
    const isDownload = e.target instanceof HTMLAnchorElement && e.target.hasAttribute("download");
    const isTargetBlank = e.target.hasAttribute("target") && e.target.getAttribute("target").toLowerCase() === "_blank";
    const isTargetNamedTab = e.target.hasAttribute("target") && !e.target.getAttribute("target").startsWith("_");
    return wantsNewTab || isTargetBlank || isDownload || isTargetNamedTab;
  },
  isUnloadableFormSubmit(e) {
    const isDialogSubmit = e.target && e.target.getAttribute("method") === "dialog" || e.submitter && e.submitter.getAttribute("formmethod") === "dialog";
    if (isDialogSubmit) {
      return false;
    } else {
      return !e.defaultPrevented && !this.wantsNewTab(e);
    }
  },
  isNewPageClick(e, currentLocation) {
    const href = e.target instanceof HTMLAnchorElement ? e.target.getAttribute("href") : null;
    let url;
    if (e.defaultPrevented || href === null || this.wantsNewTab(e)) {
      return false;
    }
    if (href.startsWith("mailto:") || href.startsWith("tel:")) {
      return false;
    }
    if (e.target.isContentEditable) {
      return false;
    }
    try {
      url = new URL(href);
    } catch {
      try {
        url = new URL(href, currentLocation);
      } catch {
        return true;
      }
    }
    if (url.host === currentLocation.host && url.protocol === currentLocation.protocol) {
      if (url.pathname === currentLocation.pathname && url.search === currentLocation.search) {
        return url.hash === "" && !url.href.endsWith("#");
      }
    }
    return url.protocol.startsWith("http");
  },
  markPhxChildDestroyed(el) {
    if (this.isPhxChild(el)) {
      el.setAttribute(PHX_SESSION, "");
    }
    this.putPrivate(el, "destroyed", true);
  },
  findPhxChildrenInFragment(html, parentId) {
    const template = document.createElement("template");
    template.innerHTML = html;
    return this.findPhxChildren(template.content, parentId);
  },
  isIgnored(el, phxUpdate) {
    return (el.getAttribute(phxUpdate) || el.getAttribute("data-phx-update")) === "ignore";
  },
  isPhxUpdate(el, phxUpdate, updateTypes) {
    return el.getAttribute && updateTypes.indexOf(el.getAttribute(phxUpdate)) >= 0;
  },
  findPhxSticky(el) {
    return this.all(el, `[${PHX_STICKY}]`);
  },
  findPhxChildren(el, parentId) {
    return this.all(el, `${PHX_VIEW_SELECTOR}[${PHX_PARENT_ID}="${parentId}"]`);
  },
  findExistingParentCIDs(viewId, cids) {
    const parentCids = /* @__PURE__ */ new Set();
    const childrenCids = /* @__PURE__ */ new Set();
    cids.forEach((cid) => {
      this.all(
        document,
        `[${PHX_VIEW_REF}="${viewId}"][${PHX_COMPONENT}="${cid}"]`
      ).forEach((parent) => {
        parentCids.add(cid);
        this.all(parent, `[${PHX_VIEW_REF}="${viewId}"][${PHX_COMPONENT}]`).map((el) => parseInt(el.getAttribute(PHX_COMPONENT))).forEach((childCID) => childrenCids.add(childCID));
      });
    });
    childrenCids.forEach((childCid) => parentCids.delete(childCid));
    return parentCids;
  },
  private(el, key) {
    return el[PHX_PRIVATE] && el[PHX_PRIVATE][key];
  },
  deletePrivate(el, key) {
    el[PHX_PRIVATE] && delete el[PHX_PRIVATE][key];
  },
  putPrivate(el, key, value) {
    if (!el[PHX_PRIVATE]) {
      el[PHX_PRIVATE] = {};
    }
    el[PHX_PRIVATE][key] = value;
  },
  updatePrivate(el, key, defaultVal, updateFunc) {
    const existing = this.private(el, key);
    if (existing === void 0) {
      this.putPrivate(el, key, updateFunc(defaultVal));
    } else {
      this.putPrivate(el, key, updateFunc(existing));
    }
  },
  syncPendingAttrs(fromEl, toEl) {
    if (!fromEl.hasAttribute(PHX_REF_SRC)) {
      return;
    }
    PHX_EVENT_CLASSES.forEach((className) => {
      fromEl.classList.contains(className) && toEl.classList.add(className);
    });
    PHX_PENDING_ATTRS.filter((attr) => fromEl.hasAttribute(attr)).forEach(
      (attr) => {
        toEl.setAttribute(attr, fromEl.getAttribute(attr));
      }
    );
  },
  copyPrivates(target, source) {
    if (source[PHX_PRIVATE]) {
      target[PHX_PRIVATE] = source[PHX_PRIVATE];
    }
  },
  putTitle(str) {
    const titleEl = document.querySelector("title");
    if (titleEl) {
      const { prefix, suffix, default: defaultTitle } = titleEl.dataset;
      const isEmpty2 = typeof str !== "string" || str.trim() === "";
      if (isEmpty2 && typeof defaultTitle !== "string") {
        return;
      }
      const inner = isEmpty2 ? defaultTitle : str;
      document.title = `${prefix || ""}${inner || ""}${suffix || ""}`;
    } else {
      document.title = str;
    }
  },
  debounce(el, event, phxDebounce, defaultDebounce, phxThrottle, defaultThrottle, asyncFilter, callback) {
    let debounce = el.getAttribute(phxDebounce);
    let throttle = el.getAttribute(phxThrottle);
    if (debounce === "") {
      debounce = defaultDebounce;
    }
    if (throttle === "") {
      throttle = defaultThrottle;
    }
    const value = debounce || throttle;
    switch (value) {
      case null:
        return callback();
      case "blur":
        this.incCycle(el, "debounce-blur-cycle", () => {
          if (asyncFilter()) {
            callback();
          }
        });
        if (this.once(el, "debounce-blur")) {
          el.addEventListener(
            "blur",
            () => this.triggerCycle(el, "debounce-blur-cycle")
          );
        }
        return;
      default:
        const timeout = parseInt(value);
        const trigger = () => throttle ? this.deletePrivate(el, THROTTLED) : callback();
        const currentCycle = this.incCycle(el, DEBOUNCE_TRIGGER, trigger);
        if (isNaN(timeout)) {
          return logError(`invalid throttle/debounce value: ${value}`);
        }
        if (throttle) {
          let newKeyDown = false;
          if (event.type === "keydown") {
            const prevKey = this.private(el, DEBOUNCE_PREV_KEY);
            this.putPrivate(el, DEBOUNCE_PREV_KEY, event.key);
            newKeyDown = prevKey !== event.key;
          }
          if (!newKeyDown && this.private(el, THROTTLED)) {
            return false;
          } else {
            callback();
            const t = setTimeout(() => {
              if (asyncFilter()) {
                this.triggerCycle(el, DEBOUNCE_TRIGGER);
              }
            }, timeout);
            this.putPrivate(el, THROTTLED, t);
          }
        } else {
          setTimeout(() => {
            if (asyncFilter()) {
              this.triggerCycle(el, DEBOUNCE_TRIGGER, currentCycle);
            }
          }, timeout);
        }
        const form = el.form;
        if (form && this.once(form, "bind-debounce")) {
          form.addEventListener("submit", () => {
            Array.from(new FormData(form).entries(), ([name]) => {
              const input = form.querySelector(`[name="${name}"]`);
              this.incCycle(input, DEBOUNCE_TRIGGER);
              this.deletePrivate(input, THROTTLED);
            });
          });
        }
        if (this.once(el, "bind-debounce")) {
          el.addEventListener("blur", () => {
            clearTimeout(this.private(el, THROTTLED));
            this.triggerCycle(el, DEBOUNCE_TRIGGER);
          });
        }
    }
  },
  triggerCycle(el, key, currentCycle) {
    const [cycle, trigger] = this.private(el, key);
    if (!currentCycle) {
      currentCycle = cycle;
    }
    if (currentCycle === cycle) {
      this.incCycle(el, key);
      trigger();
    }
  },
  once(el, key) {
    if (this.private(el, key) === true) {
      return false;
    }
    this.putPrivate(el, key, true);
    return true;
  },
  incCycle(el, key, trigger = function() {
  }) {
    let [currentCycle] = this.private(el, key) || [0, trigger];
    currentCycle++;
    this.putPrivate(el, key, [currentCycle, trigger]);
    return currentCycle;
  },
  // maintains or adds privately used hook information
  // fromEl and toEl can be the same element in the case of a newly added node
  // fromEl and toEl can be any HTML node type, so we need to check if it's an element node
  maintainPrivateHooks(fromEl, toEl, phxViewportTop, phxViewportBottom) {
    if (fromEl.hasAttribute && fromEl.hasAttribute("data-phx-hook") && !toEl.hasAttribute("data-phx-hook")) {
      toEl.setAttribute("data-phx-hook", fromEl.getAttribute("data-phx-hook"));
    }
    if (toEl.hasAttribute && (toEl.hasAttribute(phxViewportTop) || toEl.hasAttribute(phxViewportBottom))) {
      toEl.setAttribute("data-phx-hook", "Phoenix.InfiniteScroll");
    }
  },
  putCustomElHook(el, hook) {
    if (el.isConnected) {
      el.setAttribute("data-phx-hook", "");
    } else {
      console.error(`
        hook attached to non-connected DOM element
        ensure you are calling createHook within your connectedCallback. ${el.outerHTML}
      `);
    }
    this.putPrivate(el, "custom-el-hook", hook);
  },
  getCustomElHook(el) {
    return this.private(el, "custom-el-hook");
  },
  isUsedInput(el) {
    return el.nodeType === Node.ELEMENT_NODE && (this.private(el, PHX_HAS_FOCUSED) || this.private(el, PHX_HAS_SUBMITTED));
  },
  resetForm(form) {
    Array.from(form.elements).forEach((input) => {
      this.deletePrivate(input, PHX_HAS_FOCUSED);
      this.deletePrivate(input, PHX_HAS_SUBMITTED);
    });
  },
  isPhxChild(node) {
    return node.getAttribute && node.getAttribute(PHX_PARENT_ID);
  },
  isPhxSticky(node) {
    return node.getAttribute && node.getAttribute(PHX_STICKY) !== null;
  },
  isChildOfAny(el, parents) {
    return !!parents.find((parent) => parent.contains(el));
  },
  firstPhxChild(el) {
    return this.isPhxChild(el) ? el : this.all(el, `[${PHX_PARENT_ID}]`)[0];
  },
  isPortalTemplate(el) {
    return el.tagName === "TEMPLATE" && el.hasAttribute(PHX_PORTAL);
  },
  closestViewEl(el) {
    const portalOrViewEl = el.closest(
      `[${PHX_TELEPORTED_REF}],${PHX_VIEW_SELECTOR}`
    );
    if (!portalOrViewEl) {
      return null;
    }
    if (portalOrViewEl.hasAttribute(PHX_TELEPORTED_REF)) {
      return this.byId(portalOrViewEl.getAttribute(PHX_TELEPORTED_REF));
    } else if (portalOrViewEl.hasAttribute(PHX_SESSION)) {
      return portalOrViewEl;
    }
    return null;
  },
  dispatchEvent(target, name, opts = {}) {
    let defaultBubble = true;
    const isUploadTarget = target.nodeName === "INPUT" && target.type === "file";
    if (isUploadTarget && name === "click") {
      defaultBubble = false;
    }
    const bubbles = opts.bubbles === void 0 ? defaultBubble : !!opts.bubbles;
    const eventOpts = {
      bubbles,
      cancelable: true,
      detail: opts.detail || {}
    };
    const event = name === "click" ? new MouseEvent("click", eventOpts) : new CustomEvent(name, eventOpts);
    target.dispatchEvent(event);
  },
  cloneNode(node, html) {
    if (typeof html === "undefined") {
      return node.cloneNode(true);
    } else {
      const cloned = node.cloneNode(false);
      cloned.innerHTML = html;
      return cloned;
    }
  },
  // merge attributes from source to target
  // if an element is ignored, we only merge data attributes
  // including removing data attributes that are no longer in the source
  mergeAttrs(target, source, opts = {}) {
    const exclude = new Set(opts.exclude || []);
    const isIgnored = opts.isIgnored;
    const sourceAttrs = source.attributes;
    for (let i = sourceAttrs.length - 1; i >= 0; i--) {
      const name = sourceAttrs[i].name;
      if (!exclude.has(name)) {
        const sourceValue = source.getAttribute(name);
        if (target.getAttribute(name) !== sourceValue && (!isIgnored || isIgnored && name.startsWith("data-"))) {
          target.setAttribute(name, sourceValue);
        }
      } else {
        if (name === "value") {
          const sourceValue = source.value ?? source.getAttribute(name);
          if (target.value === sourceValue) {
            target.setAttribute("value", source.getAttribute(name));
          }
        }
      }
    }
    const targetAttrs = target.attributes;
    for (let i = targetAttrs.length - 1; i >= 0; i--) {
      const name = targetAttrs[i].name;
      if (isIgnored) {
        if (name.startsWith("data-") && !source.hasAttribute(name) && !PHX_PENDING_ATTRS.includes(name)) {
          target.removeAttribute(name);
        }
      } else {
        if (!source.hasAttribute(name)) {
          target.removeAttribute(name);
        }
      }
    }
  },
  mergeFocusedInput(target, source) {
    if (!(target instanceof HTMLSelectElement)) {
      DOM.mergeAttrs(target, source, { exclude: ["value"] });
    }
    if (source.readOnly) {
      target.setAttribute("readonly", true);
    } else {
      target.removeAttribute("readonly");
    }
  },
  hasSelectionRange(el) {
    return el.setSelectionRange && (el.type === "text" || el.type === "textarea");
  },
  restoreFocus(focused, selectionStart, selectionEnd) {
    if (focused instanceof HTMLSelectElement) {
      focused.focus();
    }
    if (!DOM.isTextualInput(focused)) {
      return;
    }
    const wasFocused = focused.matches(":focus");
    if (!wasFocused) {
      focused.focus();
    }
    if (this.hasSelectionRange(focused)) {
      focused.setSelectionRange(selectionStart, selectionEnd);
    }
  },
  isFormInput(el) {
    if (el.localName && customElements.get(el.localName)) {
      return customElements.get(el.localName)[`formAssociated`];
    }
    return /^(?:input|select|textarea)$/i.test(el.tagName) && el.type !== "button";
  },
  syncAttrsToProps(el) {
    if (el instanceof HTMLInputElement && CHECKABLE_INPUTS.indexOf(el.type.toLocaleLowerCase()) >= 0) {
      el.checked = el.getAttribute("checked") !== null;
    }
  },
  isTextualInput(el) {
    return FOCUSABLE_INPUTS.indexOf(el.type) >= 0;
  },
  isNowTriggerFormExternal(el, phxTriggerExternal) {
    return el.getAttribute && el.getAttribute(phxTriggerExternal) !== null && document.body.contains(el);
  },
  cleanChildNodes(container, phxUpdate) {
    if (DOM.isPhxUpdate(container, phxUpdate, ["append", "prepend", PHX_STREAM])) {
      const toRemove = [];
      container.childNodes.forEach((childNode) => {
        if (!childNode.id) {
          const isEmptyTextNode = childNode.nodeType === Node.TEXT_NODE && childNode.nodeValue.trim() === "";
          if (!isEmptyTextNode && childNode.nodeType !== Node.COMMENT_NODE) {
            logError(
              `only HTML element tags with an id are allowed inside containers with phx-update.

removing illegal node: "${(childNode.outerHTML || childNode.nodeValue).trim()}"

`
            );
          }
          toRemove.push(childNode);
        }
      });
      toRemove.forEach((childNode) => childNode.remove());
    }
  },
  replaceRootContainer(container, tagName, attrs) {
    const retainedAttrs = /* @__PURE__ */ new Set([
      "id",
      PHX_SESSION,
      PHX_STATIC,
      PHX_MAIN,
      PHX_ROOT_ID
    ]);
    if (container.tagName.toLowerCase() === tagName.toLowerCase()) {
      Array.from(container.attributes).filter((attr) => !retainedAttrs.has(attr.name.toLowerCase())).forEach((attr) => container.removeAttribute(attr.name));
      Object.keys(attrs).filter((name) => !retainedAttrs.has(name.toLowerCase())).forEach((attr) => container.setAttribute(attr, attrs[attr]));
      return container;
    } else {
      const newContainer = document.createElement(tagName);
      Object.keys(attrs).forEach(
        (attr) => newContainer.setAttribute(attr, attrs[attr])
      );
      retainedAttrs.forEach(
        (attr) => newContainer.setAttribute(attr, container.getAttribute(attr))
      );
      newContainer.innerHTML = container.innerHTML;
      container.replaceWith(newContainer);
      return newContainer;
    }
  },
  getSticky(el, name, defaultVal) {
    const op = (DOM.private(el, "sticky") || []).find(
      ([existingName]) => name === existingName
    );
    if (op) {
      const [_name, _op, stashedResult] = op;
      return stashedResult;
    } else {
      return typeof defaultVal === "function" ? defaultVal() : defaultVal;
    }
  },
  deleteSticky(el, name) {
    this.updatePrivate(el, "sticky", [], (ops) => {
      return ops.filter(([existingName, _]) => existingName !== name);
    });
  },
  putSticky(el, name, op) {
    const stashedResult = op(el);
    this.updatePrivate(el, "sticky", [], (ops) => {
      const existingIndex = ops.findIndex(
        ([existingName]) => name === existingName
      );
      if (existingIndex >= 0) {
        ops[existingIndex] = [name, op, stashedResult];
      } else {
        ops.push([name, op, stashedResult]);
      }
      return ops;
    });
  },
  applyStickyOperations(el) {
    const ops = DOM.private(el, "sticky");
    if (!ops) {
      return;
    }
    ops.forEach(([name, op, _stashed]) => this.putSticky(el, name, op));
  },
  isLocked(el) {
    return el.hasAttribute && el.hasAttribute(PHX_REF_LOCK);
  }
};
var dom_default = DOM;

// js/phoenix_live_view/upload_entry.js
var UploadEntry = class {
  static isActive(fileEl, file) {
    const isNew = file._phxRef === void 0;
    const activeRefs = fileEl.getAttribute(PHX_ACTIVE_ENTRY_REFS).split(",");
    const isActive = activeRefs.indexOf(LiveUploader.genFileRef(file)) >= 0;
    return file.size > 0 && (isNew || isActive);
  }
  static isPreflighted(fileEl, file) {
    const preflightedRefs = fileEl.getAttribute(PHX_PREFLIGHTED_REFS).split(",");
    const isPreflighted = preflightedRefs.indexOf(LiveUploader.genFileRef(file)) >= 0;
    return isPreflighted && this.isActive(fileEl, file);
  }
  static isPreflightInProgress(file) {
    return file._preflightInProgress === true;
  }
  static markPreflightInProgress(file) {
    file._preflightInProgress = true;
  }
  constructor(fileEl, file, view, autoUpload) {
    this.ref = LiveUploader.genFileRef(file);
    this.fileEl = fileEl;
    this.file = file;
    this.view = view;
    this.meta = null;
    this._isCancelled = false;
    this._isDone = false;
    this._progress = 0;
    this._lastProgressSent = -1;
    this._onDone = function() {
    };
    this._onElUpdated = this.onElUpdated.bind(this);
    this.fileEl.addEventListener(PHX_LIVE_FILE_UPDATED, this._onElUpdated);
    this.autoUpload = autoUpload;
  }
  metadata() {
    return this.meta;
  }
  progress(progress) {
    this._progress = Math.floor(progress);
    if (this._progress > this._lastProgressSent) {
      if (this._progress >= 100) {
        this._progress = 100;
        this._lastProgressSent = 100;
        this._isDone = true;
        this.view.pushFileProgress(this.fileEl, this.ref, 100, () => {
          LiveUploader.untrackFile(this.fileEl, this.file);
          this._onDone();
        });
      } else {
        this._lastProgressSent = this._progress;
        this.view.pushFileProgress(this.fileEl, this.ref, this._progress);
      }
    }
  }
  isCancelled() {
    return this._isCancelled;
  }
  cancel() {
    this.file._preflightInProgress = false;
    this._isCancelled = true;
    this._isDone = true;
    this._onDone();
  }
  isDone() {
    return this._isDone;
  }
  error(reason = "failed") {
    this.fileEl.removeEventListener(PHX_LIVE_FILE_UPDATED, this._onElUpdated);
    this.view.pushFileProgress(this.fileEl, this.ref, { error: reason });
    if (!this.isAutoUpload()) {
      LiveUploader.clearFiles(this.fileEl);
    }
  }
  isAutoUpload() {
    return this.autoUpload;
  }
  //private
  onDone(callback) {
    this._onDone = () => {
      this.fileEl.removeEventListener(PHX_LIVE_FILE_UPDATED, this._onElUpdated);
      callback();
    };
  }
  onElUpdated() {
    const activeRefs = this.fileEl.getAttribute(PHX_ACTIVE_ENTRY_REFS).split(",");
    if (activeRefs.indexOf(this.ref) === -1) {
      LiveUploader.untrackFile(this.fileEl, this.file);
      this.cancel();
    }
  }
  toPreflightPayload() {
    return {
      last_modified: this.file.lastModified,
      name: this.file.name,
      relative_path: this.file.webkitRelativePath,
      size: this.file.size,
      type: this.file.type,
      ref: this.ref,
      meta: typeof this.file.meta === "function" ? this.file.meta() : void 0
    };
  }
  uploader(uploaders) {
    if (this.meta.uploader) {
      const callback = uploaders[this.meta.uploader] || logError(`no uploader configured for ${this.meta.uploader}`);
      return { name: this.meta.uploader, callback };
    } else {
      return { name: "channel", callback: channelUploader };
    }
  }
  zipPostFlight(resp) {
    this.meta = resp.entries[this.ref];
    if (!this.meta) {
      logError(`no preflight upload response returned with ref ${this.ref}`, {
        input: this.fileEl,
        response: resp
      });
    }
  }
};

// js/phoenix_live_view/live_uploader.js
var liveUploaderFileRef = 0;
var LiveUploader = class _LiveUploader {
  static genFileRef(file) {
    const ref = file._phxRef;
    if (ref !== void 0) {
      return ref;
    } else {
      file._phxRef = (liveUploaderFileRef++).toString();
      return file._phxRef;
    }
  }
  static getEntryDataURL(inputEl, ref, callback) {
    const file = this.activeFiles(inputEl).find(
      (file2) => this.genFileRef(file2) === ref
    );
    callback(URL.createObjectURL(file));
  }
  static hasUploadsInProgress(formEl) {
    let active = 0;
    dom_default.findUploadInputs(formEl).forEach((input) => {
      if (input.getAttribute(PHX_PREFLIGHTED_REFS) !== input.getAttribute(PHX_DONE_REFS)) {
        active++;
      }
    });
    return active > 0;
  }
  static serializeUploads(inputEl) {
    const files = this.activeFiles(inputEl);
    const fileData = {};
    files.forEach((file) => {
      const entry = { path: inputEl.name };
      const uploadRef = inputEl.getAttribute(PHX_UPLOAD_REF);
      fileData[uploadRef] = fileData[uploadRef] || [];
      entry.ref = this.genFileRef(file);
      entry.last_modified = file.lastModified;
      entry.name = file.name || entry.ref;
      entry.relative_path = file.webkitRelativePath;
      entry.type = file.type;
      entry.size = file.size;
      if (typeof file.meta === "function") {
        entry.meta = file.meta();
      }
      fileData[uploadRef].push(entry);
    });
    return fileData;
  }
  static clearFiles(inputEl) {
    inputEl.value = null;
    inputEl.removeAttribute(PHX_UPLOAD_REF);
    dom_default.putPrivate(inputEl, "files", []);
  }
  static untrackFile(inputEl, file) {
    dom_default.putPrivate(
      inputEl,
      "files",
      dom_default.private(inputEl, "files").filter((f) => !Object.is(f, file))
    );
  }
  /**
   * @param {HTMLInputElement} inputEl
   * @param {Array<File|Blob>} files
   * @param {DataTransfer} [dataTransfer]
   */
  static trackFiles(inputEl, files, dataTransfer) {
    if (inputEl.getAttribute("multiple") !== null) {
      const newFiles = files.filter(
        (file) => !this.activeFiles(inputEl).find((f) => Object.is(f, file))
      );
      dom_default.updatePrivate(
        inputEl,
        "files",
        [],
        (existing) => existing.concat(newFiles)
      );
      inputEl.value = null;
    } else {
      if (dataTransfer && dataTransfer.files.length > 0) {
        inputEl.files = dataTransfer.files;
      }
      dom_default.putPrivate(inputEl, "files", files);
    }
  }
  static activeFileInputs(formEl) {
    const fileInputs = dom_default.findUploadInputs(formEl);
    return Array.from(fileInputs).filter(
      (el) => el.files && this.activeFiles(el).length > 0
    );
  }
  static activeFiles(input) {
    return (dom_default.private(input, "files") || []).filter(
      (f) => UploadEntry.isActive(input, f)
    );
  }
  static inputsAwaitingPreflight(formEl) {
    const fileInputs = dom_default.findUploadInputs(formEl);
    return Array.from(fileInputs).filter(
      (input) => this.filesAwaitingPreflight(input).length > 0
    );
  }
  static filesAwaitingPreflight(input) {
    return this.activeFiles(input).filter(
      (f) => !UploadEntry.isPreflighted(input, f) && !UploadEntry.isPreflightInProgress(f)
    );
  }
  static markPreflightInProgress(entries) {
    entries.forEach((entry) => UploadEntry.markPreflightInProgress(entry.file));
  }
  constructor(inputEl, view, onComplete) {
    this.autoUpload = dom_default.isAutoUpload(inputEl);
    this.view = view;
    this.onComplete = onComplete;
    this._entries = Array.from(
      _LiveUploader.filesAwaitingPreflight(inputEl) || []
    ).map((file) => new UploadEntry(inputEl, file, view, this.autoUpload));
    _LiveUploader.markPreflightInProgress(this._entries);
    this.numEntriesInProgress = this._entries.length;
  }
  isAutoUpload() {
    return this.autoUpload;
  }
  entries() {
    return this._entries;
  }
  initAdapterUpload(resp, onError, liveSocket) {
    this._entries = this._entries.map((entry) => {
      if (entry.isCancelled()) {
        this.numEntriesInProgress--;
        if (this.numEntriesInProgress === 0) {
          this.onComplete();
        }
      } else {
        entry.zipPostFlight(resp);
        entry.onDone(() => {
          this.numEntriesInProgress--;
          if (this.numEntriesInProgress === 0) {
            this.onComplete();
          }
        });
      }
      return entry;
    });
    const groupedEntries = this._entries.reduce((acc, entry) => {
      if (!entry.meta) {
        return acc;
      }
      const { name, callback } = entry.uploader(liveSocket.uploaders);
      acc[name] = acc[name] || { callback, entries: [] };
      acc[name].entries.push(entry);
      return acc;
    }, {});
    for (const name in groupedEntries) {
      const { callback, entries } = groupedEntries[name];
      callback(entries, onError, resp, liveSocket);
    }
  }
};

// js/phoenix_live_view/aria.js
var ARIA = {
  anyOf(instance, classes) {
    return classes.find((name) => instance instanceof name);
  },
  isFocusable(el, interactiveOnly) {
    return el instanceof HTMLAnchorElement && el.rel !== "ignore" || el instanceof HTMLAreaElement && el.href !== void 0 || !el.disabled && this.anyOf(el, [
      HTMLInputElement,
      HTMLSelectElement,
      HTMLTextAreaElement,
      HTMLButtonElement
    ]) || el instanceof HTMLIFrameElement || el.tabIndex >= 0 && el.getAttribute("aria-hidden") !== "true" || !interactiveOnly && el.getAttribute("tabindex") !== null && el.getAttribute("aria-hidden") !== "true";
  },
  attemptFocus(el, interactiveOnly) {
    if (this.isFocusable(el, interactiveOnly)) {
      try {
        el.focus();
      } catch {
      }
    }
    return !!document.activeElement && document.activeElement.isSameNode(el);
  },
  focusFirstInteractive(el) {
    let child = el.firstElementChild;
    while (child) {
      if (this.attemptFocus(child, true) || this.focusFirstInteractive(child)) {
        return true;
      }
      child = child.nextElementSibling;
    }
  },
  focusFirst(el) {
    let child = el.firstElementChild;
    while (child) {
      if (this.attemptFocus(child) || this.focusFirst(child)) {
        return true;
      }
      child = child.nextElementSibling;
    }
  },
  focusLast(el) {
    let child = el.lastElementChild;
    while (child) {
      if (this.attemptFocus(child) || this.focusLast(child)) {
        return true;
      }
      child = child.previousElementSibling;
    }
  }
};
var aria_default = ARIA;

// js/phoenix_live_view/hooks.js
var Hooks = {
  LiveFileUpload: {
    activeRefs() {
      return this.el.getAttribute(PHX_ACTIVE_ENTRY_REFS);
    },
    preflightedRefs() {
      return this.el.getAttribute(PHX_PREFLIGHTED_REFS);
    },
    mounted() {
      this.preflightedWas = this.preflightedRefs();
    },
    updated() {
      const newPreflights = this.preflightedRefs();
      if (this.preflightedWas !== newPreflights) {
        this.preflightedWas = newPreflights;
        if (newPreflights === "") {
          this.__view().cancelSubmit(this.el.form);
        }
      }
      if (this.activeRefs() === "") {
        this.el.value = null;
      }
      this.el.dispatchEvent(new CustomEvent(PHX_LIVE_FILE_UPDATED));
    }
  },
  LiveImgPreview: {
    mounted() {
      this.ref = this.el.getAttribute("data-phx-entry-ref");
      this.inputEl = document.getElementById(
        this.el.getAttribute(PHX_UPLOAD_REF)
      );
      LiveUploader.getEntryDataURL(this.inputEl, this.ref, (url) => {
        this.url = url;
        this.el.src = url;
      });
    },
    destroyed() {
      URL.revokeObjectURL(this.url);
    }
  },
  FocusWrap: {
    mounted() {
      this.focusStart = this.el.firstElementChild;
      this.focusEnd = this.el.lastElementChild;
      this.focusStart.addEventListener("focus", (e) => {
        if (!e.relatedTarget || !this.el.contains(e.relatedTarget)) {
          const nextFocus = e.target.nextElementSibling;
          aria_default.attemptFocus(nextFocus) || aria_default.focusFirst(nextFocus);
        } else {
          aria_default.focusLast(this.el);
        }
      });
      this.focusEnd.addEventListener("focus", (e) => {
        if (!e.relatedTarget || !this.el.contains(e.relatedTarget)) {
          const nextFocus = e.target.previousElementSibling;
          aria_default.attemptFocus(nextFocus) || aria_default.focusLast(nextFocus);
        } else {
          aria_default.focusFirst(this.el);
        }
      });
      if (!this.el.contains(document.activeElement)) {
        this.el.addEventListener("phx:show-end", () => this.el.focus());
        if (window.getComputedStyle(this.el).display !== "none") {
          aria_default.focusFirst(this.el);
        }
      }
    }
  }
};
var findScrollContainer = (el) => {
  if (["HTML", "BODY"].indexOf(el.nodeName.toUpperCase()) >= 0)
    return null;
  if (["scroll", "auto"].indexOf(getComputedStyle(el).overflowY) >= 0)
    return el;
  return findScrollContainer(el.parentElement);
};
var scrollTop = (scrollContainer) => {
  if (scrollContainer) {
    return scrollContainer.scrollTop;
  } else {
    return document.documentElement.scrollTop || document.body.scrollTop;
  }
};
var bottom = (scrollContainer) => {
  if (scrollContainer) {
    return scrollContainer.getBoundingClientRect().bottom;
  } else {
    return window.innerHeight || document.documentElement.clientHeight;
  }
};
var top = (scrollContainer) => {
  if (scrollContainer) {
    return scrollContainer.getBoundingClientRect().top;
  } else {
    return 0;
  }
};
var isAtViewportTop = (el, scrollContainer) => {
  const rect = el.getBoundingClientRect();
  return Math.ceil(rect.top) >= top(scrollContainer) && Math.ceil(rect.left) >= 0 && Math.floor(rect.top) <= bottom(scrollContainer);
};
var isAtViewportBottom = (el, scrollContainer) => {
  const rect = el.getBoundingClientRect();
  return Math.ceil(rect.bottom) >= top(scrollContainer) && Math.ceil(rect.left) >= 0 && Math.floor(rect.bottom) <= bottom(scrollContainer);
};
var isWithinViewport = (el, scrollContainer) => {
  const rect = el.getBoundingClientRect();
  return Math.ceil(rect.top) >= top(scrollContainer) && Math.ceil(rect.left) >= 0 && Math.floor(rect.top) <= bottom(scrollContainer);
};
Hooks.InfiniteScroll = {
  mounted() {
    this.scrollContainer = findScrollContainer(this.el);
    let scrollBefore = scrollTop(this.scrollContainer);
    let topOverran = false;
    const throttleInterval = 500;
    let pendingOp = null;
    const onTopOverrun = this.throttle(
      throttleInterval,
      (topEvent, firstChild) => {
        pendingOp = () => true;
        this.liveSocket.js().push(this.el, topEvent, {
          value: { id: firstChild.id, _overran: true },
          callback: () => {
            pendingOp = null;
          }
        });
      }
    );
    const onFirstChildAtTop = this.throttle(
      throttleInterval,
      (topEvent, firstChild) => {
        pendingOp = () => firstChild.scrollIntoView({ block: "start" });
        this.liveSocket.js().push(this.el, topEvent, {
          value: { id: firstChild.id },
          callback: () => {
            pendingOp = null;
            window.requestAnimationFrame(() => {
              if (!isWithinViewport(firstChild, this.scrollContainer)) {
                firstChild.scrollIntoView({ block: "start" });
              }
            });
          }
        });
      }
    );
    const onLastChildAtBottom = this.throttle(
      throttleInterval,
      (bottomEvent, lastChild) => {
        pendingOp = () => lastChild.scrollIntoView({ block: "end" });
        this.liveSocket.js().push(this.el, bottomEvent, {
          value: { id: lastChild.id },
          callback: () => {
            pendingOp = null;
            window.requestAnimationFrame(() => {
              if (!isWithinViewport(lastChild, this.scrollContainer)) {
                lastChild.scrollIntoView({ block: "end" });
              }
            });
          }
        });
      }
    );
    this.onScroll = (_e) => {
      const scrollNow = scrollTop(this.scrollContainer);
      if (pendingOp) {
        scrollBefore = scrollNow;
        return pendingOp();
      }
      const rect = this.el.getBoundingClientRect();
      const topEvent = this.el.getAttribute(
        this.liveSocket.binding("viewport-top")
      );
      const bottomEvent = this.el.getAttribute(
        this.liveSocket.binding("viewport-bottom")
      );
      const lastChild = this.el.lastElementChild;
      const firstChild = this.el.firstElementChild;
      const isScrollingUp = scrollNow < scrollBefore;
      const isScrollingDown = scrollNow > scrollBefore;
      if (isScrollingUp && topEvent && !topOverran && rect.top >= 0) {
        topOverran = true;
        onTopOverrun(topEvent, firstChild);
      } else if (isScrollingDown && topOverran && rect.top <= 0) {
        topOverran = false;
      }
      if (topEvent && isScrollingUp && isAtViewportTop(firstChild, this.scrollContainer)) {
        onFirstChildAtTop(topEvent, firstChild);
      } else if (bottomEvent && isScrollingDown && isAtViewportBottom(lastChild, this.scrollContainer)) {
        onLastChildAtBottom(bottomEvent, lastChild);
      }
      scrollBefore = scrollNow;
    };
    if (this.scrollContainer) {
      this.scrollContainer.addEventListener("scroll", this.onScroll);
    } else {
      window.addEventListener("scroll", this.onScroll);
    }
  },
  destroyed() {
    if (this.scrollContainer) {
      this.scrollContainer.removeEventListener("scroll", this.onScroll);
    } else {
      window.removeEventListener("scroll", this.onScroll);
    }
  },
  throttle(interval, callback) {
    let lastCallAt = 0;
    let timer;
    return (...args) => {
      const now = Date.now();
      const remainingTime = interval - (now - lastCallAt);
      if (remainingTime <= 0 || remainingTime > interval) {
        if (timer) {
          clearTimeout(timer);
          timer = null;
        }
        lastCallAt = now;
        callback(...args);
      } else if (!timer) {
        timer = setTimeout(() => {
          lastCallAt = Date.now();
          timer = null;
          callback(...args);
        }, remainingTime);
      }
    };
  }
};
var hooks_default = Hooks;

// js/phoenix_live_view/element_ref.js
var ElementRef = class {
  static onUnlock(el, callback) {
    if (!dom_default.isLocked(el) && !el.closest(`[${PHX_REF_LOCK}]`)) {
      return callback();
    }
    const closestLock = el.closest(`[${PHX_REF_LOCK}]`);
    const ref = closestLock.closest(`[${PHX_REF_LOCK}]`).getAttribute(PHX_REF_LOCK);
    closestLock.addEventListener(
      `phx:undo-lock:${ref}`,
      () => {
        callback();
      },
      { once: true }
    );
  }
  constructor(el) {
    this.el = el;
    this.loadingRef = el.hasAttribute(PHX_REF_LOADING) ? parseInt(el.getAttribute(PHX_REF_LOADING), 10) : null;
    this.lockRef = el.hasAttribute(PHX_REF_LOCK) ? parseInt(el.getAttribute(PHX_REF_LOCK), 10) : null;
  }
  // public
  maybeUndo(ref, phxEvent, eachCloneCallback) {
    if (!this.isWithin(ref)) {
      dom_default.updatePrivate(this.el, PHX_PENDING_REFS, [], (pendingRefs) => {
        pendingRefs.push(ref);
        return pendingRefs;
      });
      return;
    }
    this.undoLocks(ref, phxEvent, eachCloneCallback);
    this.undoLoading(ref, phxEvent);
    dom_default.updatePrivate(this.el, PHX_PENDING_REFS, [], (pendingRefs) => {
      return pendingRefs.filter((pendingRef) => {
        let opts = {
          detail: { ref: pendingRef, event: phxEvent },
          bubbles: true,
          cancelable: false
        };
        if (this.loadingRef && this.loadingRef > pendingRef) {
          this.el.dispatchEvent(
            new CustomEvent(`phx:undo-loading:${pendingRef}`, opts)
          );
        }
        if (this.lockRef && this.lockRef > pendingRef) {
          this.el.dispatchEvent(
            new CustomEvent(`phx:undo-lock:${pendingRef}`, opts)
          );
        }
        return pendingRef > ref;
      });
    });
    if (this.isFullyResolvedBy(ref)) {
      this.el.removeAttribute(PHX_REF_SRC);
    }
  }
  // private
  isWithin(ref) {
    return !(this.loadingRef !== null && this.loadingRef > ref && this.lockRef !== null && this.lockRef > ref);
  }
  // Check for cloned PHX_REF_LOCK element that has been morphed behind
  // the scenes while this element was locked in the DOM.
  // When we apply the cloned tree to the active DOM element, we must
  //
  //   1. execute pending mounted hooks for nodes now in the DOM
  //   2. undo any ref inside the cloned tree that has since been ack'd
  undoLocks(ref, phxEvent, eachCloneCallback) {
    if (!this.isLockUndoneBy(ref)) {
      return;
    }
    const clonedTree = dom_default.private(this.el, PHX_REF_LOCK);
    if (clonedTree) {
      eachCloneCallback(clonedTree);
      dom_default.deletePrivate(this.el, PHX_REF_LOCK);
    }
    this.el.removeAttribute(PHX_REF_LOCK);
    const opts = {
      detail: { ref, event: phxEvent },
      bubbles: true,
      cancelable: false
    };
    this.el.dispatchEvent(
      new CustomEvent(`phx:undo-lock:${this.lockRef}`, opts)
    );
  }
  undoLoading(ref, phxEvent) {
    if (!this.isLoadingUndoneBy(ref)) {
      if (this.canUndoLoading(ref) && this.el.classList.contains("phx-submit-loading")) {
        this.el.classList.remove("phx-change-loading");
      }
      return;
    }
    if (this.canUndoLoading(ref)) {
      this.el.removeAttribute(PHX_REF_LOADING);
      const disabledVal = this.el.getAttribute(PHX_DISABLED);
      const readOnlyVal = this.el.getAttribute(PHX_READONLY);
      if (readOnlyVal !== null) {
        this.el.readOnly = readOnlyVal === "true" ? true : false;
        this.el.removeAttribute(PHX_READONLY);
      }
      if (disabledVal !== null) {
        this.el.disabled = disabledVal === "true" ? true : false;
        this.el.removeAttribute(PHX_DISABLED);
      }
      const disableRestore = this.el.getAttribute(PHX_DISABLE_WITH_RESTORE);
      if (disableRestore !== null) {
        this.el.innerText = disableRestore;
        this.el.removeAttribute(PHX_DISABLE_WITH_RESTORE);
      }
      const opts = {
        detail: { ref, event: phxEvent },
        bubbles: true,
        cancelable: false
      };
      this.el.dispatchEvent(
        new CustomEvent(`phx:undo-loading:${this.loadingRef}`, opts)
      );
    }
    PHX_EVENT_CLASSES.forEach((name) => {
      if (name !== "phx-submit-loading" || this.canUndoLoading(ref)) {
        dom_default.removeClass(this.el, name);
      }
    });
  }
  isLoadingUndoneBy(ref) {
    return this.loadingRef === null ? false : this.loadingRef <= ref;
  }
  isLockUndoneBy(ref) {
    return this.lockRef === null ? false : this.lockRef <= ref;
  }
  isFullyResolvedBy(ref) {
    return (this.loadingRef === null || this.loadingRef <= ref) && (this.lockRef === null || this.lockRef <= ref);
  }
  // only remove the phx-submit-loading class if we are not locked
  canUndoLoading(ref) {
    return this.lockRef === null || this.lockRef <= ref;
  }
};

// js/phoenix_live_view/dom_post_morph_restorer.js
var DOMPostMorphRestorer = class {
  constructor(containerBefore, containerAfter, updateType) {
    const idsBefore = /* @__PURE__ */ new Set();
    const idsAfter = new Set(
      [...containerAfter.children].map((child) => child.id)
    );
    const elementsToModify = [];
    Array.from(containerBefore.children).forEach((child) => {
      if (child.id) {
        idsBefore.add(child.id);
        if (idsAfter.has(child.id)) {
          const previousElementId = child.previousElementSibling && child.previousElementSibling.id;
          elementsToModify.push({
            elementId: child.id,
            previousElementId
          });
        }
      }
    });
    this.containerId = containerAfter.id;
    this.updateType = updateType;
    this.elementsToModify = elementsToModify;
    this.elementIdsToAdd = [...idsAfter].filter((id) => !idsBefore.has(id));
  }
  // We do the following to optimize append/prepend operations:
  //   1) Track ids of modified elements & of new elements
  //   2) All the modified elements are put back in the correct position in the DOM tree
  //      by storing the id of their previous sibling
  //   3) New elements are going to be put in the right place by morphdom during append.
  //      For prepend, we move them to the first position in the container
  perform() {
    const container = dom_default.byId(this.containerId);
    if (!container) {
      return;
    }
    this.elementsToModify.forEach((elementToModify) => {
      if (elementToModify.previousElementId) {
        maybe(
          document.getElementById(elementToModify.previousElementId),
          (previousElem) => {
            maybe(
              document.getElementById(elementToModify.elementId),
              (elem) => {
                const isInRightPlace = elem.previousElementSibling && elem.previousElementSibling.id == previousElem.id;
                if (!isInRightPlace) {
                  previousElem.insertAdjacentElement("afterend", elem);
                }
              }
            );
          }
        );
      } else {
        maybe(document.getElementById(elementToModify.elementId), (elem) => {
          const isInRightPlace = elem.previousElementSibling == null;
          if (!isInRightPlace) {
            container.insertAdjacentElement("afterbegin", elem);
          }
        });
      }
    });
    if (this.updateType == "prepend") {
      this.elementIdsToAdd.reverse().forEach((elemId) => {
        maybe(
          document.getElementById(elemId),
          (elem) => container.insertAdjacentElement("afterbegin", elem)
        );
      });
    }
  }
};

// ../node_modules/morphdom/dist/morphdom-esm.js
var DOCUMENT_FRAGMENT_NODE = 11;
function morphAttrs(fromNode, toNode) {
  var toNodeAttrs = toNode.attributes;
  var attr;
  var attrName;
  var attrNamespaceURI;
  var attrValue;
  var fromValue;
  if (toNode.nodeType === DOCUMENT_FRAGMENT_NODE || fromNode.nodeType === DOCUMENT_FRAGMENT_NODE) {
    return;
  }
  for (var i = toNodeAttrs.length - 1; i >= 0; i--) {
    attr = toNodeAttrs[i];
    attrName = attr.name;
    attrNamespaceURI = attr.namespaceURI;
    attrValue = attr.value;
    if (attrNamespaceURI) {
      attrName = attr.localName || attrName;
      fromValue = fromNode.getAttributeNS(attrNamespaceURI, attrName);
      if (fromValue !== attrValue) {
        if (attr.prefix === "xmlns") {
          attrName = attr.name;
        }
        fromNode.setAttributeNS(attrNamespaceURI, attrName, attrValue);
      }
    } else {
      fromValue = fromNode.getAttribute(attrName);
      if (fromValue !== attrValue) {
        fromNode.setAttribute(attrName, attrValue);
      }
    }
  }
  var fromNodeAttrs = fromNode.attributes;
  for (var d = fromNodeAttrs.length - 1; d >= 0; d--) {
    attr = fromNodeAttrs[d];
    attrName = attr.name;
    attrNamespaceURI = attr.namespaceURI;
    if (attrNamespaceURI) {
      attrName = attr.localName || attrName;
      if (!toNode.hasAttributeNS(attrNamespaceURI, attrName)) {
        fromNode.removeAttributeNS(attrNamespaceURI, attrName);
      }
    } else {
      if (!toNode.hasAttribute(attrName)) {
        fromNode.removeAttribute(attrName);
      }
    }
  }
}
var range;
var NS_XHTML = "http://www.w3.org/1999/xhtml";
var doc = typeof document === "undefined" ? void 0 : document;
var HAS_TEMPLATE_SUPPORT = !!doc && "content" in doc.createElement("template");
var HAS_RANGE_SUPPORT = !!doc && doc.createRange && "createContextualFragment" in doc.createRange();
function createFragmentFromTemplate(str) {
  var template = doc.createElement("template");
  template.innerHTML = str;
  return template.content.childNodes[0];
}
function createFragmentFromRange(str) {
  if (!range) {
    range = doc.createRange();
    range.selectNode(doc.body);
  }
  var fragment = range.createContextualFragment(str);
  return fragment.childNodes[0];
}
function createFragmentFromWrap(str) {
  var fragment = doc.createElement("body");
  fragment.innerHTML = str;
  return fragment.childNodes[0];
}
function toElement(str) {
  str = str.trim();
  if (HAS_TEMPLATE_SUPPORT) {
    return createFragmentFromTemplate(str);
  } else if (HAS_RANGE_SUPPORT) {
    return createFragmentFromRange(str);
  }
  return createFragmentFromWrap(str);
}
function compareNodeNames(fromEl, toEl) {
  var fromNodeName = fromEl.nodeName;
  var toNodeName = toEl.nodeName;
  var fromCodeStart, toCodeStart;
  if (fromNodeName === toNodeName) {
    return true;
  }
  fromCodeStart = fromNodeName.charCodeAt(0);
  toCodeStart = toNodeName.charCodeAt(0);
  if (fromCodeStart <= 90 && toCodeStart >= 97) {
    return fromNodeName === toNodeName.toUpperCase();
  } else if (toCodeStart <= 90 && fromCodeStart >= 97) {
    return toNodeName === fromNodeName.toUpperCase();
  } else {
    return false;
  }
}
function createElementNS(name, namespaceURI) {
  return !namespaceURI || namespaceURI === NS_XHTML ? doc.createElement(name) : doc.createElementNS(namespaceURI, name);
}
function moveChildren(fromEl, toEl) {
  var curChild = fromEl.firstChild;
  while (curChild) {
    var nextChild = curChild.nextSibling;
    toEl.appendChild(curChild);
    curChild = nextChild;
  }
  return toEl;
}
function syncBooleanAttrProp(fromEl, toEl, name) {
  if (fromEl[name] !== toEl[name]) {
    fromEl[name] = toEl[name];
    if (fromEl[name]) {
      fromEl.setAttribute(name, "");
    } else {
      fromEl.removeAttribute(name);
    }
  }
}
var specialElHandlers = {
  OPTION: function(fromEl, toEl) {
    var parentNode = fromEl.parentNode;
    if (parentNode) {
      var parentName = parentNode.nodeName.toUpperCase();
      if (parentName === "OPTGROUP") {
        parentNode = parentNode.parentNode;
        parentName = parentNode && parentNode.nodeName.toUpperCase();
      }
      if (parentName === "SELECT" && !parentNode.hasAttribute("multiple")) {
        if (fromEl.hasAttribute("selected") && !toEl.selected) {
          fromEl.setAttribute("selected", "selected");
          fromEl.removeAttribute("selected");
        }
        parentNode.selectedIndex = -1;
      }
    }
    syncBooleanAttrProp(fromEl, toEl, "selected");
  },
  /**
   * The "value" attribute is special for the <input> element since it sets
   * the initial value. Changing the "value" attribute without changing the
   * "value" property will have no effect since it is only used to the set the
   * initial value.  Similar for the "checked" attribute, and "disabled".
   */
  INPUT: function(fromEl, toEl) {
    syncBooleanAttrProp(fromEl, toEl, "checked");
    syncBooleanAttrProp(fromEl, toEl, "disabled");
    if (fromEl.value !== toEl.value) {
      fromEl.value = toEl.value;
    }
    if (!toEl.hasAttribute("value")) {
      fromEl.removeAttribute("value");
    }
  },
  TEXTAREA: function(fromEl, toEl) {
    var newValue = toEl.value;
    if (fromEl.value !== newValue) {
      fromEl.value = newValue;
    }
    var firstChild = fromEl.firstChild;
    if (firstChild) {
      var oldValue = firstChild.nodeValue;
      if (oldValue == newValue || !newValue && oldValue == fromEl.placeholder) {
        return;
      }
      firstChild.nodeValue = newValue;
    }
  },
  SELECT: function(fromEl, toEl) {
    if (!toEl.hasAttribute("multiple")) {
      var selectedIndex = -1;
      var i = 0;
      var curChild = fromEl.firstChild;
      var optgroup;
      var nodeName;
      while (curChild) {
        nodeName = curChild.nodeName && curChild.nodeName.toUpperCase();
        if (nodeName === "OPTGROUP") {
          optgroup = curChild;
          curChild = optgroup.firstChild;
          if (!curChild) {
            curChild = optgroup.nextSibling;
            optgroup = null;
          }
        } else {
          if (nodeName === "OPTION") {
            if (curChild.hasAttribute("selected")) {
              selectedIndex = i;
              break;
            }
            i++;
          }
          curChild = curChild.nextSibling;
          if (!curChild && optgroup) {
            curChild = optgroup.nextSibling;
            optgroup = null;
          }
        }
      }
      fromEl.selectedIndex = selectedIndex;
    }
  }
};
var ELEMENT_NODE = 1;
var DOCUMENT_FRAGMENT_NODE$1 = 11;
var TEXT_NODE = 3;
var COMMENT_NODE = 8;
function noop() {
}
function defaultGetNodeKey(node) {
  if (node) {
    return node.getAttribute && node.getAttribute("id") || node.id;
  }
}
function morphdomFactory(morphAttrs2) {
  return function morphdom2(fromNode, toNode, options) {
    if (!options) {
      options = {};
    }
    if (typeof toNode === "string") {
      if (fromNode.nodeName === "#document" || fromNode.nodeName === "HTML" || fromNode.nodeName === "BODY") {
        var toNodeHtml = toNode;
        toNode = doc.createElement("html");
        toNode.innerHTML = toNodeHtml;
      } else {
        toNode = toElement(toNode);
      }
    } else if (toNode.nodeType === DOCUMENT_FRAGMENT_NODE$1) {
      toNode = toNode.firstElementChild;
    }
    var getNodeKey = options.getNodeKey || defaultGetNodeKey;
    var onBeforeNodeAdded = options.onBeforeNodeAdded || noop;
    var onNodeAdded = options.onNodeAdded || noop;
    var onBeforeElUpdated = options.onBeforeElUpdated || noop;
    var onElUpdated = options.onElUpdated || noop;
    var onBeforeNodeDiscarded = options.onBeforeNodeDiscarded || noop;
    var onNodeDiscarded = options.onNodeDiscarded || noop;
    var onBeforeElChildrenUpdated = options.onBeforeElChildrenUpdated || noop;
    var skipFromChildren = options.skipFromChildren || noop;
    var addChild = options.addChild || function(parent, child) {
      return parent.appendChild(child);
    };
    var childrenOnly = options.childrenOnly === true;
    var fromNodesLookup = /* @__PURE__ */ Object.create(null);
    var keyedRemovalList = [];
    function addKeyedRemoval(key) {
      keyedRemovalList.push(key);
    }
    function walkDiscardedChildNodes(node, skipKeyedNodes) {
      if (node.nodeType === ELEMENT_NODE) {
        var curChild = node.firstChild;
        while (curChild) {
          var key = void 0;
          if (skipKeyedNodes && (key = getNodeKey(curChild))) {
            addKeyedRemoval(key);
          } else {
            onNodeDiscarded(curChild);
            if (curChild.firstChild) {
              walkDiscardedChildNodes(curChild, skipKeyedNodes);
            }
          }
          curChild = curChild.nextSibling;
        }
      }
    }
    function removeNode(node, parentNode, skipKeyedNodes) {
      if (onBeforeNodeDiscarded(node) === false) {
        return;
      }
      if (parentNode) {
        parentNode.removeChild(node);
      }
      onNodeDiscarded(node);
      walkDiscardedChildNodes(node, skipKeyedNodes);
    }
    function indexTree(node) {
      if (node.nodeType === ELEMENT_NODE || node.nodeType === DOCUMENT_FRAGMENT_NODE$1) {
        var curChild = node.firstChild;
        while (curChild) {
          var key = getNodeKey(curChild);
          if (key) {
            fromNodesLookup[key] = curChild;
          }
          indexTree(curChild);
          curChild = curChild.nextSibling;
        }
      }
    }
    indexTree(fromNode);
    function handleNodeAdded(el) {
      onNodeAdded(el);
      var curChild = el.firstChild;
      while (curChild) {
        var nextSibling = curChild.nextSibling;
        var key = getNodeKey(curChild);
        if (key) {
          var unmatchedFromEl = fromNodesLookup[key];
          if (unmatchedFromEl && compareNodeNames(curChild, unmatchedFromEl)) {
            curChild.parentNode.replaceChild(unmatchedFromEl, curChild);
            morphEl(unmatchedFromEl, curChild);
          } else {
            handleNodeAdded(curChild);
          }
        } else {
          handleNodeAdded(curChild);
        }
        curChild = nextSibling;
      }
    }
    function cleanupFromEl(fromEl, curFromNodeChild, curFromNodeKey) {
      while (curFromNodeChild) {
        var fromNextSibling = curFromNodeChild.nextSibling;
        if (curFromNodeKey = getNodeKey(curFromNodeChild)) {
          addKeyedRemoval(curFromNodeKey);
        } else {
          removeNode(
            curFromNodeChild,
            fromEl,
            true
            /* skip keyed nodes */
          );
        }
        curFromNodeChild = fromNextSibling;
      }
    }
    function morphEl(fromEl, toEl, childrenOnly2) {
      var toElKey = getNodeKey(toEl);
      if (toElKey) {
        delete fromNodesLookup[toElKey];
      }
      if (!childrenOnly2) {
        var beforeUpdateResult = onBeforeElUpdated(fromEl, toEl);
        if (beforeUpdateResult === false) {
          return;
        } else if (beforeUpdateResult instanceof HTMLElement) {
          fromEl = beforeUpdateResult;
          indexTree(fromEl);
        }
        morphAttrs2(fromEl, toEl);
        onElUpdated(fromEl);
        if (onBeforeElChildrenUpdated(fromEl, toEl) === false) {
          return;
        }
      }
      if (fromEl.nodeName !== "TEXTAREA") {
        morphChildren(fromEl, toEl);
      } else {
        specialElHandlers.TEXTAREA(fromEl, toEl);
      }
    }
    function morphChildren(fromEl, toEl) {
      var skipFrom = skipFromChildren(fromEl, toEl);
      var curToNodeChild = toEl.firstChild;
      var curFromNodeChild = fromEl.firstChild;
      var curToNodeKey;
      var curFromNodeKey;
      var fromNextSibling;
      var toNextSibling;
      var matchingFromEl;
      outer:
        while (curToNodeChild) {
          toNextSibling = curToNodeChild.nextSibling;
          curToNodeKey = getNodeKey(curToNodeChild);
          while (!skipFrom && curFromNodeChild) {
            fromNextSibling = curFromNodeChild.nextSibling;
            if (curToNodeChild.isSameNode && curToNodeChild.isSameNode(curFromNodeChild)) {
              curToNodeChild = toNextSibling;
              curFromNodeChild = fromNextSibling;
              continue outer;
            }
            curFromNodeKey = getNodeKey(curFromNodeChild);
            var curFromNodeType = curFromNodeChild.nodeType;
            var isCompatible = void 0;
            if (curFromNodeType === curToNodeChild.nodeType) {
              if (curFromNodeType === ELEMENT_NODE) {
                if (curToNodeKey) {
                  if (curToNodeKey !== curFromNodeKey) {
                    if (matchingFromEl = fromNodesLookup[curToNodeKey]) {
                      if (fromNextSibling === matchingFromEl) {
                        isCompatible = false;
                      } else {
                        fromEl.insertBefore(matchingFromEl, curFromNodeChild);
                        if (curFromNodeKey) {
                          addKeyedRemoval(curFromNodeKey);
                        } else {
                          removeNode(
                            curFromNodeChild,
                            fromEl,
                            true
                            /* skip keyed nodes */
                          );
                        }
                        curFromNodeChild = matchingFromEl;
                        curFromNodeKey = getNodeKey(curFromNodeChild);
                      }
                    } else {
                      isCompatible = false;
                    }
                  }
                } else if (curFromNodeKey) {
                  isCompatible = false;
                }
                isCompatible = isCompatible !== false && compareNodeNames(curFromNodeChild, curToNodeChild);
                if (isCompatible) {
                  morphEl(curFromNodeChild, curToNodeChild);
                }
              } else if (curFromNodeType === TEXT_NODE || curFromNodeType == COMMENT_NODE) {
                isCompatible = true;
                if (curFromNodeChild.nodeValue !== curToNodeChild.nodeValue) {
                  curFromNodeChild.nodeValue = curToNodeChild.nodeValue;
                }
              }
            }
            if (isCompatible) {
              curToNodeChild = toNextSibling;
              curFromNodeChild = fromNextSibling;
              continue outer;
            }
            if (curFromNodeKey) {
              addKeyedRemoval(curFromNodeKey);
            } else {
              removeNode(
                curFromNodeChild,
                fromEl,
                true
                /* skip keyed nodes */
              );
            }
            curFromNodeChild = fromNextSibling;
          }
          if (curToNodeKey && (matchingFromEl = fromNodesLookup[curToNodeKey]) && compareNodeNames(matchingFromEl, curToNodeChild)) {
            if (!skipFrom) {
              addChild(fromEl, matchingFromEl);
            }
            morphEl(matchingFromEl, curToNodeChild);
          } else {
            var onBeforeNodeAddedResult = onBeforeNodeAdded(curToNodeChild);
            if (onBeforeNodeAddedResult !== false) {
              if (onBeforeNodeAddedResult) {
                curToNodeChild = onBeforeNodeAddedResult;
              }
              if (curToNodeChild.actualize) {
                curToNodeChild = curToNodeChild.actualize(fromEl.ownerDocument || doc);
              }
              addChild(fromEl, curToNodeChild);
              handleNodeAdded(curToNodeChild);
            }
          }
          curToNodeChild = toNextSibling;
          curFromNodeChild = fromNextSibling;
        }
      cleanupFromEl(fromEl, curFromNodeChild, curFromNodeKey);
      var specialElHandler = specialElHandlers[fromEl.nodeName];
      if (specialElHandler) {
        specialElHandler(fromEl, toEl);
      }
    }
    var morphedNode = fromNode;
    var morphedNodeType = morphedNode.nodeType;
    var toNodeType = toNode.nodeType;
    if (!childrenOnly) {
      if (morphedNodeType === ELEMENT_NODE) {
        if (toNodeType === ELEMENT_NODE) {
          if (!compareNodeNames(fromNode, toNode)) {
            onNodeDiscarded(fromNode);
            morphedNode = moveChildren(fromNode, createElementNS(toNode.nodeName, toNode.namespaceURI));
          }
        } else {
          morphedNode = toNode;
        }
      } else if (morphedNodeType === TEXT_NODE || morphedNodeType === COMMENT_NODE) {
        if (toNodeType === morphedNodeType) {
          if (morphedNode.nodeValue !== toNode.nodeValue) {
            morphedNode.nodeValue = toNode.nodeValue;
          }
          return morphedNode;
        } else {
          morphedNode = toNode;
        }
      }
    }
    if (morphedNode === toNode) {
      onNodeDiscarded(fromNode);
    } else {
      if (toNode.isSameNode && toNode.isSameNode(morphedNode)) {
        return;
      }
      morphEl(morphedNode, toNode, childrenOnly);
      if (keyedRemovalList) {
        for (var i = 0, len = keyedRemovalList.length; i < len; i++) {
          var elToRemove = fromNodesLookup[keyedRemovalList[i]];
          if (elToRemove) {
            removeNode(elToRemove, elToRemove.parentNode, false);
          }
        }
      }
    }
    if (!childrenOnly && morphedNode !== fromNode && fromNode.parentNode) {
      if (morphedNode.actualize) {
        morphedNode = morphedNode.actualize(fromNode.ownerDocument || doc);
      }
      fromNode.parentNode.replaceChild(morphedNode, fromNode);
    }
    return morphedNode;
  };
}
var morphdom = morphdomFactory(morphAttrs);
var morphdom_esm_default = morphdom;

// js/phoenix_live_view/dom_patch.js
var DOMPatch = class {
  constructor(view, container, id, html, streams, targetCID, opts = {}) {
    this.view = view;
    this.liveSocket = view.liveSocket;
    this.container = container;
    this.id = id;
    this.rootID = view.root.id;
    this.html = html;
    this.streams = streams;
    this.streamInserts = {};
    this.streamComponentRestore = {};
    this.targetCID = targetCID;
    this.cidPatch = isCid(this.targetCID);
    this.pendingRemoves = [];
    this.phxRemove = this.liveSocket.binding("remove");
    this.targetContainer = this.isCIDPatch() ? this.targetCIDContainer(html) : container;
    this.callbacks = {
      beforeadded: [],
      beforeupdated: [],
      beforephxChildAdded: [],
      afteradded: [],
      afterupdated: [],
      afterdiscarded: [],
      afterphxChildAdded: [],
      aftertransitionsDiscarded: []
    };
    this.withChildren = opts.withChildren || opts.undoRef || false;
    this.undoRef = opts.undoRef;
  }
  before(kind, callback) {
    this.callbacks[`before${kind}`].push(callback);
  }
  after(kind, callback) {
    this.callbacks[`after${kind}`].push(callback);
  }
  trackBefore(kind, ...args) {
    this.callbacks[`before${kind}`].forEach((callback) => callback(...args));
  }
  trackAfter(kind, ...args) {
    this.callbacks[`after${kind}`].forEach((callback) => callback(...args));
  }
  markPrunableContentForRemoval() {
    const phxUpdate = this.liveSocket.binding(PHX_UPDATE);
    dom_default.all(
      this.container,
      `[${phxUpdate}=append] > *, [${phxUpdate}=prepend] > *`,
      (el) => {
        el.setAttribute(PHX_PRUNE, "");
      }
    );
  }
  perform(isJoinPatch) {
    const { view, liveSocket, html, container } = this;
    let targetContainer = this.targetContainer;
    if (this.isCIDPatch() && !this.targetContainer) {
      return;
    }
    if (this.isCIDPatch()) {
      const closestLock = targetContainer.closest(`[${PHX_REF_LOCK}]`);
      if (closestLock) {
        const clonedTree = dom_default.private(closestLock, PHX_REF_LOCK);
        if (clonedTree) {
          targetContainer = clonedTree.querySelector(
            `[data-phx-component="${this.targetCID}"]`
          );
        }
      }
    }
    const focused = liveSocket.getActiveElement();
    const { selectionStart, selectionEnd } = focused && dom_default.hasSelectionRange(focused) ? focused : {};
    const phxUpdate = liveSocket.binding(PHX_UPDATE);
    const phxViewportTop = liveSocket.binding(PHX_VIEWPORT_TOP);
    const phxViewportBottom = liveSocket.binding(PHX_VIEWPORT_BOTTOM);
    const phxTriggerExternal = liveSocket.binding(PHX_TRIGGER_ACTION);
    const added = [];
    const updates = [];
    const appendPrependUpdates = [];
    const portalCallbacks = [];
    let externalFormTriggered = null;
    const morph = (targetContainer2, source, withChildren = this.withChildren) => {
      const morphCallbacks = {
        // normally, we are running with childrenOnly, as the patch HTML for a LV
        // does not include the LV attrs (data-phx-session, etc.)
        // when we are patching a live component, we do want to patch the root element as well;
        // another case is the recursive patch of a stream item that was kept on reset (-> onBeforeNodeAdded)
        childrenOnly: targetContainer2.getAttribute(PHX_COMPONENT) === null && !withChildren,
        getNodeKey: (node) => {
          if (dom_default.isPhxDestroyed(node)) {
            return null;
          }
          if (isJoinPatch) {
            return node.id;
          }
          return node.id || node.getAttribute && node.getAttribute(PHX_MAGIC_ID);
        },
        // skip indexing from children when container is stream
        skipFromChildren: (from) => {
          return from.getAttribute(phxUpdate) === PHX_STREAM;
        },
        // tell morphdom how to add a child
        addChild: (parent, child) => {
          const { ref, streamAt } = this.getStreamInsert(child);
          if (ref === void 0) {
            return parent.appendChild(child);
          }
          this.setStreamRef(child, ref);
          if (streamAt === 0) {
            parent.insertAdjacentElement("afterbegin", child);
          } else if (streamAt === -1) {
            const lastChild = parent.lastElementChild;
            if (lastChild && !lastChild.hasAttribute(PHX_STREAM_REF)) {
              const nonStreamChild = Array.from(parent.children).find(
                (c) => !c.hasAttribute(PHX_STREAM_REF)
              );
              parent.insertBefore(child, nonStreamChild);
            } else {
              parent.appendChild(child);
            }
          } else if (streamAt > 0) {
            const sibling = Array.from(parent.children)[streamAt];
            parent.insertBefore(child, sibling);
          }
        },
        onBeforeNodeAdded: (el) => {
          if (this.getStreamInsert(el)?.updateOnly && !this.streamComponentRestore[el.id]) {
            return false;
          }
          dom_default.maintainPrivateHooks(el, el, phxViewportTop, phxViewportBottom);
          this.trackBefore("added", el);
          let morphedEl = el;
          if (this.streamComponentRestore[el.id]) {
            morphedEl = this.streamComponentRestore[el.id];
            delete this.streamComponentRestore[el.id];
            morph(morphedEl, el, true);
          }
          return morphedEl;
        },
        onNodeAdded: (el) => {
          if (el.getAttribute) {
            this.maybeReOrderStream(el, true);
          }
          if (dom_default.isPortalTemplate(el)) {
            portalCallbacks.push(() => this.teleport(el, morph));
          }
          if (el instanceof HTMLImageElement && el.srcset) {
            el.srcset = el.srcset;
          } else if (el instanceof HTMLVideoElement && el.autoplay) {
            el.play();
          }
          if (dom_default.isNowTriggerFormExternal(el, phxTriggerExternal)) {
            externalFormTriggered = el;
          }
          if (dom_default.isPhxChild(el) && view.ownsElement(el) || dom_default.isPhxSticky(el) && view.ownsElement(el.parentNode)) {
            this.trackAfter("phxChildAdded", el);
          }
          if (el.nodeName === "SCRIPT" && el.hasAttribute(PHX_RUNTIME_HOOK)) {
            this.handleRuntimeHook(el, source);
          }
          added.push(el);
        },
        onNodeDiscarded: (el) => this.onNodeDiscarded(el),
        onBeforeNodeDiscarded: (el) => {
          if (el.getAttribute && el.getAttribute(PHX_PRUNE) !== null) {
            return true;
          }
          if (el.parentElement !== null && el.id && dom_default.isPhxUpdate(el.parentElement, phxUpdate, [
            PHX_STREAM,
            "append",
            "prepend"
          ])) {
            return false;
          }
          if (el.getAttribute && el.getAttribute(PHX_TELEPORTED_REF)) {
            return false;
          }
          if (this.maybePendingRemove(el)) {
            return false;
          }
          if (this.skipCIDSibling(el)) {
            return false;
          }
          if (dom_default.isPortalTemplate(el)) {
            const teleportedEl = document.getElementById(
              el.content.firstElementChild.id
            );
            if (teleportedEl) {
              teleportedEl.remove();
              morphCallbacks.onNodeDiscarded(teleportedEl);
              this.view.dropPortalElementId(teleportedEl.id);
            }
          }
          return true;
        },
        onElUpdated: (el) => {
          if (dom_default.isNowTriggerFormExternal(el, phxTriggerExternal)) {
            externalFormTriggered = el;
          }
          updates.push(el);
          this.maybeReOrderStream(el, false);
        },
        onBeforeElUpdated: (fromEl, toEl) => {
          if (fromEl.id && fromEl.isSameNode(targetContainer2) && fromEl.id !== toEl.id) {
            morphCallbacks.onNodeDiscarded(fromEl);
            fromEl.replaceWith(toEl);
            return morphCallbacks.onNodeAdded(toEl);
          }
          dom_default.syncPendingAttrs(fromEl, toEl);
          dom_default.maintainPrivateHooks(
            fromEl,
            toEl,
            phxViewportTop,
            phxViewportBottom
          );
          dom_default.cleanChildNodes(toEl, phxUpdate);
          if (this.skipCIDSibling(toEl)) {
            this.maybeReOrderStream(fromEl);
            return false;
          }
          if (dom_default.isPhxSticky(fromEl)) {
            [PHX_SESSION, PHX_STATIC, PHX_ROOT_ID].map((attr) => [
              attr,
              fromEl.getAttribute(attr),
              toEl.getAttribute(attr)
            ]).forEach(([attr, fromVal, toVal]) => {
              if (toVal && fromVal !== toVal) {
                fromEl.setAttribute(attr, toVal);
              }
            });
            return false;
          }
          if (dom_default.isIgnored(fromEl, phxUpdate) || fromEl.form && fromEl.form.isSameNode(externalFormTriggered)) {
            this.trackBefore("updated", fromEl, toEl);
            dom_default.mergeAttrs(fromEl, toEl, {
              isIgnored: dom_default.isIgnored(fromEl, phxUpdate)
            });
            updates.push(fromEl);
            dom_default.applyStickyOperations(fromEl);
            return false;
          }
          if (fromEl.type === "number" && fromEl.validity && fromEl.validity.badInput) {
            return false;
          }
          const isFocusedFormEl = focused && fromEl.isSameNode(focused) && dom_default.isFormInput(fromEl);
          const focusedSelectChanged = isFocusedFormEl && this.isChangedSelect(fromEl, toEl);
          if (fromEl.hasAttribute(PHX_REF_SRC)) {
            const ref = new ElementRef(fromEl);
            if (ref.lockRef && (!this.undoRef || !ref.isLockUndoneBy(this.undoRef))) {
              if (dom_default.isUploadInput(fromEl)) {
                dom_default.mergeAttrs(fromEl, toEl, { isIgnored: true });
                this.trackBefore("updated", fromEl, toEl);
                updates.push(fromEl);
              }
              dom_default.applyStickyOperations(fromEl);
              const isLocked = fromEl.hasAttribute(PHX_REF_LOCK);
              const clone2 = isLocked ? dom_default.private(fromEl, PHX_REF_LOCK) || fromEl.cloneNode(true) : null;
              if (clone2) {
                dom_default.putPrivate(fromEl, PHX_REF_LOCK, clone2);
                if (!isFocusedFormEl) {
                  fromEl = clone2;
                }
              }
            }
          }
          if (dom_default.isPhxChild(toEl)) {
            const prevSession = fromEl.getAttribute(PHX_SESSION);
            dom_default.mergeAttrs(fromEl, toEl, { exclude: [PHX_STATIC] });
            if (prevSession !== "") {
              fromEl.setAttribute(PHX_SESSION, prevSession);
            }
            fromEl.setAttribute(PHX_ROOT_ID, this.rootID);
            dom_default.applyStickyOperations(fromEl);
            return false;
          }
          if (this.undoRef && dom_default.private(toEl, PHX_REF_LOCK)) {
            dom_default.putPrivate(
              fromEl,
              PHX_REF_LOCK,
              dom_default.private(toEl, PHX_REF_LOCK)
            );
          }
          dom_default.copyPrivates(toEl, fromEl);
          if (dom_default.isPortalTemplate(toEl)) {
            portalCallbacks.push(() => this.teleport(toEl, morph));
            return false;
          }
          if (isFocusedFormEl && fromEl.type !== "hidden" && !focusedSelectChanged) {
            this.trackBefore("updated", fromEl, toEl);
            dom_default.mergeFocusedInput(fromEl, toEl);
            dom_default.syncAttrsToProps(fromEl);
            updates.push(fromEl);
            dom_default.applyStickyOperations(fromEl);
            return false;
          } else {
            if (focusedSelectChanged) {
              fromEl.blur();
            }
            if (dom_default.isPhxUpdate(toEl, phxUpdate, ["append", "prepend"])) {
              appendPrependUpdates.push(
                new DOMPostMorphRestorer(
                  fromEl,
                  toEl,
                  toEl.getAttribute(phxUpdate)
                )
              );
            }
            dom_default.syncAttrsToProps(toEl);
            dom_default.applyStickyOperations(toEl);
            this.trackBefore("updated", fromEl, toEl);
            return fromEl;
          }
        }
      };
      morphdom_esm_default(targetContainer2, source, morphCallbacks);
    };
    this.trackBefore("added", container);
    this.trackBefore("updated", container, container);
    liveSocket.time("morphdom", () => {
      this.streams.forEach(([ref, inserts, deleteIds, reset]) => {
        inserts.forEach(([key, streamAt, limit, updateOnly]) => {
          this.streamInserts[key] = { ref, streamAt, limit, reset, updateOnly };
        });
        if (reset !== void 0) {
          dom_default.all(container, `[${PHX_STREAM_REF}="${ref}"]`, (child) => {
            this.removeStreamChildElement(child);
          });
        }
        deleteIds.forEach((id) => {
          const child = container.querySelector(`[id="${id}"]`);
          if (child) {
            this.removeStreamChildElement(child);
          }
        });
      });
      if (isJoinPatch) {
        dom_default.all(this.container, `[${phxUpdate}=${PHX_STREAM}]`).filter((el) => this.view.ownsElement(el)).forEach((el) => {
          Array.from(el.children).forEach((child) => {
            this.removeStreamChildElement(child, true);
          });
        });
      }
      morph(targetContainer, html);
      portalCallbacks.forEach((callback) => callback());
      this.view.portalElementIds.forEach((id) => {
        const el = document.getElementById(id);
        if (el) {
          const source = document.getElementById(
            el.getAttribute(PHX_TELEPORTED_SRC)
          );
          if (!source) {
            el.remove();
            this.onNodeDiscarded(el);
            this.view.dropPortalElementId(id);
          }
        }
      });
    });
    if (liveSocket.isDebugEnabled()) {
      detectDuplicateIds();
      detectInvalidStreamInserts(this.streamInserts);
      Array.from(document.querySelectorAll("input[name=id]")).forEach(
        (node) => {
          if (node instanceof HTMLInputElement && node.form) {
            console.error(
              'Detected an input with name="id" inside a form! This will cause problems when patching the DOM.\n',
              node
            );
          }
        }
      );
    }
    if (appendPrependUpdates.length > 0) {
      liveSocket.time("post-morph append/prepend restoration", () => {
        appendPrependUpdates.forEach((update) => update.perform());
      });
    }
    liveSocket.silenceEvents(
      () => dom_default.restoreFocus(focused, selectionStart, selectionEnd)
    );
    dom_default.dispatchEvent(document, "phx:update");
    added.forEach((el) => this.trackAfter("added", el));
    updates.forEach((el) => this.trackAfter("updated", el));
    this.transitionPendingRemoves();
    if (externalFormTriggered) {
      liveSocket.unload();
      const submitter = dom_default.private(externalFormTriggered, "submitter");
      if (submitter && submitter.name && targetContainer.contains(submitter)) {
        const input = document.createElement("input");
        input.type = "hidden";
        const formId = submitter.getAttribute("form");
        if (formId) {
          input.setAttribute("form", formId);
        }
        input.name = submitter.name;
        input.value = submitter.value;
        submitter.parentElement.insertBefore(input, submitter);
      }
      Object.getPrototypeOf(externalFormTriggered).submit.call(
        externalFormTriggered
      );
    }
    return true;
  }
  onNodeDiscarded(el) {
    if (dom_default.isPhxChild(el) || dom_default.isPhxSticky(el)) {
      this.liveSocket.destroyViewByEl(el);
    }
    this.trackAfter("discarded", el);
  }
  maybePendingRemove(node) {
    if (node.getAttribute && node.getAttribute(this.phxRemove) !== null) {
      this.pendingRemoves.push(node);
      return true;
    } else {
      return false;
    }
  }
  removeStreamChildElement(child, force = false) {
    if (!force && !this.view.ownsElement(child)) {
      return;
    }
    if (this.streamInserts[child.id]) {
      this.streamComponentRestore[child.id] = child;
      child.remove();
    } else {
      if (!this.maybePendingRemove(child)) {
        child.remove();
        this.onNodeDiscarded(child);
      }
    }
  }
  getStreamInsert(el) {
    const insert = el.id ? this.streamInserts[el.id] : {};
    return insert || {};
  }
  setStreamRef(el, ref) {
    dom_default.putSticky(
      el,
      PHX_STREAM_REF,
      (el2) => el2.setAttribute(PHX_STREAM_REF, ref)
    );
  }
  maybeReOrderStream(el, isNew) {
    const { ref, streamAt, reset } = this.getStreamInsert(el);
    if (streamAt === void 0) {
      return;
    }
    this.setStreamRef(el, ref);
    if (!reset && !isNew) {
      return;
    }
    if (!el.parentElement) {
      return;
    }
    if (streamAt === 0) {
      el.parentElement.insertBefore(el, el.parentElement.firstElementChild);
    } else if (streamAt > 0) {
      const children = Array.from(el.parentElement.children);
      const oldIndex = children.indexOf(el);
      if (streamAt >= children.length - 1) {
        el.parentElement.appendChild(el);
      } else {
        const sibling = children[streamAt];
        if (oldIndex > streamAt) {
          el.parentElement.insertBefore(el, sibling);
        } else {
          el.parentElement.insertBefore(el, sibling.nextElementSibling);
        }
      }
    }
    this.maybeLimitStream(el);
  }
  maybeLimitStream(el) {
    const { limit } = this.getStreamInsert(el);
    const children = limit !== null && Array.from(el.parentElement.children);
    if (limit && limit < 0 && children.length > limit * -1) {
      children.slice(0, children.length + limit).forEach((child) => this.removeStreamChildElement(child));
    } else if (limit && limit >= 0 && children.length > limit) {
      children.slice(limit).forEach((child) => this.removeStreamChildElement(child));
    }
  }
  transitionPendingRemoves() {
    const { pendingRemoves, liveSocket } = this;
    if (pendingRemoves.length > 0) {
      liveSocket.transitionRemoves(pendingRemoves, () => {
        pendingRemoves.forEach((el) => {
          const child = dom_default.firstPhxChild(el);
          if (child) {
            liveSocket.destroyViewByEl(child);
          }
          el.remove();
        });
        this.trackAfter("transitionsDiscarded", pendingRemoves);
      });
    }
  }
  isChangedSelect(fromEl, toEl) {
    if (!(fromEl instanceof HTMLSelectElement) || fromEl.multiple) {
      return false;
    }
    if (fromEl.options.length !== toEl.options.length) {
      return true;
    }
    toEl.value = fromEl.value;
    return !fromEl.isEqualNode(toEl);
  }
  isCIDPatch() {
    return this.cidPatch;
  }
  skipCIDSibling(el) {
    return el.nodeType === Node.ELEMENT_NODE && el.hasAttribute(PHX_SKIP);
  }
  targetCIDContainer(html) {
    if (!this.isCIDPatch()) {
      return;
    }
    const [first, ...rest] = dom_default.findComponentNodeList(
      this.view.id,
      this.targetCID
    );
    if (rest.length === 0 && dom_default.childNodeLength(html) === 1) {
      return first;
    } else {
      return first && first.parentNode;
    }
  }
  indexOf(parent, child) {
    return Array.from(parent.children).indexOf(child);
  }
  teleport(el, morph) {
    const targetSelector = el.getAttribute(PHX_PORTAL);
    const portalContainer = document.querySelector(targetSelector);
    if (!portalContainer) {
      throw new Error(
        "portal target with selector " + targetSelector + " not found"
      );
    }
    const toTeleport = el.content.firstElementChild;
    if (this.skipCIDSibling(toTeleport)) {
      return;
    }
    if (!toTeleport?.id) {
      throw new Error(
        "phx-portal template must have a single root element with ID!"
      );
    }
    const existing = document.getElementById(toTeleport.id);
    let portalTarget;
    if (existing) {
      if (!portalContainer.contains(existing)) {
        portalContainer.appendChild(existing);
      }
      portalTarget = existing;
    } else {
      portalTarget = document.createElement(toTeleport.tagName);
      portalContainer.appendChild(portalTarget);
    }
    toTeleport.setAttribute(PHX_TELEPORTED_REF, this.view.id);
    toTeleport.setAttribute(PHX_TELEPORTED_SRC, el.id);
    morph(portalTarget, toTeleport, true);
    toTeleport.removeAttribute(PHX_TELEPORTED_REF);
    toTeleport.removeAttribute(PHX_TELEPORTED_SRC);
    this.view.pushPortalElementId(toTeleport.id);
  }
  handleRuntimeHook(el, source) {
    const name = el.getAttribute(PHX_RUNTIME_HOOK);
    let nonce = el.hasAttribute("nonce") ? el.getAttribute("nonce") : null;
    if (el.hasAttribute("nonce")) {
      const template = document.createElement("template");
      template.innerHTML = source;
      nonce = template.content.querySelector(`script[${PHX_RUNTIME_HOOK}="${CSS.escape(name)}"]`).getAttribute("nonce");
    }
    const script = document.createElement("script");
    script.textContent = el.textContent;
    dom_default.mergeAttrs(script, el, { isIgnored: false });
    if (nonce) {
      script.nonce = nonce;
    }
    el.replaceWith(script);
    el = script;
  }
};

// js/phoenix_live_view/rendered.js
var VOID_TAGS = /* @__PURE__ */ new Set([
  "area",
  "base",
  "br",
  "col",
  "command",
  "embed",
  "hr",
  "img",
  "input",
  "keygen",
  "link",
  "meta",
  "param",
  "source",
  "track",
  "wbr"
]);
var quoteChars = /* @__PURE__ */ new Set(["'", '"']);
var modifyRoot = (html, attrs, clearInnerHTML) => {
  let i = 0;
  let insideComment = false;
  let beforeTag, afterTag, tag, tagNameEndsAt, id, newHTML;
  const lookahead = html.match(/^(\s*(?:<!--.*?-->\s*)*)<([^\s\/>]+)/);
  if (lookahead === null) {
    throw new Error(`malformed html ${html}`);
  }
  i = lookahead[0].length;
  beforeTag = lookahead[1];
  tag = lookahead[2];
  tagNameEndsAt = i;
  for (i; i < html.length; i++) {
    if (html.charAt(i) === ">") {
      break;
    }
    if (html.charAt(i) === "=") {
      const isId = html.slice(i - 3, i) === " id";
      i++;
      const char = html.charAt(i);
      if (quoteChars.has(char)) {
        const attrStartsAt = i;
        i++;
        for (i; i < html.length; i++) {
          if (html.charAt(i) === char) {
            break;
          }
        }
        if (isId) {
          id = html.slice(attrStartsAt + 1, i);
          break;
        }
      }
    }
  }
  let closeAt = html.length - 1;
  insideComment = false;
  while (closeAt >= beforeTag.length + tag.length) {
    const char = html.charAt(closeAt);
    if (insideComment) {
      if (char === "-" && html.slice(closeAt - 3, closeAt) === "<!-") {
        insideComment = false;
        closeAt -= 4;
      } else {
        closeAt -= 1;
      }
    } else if (char === ">" && html.slice(closeAt - 2, closeAt) === "--") {
      insideComment = true;
      closeAt -= 3;
    } else if (char === ">") {
      break;
    } else {
      closeAt -= 1;
    }
  }
  afterTag = html.slice(closeAt + 1, html.length);
  const attrsStr = Object.keys(attrs).map((attr) => attrs[attr] === true ? attr : `${attr}="${attrs[attr]}"`).join(" ");
  if (clearInnerHTML) {
    const idAttrStr = id ? ` id="${id}"` : "";
    if (VOID_TAGS.has(tag)) {
      newHTML = `<${tag}${idAttrStr}${attrsStr === "" ? "" : " "}${attrsStr}/>`;
    } else {
      newHTML = `<${tag}${idAttrStr}${attrsStr === "" ? "" : " "}${attrsStr}></${tag}>`;
    }
  } else {
    const rest = html.slice(tagNameEndsAt, closeAt + 1);
    newHTML = `<${tag}${attrsStr === "" ? "" : " "}${attrsStr}${rest}`;
  }
  return [newHTML, beforeTag, afterTag];
};
var Rendered = class {
  static extract(diff) {
    const { [REPLY]: reply, [EVENTS]: events, [TITLE]: title } = diff;
    delete diff[REPLY];
    delete diff[EVENTS];
    delete diff[TITLE];
    return { diff, title, reply: reply || null, events: events || [] };
  }
  constructor(viewId, rendered) {
    this.viewId = viewId;
    this.rendered = {};
    this.magicId = 0;
    this.mergeDiff(rendered);
  }
  parentViewId() {
    return this.viewId;
  }
  toString(onlyCids) {
    const { buffer: str, streams } = this.recursiveToString(
      this.rendered,
      this.rendered[COMPONENTS],
      onlyCids,
      true,
      {}
    );
    return { buffer: str, streams };
  }
  recursiveToString(rendered, components = rendered[COMPONENTS], onlyCids, changeTracking, rootAttrs) {
    onlyCids = onlyCids ? new Set(onlyCids) : null;
    const output = {
      buffer: "",
      components,
      onlyCids,
      streams: /* @__PURE__ */ new Set()
    };
    this.toOutputBuffer(rendered, null, output, changeTracking, rootAttrs);
    return { buffer: output.buffer, streams: output.streams };
  }
  componentCIDs(diff) {
    return Object.keys(diff[COMPONENTS] || {}).map((i) => parseInt(i));
  }
  isComponentOnlyDiff(diff) {
    if (!diff[COMPONENTS]) {
      return false;
    }
    return Object.keys(diff).length === 1;
  }
  getComponent(diff, cid) {
    return diff[COMPONENTS][cid];
  }
  resetRender(cid) {
    if (this.rendered[COMPONENTS][cid]) {
      this.rendered[COMPONENTS][cid].reset = true;
    }
  }
  mergeDiff(diff) {
    const newc = diff[COMPONENTS];
    const cache = {};
    delete diff[COMPONENTS];
    this.rendered = this.mutableMerge(this.rendered, diff);
    this.rendered[COMPONENTS] = this.rendered[COMPONENTS] || {};
    if (newc) {
      const oldc = this.rendered[COMPONENTS];
      for (const cid in newc) {
        newc[cid] = this.cachedFindComponent(cid, newc[cid], oldc, newc, cache);
      }
      for (const cid in newc) {
        oldc[cid] = newc[cid];
      }
      diff[COMPONENTS] = newc;
    }
  }
  cachedFindComponent(cid, cdiff, oldc, newc, cache) {
    if (cache[cid]) {
      return cache[cid];
    } else {
      let ndiff, stat, scid = cdiff[STATIC];
      if (isCid(scid)) {
        let tdiff;
        if (scid > 0) {
          tdiff = this.cachedFindComponent(scid, newc[scid], oldc, newc, cache);
        } else {
          tdiff = oldc[-scid];
        }
        stat = tdiff[STATIC];
        ndiff = this.cloneMerge(tdiff, cdiff, true);
        ndiff[STATIC] = stat;
      } else {
        ndiff = cdiff[STATIC] !== void 0 || oldc[cid] === void 0 ? cdiff : this.cloneMerge(oldc[cid], cdiff, false);
      }
      cache[cid] = ndiff;
      return ndiff;
    }
  }
  mutableMerge(target, source) {
    if (source[STATIC] !== void 0) {
      return source;
    } else {
      this.doMutableMerge(target, source);
      return target;
    }
  }
  doMutableMerge(target, source) {
    if (source[KEYED]) {
      this.mergeKeyed(target, source);
    } else {
      for (const key in source) {
        const val = source[key];
        const targetVal = target[key];
        const isObjVal = isObject(val);
        if (isObjVal && val[STATIC] === void 0 && isObject(targetVal)) {
          this.doMutableMerge(targetVal, val);
        } else {
          target[key] = val;
        }
      }
    }
    if (target[ROOT]) {
      target.newRender = true;
    }
  }
  clone(diff) {
    if ("structuredClone" in window) {
      return structuredClone(diff);
    } else {
      return JSON.parse(JSON.stringify(diff));
    }
  }
  // keyed comprehensions
  mergeKeyed(target, source) {
    const clonedTarget = this.clone(target);
    Object.entries(source[KEYED]).forEach(([i, entry]) => {
      if (i === KEYED_COUNT) {
        return;
      }
      if (Array.isArray(entry)) {
        const [old_idx, diff] = entry;
        target[KEYED][i] = clonedTarget[KEYED][old_idx];
        this.doMutableMerge(target[KEYED][i], diff);
      } else if (typeof entry === "number") {
        const old_idx = entry;
        target[KEYED][i] = clonedTarget[KEYED][old_idx];
      } else if (typeof entry === "object") {
        if (!target[KEYED][i]) {
          target[KEYED][i] = {};
        }
        this.doMutableMerge(target[KEYED][i], entry);
      }
    });
    if (source[KEYED][KEYED_COUNT] < target[KEYED][KEYED_COUNT]) {
      for (let i = source[KEYED][KEYED_COUNT]; i < target[KEYED][KEYED_COUNT]; i++) {
        delete target[KEYED][i];
      }
    }
    target[KEYED][KEYED_COUNT] = source[KEYED][KEYED_COUNT];
    if (source[STREAM]) {
      target[STREAM] = source[STREAM];
    }
    if (source[TEMPLATES]) {
      target[TEMPLATES] = source[TEMPLATES];
    }
  }
  // Merges cid trees together, copying statics from source tree.
  //
  // The `pruneMagicId` is passed to control pruning the magicId of the
  // target. We must always prune the magicId when we are sharing statics
  // from another component. If not pruning, we replicate the logic from
  // mutableMerge, where we set newRender to true if there is a root
  // (effectively forcing the new version to be rendered instead of skipped)
  //
  cloneMerge(target, source, pruneMagicId) {
    const merged = { ...target, ...source };
    for (const key in merged) {
      const val = source[key];
      const targetVal = target[key];
      if (isObject(val) && val[STATIC] === void 0 && isObject(targetVal)) {
        merged[key] = this.cloneMerge(targetVal, val, pruneMagicId);
      } else if (val === void 0 && isObject(targetVal)) {
        merged[key] = this.cloneMerge(targetVal, {}, pruneMagicId);
      }
    }
    if (pruneMagicId) {
      delete merged.magicId;
      delete merged.newRender;
    } else if (target[ROOT]) {
      merged.newRender = true;
    }
    return merged;
  }
  componentToString(cid) {
    const { buffer: str, streams } = this.recursiveCIDToString(
      this.rendered[COMPONENTS],
      cid,
      null
    );
    const [strippedHTML, _before, _after] = modifyRoot(str, {});
    return { buffer: strippedHTML, streams };
  }
  pruneCIDs(cids) {
    cids.forEach((cid) => delete this.rendered[COMPONENTS][cid]);
  }
  // private
  get() {
    return this.rendered;
  }
  isNewFingerprint(diff = {}) {
    return !!diff[STATIC];
  }
  templateStatic(part, templates) {
    if (typeof part === "number") {
      return templates[part];
    } else {
      return part;
    }
  }
  nextMagicID() {
    this.magicId++;
    return `m${this.magicId}-${this.parentViewId()}`;
  }
  // Converts rendered tree to output buffer.
  //
  // changeTracking controls if we can apply the PHX_SKIP optimization.
  toOutputBuffer(rendered, templates, output, changeTracking, rootAttrs = {}) {
    if (rendered[KEYED]) {
      return this.comprehensionToBuffer(
        rendered,
        templates,
        output,
        changeTracking
      );
    }
    if (rendered[TEMPLATES]) {
      templates = rendered[TEMPLATES];
      delete rendered[TEMPLATES];
    }
    let { [STATIC]: statics } = rendered;
    statics = this.templateStatic(statics, templates);
    rendered[STATIC] = statics;
    const isRoot = rendered[ROOT];
    const prevBuffer = output.buffer;
    if (isRoot) {
      output.buffer = "";
    }
    if (changeTracking && isRoot && !rendered.magicId) {
      rendered.newRender = true;
      rendered.magicId = this.nextMagicID();
    }
    output.buffer += statics[0];
    for (let i = 1; i < statics.length; i++) {
      this.dynamicToBuffer(rendered[i - 1], templates, output, changeTracking);
      output.buffer += statics[i];
    }
    if (isRoot) {
      let skip = false;
      let attrs;
      if (changeTracking || rendered.magicId) {
        skip = changeTracking && !rendered.newRender;
        attrs = { [PHX_MAGIC_ID]: rendered.magicId, ...rootAttrs };
      } else {
        attrs = rootAttrs;
      }
      if (skip) {
        attrs[PHX_SKIP] = true;
      }
      const [newRoot, commentBefore, commentAfter] = modifyRoot(
        output.buffer,
        attrs,
        skip
      );
      rendered.newRender = false;
      output.buffer = prevBuffer + commentBefore + newRoot + commentAfter;
    }
  }
  comprehensionToBuffer(rendered, templates, output, changeTracking) {
    const keyedTemplates = templates || rendered[TEMPLATES];
    const statics = this.templateStatic(rendered[STATIC], templates);
    rendered[STATIC] = statics;
    delete rendered[TEMPLATES];
    for (let i = 0; i < rendered[KEYED][KEYED_COUNT]; i++) {
      output.buffer += statics[0];
      for (let j = 1; j < statics.length; j++) {
        this.dynamicToBuffer(
          rendered[KEYED][i][j - 1],
          keyedTemplates,
          output,
          changeTracking
        );
        output.buffer += statics[j];
      }
    }
    if (rendered[STREAM]) {
      const stream = rendered[STREAM];
      const [_ref, _inserts, deleteIds, reset] = stream || [null, {}, [], null];
      if (stream !== void 0 && (rendered[KEYED][KEYED_COUNT] > 0 || deleteIds.length > 0 || reset)) {
        delete rendered[STREAM];
        rendered[KEYED] = {
          [KEYED_COUNT]: 0
        };
        output.streams.add(stream);
      }
    }
  }
  dynamicToBuffer(rendered, templates, output, changeTracking) {
    if (typeof rendered === "number") {
      const { buffer: str, streams } = this.recursiveCIDToString(
        output.components,
        rendered,
        output.onlyCids
      );
      output.buffer += str;
      output.streams = /* @__PURE__ */ new Set([...output.streams, ...streams]);
    } else if (isObject(rendered)) {
      this.toOutputBuffer(rendered, templates, output, changeTracking, {});
    } else {
      output.buffer += rendered;
    }
  }
  recursiveCIDToString(components, cid, onlyCids) {
    const component = components[cid] || logError(`no component for CID ${cid}`, components);
    const attrs = { [PHX_COMPONENT]: cid, [PHX_VIEW_REF]: this.viewId };
    const skip = onlyCids && !onlyCids.has(cid);
    component.newRender = !skip;
    component.magicId = `c${cid}-${this.parentViewId()}`;
    const changeTracking = !component.reset;
    const { buffer: html, streams } = this.recursiveToString(
      component,
      components,
      onlyCids,
      changeTracking,
      attrs
    );
    delete component.reset;
    return { buffer: html, streams };
  }
};

// js/phoenix_live_view/js.js
var focusStack = [];
var default_transition_time = 200;
var JS = {
  // private
  exec(e, eventType, phxEvent, view, sourceEl, defaults) {
    const [defaultKind, defaultArgs] = defaults || [
      null,
      { callback: defaults && defaults.callback }
    ];
    const commands = phxEvent.charAt(0) === "[" ? JSON.parse(phxEvent) : [[defaultKind, defaultArgs]];
    commands.forEach(([kind, args]) => {
      if (kind === defaultKind) {
        args = { ...defaultArgs, ...args };
        args.callback = args.callback || defaultArgs.callback;
      }
      this.filterToEls(view.liveSocket, sourceEl, args).forEach((el) => {
        this[`exec_${kind}`](e, eventType, phxEvent, view, sourceEl, el, args);
      });
    });
  },
  isVisible(el) {
    return !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length > 0);
  },
  // returns true if any part of the element is inside the viewport
  isInViewport(el) {
    const rect = el.getBoundingClientRect();
    const windowHeight = window.innerHeight || document.documentElement.clientHeight;
    const windowWidth = window.innerWidth || document.documentElement.clientWidth;
    return rect.right > 0 && rect.bottom > 0 && rect.left < windowWidth && rect.top < windowHeight;
  },
  // private
  // commands
  exec_exec(e, eventType, phxEvent, view, sourceEl, el, { attr, to }) {
    const encodedJS = el.getAttribute(attr);
    if (!encodedJS) {
      throw new Error(`expected ${attr} to contain JS command on "${to}"`);
    }
    view.liveSocket.execJS(el, encodedJS, eventType);
  },
  exec_dispatch(e, eventType, phxEvent, view, sourceEl, el, { event, detail, bubbles, blocking }) {
    detail = detail || {};
    detail.dispatcher = sourceEl;
    if (blocking) {
      const promise = new Promise((resolve, _reject) => {
        detail.done = resolve;
      });
      view.liveSocket.asyncTransition(promise);
    }
    dom_default.dispatchEvent(el, event, { detail, bubbles });
  },
  exec_push(e, eventType, phxEvent, view, sourceEl, el, args) {
    const {
      event,
      data,
      target,
      page_loading,
      loading,
      value,
      dispatcher,
      callback
    } = args;
    const pushOpts = {
      loading,
      value,
      target,
      page_loading: !!page_loading,
      originalEvent: e
    };
    const targetSrc = eventType === "change" && dispatcher ? dispatcher : sourceEl;
    const phxTarget = target || targetSrc.getAttribute(view.binding("target")) || targetSrc;
    const handler = (targetView, targetCtx) => {
      if (!targetView.isConnected()) {
        return;
      }
      if (eventType === "change") {
        let { newCid, _target } = args;
        _target = _target || (dom_default.isFormInput(sourceEl) ? sourceEl.name : void 0);
        if (_target) {
          pushOpts._target = _target;
        }
        targetView.pushInput(
          sourceEl,
          targetCtx,
          newCid,
          event || phxEvent,
          pushOpts,
          callback
        );
      } else if (eventType === "submit") {
        const { submitter } = args;
        targetView.submitForm(
          sourceEl,
          targetCtx,
          event || phxEvent,
          submitter,
          pushOpts,
          callback
        );
      } else {
        targetView.pushEvent(
          eventType,
          sourceEl,
          targetCtx,
          event || phxEvent,
          data,
          pushOpts,
          callback
        );
      }
    };
    if (args.targetView && args.targetCtx) {
      handler(args.targetView, args.targetCtx);
    } else {
      view.withinTargets(phxTarget, handler);
    }
  },
  exec_navigate(e, eventType, phxEvent, view, sourceEl, el, { href, replace }) {
    view.liveSocket.historyRedirect(
      e,
      href,
      replace ? "replace" : "push",
      null,
      sourceEl
    );
  },
  exec_patch(e, eventType, phxEvent, view, sourceEl, el, { href, replace }) {
    view.liveSocket.pushHistoryPatch(
      e,
      href,
      replace ? "replace" : "push",
      sourceEl
    );
  },
  exec_focus(e, eventType, phxEvent, view, sourceEl, el) {
    aria_default.attemptFocus(el);
    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => aria_default.attemptFocus(el));
    });
  },
  exec_focus_first(e, eventType, phxEvent, view, sourceEl, el) {
    aria_default.focusFirstInteractive(el) || aria_default.focusFirst(el);
    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(
        () => aria_default.focusFirstInteractive(el) || aria_default.focusFirst(el)
      );
    });
  },
  exec_push_focus(e, eventType, phxEvent, view, sourceEl, el) {
    focusStack.push(el || sourceEl);
  },
  exec_pop_focus(_e, _eventType, _phxEvent, _view, _sourceEl, _el) {
    const el = focusStack.pop();
    if (el) {
      el.focus();
      window.requestAnimationFrame(() => {
        window.requestAnimationFrame(() => el.focus());
      });
    }
  },
  exec_add_class(e, eventType, phxEvent, view, sourceEl, el, { names, transition, time, blocking }) {
    this.addOrRemoveClasses(el, names, [], transition, time, view, blocking);
  },
  exec_remove_class(e, eventType, phxEvent, view, sourceEl, el, { names, transition, time, blocking }) {
    this.addOrRemoveClasses(el, [], names, transition, time, view, blocking);
  },
  exec_toggle_class(e, eventType, phxEvent, view, sourceEl, el, { names, transition, time, blocking }) {
    this.toggleClasses(el, names, transition, time, view, blocking);
  },
  exec_toggle_attr(e, eventType, phxEvent, view, sourceEl, el, { attr: [attr, val1, val2] }) {
    this.toggleAttr(el, attr, val1, val2);
  },
  exec_ignore_attrs(e, eventType, phxEvent, view, sourceEl, el, { attrs }) {
    this.ignoreAttrs(el, attrs);
  },
  exec_transition(e, eventType, phxEvent, view, sourceEl, el, { time, transition, blocking }) {
    this.addOrRemoveClasses(el, [], [], transition, time, view, blocking);
  },
  exec_toggle(e, eventType, phxEvent, view, sourceEl, el, { display, ins, outs, time, blocking }) {
    this.toggle(eventType, view, el, display, ins, outs, time, blocking);
  },
  exec_show(e, eventType, phxEvent, view, sourceEl, el, { display, transition, time, blocking }) {
    this.show(eventType, view, el, display, transition, time, blocking);
  },
  exec_hide(e, eventType, phxEvent, view, sourceEl, el, { display, transition, time, blocking }) {
    this.hide(eventType, view, el, display, transition, time, blocking);
  },
  exec_set_attr(e, eventType, phxEvent, view, sourceEl, el, { attr: [attr, val] }) {
    this.setOrRemoveAttrs(el, [[attr, val]], []);
  },
  exec_remove_attr(e, eventType, phxEvent, view, sourceEl, el, { attr }) {
    this.setOrRemoveAttrs(el, [], [attr]);
  },
  ignoreAttrs(el, attrs) {
    dom_default.putPrivate(el, "JS:ignore_attrs", {
      apply: (fromEl, toEl) => {
        Array.from(fromEl.attributes).forEach((attr) => {
          if (attrs.some(
            (toIgnore) => attr.name == toIgnore || toIgnore === "*" || toIgnore.includes("*") && attr.name.match(toIgnore) != null
          )) {
            toEl.setAttribute(attr.name, attr.value);
          }
        });
      }
    });
  },
  onBeforeElUpdated(fromEl, toEl) {
    const ignoreAttrs = dom_default.private(fromEl, "JS:ignore_attrs");
    if (ignoreAttrs) {
      ignoreAttrs.apply(fromEl, toEl);
    }
  },
  // utils for commands
  show(eventType, view, el, display, transition, time, blocking) {
    if (!this.isVisible(el)) {
      this.toggle(
        eventType,
        view,
        el,
        display,
        transition,
        null,
        time,
        blocking
      );
    }
  },
  hide(eventType, view, el, display, transition, time, blocking) {
    if (this.isVisible(el)) {
      this.toggle(
        eventType,
        view,
        el,
        display,
        null,
        transition,
        time,
        blocking
      );
    }
  },
  toggle(eventType, view, el, display, ins, outs, time, blocking) {
    time = time || default_transition_time;
    const [inClasses, inStartClasses, inEndClasses] = ins || [[], [], []];
    const [outClasses, outStartClasses, outEndClasses] = outs || [[], [], []];
    if (inClasses.length > 0 || outClasses.length > 0) {
      if (this.isVisible(el)) {
        const onStart = () => {
          this.addOrRemoveClasses(
            el,
            outStartClasses,
            inClasses.concat(inStartClasses).concat(inEndClasses)
          );
          window.requestAnimationFrame(() => {
            this.addOrRemoveClasses(el, outClasses, []);
            window.requestAnimationFrame(
              () => this.addOrRemoveClasses(el, outEndClasses, outStartClasses)
            );
          });
        };
        const onEnd = () => {
          this.addOrRemoveClasses(el, [], outClasses.concat(outEndClasses));
          dom_default.putSticky(
            el,
            "toggle",
            (currentEl) => currentEl.style.display = "none"
          );
          el.dispatchEvent(new Event("phx:hide-end"));
        };
        el.dispatchEvent(new Event("phx:hide-start"));
        if (blocking === false) {
          onStart();
          setTimeout(onEnd, time);
        } else {
          view.transition(time, onStart, onEnd);
        }
      } else {
        if (eventType === "remove") {
          return;
        }
        const onStart = () => {
          this.addOrRemoveClasses(
            el,
            inStartClasses,
            outClasses.concat(outStartClasses).concat(outEndClasses)
          );
          const stickyDisplay = display || this.defaultDisplay(el);
          window.requestAnimationFrame(() => {
            this.addOrRemoveClasses(el, inClasses, []);
            window.requestAnimationFrame(() => {
              dom_default.putSticky(
                el,
                "toggle",
                (currentEl) => currentEl.style.display = stickyDisplay
              );
              this.addOrRemoveClasses(el, inEndClasses, inStartClasses);
            });
          });
        };
        const onEnd = () => {
          this.addOrRemoveClasses(el, [], inClasses.concat(inEndClasses));
          el.dispatchEvent(new Event("phx:show-end"));
        };
        el.dispatchEvent(new Event("phx:show-start"));
        if (blocking === false) {
          onStart();
          setTimeout(onEnd, time);
        } else {
          view.transition(time, onStart, onEnd);
        }
      }
    } else {
      if (this.isVisible(el)) {
        window.requestAnimationFrame(() => {
          el.dispatchEvent(new Event("phx:hide-start"));
          dom_default.putSticky(
            el,
            "toggle",
            (currentEl) => currentEl.style.display = "none"
          );
          el.dispatchEvent(new Event("phx:hide-end"));
        });
      } else {
        window.requestAnimationFrame(() => {
          el.dispatchEvent(new Event("phx:show-start"));
          const stickyDisplay = display || this.defaultDisplay(el);
          dom_default.putSticky(
            el,
            "toggle",
            (currentEl) => currentEl.style.display = stickyDisplay
          );
          el.dispatchEvent(new Event("phx:show-end"));
        });
      }
    }
  },
  toggleClasses(el, classes, transition, time, view, blocking) {
    window.requestAnimationFrame(() => {
      const [prevAdds, prevRemoves] = dom_default.getSticky(el, "classes", [[], []]);
      const newAdds = classes.filter(
        (name) => prevAdds.indexOf(name) < 0 && !el.classList.contains(name)
      );
      const newRemoves = classes.filter(
        (name) => prevRemoves.indexOf(name) < 0 && el.classList.contains(name)
      );
      this.addOrRemoveClasses(
        el,
        newAdds,
        newRemoves,
        transition,
        time,
        view,
        blocking
      );
    });
  },
  toggleAttr(el, attr, val1, val2) {
    if (el.hasAttribute(attr)) {
      if (val2 !== void 0) {
        if (el.getAttribute(attr) === val1) {
          this.setOrRemoveAttrs(el, [[attr, val2]], []);
        } else {
          this.setOrRemoveAttrs(el, [[attr, val1]], []);
        }
      } else {
        this.setOrRemoveAttrs(el, [], [attr]);
      }
    } else {
      this.setOrRemoveAttrs(el, [[attr, val1]], []);
    }
  },
  addOrRemoveClasses(el, adds, removes, transition, time, view, blocking) {
    time = time || default_transition_time;
    const [transitionRun, transitionStart, transitionEnd] = transition || [
      [],
      [],
      []
    ];
    if (transitionRun.length > 0) {
      const onStart = () => {
        this.addOrRemoveClasses(
          el,
          transitionStart,
          [].concat(transitionRun).concat(transitionEnd)
        );
        window.requestAnimationFrame(() => {
          this.addOrRemoveClasses(el, transitionRun, []);
          window.requestAnimationFrame(
            () => this.addOrRemoveClasses(el, transitionEnd, transitionStart)
          );
        });
      };
      const onDone = () => this.addOrRemoveClasses(
        el,
        adds.concat(transitionEnd),
        removes.concat(transitionRun).concat(transitionStart)
      );
      if (blocking === false) {
        onStart();
        setTimeout(onDone, time);
      } else {
        view.transition(time, onStart, onDone);
      }
      return;
    }
    window.requestAnimationFrame(() => {
      const [prevAdds, prevRemoves] = dom_default.getSticky(el, "classes", [[], []]);
      const keepAdds = adds.filter(
        (name) => prevAdds.indexOf(name) < 0 && !el.classList.contains(name)
      );
      const keepRemoves = removes.filter(
        (name) => prevRemoves.indexOf(name) < 0 && el.classList.contains(name)
      );
      const newAdds = prevAdds.filter((name) => removes.indexOf(name) < 0).concat(keepAdds);
      const newRemoves = prevRemoves.filter((name) => adds.indexOf(name) < 0).concat(keepRemoves);
      dom_default.putSticky(el, "classes", (currentEl) => {
        currentEl.classList.remove(...newRemoves);
        currentEl.classList.add(...newAdds);
        return [newAdds, newRemoves];
      });
    });
  },
  setOrRemoveAttrs(el, sets, removes) {
    const [prevSets, prevRemoves] = dom_default.getSticky(el, "attrs", [[], []]);
    const alteredAttrs = sets.map(([attr, _val]) => attr).concat(removes);
    const newSets = prevSets.filter(([attr, _val]) => !alteredAttrs.includes(attr)).concat(sets);
    const newRemoves = prevRemoves.filter((attr) => !alteredAttrs.includes(attr)).concat(removes);
    dom_default.putSticky(el, "attrs", (currentEl) => {
      newRemoves.forEach((attr) => currentEl.removeAttribute(attr));
      newSets.forEach(([attr, val]) => currentEl.setAttribute(attr, val));
      return [newSets, newRemoves];
    });
  },
  hasAllClasses(el, classes) {
    return classes.every((name) => el.classList.contains(name));
  },
  isToggledOut(el, outClasses) {
    return !this.isVisible(el) || this.hasAllClasses(el, outClasses);
  },
  filterToEls(liveSocket, sourceEl, { to }) {
    const defaultQuery = () => {
      if (typeof to === "string") {
        return document.querySelectorAll(to);
      } else if (to.closest) {
        const toEl = sourceEl.closest(to.closest);
        return toEl ? [toEl] : [];
      } else if (to.inner) {
        return sourceEl.querySelectorAll(to.inner);
      }
    };
    return to ? liveSocket.jsQuerySelectorAll(sourceEl, to, defaultQuery) : [sourceEl];
  },
  defaultDisplay(el) {
    return { tr: "table-row", td: "table-cell" }[el.tagName.toLowerCase()] || "block";
  },
  transitionClasses(val) {
    if (!val) {
      return null;
    }
    let [trans, tStart, tEnd] = Array.isArray(val) ? val : [val.split(" "), [], []];
    trans = Array.isArray(trans) ? trans : trans.split(" ");
    tStart = Array.isArray(tStart) ? tStart : tStart.split(" ");
    tEnd = Array.isArray(tEnd) ? tEnd : tEnd.split(" ");
    return [trans, tStart, tEnd];
  }
};
var js_default = JS;

// js/phoenix_live_view/js_commands.ts
var js_commands_default = (liveSocket, eventType) => {
  return {
    exec(el, encodedJS) {
      liveSocket.execJS(el, encodedJS, eventType);
    },
    show(el, opts = {}) {
      const owner = liveSocket.owner(el);
      js_default.show(
        eventType,
        owner,
        el,
        opts.display,
        js_default.transitionClasses(opts.transition),
        opts.time,
        opts.blocking
      );
    },
    hide(el, opts = {}) {
      const owner = liveSocket.owner(el);
      js_default.hide(
        eventType,
        owner,
        el,
        null,
        js_default.transitionClasses(opts.transition),
        opts.time,
        opts.blocking
      );
    },
    toggle(el, opts = {}) {
      const owner = liveSocket.owner(el);
      const inTransition = js_default.transitionClasses(opts.in);
      const outTransition = js_default.transitionClasses(opts.out);
      js_default.toggle(
        eventType,
        owner,
        el,
        opts.display,
        inTransition,
        outTransition,
        opts.time,
        opts.blocking
      );
    },
    addClass(el, names, opts = {}) {
      const classNames = Array.isArray(names) ? names : names.split(" ");
      const owner = liveSocket.owner(el);
      js_default.addOrRemoveClasses(
        el,
        classNames,
        [],
        js_default.transitionClasses(opts.transition),
        opts.time,
        owner,
        opts.blocking
      );
    },
    removeClass(el, names, opts = {}) {
      const classNames = Array.isArray(names) ? names : names.split(" ");
      const owner = liveSocket.owner(el);
      js_default.addOrRemoveClasses(
        el,
        [],
        classNames,
        js_default.transitionClasses(opts.transition),
        opts.time,
        owner,
        opts.blocking
      );
    },
    toggleClass(el, names, opts = {}) {
      const classNames = Array.isArray(names) ? names : names.split(" ");
      const owner = liveSocket.owner(el);
      js_default.toggleClasses(
        el,
        classNames,
        js_default.transitionClasses(opts.transition),
        opts.time,
        owner,
        opts.blocking
      );
    },
    transition(el, transition, opts = {}) {
      const owner = liveSocket.owner(el);
      js_default.addOrRemoveClasses(
        el,
        [],
        [],
        js_default.transitionClasses(transition),
        opts.time,
        owner,
        opts.blocking
      );
    },
    setAttribute(el, attr, val) {
      js_default.setOrRemoveAttrs(el, [[attr, val]], []);
    },
    removeAttribute(el, attr) {
      js_default.setOrRemoveAttrs(el, [], [attr]);
    },
    toggleAttribute(el, attr, val1, val2) {
      js_default.toggleAttr(el, attr, val1, val2);
    },
    push(el, type, opts = {}) {
      liveSocket.withinOwners(el, (view) => {
        const data = opts.value || {};
        delete opts.value;
        let e = new CustomEvent("phx:exec", { detail: { sourceElement: el } });
        js_default.exec(e, eventType, type, view, el, ["push", { data, ...opts }]);
      });
    },
    navigate(href, opts = {}) {
      const customEvent = new CustomEvent("phx:exec");
      liveSocket.historyRedirect(
        customEvent,
        href,
        opts.replace ? "replace" : "push",
        null,
        null
      );
    },
    patch(href, opts = {}) {
      const customEvent = new CustomEvent("phx:exec");
      liveSocket.pushHistoryPatch(
        customEvent,
        href,
        opts.replace ? "replace" : "push",
        null
      );
    },
    ignoreAttributes(el, attrs) {
      js_default.ignoreAttrs(el, Array.isArray(attrs) ? attrs : [attrs]);
    }
  };
};

// js/phoenix_live_view/view_hook.ts
var HOOK_ID = "hookId";
var viewHookID = 1;
var ViewHook = class _ViewHook {
  static makeID() {
    return viewHookID++;
  }
  static elementID(el) {
    return dom_default.private(el, HOOK_ID);
  }
  constructor(view, el, callbacks) {
    this.el = el;
    this.__attachView(view);
    this.__listeners = /* @__PURE__ */ new Set();
    this.__isDisconnected = false;
    dom_default.putPrivate(this.el, HOOK_ID, _ViewHook.makeID());
    if (callbacks) {
      const protectedProps = /* @__PURE__ */ new Set([
        "el",
        "liveSocket",
        "__view",
        "__listeners",
        "__isDisconnected",
        "constructor",
        // Standard object properties
        // Core ViewHook API methods
        "js",
        "pushEvent",
        "pushEventTo",
        "handleEvent",
        "removeHandleEvent",
        "upload",
        "uploadTo",
        // Internal lifecycle callers
        "__mounted",
        "__updated",
        "__beforeUpdate",
        "__destroyed",
        "__reconnected",
        "__disconnected",
        "__cleanup__"
      ]);
      for (const key in callbacks) {
        if (Object.prototype.hasOwnProperty.call(callbacks, key)) {
          this[key] = callbacks[key];
          if (protectedProps.has(key)) {
            console.warn(
              `Hook object for element #${el.id} overwrites core property '${key}'!`
            );
          }
        }
      }
      const lifecycleMethods = [
        "mounted",
        "beforeUpdate",
        "updated",
        "destroyed",
        "disconnected",
        "reconnected"
      ];
      lifecycleMethods.forEach((methodName) => {
        if (callbacks[methodName] && typeof callbacks[methodName] === "function") {
          this[methodName] = callbacks[methodName];
        }
      });
    }
  }
  /** @internal */
  __attachView(view) {
    if (view) {
      this.__view = () => view;
      this.liveSocket = view.liveSocket;
    } else {
      this.__view = () => {
        throw new Error(
          `hook not yet attached to a live view: ${this.el.outerHTML}`
        );
      };
      this.liveSocket = null;
    }
  }
  // Default lifecycle methods
  mounted() {
  }
  beforeUpdate() {
  }
  updated() {
  }
  destroyed() {
  }
  disconnected() {
  }
  reconnected() {
  }
  // Internal lifecycle callers - called by the View
  /** @internal */
  __mounted() {
    this.mounted();
  }
  /** @internal */
  __updated() {
    this.updated();
  }
  /** @internal */
  __beforeUpdate() {
    this.beforeUpdate();
  }
  /** @internal */
  __destroyed() {
    this.destroyed();
    dom_default.deletePrivate(this.el, HOOK_ID);
  }
  /** @internal */
  __reconnected() {
    if (this.__isDisconnected) {
      this.__isDisconnected = false;
      this.reconnected();
    }
  }
  /** @internal */
  __disconnected() {
    this.__isDisconnected = true;
    this.disconnected();
  }
  js() {
    return {
      ...js_commands_default(this.__view().liveSocket, "hook"),
      exec: (encodedJS) => {
        this.__view().liveSocket.execJS(this.el, encodedJS, "hook");
      }
    };
  }
  pushEvent(event, payload, onReply) {
    const promise = this.__view().pushHookEvent(
      this.el,
      null,
      event,
      payload || {}
    );
    if (onReply === void 0) {
      return promise.then(({ reply }) => reply);
    }
    promise.then(({ reply, ref }) => onReply(reply, ref)).catch(() => {
    });
    return;
  }
  pushEventTo(selectorOrTarget, event, payload, onReply) {
    if (onReply === void 0) {
      const targetPair = [];
      this.__view().withinTargets(selectorOrTarget, (view, targetCtx) => {
        targetPair.push({ view, targetCtx });
      });
      const promises = targetPair.map(({ view, targetCtx }) => {
        return view.pushHookEvent(this.el, targetCtx, event, payload || {});
      });
      return Promise.allSettled(promises);
    }
    this.__view().withinTargets(selectorOrTarget, (view, targetCtx) => {
      view.pushHookEvent(this.el, targetCtx, event, payload || {}).then(({ reply, ref }) => onReply(reply, ref)).catch(() => {
      });
    });
    return;
  }
  handleEvent(event, callback) {
    const callbackRef = {
      event,
      callback: (customEvent) => callback(customEvent.detail)
    };
    window.addEventListener(
      `phx:${event}`,
      callbackRef.callback
    );
    this.__listeners.add(callbackRef);
    return callbackRef;
  }
  removeHandleEvent(ref) {
    window.removeEventListener(
      `phx:${ref.event}`,
      ref.callback
    );
    this.__listeners.delete(ref);
  }
  upload(name, files) {
    return this.__view().dispatchUploads(null, name, files);
  }
  uploadTo(selectorOrTarget, name, files) {
    return this.__view().withinTargets(selectorOrTarget, (view, targetCtx) => {
      view.dispatchUploads(targetCtx, name, files);
    });
  }
  /** @internal */
  __cleanup__() {
    this.__listeners.forEach(
      (callbackRef) => this.removeHandleEvent(callbackRef)
    );
  }
};

// js/phoenix_live_view/view.js
var prependFormDataKey = (key, prefix) => {
  const isArray = key.endsWith("[]");
  let baseKey = isArray ? key.slice(0, -2) : key;
  baseKey = baseKey.replace(/([^\[\]]+)(\]?$)/, `${prefix}$1$2`);
  if (isArray) {
    baseKey += "[]";
  }
  return baseKey;
};
var serializeForm = (form, opts, onlyNames = []) => {
  const { submitter } = opts;
  let injectedElement;
  if (submitter && submitter.name) {
    const input = document.createElement("input");
    input.type = "hidden";
    const formId = submitter.getAttribute("form");
    if (formId) {
      input.setAttribute("form", formId);
    }
    input.name = submitter.name;
    input.value = submitter.value;
    submitter.parentElement.insertBefore(input, submitter);
    injectedElement = input;
  }
  const formData = new FormData(form);
  const toRemove = [];
  formData.forEach((val, key, _index) => {
    if (val instanceof File) {
      toRemove.push(key);
    }
  });
  toRemove.forEach((key) => formData.delete(key));
  const params = new URLSearchParams();
  const { inputsUnused, onlyHiddenInputs } = Array.from(form.elements).reduce(
    (acc, input) => {
      const { inputsUnused: inputsUnused2, onlyHiddenInputs: onlyHiddenInputs2 } = acc;
      const key = input.name;
      if (!key) {
        return acc;
      }
      if (inputsUnused2[key] === void 0) {
        inputsUnused2[key] = true;
      }
      if (onlyHiddenInputs2[key] === void 0) {
        onlyHiddenInputs2[key] = true;
      }
      const isUsed = dom_default.private(input, PHX_HAS_FOCUSED) || dom_default.private(input, PHX_HAS_SUBMITTED);
      const isHidden = input.type === "hidden";
      inputsUnused2[key] = inputsUnused2[key] && !isUsed;
      onlyHiddenInputs2[key] = onlyHiddenInputs2[key] && isHidden;
      return acc;
    },
    { inputsUnused: {}, onlyHiddenInputs: {} }
  );
  for (const [key, val] of formData.entries()) {
    if (onlyNames.length === 0 || onlyNames.indexOf(key) >= 0) {
      const isUnused = inputsUnused[key];
      const hidden = onlyHiddenInputs[key];
      if (isUnused && !(submitter && submitter.name == key) && !hidden) {
        params.append(prependFormDataKey(key, "_unused_"), "");
      }
      if (typeof val === "string") {
        params.append(key, val);
      }
    }
  }
  if (submitter && injectedElement) {
    submitter.parentElement.removeChild(injectedElement);
  }
  return params.toString();
};
var View = class _View {
  static closestView(el) {
    const liveViewEl = el.closest(PHX_VIEW_SELECTOR);
    return liveViewEl ? dom_default.private(liveViewEl, "view") : null;
  }
  constructor(el, liveSocket, parentView, flash, liveReferer) {
    this.isDead = false;
    this.liveSocket = liveSocket;
    this.flash = flash;
    this.parent = parentView;
    this.root = parentView ? parentView.root : this;
    this.el = el;
    const boundView = dom_default.private(this.el, "view");
    if (boundView !== void 0 && boundView.isDead !== true) {
      logError(
        `The DOM element for this view has already been bound to a view.

        An element can only ever be associated with a single view!
        Please ensure that you are not trying to initialize multiple LiveSockets on the same page.
        This could happen if you're accidentally trying to render your root layout more than once.
        Ensure that the template set on the LiveView is different than the root layout.
      `,
        { view: boundView }
      );
      throw new Error("Cannot bind multiple views to the same DOM element.");
    }
    dom_default.putPrivate(this.el, "view", this);
    this.id = this.el.id;
    this.ref = 0;
    this.lastAckRef = null;
    this.childJoins = 0;
    this.loaderTimer = null;
    this.disconnectedTimer = null;
    this.pendingDiffs = [];
    this.pendingForms = /* @__PURE__ */ new Set();
    this.redirect = false;
    this.href = null;
    this.joinCount = this.parent ? this.parent.joinCount - 1 : 0;
    this.joinAttempts = 0;
    this.joinPending = true;
    this.destroyed = false;
    this.joinCallback = function(onDone) {
      onDone && onDone();
    };
    this.stopCallback = function() {
    };
    this.pendingJoinOps = [];
    this.viewHooks = {};
    this.formSubmits = [];
    this.children = this.parent ? null : {};
    this.root.children[this.id] = {};
    this.formsForRecovery = {};
    this.channel = this.liveSocket.channel(`lv:${this.id}`, () => {
      const url = this.href && this.expandURL(this.href);
      return {
        redirect: this.redirect ? url : void 0,
        url: this.redirect ? void 0 : url || void 0,
        params: this.connectParams(liveReferer),
        session: this.getSession(),
        static: this.getStatic(),
        flash: this.flash,
        sticky: this.el.hasAttribute(PHX_STICKY)
      };
    });
    this.portalElementIds = /* @__PURE__ */ new Set();
  }
  setHref(href) {
    this.href = href;
  }
  setRedirect(href) {
    this.redirect = true;
    this.href = href;
  }
  isMain() {
    return this.el.hasAttribute(PHX_MAIN);
  }
  connectParams(liveReferer) {
    const params = this.liveSocket.params(this.el);
    const manifest = dom_default.all(document, `[${this.binding(PHX_TRACK_STATIC)}]`).map((node) => node.src || node.href).filter((url) => typeof url === "string");
    if (manifest.length > 0) {
      params["_track_static"] = manifest;
    }
    params["_mounts"] = this.joinCount;
    params["_mount_attempts"] = this.joinAttempts;
    params["_live_referer"] = liveReferer;
    this.joinAttempts++;
    return params;
  }
  isConnected() {
    return this.channel.canPush();
  }
  getSession() {
    return this.el.getAttribute(PHX_SESSION);
  }
  getStatic() {
    const val = this.el.getAttribute(PHX_STATIC);
    return val === "" ? null : val;
  }
  destroy(callback = function() {
  }) {
    this.destroyAllChildren();
    this.destroyPortalElements();
    this.destroyed = true;
    dom_default.deletePrivate(this.el, "view");
    delete this.root.children[this.id];
    if (this.parent) {
      delete this.root.children[this.parent.id][this.id];
    }
    clearTimeout(this.loaderTimer);
    const onFinished = () => {
      callback();
      for (const id in this.viewHooks) {
        this.destroyHook(this.viewHooks[id]);
      }
    };
    dom_default.markPhxChildDestroyed(this.el);
    this.log("destroyed", () => ["the child has been removed from the parent"]);
    this.channel.leave().receive("ok", onFinished).receive("error", onFinished).receive("timeout", onFinished);
  }
  setContainerClasses(...classes) {
    this.el.classList.remove(
      PHX_CONNECTED_CLASS,
      PHX_LOADING_CLASS,
      PHX_ERROR_CLASS,
      PHX_CLIENT_ERROR_CLASS,
      PHX_SERVER_ERROR_CLASS
    );
    this.el.classList.add(...classes);
  }
  showLoader(timeout) {
    clearTimeout(this.loaderTimer);
    if (timeout) {
      this.loaderTimer = setTimeout(() => this.showLoader(), timeout);
    } else {
      for (const id in this.viewHooks) {
        this.viewHooks[id].__disconnected();
      }
      this.setContainerClasses(PHX_LOADING_CLASS);
    }
  }
  execAll(binding) {
    dom_default.all(
      this.el,
      `[${binding}]`,
      (el) => this.liveSocket.execJS(el, el.getAttribute(binding))
    );
  }
  hideLoader() {
    clearTimeout(this.loaderTimer);
    clearTimeout(this.disconnectedTimer);
    this.setContainerClasses(PHX_CONNECTED_CLASS);
    this.execAll(this.binding("connected"));
  }
  triggerReconnected() {
    for (const id in this.viewHooks) {
      this.viewHooks[id].__reconnected();
    }
  }
  log(kind, msgCallback) {
    this.liveSocket.log(this, kind, msgCallback);
  }
  transition(time, onStart, onDone = function() {
  }) {
    this.liveSocket.transition(time, onStart, onDone);
  }
  // calls the callback with the view and target element for the given phxTarget
  // targets can be:
  //  * an element itself, then it is simply passed to liveSocket.owner;
  //  * a CID (Component ID), then we first search the component's element in the DOM
  //  * a selector, then we search the selector in the DOM and call the callback
  //    for each element found with the corresponding owner view
  withinTargets(phxTarget, callback, dom = document) {
    if (phxTarget instanceof HTMLElement || phxTarget instanceof SVGElement) {
      return this.liveSocket.owner(
        phxTarget,
        (view) => callback(view, phxTarget)
      );
    }
    if (isCid(phxTarget)) {
      const targets = dom_default.findComponentNodeList(this.id, phxTarget, dom);
      if (targets.length === 0) {
        logError(`no component found matching phx-target of ${phxTarget}`);
      } else {
        callback(this, parseInt(phxTarget));
      }
    } else {
      const targets = Array.from(dom.querySelectorAll(phxTarget));
      if (targets.length === 0) {
        logError(
          `nothing found matching the phx-target selector "${phxTarget}"`
        );
      }
      targets.forEach(
        (target) => this.liveSocket.owner(target, (view) => callback(view, target))
      );
    }
  }
  applyDiff(type, rawDiff, callback) {
    this.log(type, () => ["", clone(rawDiff)]);
    const { diff, reply, events, title } = Rendered.extract(rawDiff);
    callback({ diff, reply, events });
    if (typeof title === "string" || type == "mount" && this.isMain()) {
      window.requestAnimationFrame(() => dom_default.putTitle(title));
    }
  }
  onJoin(resp) {
    const { rendered, container, liveview_version, pid } = resp;
    if (container) {
      const [tag, attrs] = container;
      this.el = dom_default.replaceRootContainer(this.el, tag, attrs);
    }
    this.childJoins = 0;
    this.joinPending = true;
    this.flash = null;
    if (this.root === this) {
      this.formsForRecovery = this.getFormsForRecovery();
    }
    if (this.isMain() && window.history.state === null) {
      browser_default.pushState("replace", {
        type: "patch",
        id: this.id,
        position: this.liveSocket.currentHistoryPosition
      });
    }
    if (liveview_version !== this.liveSocket.version()) {
      console.error(
        `LiveView asset version mismatch. JavaScript version ${this.liveSocket.version()} vs. server ${liveview_version}. To avoid issues, please ensure that your assets use the same version as the server.`
      );
    }
    if (pid) {
      this.el.setAttribute(PHX_LV_PID, pid);
    }
    browser_default.dropLocal(
      this.liveSocket.localStorage,
      window.location.pathname,
      CONSECUTIVE_RELOADS
    );
    this.applyDiff("mount", rendered, ({ diff, events }) => {
      this.rendered = new Rendered(this.id, diff);
      const [html, streams] = this.renderContainer(null, "join");
      this.dropPendingRefs();
      this.joinCount++;
      this.joinAttempts = 0;
      this.maybeRecoverForms(html, () => {
        this.onJoinComplete(resp, html, streams, events);
      });
    });
  }
  dropPendingRefs() {
    dom_default.all(document, `[${PHX_REF_SRC}="${this.refSrc()}"]`, (el) => {
      el.removeAttribute(PHX_REF_LOADING);
      el.removeAttribute(PHX_REF_SRC);
      el.removeAttribute(PHX_REF_LOCK);
    });
  }
  onJoinComplete({ live_patch }, html, streams, events) {
    if (this.joinCount > 1 || this.parent && !this.parent.isJoinPending()) {
      return this.applyJoinPatch(live_patch, html, streams, events);
    }
    const newChildren = dom_default.findPhxChildrenInFragment(html, this.id).filter(
      (toEl) => {
        const fromEl = toEl.id && this.el.querySelector(`[id="${toEl.id}"]`);
        const phxStatic = fromEl && fromEl.getAttribute(PHX_STATIC);
        if (phxStatic) {
          toEl.setAttribute(PHX_STATIC, phxStatic);
        }
        if (fromEl) {
          fromEl.setAttribute(PHX_ROOT_ID, this.root.id);
        }
        return this.joinChild(toEl);
      }
    );
    if (newChildren.length === 0) {
      if (this.parent) {
        this.root.pendingJoinOps.push([
          this,
          () => this.applyJoinPatch(live_patch, html, streams, events)
        ]);
        this.parent.ackJoin(this);
      } else {
        this.onAllChildJoinsComplete();
        this.applyJoinPatch(live_patch, html, streams, events);
      }
    } else {
      this.root.pendingJoinOps.push([
        this,
        () => this.applyJoinPatch(live_patch, html, streams, events)
      ]);
    }
  }
  attachTrueDocEl() {
    this.el = dom_default.byId(this.id);
    this.el.setAttribute(PHX_ROOT_ID, this.root.id);
  }
  // this is invoked for dead and live views, so we must filter by
  // by owner to ensure we aren't duplicating hooks across disconnect
  // and connected states. This also handles cases where hooks exist
  // in a root layout with a LV in the body
  execNewMounted(parent = document) {
    let phxViewportTop = this.binding(PHX_VIEWPORT_TOP);
    let phxViewportBottom = this.binding(PHX_VIEWPORT_BOTTOM);
    this.all(
      parent,
      `[${phxViewportTop}], [${phxViewportBottom}]`,
      (hookEl) => {
        dom_default.maintainPrivateHooks(
          hookEl,
          hookEl,
          phxViewportTop,
          phxViewportBottom
        );
        this.maybeAddNewHook(hookEl);
      }
    );
    this.all(
      parent,
      `[${this.binding(PHX_HOOK)}], [data-phx-${PHX_HOOK}]`,
      (hookEl) => {
        this.maybeAddNewHook(hookEl);
      }
    );
    this.all(parent, `[${this.binding(PHX_MOUNTED)}]`, (el) => {
      this.maybeMounted(el);
    });
  }
  all(parent, selector, callback) {
    dom_default.all(parent, selector, (el) => {
      if (this.ownsElement(el)) {
        callback(el);
      }
    });
  }
  applyJoinPatch(live_patch, html, streams, events) {
    if (this.joinCount > 1) {
      if (this.pendingJoinOps.length) {
        this.pendingJoinOps.forEach((cb) => typeof cb === "function" && cb());
        this.pendingJoinOps = [];
      }
    }
    this.attachTrueDocEl();
    const patch = new DOMPatch(this, this.el, this.id, html, streams, null);
    patch.markPrunableContentForRemoval();
    this.performPatch(patch, false, true);
    this.joinNewChildren();
    this.execNewMounted();
    this.joinPending = false;
    this.liveSocket.dispatchEvents(events);
    this.applyPendingUpdates();
    if (live_patch) {
      const { kind, to } = live_patch;
      this.liveSocket.historyPatch(to, kind);
    }
    this.hideLoader();
    if (this.joinCount > 1) {
      this.triggerReconnected();
    }
    this.stopCallback();
  }
  triggerBeforeUpdateHook(fromEl, toEl) {
    this.liveSocket.triggerDOM("onBeforeElUpdated", [fromEl, toEl]);
    const hook = this.getHook(fromEl);
    const isIgnored = hook && dom_default.isIgnored(fromEl, this.binding(PHX_UPDATE));
    if (hook && !fromEl.isEqualNode(toEl) && !(isIgnored && isEqualObj(fromEl.dataset, toEl.dataset))) {
      hook.__beforeUpdate();
      return hook;
    }
  }
  maybeMounted(el) {
    const phxMounted = el.getAttribute(this.binding(PHX_MOUNTED));
    const hasBeenInvoked = phxMounted && dom_default.private(el, "mounted");
    if (phxMounted && !hasBeenInvoked) {
      this.liveSocket.execJS(el, phxMounted);
      dom_default.putPrivate(el, "mounted", true);
    }
  }
  maybeAddNewHook(el) {
    const newHook = this.addHook(el);
    if (newHook) {
      newHook.__mounted();
    }
  }
  performPatch(patch, pruneCids, isJoinPatch = false) {
    const removedEls = [];
    let phxChildrenAdded = false;
    const updatedHookIds = /* @__PURE__ */ new Set();
    this.liveSocket.triggerDOM("onPatchStart", [patch.targetContainer]);
    patch.after("added", (el) => {
      this.liveSocket.triggerDOM("onNodeAdded", [el]);
      const phxViewportTop = this.binding(PHX_VIEWPORT_TOP);
      const phxViewportBottom = this.binding(PHX_VIEWPORT_BOTTOM);
      dom_default.maintainPrivateHooks(el, el, phxViewportTop, phxViewportBottom);
      this.maybeAddNewHook(el);
      if (el.getAttribute) {
        this.maybeMounted(el);
      }
    });
    patch.after("phxChildAdded", (el) => {
      if (dom_default.isPhxSticky(el)) {
        this.liveSocket.joinRootViews();
      } else {
        phxChildrenAdded = true;
      }
    });
    patch.before("updated", (fromEl, toEl) => {
      const hook = this.triggerBeforeUpdateHook(fromEl, toEl);
      if (hook) {
        updatedHookIds.add(fromEl.id);
      }
      js_default.onBeforeElUpdated(fromEl, toEl);
    });
    patch.after("updated", (el) => {
      if (updatedHookIds.has(el.id)) {
        this.getHook(el).__updated();
      }
    });
    patch.after("discarded", (el) => {
      if (el.nodeType === Node.ELEMENT_NODE) {
        removedEls.push(el);
      }
    });
    patch.after(
      "transitionsDiscarded",
      (els) => this.afterElementsRemoved(els, pruneCids)
    );
    patch.perform(isJoinPatch);
    this.afterElementsRemoved(removedEls, pruneCids);
    this.liveSocket.triggerDOM("onPatchEnd", [patch.targetContainer]);
    return phxChildrenAdded;
  }
  afterElementsRemoved(elements, pruneCids) {
    const destroyedCIDs = [];
    elements.forEach((parent) => {
      const components = dom_default.all(
        parent,
        `[${PHX_VIEW_REF}="${this.id}"][${PHX_COMPONENT}]`
      );
      const hooks = dom_default.all(
        parent,
        `[${this.binding(PHX_HOOK)}], [data-phx-hook]`
      );
      components.concat(parent).forEach((el) => {
        const cid = this.componentID(el);
        if (isCid(cid) && destroyedCIDs.indexOf(cid) === -1 && el.getAttribute(PHX_VIEW_REF) === this.id) {
          destroyedCIDs.push(cid);
        }
      });
      hooks.concat(parent).forEach((hookEl) => {
        const hook = this.getHook(hookEl);
        hook && this.destroyHook(hook);
      });
    });
    if (pruneCids) {
      this.maybePushComponentsDestroyed(destroyedCIDs);
    }
  }
  joinNewChildren() {
    dom_default.findPhxChildren(document, this.id).forEach((el) => this.joinChild(el));
  }
  maybeRecoverForms(html, callback) {
    const phxChange = this.binding("change");
    const oldForms = this.root.formsForRecovery;
    const template = document.createElement("template");
    template.innerHTML = html;
    dom_default.all(template.content, `[${PHX_PORTAL}]`).forEach((portalTemplate) => {
      template.content.firstElementChild.appendChild(
        portalTemplate.content.firstElementChild
      );
    });
    const rootEl = template.content.firstElementChild;
    rootEl.id = this.id;
    rootEl.setAttribute(PHX_ROOT_ID, this.root.id);
    rootEl.setAttribute(PHX_SESSION, this.getSession());
    rootEl.setAttribute(PHX_STATIC, this.getStatic());
    rootEl.setAttribute(PHX_PARENT_ID, this.parent ? this.parent.id : null);
    const formsToRecover = (
      // we go over all forms in the new DOM; because this is only the HTML for the current
      // view, we can be sure that all forms are owned by this view:
      dom_default.all(template.content, "form").filter((newForm) => newForm.id && oldForms[newForm.id]).filter((newForm) => !this.pendingForms.has(newForm.id)).filter(
        (newForm) => oldForms[newForm.id].getAttribute(phxChange) === newForm.getAttribute(phxChange)
      ).map((newForm) => {
        return [oldForms[newForm.id], newForm];
      })
    );
    if (formsToRecover.length === 0) {
      return callback();
    }
    formsToRecover.forEach(([oldForm, newForm], i) => {
      this.pendingForms.add(newForm.id);
      this.pushFormRecovery(
        oldForm,
        newForm,
        template.content.firstElementChild,
        () => {
          this.pendingForms.delete(newForm.id);
          if (i === formsToRecover.length - 1) {
            callback();
          }
        }
      );
    });
  }
  getChildById(id) {
    return this.root.children[this.id][id];
  }
  getDescendentByEl(el) {
    if (el.id === this.id) {
      return this;
    } else {
      return this.children[el.getAttribute(PHX_PARENT_ID)]?.[el.id];
    }
  }
  destroyDescendent(id) {
    for (const parentId in this.root.children) {
      for (const childId in this.root.children[parentId]) {
        if (childId === id) {
          return this.root.children[parentId][childId].destroy();
        }
      }
    }
  }
  joinChild(el) {
    const child = this.getChildById(el.id);
    if (!child) {
      const view = new _View(el, this.liveSocket, this);
      this.root.children[this.id][view.id] = view;
      view.join();
      this.childJoins++;
      return true;
    }
  }
  isJoinPending() {
    return this.joinPending;
  }
  ackJoin(_child) {
    this.childJoins--;
    if (this.childJoins === 0) {
      if (this.parent) {
        this.parent.ackJoin(this);
      } else {
        this.onAllChildJoinsComplete();
      }
    }
  }
  onAllChildJoinsComplete() {
    this.pendingForms.clear();
    this.formsForRecovery = {};
    this.joinCallback(() => {
      this.pendingJoinOps.forEach(([view, op]) => {
        if (!view.isDestroyed()) {
          op();
        }
      });
      this.pendingJoinOps = [];
    });
  }
  update(diff, events, isPending = false) {
    if (this.isJoinPending() || this.liveSocket.hasPendingLink() && this.root.isMain()) {
      if (!isPending) {
        this.pendingDiffs.push({ diff, events });
      }
      return false;
    }
    this.rendered.mergeDiff(diff);
    let phxChildrenAdded = false;
    if (this.rendered.isComponentOnlyDiff(diff)) {
      this.liveSocket.time("component patch complete", () => {
        const parentCids = dom_default.findExistingParentCIDs(
          this.id,
          this.rendered.componentCIDs(diff)
        );
        parentCids.forEach((parentCID) => {
          if (this.componentPatch(
            this.rendered.getComponent(diff, parentCID),
            parentCID
          )) {
            phxChildrenAdded = true;
          }
        });
      });
    } else if (!isEmpty(diff)) {
      this.liveSocket.time("full patch complete", () => {
        const [html, streams] = this.renderContainer(diff, "update");
        const patch = new DOMPatch(this, this.el, this.id, html, streams, null);
        phxChildrenAdded = this.performPatch(patch, true);
      });
    }
    this.liveSocket.dispatchEvents(events);
    if (phxChildrenAdded) {
      this.joinNewChildren();
    }
    return true;
  }
  renderContainer(diff, kind) {
    return this.liveSocket.time(`toString diff (${kind})`, () => {
      const tag = this.el.tagName;
      const cids = diff ? this.rendered.componentCIDs(diff) : null;
      const { buffer: html, streams } = this.rendered.toString(cids);
      return [`<${tag}>${html}</${tag}>`, streams];
    });
  }
  componentPatch(diff, cid) {
    if (isEmpty(diff))
      return false;
    const { buffer: html, streams } = this.rendered.componentToString(cid);
    const patch = new DOMPatch(this, this.el, this.id, html, streams, cid);
    const childrenAdded = this.performPatch(patch, true);
    return childrenAdded;
  }
  getHook(el) {
    return this.viewHooks[ViewHook.elementID(el)];
  }
  addHook(el) {
    const hookElId = ViewHook.elementID(el);
    if (el.getAttribute && !this.ownsElement(el)) {
      return;
    }
    if (hookElId && !this.viewHooks[hookElId]) {
      const hook = dom_default.getCustomElHook(el) || logError(`no hook found for custom element: ${el.id}`);
      this.viewHooks[hookElId] = hook;
      hook.__attachView(this);
      return hook;
    } else if (hookElId || !el.getAttribute) {
      return;
    } else {
      const hookName = el.getAttribute(`data-phx-${PHX_HOOK}`) || el.getAttribute(this.binding(PHX_HOOK));
      if (!hookName) {
        return;
      }
      const hookDefinition = this.liveSocket.getHookDefinition(hookName);
      if (hookDefinition) {
        if (!el.id) {
          logError(
            `no DOM ID for hook "${hookName}". Hooks require a unique ID on each element.`,
            el
          );
          return;
        }
        let hookInstance;
        try {
          if (typeof hookDefinition === "function" && hookDefinition.prototype instanceof ViewHook) {
            hookInstance = new hookDefinition(this, el);
          } else if (typeof hookDefinition === "object" && hookDefinition !== null) {
            hookInstance = new ViewHook(this, el, hookDefinition);
          } else {
            logError(
              `Invalid hook definition for "${hookName}". Expected a class extending ViewHook or an object definition.`,
              el
            );
            return;
          }
        } catch (e) {
          const errorMessage = e instanceof Error ? e.message : String(e);
          logError(`Failed to create hook "${hookName}": ${errorMessage}`, el);
          return;
        }
        this.viewHooks[ViewHook.elementID(hookInstance.el)] = hookInstance;
        return hookInstance;
      } else if (hookName !== null) {
        logError(`unknown hook found for "${hookName}"`, el);
      }
    }
  }
  destroyHook(hook) {
    const hookId = ViewHook.elementID(hook.el);
    hook.__destroyed();
    hook.__cleanup__();
    delete this.viewHooks[hookId];
  }
  applyPendingUpdates() {
    this.pendingDiffs = this.pendingDiffs.filter(
      ({ diff, events }) => !this.update(diff, events, true)
    );
    this.eachChild((child) => child.applyPendingUpdates());
  }
  eachChild(callback) {
    const children = this.root.children[this.id] || {};
    for (const id in children) {
      callback(this.getChildById(id));
    }
  }
  onChannel(event, cb) {
    this.liveSocket.onChannel(this.channel, event, (resp) => {
      if (this.isJoinPending()) {
        if (this.joinCount > 1) {
          this.pendingJoinOps.push(() => cb(resp));
        } else {
          this.root.pendingJoinOps.push([this, () => cb(resp)]);
        }
      } else {
        this.liveSocket.requestDOMUpdate(() => cb(resp));
      }
    });
  }
  bindChannel() {
    this.liveSocket.onChannel(this.channel, "diff", (rawDiff) => {
      this.liveSocket.requestDOMUpdate(() => {
        this.applyDiff(
          "update",
          rawDiff,
          ({ diff, events }) => this.update(diff, events)
        );
      });
    });
    this.onChannel(
      "redirect",
      ({ to, flash }) => this.onRedirect({ to, flash })
    );
    this.onChannel("live_patch", (redir) => this.onLivePatch(redir));
    this.onChannel("live_redirect", (redir) => this.onLiveRedirect(redir));
    this.channel.onError((reason) => this.onError(reason));
    this.channel.onClose((reason) => this.onClose(reason));
  }
  destroyAllChildren() {
    this.eachChild((child) => child.destroy());
  }
  onLiveRedirect(redir) {
    const { to, kind, flash } = redir;
    const url = this.expandURL(to);
    const e = new CustomEvent("phx:server-navigate", {
      detail: { to, kind, flash }
    });
    this.liveSocket.historyRedirect(e, url, kind, flash);
  }
  onLivePatch(redir) {
    const { to, kind } = redir;
    this.href = this.expandURL(to);
    this.liveSocket.historyPatch(to, kind);
  }
  expandURL(to) {
    return to.startsWith("/") ? `${window.location.protocol}//${window.location.host}${to}` : to;
  }
  /**
   * @param {{to: string, flash?: string, reloadToken?: string}} redirect
   */
  onRedirect({ to, flash, reloadToken }) {
    this.liveSocket.redirect(to, flash, reloadToken);
  }
  isDestroyed() {
    return this.destroyed;
  }
  joinDead() {
    this.isDead = true;
  }
  joinPush() {
    this.joinPush = this.joinPush || this.channel.join();
    return this.joinPush;
  }
  join(callback) {
    this.showLoader(this.liveSocket.loaderTimeout);
    this.bindChannel();
    if (this.isMain()) {
      this.stopCallback = this.liveSocket.withPageLoading({
        to: this.href,
        kind: "initial"
      });
    }
    this.joinCallback = (onDone) => {
      onDone = onDone || function() {
      };
      callback ? callback(this.joinCount, onDone) : onDone();
    };
    this.wrapPush(() => this.channel.join(), {
      ok: (resp) => this.liveSocket.requestDOMUpdate(() => this.onJoin(resp)),
      error: (error) => this.onJoinError(error),
      timeout: () => this.onJoinError({ reason: "timeout" })
    });
  }
  onJoinError(resp) {
    if (resp.reason === "reload") {
      this.log("error", () => [
        `failed mount with ${resp.status}. Falling back to page reload`,
        resp
      ]);
      this.onRedirect({ to: this.root.href, reloadToken: resp.token });
      return;
    } else if (resp.reason === "unauthorized" || resp.reason === "stale") {
      this.log("error", () => [
        "unauthorized live_redirect. Falling back to page request",
        resp
      ]);
      this.onRedirect({ to: this.root.href, flash: this.flash });
      return;
    }
    if (resp.redirect || resp.live_redirect) {
      this.joinPending = false;
      this.channel.leave();
    }
    if (resp.redirect) {
      return this.onRedirect(resp.redirect);
    }
    if (resp.live_redirect) {
      return this.onLiveRedirect(resp.live_redirect);
    }
    this.log("error", () => ["unable to join", resp]);
    if (this.isMain()) {
      this.displayError(
        [PHX_LOADING_CLASS, PHX_ERROR_CLASS, PHX_SERVER_ERROR_CLASS],
        { unstructuredError: resp, errorKind: "server" }
      );
      if (this.liveSocket.isConnected()) {
        this.liveSocket.reloadWithJitter(this);
      }
    } else {
      if (this.joinAttempts >= MAX_CHILD_JOIN_ATTEMPTS) {
        this.root.displayError(
          [PHX_LOADING_CLASS, PHX_ERROR_CLASS, PHX_SERVER_ERROR_CLASS],
          { unstructuredError: resp, errorKind: "server" }
        );
        this.log("error", () => [
          `giving up trying to mount after ${MAX_CHILD_JOIN_ATTEMPTS} tries`,
          resp
        ]);
        this.destroy();
      }
      const trueChildEl = dom_default.byId(this.el.id);
      if (trueChildEl) {
        dom_default.mergeAttrs(trueChildEl, this.el);
        this.displayError(
          [PHX_LOADING_CLASS, PHX_ERROR_CLASS, PHX_SERVER_ERROR_CLASS],
          { unstructuredError: resp, errorKind: "server" }
        );
        this.el = trueChildEl;
      } else {
        this.destroy();
      }
    }
  }
  onClose(reason) {
    if (this.isDestroyed()) {
      return;
    }
    if (this.isMain() && this.liveSocket.hasPendingLink() && reason !== "leave") {
      return this.liveSocket.reloadWithJitter(this);
    }
    this.destroyAllChildren();
    this.liveSocket.dropActiveElement(this);
    if (this.liveSocket.isUnloaded()) {
      this.showLoader(BEFORE_UNLOAD_LOADER_TIMEOUT);
    }
  }
  onError(reason) {
    this.onClose(reason);
    if (this.liveSocket.isConnected()) {
      this.log("error", () => ["view crashed", reason]);
    }
    if (!this.liveSocket.isUnloaded()) {
      if (this.liveSocket.isConnected()) {
        this.displayError(
          [PHX_LOADING_CLASS, PHX_ERROR_CLASS, PHX_SERVER_ERROR_CLASS],
          { unstructuredError: reason, errorKind: "server" }
        );
      } else {
        this.displayError(
          [PHX_LOADING_CLASS, PHX_ERROR_CLASS, PHX_CLIENT_ERROR_CLASS],
          { unstructuredError: reason, errorKind: "client" }
        );
      }
    }
  }
  displayError(classes, details = {}) {
    if (this.isMain()) {
      dom_default.dispatchEvent(window, "phx:page-loading-start", {
        detail: { to: this.href, kind: "error", ...details }
      });
    }
    this.showLoader();
    this.setContainerClasses(...classes);
    this.delayedDisconnected();
  }
  delayedDisconnected() {
    this.disconnectedTimer = setTimeout(() => {
      this.execAll(this.binding("disconnected"));
    }, this.liveSocket.disconnectedTimeout);
  }
  wrapPush(callerPush, receives) {
    const latency = this.liveSocket.getLatencySim();
    const withLatency = latency ? (cb) => setTimeout(() => !this.isDestroyed() && cb(), latency) : (cb) => !this.isDestroyed() && cb();
    withLatency(() => {
      callerPush().receive(
        "ok",
        (resp) => withLatency(() => receives.ok && receives.ok(resp))
      ).receive(
        "error",
        (reason) => withLatency(() => receives.error && receives.error(reason))
      ).receive(
        "timeout",
        () => withLatency(() => receives.timeout && receives.timeout())
      );
    });
  }
  pushWithReply(refGenerator, event, payload) {
    if (!this.isConnected()) {
      return Promise.reject(new Error("no connection"));
    }
    const [ref, [el], opts] = refGenerator ? refGenerator({ payload }) : [null, [], {}];
    const oldJoinCount = this.joinCount;
    let onLoadingDone = function() {
    };
    if (opts.page_loading) {
      onLoadingDone = this.liveSocket.withPageLoading({
        kind: "element",
        target: el
      });
    }
    if (typeof payload.cid !== "number") {
      delete payload.cid;
    }
    return new Promise((resolve, reject) => {
      this.wrapPush(() => this.channel.push(event, payload, PUSH_TIMEOUT), {
        ok: (resp) => {
          if (ref !== null) {
            this.lastAckRef = ref;
          }
          const finish = (hookReply) => {
            if (resp.redirect) {
              this.onRedirect(resp.redirect);
            }
            if (resp.live_patch) {
              this.onLivePatch(resp.live_patch);
            }
            if (resp.live_redirect) {
              this.onLiveRedirect(resp.live_redirect);
            }
            onLoadingDone();
            resolve({ resp, reply: hookReply, ref });
          };
          if (resp.diff) {
            this.liveSocket.requestDOMUpdate(() => {
              this.applyDiff("update", resp.diff, ({ diff, reply, events }) => {
                if (ref !== null) {
                  this.undoRefs(ref, payload.event);
                }
                this.update(diff, events);
                finish(reply);
              });
            });
          } else {
            if (ref !== null) {
              this.undoRefs(ref, payload.event);
            }
            finish(null);
          }
        },
        error: (reason) => reject(new Error(`failed with reason: ${JSON.stringify(reason)}`)),
        timeout: () => {
          reject(new Error("timeout"));
          if (this.joinCount === oldJoinCount) {
            this.liveSocket.reloadWithJitter(this, () => {
              this.log("timeout", () => [
                "received timeout while communicating with server. Falling back to hard refresh for recovery"
              ]);
            });
          }
        }
      });
    });
  }
  undoRefs(ref, phxEvent, onlyEls) {
    if (!this.isConnected()) {
      return;
    }
    const selector = `[${PHX_REF_SRC}="${this.refSrc()}"]`;
    if (onlyEls) {
      onlyEls = new Set(onlyEls);
      dom_default.all(document, selector, (parent) => {
        if (onlyEls && !onlyEls.has(parent)) {
          return;
        }
        dom_default.all(
          parent,
          selector,
          (child) => this.undoElRef(child, ref, phxEvent)
        );
        this.undoElRef(parent, ref, phxEvent);
      });
    } else {
      dom_default.all(document, selector, (el) => this.undoElRef(el, ref, phxEvent));
    }
  }
  undoElRef(el, ref, phxEvent) {
    const elRef = new ElementRef(el);
    elRef.maybeUndo(ref, phxEvent, (clonedTree) => {
      const patch = new DOMPatch(this, el, this.id, clonedTree, [], null, {
        undoRef: ref
      });
      const phxChildrenAdded = this.performPatch(patch, true);
      dom_default.all(
        el,
        `[${PHX_REF_SRC}="${this.refSrc()}"]`,
        (child) => this.undoElRef(child, ref, phxEvent)
      );
      if (phxChildrenAdded) {
        this.joinNewChildren();
      }
    });
  }
  refSrc() {
    return this.el.id;
  }
  putRef(elements, phxEvent, eventType, opts = {}) {
    const newRef = this.ref++;
    const disableWith = this.binding(PHX_DISABLE_WITH);
    if (opts.loading) {
      const loadingEls = dom_default.all(document, opts.loading).map((el) => {
        return { el, lock: true, loading: true };
      });
      elements = elements.concat(loadingEls);
    }
    for (const { el, lock, loading } of elements) {
      if (!lock && !loading) {
        throw new Error("putRef requires lock or loading");
      }
      el.setAttribute(PHX_REF_SRC, this.refSrc());
      if (loading) {
        el.setAttribute(PHX_REF_LOADING, newRef);
      }
      if (lock) {
        el.setAttribute(PHX_REF_LOCK, newRef);
      }
      if (!loading || opts.submitter && !(el === opts.submitter || el === opts.form)) {
        continue;
      }
      const lockCompletePromise = new Promise((resolve) => {
        el.addEventListener(`phx:undo-lock:${newRef}`, () => resolve(detail), {
          once: true
        });
      });
      const loadingCompletePromise = new Promise((resolve) => {
        el.addEventListener(
          `phx:undo-loading:${newRef}`,
          () => resolve(detail),
          { once: true }
        );
      });
      el.classList.add(`phx-${eventType}-loading`);
      const disableText = el.getAttribute(disableWith);
      if (disableText !== null) {
        if (!el.getAttribute(PHX_DISABLE_WITH_RESTORE)) {
          el.setAttribute(PHX_DISABLE_WITH_RESTORE, el.innerText);
        }
        if (disableText !== "") {
          el.innerText = disableText;
        }
        el.setAttribute(
          PHX_DISABLED,
          el.getAttribute(PHX_DISABLED) || el.disabled
        );
        el.setAttribute("disabled", "");
      }
      const detail = {
        event: phxEvent,
        eventType,
        ref: newRef,
        isLoading: loading,
        isLocked: lock,
        lockElements: elements.filter(({ lock: lock2 }) => lock2).map(({ el: el2 }) => el2),
        loadingElements: elements.filter(({ loading: loading2 }) => loading2).map(({ el: el2 }) => el2),
        unlock: (els) => {
          els = Array.isArray(els) ? els : [els];
          this.undoRefs(newRef, phxEvent, els);
        },
        lockComplete: lockCompletePromise,
        loadingComplete: loadingCompletePromise,
        lock: (lockEl) => {
          return new Promise((resolve) => {
            if (this.isAcked(newRef)) {
              return resolve(detail);
            }
            lockEl.setAttribute(PHX_REF_LOCK, newRef);
            lockEl.setAttribute(PHX_REF_SRC, this.refSrc());
            lockEl.addEventListener(
              `phx:lock-stop:${newRef}`,
              () => resolve(detail),
              { once: true }
            );
          });
        }
      };
      if (opts.payload) {
        detail["payload"] = opts.payload;
      }
      if (opts.target) {
        detail["target"] = opts.target;
      }
      if (opts.originalEvent) {
        detail["originalEvent"] = opts.originalEvent;
      }
      el.dispatchEvent(
        new CustomEvent("phx:push", {
          detail,
          bubbles: true,
          cancelable: false
        })
      );
      if (phxEvent) {
        el.dispatchEvent(
          new CustomEvent(`phx:push:${phxEvent}`, {
            detail,
            bubbles: true,
            cancelable: false
          })
        );
      }
    }
    return [newRef, elements.map(({ el }) => el), opts];
  }
  isAcked(ref) {
    return this.lastAckRef !== null && this.lastAckRef >= ref;
  }
  componentID(el) {
    const cid = el.getAttribute && el.getAttribute(PHX_COMPONENT);
    return cid ? parseInt(cid) : null;
  }
  targetComponentID(target, targetCtx, opts = {}) {
    if (isCid(targetCtx)) {
      return targetCtx;
    }
    const cidOrSelector = opts.target || target.getAttribute(this.binding("target"));
    if (isCid(cidOrSelector)) {
      return parseInt(cidOrSelector);
    } else if (targetCtx && (cidOrSelector !== null || opts.target)) {
      return this.closestComponentID(targetCtx);
    } else {
      return null;
    }
  }
  closestComponentID(targetCtx) {
    if (isCid(targetCtx)) {
      return targetCtx;
    } else if (targetCtx) {
      return maybe(
        targetCtx.closest(`[${PHX_COMPONENT}]`),
        (el) => this.ownsElement(el) && this.componentID(el)
      );
    } else {
      return null;
    }
  }
  pushHookEvent(el, targetCtx, event, payload) {
    if (!this.isConnected()) {
      this.log("hook", () => [
        "unable to push hook event. LiveView not connected",
        event,
        payload
      ]);
      return Promise.reject(
        new Error("unable to push hook event. LiveView not connected")
      );
    }
    const refGenerator = () => this.putRef([{ el, loading: true, lock: true }], event, "hook", {
      payload,
      target: targetCtx
    });
    return this.pushWithReply(refGenerator, "event", {
      type: "hook",
      event,
      value: payload,
      cid: this.closestComponentID(targetCtx)
    }).then(({ resp: _resp, reply, ref }) => ({ reply, ref }));
  }
  extractMeta(el, meta, value) {
    const prefix = this.binding("value-");
    for (let i = 0; i < el.attributes.length; i++) {
      if (!meta) {
        meta = {};
      }
      const name = el.attributes[i].name;
      if (name.startsWith(prefix)) {
        meta[name.replace(prefix, "")] = el.getAttribute(name);
      }
    }
    if (el.value !== void 0 && !(el instanceof HTMLFormElement)) {
      if (!meta) {
        meta = {};
      }
      meta.value = el.value;
      if (el.tagName === "INPUT" && CHECKABLE_INPUTS.indexOf(el.type) >= 0 && !el.checked) {
        delete meta.value;
      }
    }
    if (value) {
      if (!meta) {
        meta = {};
      }
      for (const key in value) {
        meta[key] = value[key];
      }
    }
    return meta;
  }
  pushEvent(type, el, targetCtx, phxEvent, meta, opts = {}, onReply) {
    this.pushWithReply(
      (maybePayload) => this.putRef([{ el, loading: true, lock: true }], phxEvent, type, {
        ...opts,
        payload: maybePayload?.payload
      }),
      "event",
      {
        type,
        event: phxEvent,
        value: this.extractMeta(el, meta, opts.value),
        cid: this.targetComponentID(el, targetCtx, opts)
      }
    ).then(({ reply }) => onReply && onReply(reply)).catch((error) => logError("Failed to push event", error));
  }
  pushFileProgress(fileEl, entryRef, progress, onReply = function() {
  }) {
    this.liveSocket.withinOwners(fileEl.form, (view, targetCtx) => {
      view.pushWithReply(null, "progress", {
        event: fileEl.getAttribute(view.binding(PHX_PROGRESS)),
        ref: fileEl.getAttribute(PHX_UPLOAD_REF),
        entry_ref: entryRef,
        progress,
        cid: view.targetComponentID(fileEl.form, targetCtx)
      }).then(() => onReply()).catch((error) => logError("Failed to push file progress", error));
    });
  }
  pushInput(inputEl, targetCtx, forceCid, phxEvent, opts, callback) {
    if (!inputEl.form) {
      throw new Error("form events require the input to be inside a form");
    }
    let uploads;
    const cid = isCid(forceCid) ? forceCid : this.targetComponentID(inputEl.form, targetCtx, opts);
    const refGenerator = (maybePayload) => {
      return this.putRef(
        [
          { el: inputEl, loading: true, lock: true },
          { el: inputEl.form, loading: true, lock: true }
        ],
        phxEvent,
        "change",
        { ...opts, payload: maybePayload?.payload }
      );
    };
    let formData;
    const meta = this.extractMeta(inputEl.form, {}, opts.value);
    const serializeOpts = {};
    if (inputEl instanceof HTMLButtonElement) {
      serializeOpts.submitter = inputEl;
    }
    if (inputEl.getAttribute(this.binding("change"))) {
      formData = serializeForm(inputEl.form, serializeOpts, [inputEl.name]);
    } else {
      formData = serializeForm(inputEl.form, serializeOpts);
    }
    if (dom_default.isUploadInput(inputEl) && inputEl.files && inputEl.files.length > 0) {
      LiveUploader.trackFiles(inputEl, Array.from(inputEl.files));
    }
    uploads = LiveUploader.serializeUploads(inputEl);
    const event = {
      type: "form",
      event: phxEvent,
      value: formData,
      meta: {
        // no target was implicitly sent as "undefined" in LV <= 1.0.5, therefore
        // we have to keep it. In 1.0.6 we switched from passing meta as URL encoded data
        // to passing it directly in the event, but the JSON encode would drop keys with
        // undefined values.
        _target: opts._target || "undefined",
        ...meta
      },
      uploads,
      cid
    };
    this.pushWithReply(refGenerator, "event", event).then(({ resp }) => {
      if (dom_default.isUploadInput(inputEl) && dom_default.isAutoUpload(inputEl)) {
        ElementRef.onUnlock(inputEl, () => {
          if (LiveUploader.filesAwaitingPreflight(inputEl).length > 0) {
            const [ref, _els] = refGenerator();
            this.undoRefs(ref, phxEvent, [inputEl.form]);
            this.uploadFiles(
              inputEl.form,
              phxEvent,
              targetCtx,
              ref,
              cid,
              (_uploads) => {
                callback && callback(resp);
                this.triggerAwaitingSubmit(inputEl.form, phxEvent);
                this.undoRefs(ref, phxEvent);
              }
            );
          }
        });
      } else {
        callback && callback(resp);
      }
    }).catch((error) => logError("Failed to push input event", error));
  }
  triggerAwaitingSubmit(formEl, phxEvent) {
    const awaitingSubmit = this.getScheduledSubmit(formEl);
    if (awaitingSubmit) {
      const [_el, _ref, _opts, callback] = awaitingSubmit;
      this.cancelSubmit(formEl, phxEvent);
      callback();
    }
  }
  getScheduledSubmit(formEl) {
    return this.formSubmits.find(
      ([el, _ref, _opts, _callback]) => el.isSameNode(formEl)
    );
  }
  scheduleSubmit(formEl, ref, opts, callback) {
    if (this.getScheduledSubmit(formEl)) {
      return true;
    }
    this.formSubmits.push([formEl, ref, opts, callback]);
  }
  cancelSubmit(formEl, phxEvent) {
    this.formSubmits = this.formSubmits.filter(
      ([el, ref, _opts, _callback]) => {
        if (el.isSameNode(formEl)) {
          this.undoRefs(ref, phxEvent);
          return false;
        } else {
          return true;
        }
      }
    );
  }
  disableForm(formEl, phxEvent, opts = {}) {
    const filterIgnored = (el) => {
      const userIgnored = closestPhxBinding(
        el,
        `${this.binding(PHX_UPDATE)}=ignore`,
        el.form
      );
      return !(userIgnored || closestPhxBinding(el, "data-phx-update=ignore", el.form));
    };
    const filterDisables = (el) => {
      return el.hasAttribute(this.binding(PHX_DISABLE_WITH));
    };
    const filterButton = (el) => el.tagName == "BUTTON";
    const filterInput = (el) => ["INPUT", "TEXTAREA", "SELECT"].includes(el.tagName);
    const formElements = Array.from(formEl.elements);
    const disables = formElements.filter(filterDisables);
    const buttons = formElements.filter(filterButton).filter(filterIgnored);
    const inputs = formElements.filter(filterInput).filter(filterIgnored);
    buttons.forEach((button) => {
      button.setAttribute(PHX_DISABLED, button.disabled);
      button.disabled = true;
    });
    inputs.forEach((input) => {
      input.setAttribute(PHX_READONLY, input.readOnly);
      input.readOnly = true;
      if (input.files) {
        input.setAttribute(PHX_DISABLED, input.disabled);
        input.disabled = true;
      }
    });
    const formEls = disables.concat(buttons).concat(inputs).map((el) => {
      return { el, loading: true, lock: true };
    });
    const els = [{ el: formEl, loading: true, lock: false }].concat(formEls).reverse();
    return this.putRef(els, phxEvent, "submit", opts);
  }
  pushFormSubmit(formEl, targetCtx, phxEvent, submitter, opts, onReply) {
    const refGenerator = (maybePayload) => this.disableForm(formEl, phxEvent, {
      ...opts,
      form: formEl,
      payload: maybePayload?.payload,
      submitter
    });
    dom_default.putPrivate(formEl, "submitter", submitter);
    const cid = this.targetComponentID(formEl, targetCtx);
    if (LiveUploader.hasUploadsInProgress(formEl)) {
      const [ref, _els] = refGenerator();
      const push = () => this.pushFormSubmit(
        formEl,
        targetCtx,
        phxEvent,
        submitter,
        opts,
        onReply
      );
      return this.scheduleSubmit(formEl, ref, opts, push);
    } else if (LiveUploader.inputsAwaitingPreflight(formEl).length > 0) {
      const [ref, els] = refGenerator();
      const proxyRefGen = () => [ref, els, opts];
      this.uploadFiles(formEl, phxEvent, targetCtx, ref, cid, (_uploads) => {
        if (LiveUploader.inputsAwaitingPreflight(formEl).length > 0) {
          return this.undoRefs(ref, phxEvent);
        }
        const meta = this.extractMeta(formEl, {}, opts.value);
        const formData = serializeForm(formEl, { submitter });
        this.pushWithReply(proxyRefGen, "event", {
          type: "form",
          event: phxEvent,
          value: formData,
          meta,
          cid
        }).then(({ resp }) => onReply(resp)).catch((error) => logError("Failed to push form submit", error));
      });
    } else if (!(formEl.hasAttribute(PHX_REF_SRC) && formEl.classList.contains("phx-submit-loading"))) {
      const meta = this.extractMeta(formEl, {}, opts.value);
      const formData = serializeForm(formEl, { submitter });
      this.pushWithReply(refGenerator, "event", {
        type: "form",
        event: phxEvent,
        value: formData,
        meta,
        cid
      }).then(({ resp }) => onReply(resp)).catch((error) => logError("Failed to push form submit", error));
    }
  }
  uploadFiles(formEl, phxEvent, targetCtx, ref, cid, onComplete) {
    const joinCountAtUpload = this.joinCount;
    const inputEls = LiveUploader.activeFileInputs(formEl);
    let numFileInputsInProgress = inputEls.length;
    inputEls.forEach((inputEl) => {
      const uploader = new LiveUploader(inputEl, this, () => {
        numFileInputsInProgress--;
        if (numFileInputsInProgress === 0) {
          onComplete();
        }
      });
      const entries = uploader.entries().map((entry) => entry.toPreflightPayload());
      if (entries.length === 0) {
        numFileInputsInProgress--;
        return;
      }
      const payload = {
        ref: inputEl.getAttribute(PHX_UPLOAD_REF),
        entries,
        cid: this.targetComponentID(inputEl.form, targetCtx)
      };
      this.log("upload", () => ["sending preflight request", payload]);
      this.pushWithReply(null, "allow_upload", payload).then(({ resp }) => {
        this.log("upload", () => ["got preflight response", resp]);
        uploader.entries().forEach((entry) => {
          if (resp.entries && !resp.entries[entry.ref]) {
            this.handleFailedEntryPreflight(
              entry.ref,
              "failed preflight",
              uploader
            );
          }
        });
        if (resp.error || Object.keys(resp.entries).length === 0) {
          this.undoRefs(ref, phxEvent);
          const errors = resp.error || [];
          errors.map(([entry_ref, reason]) => {
            this.handleFailedEntryPreflight(entry_ref, reason, uploader);
          });
        } else {
          const onError = (callback) => {
            this.channel.onError(() => {
              if (this.joinCount === joinCountAtUpload) {
                callback();
              }
            });
          };
          uploader.initAdapterUpload(resp, onError, this.liveSocket);
        }
      }).catch((error) => logError("Failed to push upload", error));
    });
  }
  handleFailedEntryPreflight(uploadRef, reason, uploader) {
    if (uploader.isAutoUpload()) {
      const entry = uploader.entries().find((entry2) => entry2.ref === uploadRef.toString());
      if (entry) {
        entry.cancel();
      }
    } else {
      uploader.entries().map((entry) => entry.cancel());
    }
    this.log("upload", () => [`error for entry ${uploadRef}`, reason]);
  }
  dispatchUploads(targetCtx, name, filesOrBlobs) {
    const targetElement = this.targetCtxElement(targetCtx) || this.el;
    const inputs = dom_default.findUploadInputs(targetElement).filter(
      (el) => el.name === name
    );
    if (inputs.length === 0) {
      logError(`no live file inputs found matching the name "${name}"`);
    } else if (inputs.length > 1) {
      logError(`duplicate live file inputs found matching the name "${name}"`);
    } else {
      dom_default.dispatchEvent(inputs[0], PHX_TRACK_UPLOADS, {
        detail: { files: filesOrBlobs }
      });
    }
  }
  targetCtxElement(targetCtx) {
    if (isCid(targetCtx)) {
      const [target] = dom_default.findComponentNodeList(this.id, targetCtx);
      return target;
    } else if (targetCtx) {
      return targetCtx;
    } else {
      return null;
    }
  }
  pushFormRecovery(oldForm, newForm, templateDom, callback) {
    const phxChange = this.binding("change");
    const phxTarget = newForm.getAttribute(this.binding("target")) || newForm;
    const phxEvent = newForm.getAttribute(this.binding(PHX_AUTO_RECOVER)) || newForm.getAttribute(this.binding("change"));
    const inputs = Array.from(oldForm.elements).filter(
      (el) => dom_default.isFormInput(el) && el.name && !el.hasAttribute(phxChange)
    );
    if (inputs.length === 0) {
      callback();
      return;
    }
    inputs.forEach(
      (input2) => input2.hasAttribute(PHX_UPLOAD_REF) && LiveUploader.clearFiles(input2)
    );
    const input = inputs.find((el) => el.type !== "hidden") || inputs[0];
    let pending = 0;
    this.withinTargets(
      phxTarget,
      (targetView, targetCtx) => {
        const cid = this.targetComponentID(newForm, targetCtx);
        pending++;
        let e = new CustomEvent("phx:form-recovery", {
          detail: { sourceElement: oldForm }
        });
        js_default.exec(e, "change", phxEvent, this, input, [
          "push",
          {
            _target: input.name,
            targetView,
            targetCtx,
            newCid: cid,
            callback: () => {
              pending--;
              if (pending === 0) {
                callback();
              }
            }
          }
        ]);
      },
      templateDom
    );
  }
  pushLinkPatch(e, href, targetEl, callback) {
    const linkRef = this.liveSocket.setPendingLink(href);
    const loading = e.isTrusted && e.type !== "popstate";
    const refGen = targetEl ? () => this.putRef(
      [{ el: targetEl, loading, lock: true }],
      null,
      "click"
    ) : null;
    const fallback = () => this.liveSocket.redirect(window.location.href);
    const url = href.startsWith("/") ? `${location.protocol}//${location.host}${href}` : href;
    this.pushWithReply(refGen, "live_patch", { url }).then(
      ({ resp }) => {
        this.liveSocket.requestDOMUpdate(() => {
          if (resp.link_redirect) {
            this.liveSocket.replaceMain(href, null, callback, linkRef);
          } else {
            if (this.liveSocket.commitPendingLink(linkRef)) {
              this.href = href;
            }
            this.applyPendingUpdates();
            callback && callback(linkRef);
          }
        });
      },
      ({ error: _error, timeout: _timeout }) => fallback()
    );
  }
  getFormsForRecovery() {
    if (this.joinCount === 0) {
      return {};
    }
    const phxChange = this.binding("change");
    return dom_default.all(
      document,
      `#${CSS.escape(this.id)} form[${phxChange}], [${PHX_TELEPORTED_REF}="${CSS.escape(this.id)}"] form[${phxChange}]`
    ).filter((form) => form.id).filter((form) => form.elements.length > 0).filter(
      (form) => form.getAttribute(this.binding(PHX_AUTO_RECOVER)) !== "ignore"
    ).map((form) => {
      const clonedForm = form.cloneNode(true);
      morphdom_esm_default(clonedForm, form, {
        onBeforeElUpdated: (fromEl, toEl) => {
          dom_default.copyPrivates(fromEl, toEl);
          return true;
        }
      });
      const externalElements = document.querySelectorAll(
        `[form="${form.id}"]`
      );
      Array.from(externalElements).forEach((el) => {
        if (form.contains(el)) {
          return;
        }
        const clonedEl = el.cloneNode(true);
        morphdom_esm_default(clonedEl, el);
        dom_default.copyPrivates(clonedEl, el);
        clonedForm.appendChild(clonedEl);
      });
      return clonedForm;
    }).reduce((acc, form) => {
      acc[form.id] = form;
      return acc;
    }, {});
  }
  maybePushComponentsDestroyed(destroyedCIDs) {
    let willDestroyCIDs = destroyedCIDs.filter((cid) => {
      return dom_default.findComponentNodeList(this.id, cid).length === 0;
    });
    const onError = (error) => {
      if (!this.isDestroyed()) {
        logError("Failed to push components destroyed", error);
      }
    };
    if (willDestroyCIDs.length > 0) {
      willDestroyCIDs.forEach((cid) => this.rendered.resetRender(cid));
      this.pushWithReply(null, "cids_will_destroy", { cids: willDestroyCIDs }).then(() => {
        this.liveSocket.requestDOMUpdate(() => {
          let completelyDestroyCIDs = willDestroyCIDs.filter((cid) => {
            return dom_default.findComponentNodeList(this.id, cid).length === 0;
          });
          if (completelyDestroyCIDs.length > 0) {
            this.pushWithReply(null, "cids_destroyed", {
              cids: completelyDestroyCIDs
            }).then(({ resp }) => {
              this.rendered.pruneCIDs(resp.cids);
            }).catch(onError);
          }
        });
      }).catch(onError);
    }
  }
  ownsElement(el) {
    let parentViewEl = dom_default.closestViewEl(el);
    return el.getAttribute(PHX_PARENT_ID) === this.id || parentViewEl && parentViewEl.id === this.id || !parentViewEl && this.isDead;
  }
  submitForm(form, targetCtx, phxEvent, submitter, opts = {}) {
    dom_default.putPrivate(form, PHX_HAS_SUBMITTED, true);
    const inputs = Array.from(form.elements);
    inputs.forEach((input) => dom_default.putPrivate(input, PHX_HAS_SUBMITTED, true));
    this.liveSocket.blurActiveElement(this);
    this.pushFormSubmit(form, targetCtx, phxEvent, submitter, opts, () => {
      this.liveSocket.restorePreviouslyActiveFocus();
    });
  }
  binding(kind) {
    return this.liveSocket.binding(kind);
  }
  // phx-portal
  pushPortalElementId(id) {
    this.portalElementIds.add(id);
  }
  dropPortalElementId(id) {
    this.portalElementIds.delete(id);
  }
  destroyPortalElements() {
    this.portalElementIds.forEach((id) => {
      const el = document.getElementById(id);
      if (el) {
        el.remove();
      }
    });
  }
};

// js/phoenix_live_view/live_socket.js
var isUsedInput = (el) => dom_default.isUsedInput(el);
var LiveSocket = class {
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
    this.reloadWithJitterTimer = null;
    this.maxReloads = opts.maxReloads || MAX_RELOADS;
    this.reloadJitterMin = opts.reloadJitterMin || RELOAD_JITTER_MIN;
    this.reloadJitterMax = opts.reloadJitterMax || RELOAD_JITTER_MAX;
    this.failsafeJitter = opts.failsafeJitter || FAILSAFE_JITTER;
    this.localStorage = opts.localStorage || window.localStorage;
    this.sessionStorage = opts.sessionStorage || window.sessionStorage;
    this.boundTopLevelEvents = false;
    this.boundEventNames = /* @__PURE__ */ new Set();
    this.blockPhxChangeWhileComposing = opts.blockPhxChangeWhileComposing || false;
    this.serverCloseRef = null;
    this.domCallbacks = Object.assign(
      {
        jsQuerySelectorAll: null,
        onPatchStart: closure(),
        onPatchEnd: closure(),
        onNodeAdded: closure(),
        onBeforeElUpdated: closure()
      },
      opts.dom || {}
    );
    this.transitions = new TransitionSet();
    this.currentHistoryPosition = parseInt(this.sessionStorage.getItem(PHX_LV_HISTORY_POSITION)) || 0;
    window.addEventListener("pagehide", (_e) => {
      this.unloaded = true;
    });
    this.socket.onOpen(() => {
      if (this.isUnloaded()) {
        window.location.reload();
      }
    });
  }
  // public
  version() {
    return "1.1.14";
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
      "latency simulator enabled for the duration of this browser session. Call disableLatencySim() to disable"
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
    if (["complete", "loaded", "interactive"].indexOf(document.readyState) >= 0) {
      doConnect();
    } else {
      document.addEventListener("DOMContentLoaded", () => doConnect());
    }
  }
  disconnect(callback) {
    clearTimeout(this.reloadWithJitterTimer);
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
    this.owner(el, (view) => js_default.exec(e, eventType, encodedJS, view, el));
  }
  /**
   * Returns an object with methods to manipluate the DOM and execute JavaScript.
   * The applied changes integrate with server DOM patching.
   *
   * @returns {import("./js_commands").LiveSocketJSCommands}
   */
  js() {
    return js_commands_default(this, "js");
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
  transition(time, onStart, onDone = function() {
  }) {
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
    const tries = browser_default.updateLocal(
      this.localStorage,
      window.location.pathname,
      CONSECUTIVE_RELOADS,
      0,
      (count) => count + 1
    );
    if (tries >= this.maxReloads) {
      afterMs = this.failsafeJitter;
    }
    this.reloadWithJitterTimer = setTimeout(() => {
      if (view.isDestroyed() || view.isConnected()) {
        return;
      }
      view.destroy();
      log ? log() : this.log(view, "join", () => [
        `encountered ${tries} consecutive reloads`
      ]);
      if (tries >= this.maxReloads) {
        this.log(view, "join", () => [
          `exceeded ${this.maxReloads} consecutive reloads. Entering failsafe mode`
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
    return this.maybeInternalHook(name) || this.hooks[name] || this.maybeRuntimeHook(name);
  }
  maybeInternalHook(name) {
    return name && name.startsWith("Phoenix.") && hooks_default[name.split(".")[1]];
  }
  maybeRuntimeHook(name) {
    const runtimeHook = document.querySelector(
      `script[${PHX_RUNTIME_HOOK}="${CSS.escape(name)}"]`
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
    if (hookDefiniton && (typeof hookDefiniton === "object" || typeof hookDefiniton === "function")) {
      return hookDefiniton;
    }
    logError(
      "runtime hook must return an object with hook callbacks or an instance of ViewHook",
      runtimeHook
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
    if (body && !this.isPhxView(body) && !this.isPhxView(document.firstElementChild)) {
      const view = this.newRootView(body);
      view.setHref(this.getHref());
      view.joinDead();
      if (!this.main) {
        this.main = view;
      }
      window.requestAnimationFrame(() => {
        view.execNewMounted();
        this.maybeScroll(history.state?.scroll);
      });
    }
  }
  joinRootViews() {
    let rootsFound = false;
    dom_default.all(
      document,
      `${PHX_VIEW_SELECTOR}:not([${PHX_PARENT_ID}])`,
      (rootEl) => {
        if (!this.getRootById(rootEl.id)) {
          const view = this.newRootView(rootEl);
          if (!dom_default.isPhxSticky(rootEl)) {
            view.setHref(this.getHref());
          }
          view.join();
          if (rootEl.hasAttribute(PHX_MAIN)) {
            this.main = view;
          }
        }
        rootsFound = true;
      }
    );
    return rootsFound;
  }
  redirect(to, flash, reloadToken) {
    if (reloadToken) {
      browser_default.setCookie(PHX_RELOAD_STATUS, reloadToken, 60);
    }
    this.unload();
    browser_default.redirect(to, flash);
  }
  replaceMain(href, flash, callback = null, linkRef = this.setPendingLink(href)) {
    const liveReferer = this.currentLocation.href;
    this.outgoingMainEl = this.outgoingMainEl || this.main.el;
    const stickies = dom_default.findPhxSticky(document) || [];
    const removeEls = dom_default.all(
      this.outgoingMainEl,
      `[${this.binding("remove")}]`
    ).filter((el) => !dom_default.isChildOfAny(el, stickies));
    const newMainEl = dom_default.cloneNode(this.outgoingMainEl, "");
    this.main.showLoader(this.loaderTimeout);
    this.main.destroy();
    this.main = this.newRootView(newMainEl, flash, liveReferer);
    this.main.setRedirect(href);
    this.transitionRemoves(removeEls);
    this.main.join((joinCount, onDone) => {
      if (joinCount === 1 && this.commitPendingLink(linkRef)) {
        this.requestDOMUpdate(() => {
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
      for (const event of this.boundEventNames) {
        el.addEventListener(event, silenceEvents, true);
      }
      this.execJS(el, el.getAttribute(removeAttr), "remove");
    });
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
    const viewEl = dom_default.closestViewEl(childEl);
    if (viewEl) {
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
    return maybe(
      this.getRootById(rootId),
      (root) => root.getDescendentByEl(el)
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
    if (this.prevActive && this.prevActive !== document.body && this.prevActive instanceof HTMLElement) {
      this.prevActive.focus();
    }
  }
  blurActiveElement() {
    this.prevActive = this.getActiveElement();
    if (this.prevActive !== document.body && this.prevActive instanceof HTMLElement) {
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
    this.serverCloseRef = this.socket.onClose((event) => {
      if (event && event.code === 1e3 && this.main) {
        return this.reloadWithJitter(this.main);
      }
    });
    document.body.addEventListener("click", function() {
    });
    window.addEventListener(
      "pageshow",
      (e) => {
        if (e.persisted) {
          this.getSocket().disconnect();
          this.withPageLoading({ to: window.location.href, kind: "redirect" });
          window.location.reload();
        }
      },
      true
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
        const pressedKey = e.key && e.key.toLowerCase();
        if (matchKey && matchKey.toLowerCase() !== pressedKey) {
          return;
        }
        const data = { key: e.key, ...this.eventMeta(type, e, targetEl) };
        js_default.exec(e, type, phxEvent, view, targetEl, ["push", { data }]);
      }
    );
    this.bind(
      { blur: "focusout", focus: "focusin" },
      (e, type, view, targetEl, phxEvent, phxTarget) => {
        if (!phxTarget) {
          const data = { key: e.key, ...this.eventMeta(type, e, targetEl) };
          js_default.exec(e, type, phxEvent, view, targetEl, ["push", { data }]);
        }
      }
    );
    this.bind(
      { blur: "blur", focus: "focus" },
      (e, type, view, targetEl, phxEvent, phxTarget) => {
        if (phxTarget === "window") {
          const data = this.eventMeta(type, e, targetEl);
          js_default.exec(e, type, phxEvent, view, targetEl, ["push", { data }]);
        }
      }
    );
    this.on("dragover", (e) => e.preventDefault());
    this.on("drop", (e) => {
      e.preventDefault();
      const dropTargetId = maybe(
        closestPhxBinding(e.target, this.binding(PHX_DROP_TARGET)),
        (trueTarget) => {
          return trueTarget.getAttribute(this.binding(PHX_DROP_TARGET));
        }
      );
      const dropTarget = dropTargetId && document.getElementById(dropTargetId);
      const files = Array.from(e.dataTransfer.files || []);
      if (!dropTarget || !(dropTarget instanceof HTMLInputElement) || dropTarget.disabled || files.length === 0 || !(dropTarget.files instanceof FileList)) {
        return;
      }
      LiveUploader.trackFiles(dropTarget, files, e.dataTransfer);
      dropTarget.dispatchEvent(new Event("input", { bubbles: true }));
    });
    this.on(PHX_TRACK_UPLOADS, (e) => {
      const uploadTarget = e.target;
      if (!dom_default.isUploadInput(uploadTarget)) {
        return;
      }
      const files = Array.from(e.detail.files || []).filter(
        (f) => f instanceof File || f instanceof Blob
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
    browser_default.deleteCookie(PHX_RELOAD_STATUS);
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
        const targetPhxEvent = e.target.getAttribute && e.target.getAttribute(binding);
        if (targetPhxEvent) {
          this.debounce(e.target, e, browserEventName, () => {
            this.withinOwners(e.target, (view) => {
              callback(e, event, view, e.target, targetPhxEvent, null);
            });
          });
        } else {
          dom_default.all(document, `[${windowBinding}]`, (el) => {
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
    this.on("mousedown", (e) => this.clickStartedAtTarget = e.target);
    this.bindClick("click", "click");
  }
  bindClick(eventName, bindingName) {
    const click = this.binding(bindingName);
    window.addEventListener(
      eventName,
      (e) => {
        let target = null;
        if (e.detail === 0)
          this.clickStartedAtTarget = e.target;
        const clickStartedAtTarget = this.clickStartedAtTarget || e.target;
        target = closestPhxBinding(e.target, click);
        this.dispatchClickAway(e, clickStartedAtTarget);
        this.clickStartedAtTarget = null;
        const phxEvent = target && target.getAttribute(click);
        if (!phxEvent) {
          if (dom_default.isNewPageClick(e, window.location)) {
            this.unload();
          }
          return;
        }
        if (target.getAttribute("href") === "#") {
          e.preventDefault();
        }
        if (target.hasAttribute(PHX_REF_SRC)) {
          return;
        }
        this.debounce(target, e, "click", () => {
          this.withinOwners(target, (view) => {
            js_default.exec(e, "click", phxEvent, view, target, [
              "push",
              { data: this.eventMeta("click", e, target) }
            ]);
          });
        });
      },
      false
    );
  }
  dispatchClickAway(e, clickStartedAt) {
    const phxClickAway = this.binding("click-away");
    dom_default.all(document, `[${phxClickAway}]`, (el) => {
      if (!(el.isSameNode(clickStartedAt) || el.contains(clickStartedAt))) {
        this.withinOwners(el, (view) => {
          const phxEvent = el.getAttribute(phxClickAway);
          if (js_default.isVisible(el) && js_default.isInViewport(el)) {
            js_default.exec(e, "click", phxEvent, view, el, [
              "push",
              { data: this.eventMeta("click", e, e.target) }
            ]);
          }
        });
      }
    });
  }
  bindNav() {
    if (!browser_default.canPushState()) {
      return;
    }
    if (history.scrollRestoration) {
      history.scrollRestoration = "manual";
    }
    let scrollTimer = null;
    window.addEventListener("scroll", (_e) => {
      clearTimeout(scrollTimer);
      scrollTimer = setTimeout(() => {
        browser_default.updateCurrentState(
          (state) => Object.assign(state, { scroll: window.scrollY })
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
        const isForward = position > this.currentHistoryPosition;
        const navType = isForward ? type : backType || type;
        this.currentHistoryPosition = position || 0;
        this.sessionStorage.setItem(
          PHX_LV_HISTORY_POSITION,
          this.currentHistoryPosition.toString()
        );
        dom_default.dispatchEvent(window, "phx:navigate", {
          detail: {
            href,
            patch: navType === "patch",
            pop: true,
            direction: isForward ? "forward" : "backward"
          }
        });
        this.requestDOMUpdate(() => {
          const callback = () => {
            this.maybeScroll(scroll);
          };
          if (this.main.isConnected() && navType === "patch" && id === this.main.id) {
            this.main.pushLinkPatch(event, href, null, callback);
          } else {
            this.replaceMain(href, null, callback);
          }
        });
      },
      false
    );
    window.addEventListener(
      "click",
      (e) => {
        const target = closestPhxBinding(e.target, PHX_LIVE_LINK);
        const type = target && target.getAttribute(PHX_LIVE_LINK);
        if (!type || !this.isConnected() || !this.main || dom_default.wantsNewTab(e)) {
          return;
        }
        const href = target.href instanceof SVGAnimatedString ? target.href.baseVal : target.href;
        const linkState = target.getAttribute(PHX_LINK_STATE);
        e.preventDefault();
        e.stopImmediatePropagation();
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
              `expected ${PHX_LIVE_LINK} to be "patch" or "redirect", got: ${type}`
            );
          }
          const phxClick = target.getAttribute(this.binding("click"));
          if (phxClick) {
            this.requestDOMUpdate(() => this.execJS(target, phxClick, "click"));
          }
        });
      },
      false
    );
  }
  maybeScroll(scroll) {
    if (typeof scroll === "number") {
      requestAnimationFrame(() => {
        window.scrollTo(0, scroll);
      });
    }
  }
  dispatchEvent(event, payload = {}) {
    dom_default.dispatchEvent(window, `phx:${event}`, { detail: payload });
  }
  dispatchEvents(events) {
    events.forEach(([event, payload]) => this.dispatchEvent(event, payload));
  }
  withPageLoading(info, callback) {
    dom_default.dispatchEvent(window, "phx:page-loading-start", { detail: info });
    const done = () => dom_default.dispatchEvent(window, "phx:page-loading-stop", { detail: info });
    return callback ? callback(done) : done;
  }
  pushHistoryPatch(e, href, linkState, targetEl) {
    if (!this.isConnected() || !this.main.isMain()) {
      return browser_default.redirect(href);
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
    this.currentHistoryPosition++;
    this.sessionStorage.setItem(
      PHX_LV_HISTORY_POSITION,
      this.currentHistoryPosition.toString()
    );
    browser_default.updateCurrentState((state) => ({ ...state, backType: "patch" }));
    browser_default.pushState(
      linkState,
      {
        type: "patch",
        id: this.main.id,
        position: this.currentHistoryPosition
      },
      href
    );
    dom_default.dispatchEvent(window, "phx:navigate", {
      detail: { patch: true, href, pop: false, direction: "forward" }
    });
    this.registerNewLocation(window.location);
  }
  historyRedirect(e, href, linkState, flash, targetEl) {
    const clickLoading = targetEl && e.isTrusted && e.type !== "popstate";
    if (clickLoading) {
      targetEl.classList.add("phx-click-loading");
    }
    if (!this.isConnected() || !this.main.isMain()) {
      return browser_default.redirect(href, flash);
    }
    if (/^\/$|^\/[^\/]+.*$/.test(href)) {
      const { protocol, host } = window.location;
      href = `${protocol}//${host}${href}`;
    }
    const scroll = window.scrollY;
    this.withPageLoading({ to: href, kind: "redirect" }, (done) => {
      this.replaceMain(href, flash, (linkRef) => {
        if (linkRef === this.linkRef) {
          this.currentHistoryPosition++;
          this.sessionStorage.setItem(
            PHX_LV_HISTORY_POSITION,
            this.currentHistoryPosition.toString()
          );
          browser_default.updateCurrentState((state) => ({
            ...state,
            backType: "redirect"
          }));
          browser_default.pushState(
            linkState,
            {
              type: "redirect",
              id: this.main.id,
              scroll,
              position: this.currentHistoryPosition
            },
            href
          );
          dom_default.dispatchEvent(window, "phx:navigate", {
            detail: { href, patch: false, pop: false, direction: "forward" }
          });
          this.registerNewLocation(window.location);
        }
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
    this.on("submit", (e) => {
      const phxSubmit = e.target.getAttribute(this.binding("submit"));
      const phxChange = e.target.getAttribute(this.binding("change"));
      if (!externalFormSubmitted && phxChange && !phxSubmit) {
        externalFormSubmitted = true;
        e.preventDefault();
        this.withinOwners(e.target, (view) => {
          view.disableForm(e.target);
          window.requestAnimationFrame(() => {
            if (dom_default.isUnloadableFormSubmit(e)) {
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
        if (dom_default.isUnloadableFormSubmit(e)) {
          this.unload();
        }
        return;
      }
      e.preventDefault();
      e.target.disabled = true;
      this.withinOwners(e.target, (view) => {
        js_default.exec(e, "submit", phxEvent, view, e.target, [
          "push",
          { submitter: e.submitter }
        ]);
      });
    });
    for (const type of ["change", "input"]) {
      this.on(type, (e) => {
        if (e instanceof CustomEvent && (e.target instanceof HTMLInputElement || e.target instanceof HTMLSelectElement || e.target instanceof HTMLTextAreaElement) && e.target.form === void 0) {
          if (e.detail && e.detail.dispatcher) {
            throw new Error(
              `dispatching a custom ${type} event is only supported on input elements inside a form`
            );
          }
          return;
        }
        const phxChange = this.binding("change");
        const input = e.target;
        if (this.blockPhxChangeWhileComposing && e.isComposing) {
          const key = `composition-listener-${type}`;
          if (!dom_default.private(input, key)) {
            dom_default.putPrivate(input, key, true);
            input.addEventListener(
              "compositionend",
              () => {
                input.dispatchEvent(new Event(type, { bubbles: true }));
                dom_default.deletePrivate(input, key);
              },
              { once: true }
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
        if (input.type === "number" && input.validity && input.validity.badInput) {
          return;
        }
        const dispatcher = inputEvent ? input : input.form;
        const currentIterations = iterations;
        iterations++;
        const { at, type: lastType } = dom_default.private(input, "prev-iteration") || {};
        if (at === currentIterations - 1 && type === "change" && lastType === "input") {
          return;
        }
        dom_default.putPrivate(input, "prev-iteration", {
          at: currentIterations,
          type
        });
        this.debounce(input, e, type, () => {
          this.withinOwners(dispatcher, (view) => {
            dom_default.putPrivate(input, PHX_HAS_FOCUSED, true);
            js_default.exec(e, "change", phxEvent, view, input, [
              "push",
              { _target: e.target.name, dispatcher }
            ]);
          });
        });
      });
    }
    this.on("reset", (e) => {
      const form = e.target;
      dom_default.resetForm(form);
      const input = Array.from(form.elements).find((el) => el.type === "reset");
      if (input) {
        window.requestAnimationFrame(() => {
          input.dispatchEvent(
            new Event("input", { bubbles: true, cancelable: false })
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
      const asyncFilter = () => !view.isDestroyed() && document.body.contains(el);
      dom_default.debounce(
        el,
        event,
        phxDebounce,
        defaultDebounce,
        phxThrottle,
        defaultThrottle,
        asyncFilter,
        () => {
          callback();
        }
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
};
var TransitionSet = class {
  constructor() {
    this.transitions = /* @__PURE__ */ new Set();
    this.promises = /* @__PURE__ */ new Set();
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
};

// js/phoenix_live_view/index.ts
var LiveSocket2 = LiveSocket;
function createHook(el, callbacks) {
  let existingHook = dom_default.getCustomElHook(el);
  if (existingHook) {
    return existingHook;
  }
  let hook = new ViewHook(View.closestView(el), el, callbacks);
  dom_default.putCustomElHook(el, hook);
  return hook;
}
//# sourceMappingURL=phoenix_live_view.cjs.js.map
