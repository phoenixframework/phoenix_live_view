import {
  BEFORE_UNLOAD_LOADER_TIMEOUT,
  CHECKABLE_INPUTS,
  CONSECUTIVE_RELOADS,
  PHX_AUTO_RECOVER,
  PHX_COMPONENT,
  PHX_VIEW_REF,
  PHX_CONNECTED_CLASS,
  PHX_DISABLE_WITH,
  PHX_DISABLE_WITH_RESTORE,
  PHX_DISABLED,
  PHX_LOADING_CLASS,
  PHX_ERROR_CLASS,
  PHX_CLIENT_ERROR_CLASS,
  PHX_SERVER_ERROR_CLASS,
  PHX_HAS_FOCUSED,
  PHX_HAS_SUBMITTED,
  PHX_HOOK,
  PHX_PARENT_ID,
  PHX_PROGRESS,
  PHX_READONLY,
  PHX_REF_LOADING,
  PHX_REF_SRC,
  PHX_REF_LOCK,
  PHX_ROOT_ID,
  PHX_SESSION,
  PHX_STATIC,
  PHX_STICKY,
  PHX_TRACK_STATIC,
  PHX_TRACK_UPLOADS,
  PHX_UPDATE,
  PHX_UPLOAD_REF,
  PHX_VIEW_SELECTOR,
  PHX_MAIN,
  PHX_MOUNTED,
  PUSH_TIMEOUT,
  PHX_VIEWPORT_TOP,
  PHX_VIEWPORT_BOTTOM,
  MAX_CHILD_JOIN_ATTEMPTS,
  PHX_LV_PID,
  PHX_PORTAL,
  PHX_TELEPORTED_REF,
} from "./constants";

import {
  clone,
  closestPhxBinding,
  isEmpty,
  isEqualObj,
  logError,
  maybe,
  isCid,
} from "./utils";

import Browser from "./browser";
import DOM from "./dom";
import ElementRef from "./element_ref";
import DOMPatch from "./dom_patch";
import LiveUploader from "./live_uploader";
import Rendered from "./rendered";
import { ViewHook } from "./view_hook";
import JS from "./js";

import morphdom from "morphdom";

export const prependFormDataKey = (key, prefix) => {
  const isArray = key.endsWith("[]");
  // Remove the "[]" if it's an array
  let baseKey = isArray ? key.slice(0, -2) : key;
  // Replace last occurrence of key before a closing bracket or the end with key plus suffix
  baseKey = baseKey.replace(/([^\[\]]+)(\]?$)/, `${prefix}$1$2`);
  // Add back the "[]" if it was an array
  if (isArray) {
    baseKey += "[]";
  }
  return baseKey;
};

const serializeForm = (form, opts, onlyNames = []) => {
  const { submitter } = opts;

  // We must inject the submitter in the order that it exists in the DOM
  // relative to other inputs. For example, for checkbox groups, the order must be maintained.
  let injectedElement;
  if (submitter && submitter.name) {
    const input = document.createElement("input");
    input.type = "hidden";
    // set the form attribute if the submitter has one;
    // this can happen if the element is outside the actual form element
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

  // Cleanup after building fileData
  toRemove.forEach((key) => formData.delete(key));

  const params = new URLSearchParams();

  const { inputsUnused, onlyHiddenInputs } = Array.from(form.elements).reduce(
    (acc, input) => {
      const { inputsUnused, onlyHiddenInputs } = acc;
      const key = input.name;
      if (!key) {
        return acc;
      }

      if (inputsUnused[key] === undefined) {
        inputsUnused[key] = true;
      }
      if (onlyHiddenInputs[key] === undefined) {
        onlyHiddenInputs[key] = true;
      }

      const isUsed =
        DOM.private(input, PHX_HAS_FOCUSED) ||
        DOM.private(input, PHX_HAS_SUBMITTED);
      const isHidden = input.type === "hidden";
      inputsUnused[key] = inputsUnused[key] && !isUsed;
      onlyHiddenInputs[key] = onlyHiddenInputs[key] && isHidden;

      return acc;
    },
    { inputsUnused: {}, onlyHiddenInputs: {} },
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

  // remove the injected element again
  // (it would be removed by the next dom patch anyway, but this is cleaner)
  if (submitter && injectedElement) {
    submitter.parentElement.removeChild(injectedElement);
  }

  return params.toString();
};

export default class View {
  static closestView(el) {
    const liveViewEl = el.closest(PHX_VIEW_SELECTOR);
    return liveViewEl ? DOM.private(liveViewEl, "view") : null;
  }

  constructor(el, liveSocket, parentView, flash, liveReferer) {
    this.isDead = false;
    this.liveSocket = liveSocket;
    this.flash = flash;
    this.parent = parentView;
    this.root = parentView ? parentView.root : this;
    this.el = el;
    // see https://github.com/phoenixframework/phoenix_live_view/pull/3721
    // check if the element is already bound to a view
    const boundView = DOM.private(this.el, "view");
    if (boundView !== undefined && boundView.isDead !== true) {
      logError(
        `The DOM element for this view has already been bound to a view.

        An element can only ever be associated with a single view!
        Please ensure that you are not trying to initialize multiple LiveSockets on the same page.
        This could happen if you're accidentally trying to render your root layout more than once.
        Ensure that the template set on the LiveView is different than the root layout.
      `,
        { view: boundView },
      );
      throw new Error("Cannot bind multiple views to the same DOM element.");
    }
    // bind the view to the element
    DOM.putPrivate(this.el, "view", this);
    this.id = this.el.id;
    this.ref = 0;
    this.lastAckRef = null;
    this.childJoins = 0;
    /**
     * @type {ReturnType<typeof setTimeout> | null}
     */
    this.loaderTimer = null;
    /**
     * @type {ReturnType<typeof setTimeout> | null}
     */
    this.disconnectedTimer = null;
    this.pendingDiffs = [];
    this.pendingForms = new Set();
    this.redirect = false;
    this.href = null;
    this.joinCount = this.parent ? this.parent.joinCount - 1 : 0;
    this.joinAttempts = 0;
    this.joinPending = true;
    this.destroyed = false;
    this.joinCallback = function (onDone) {
      onDone && onDone();
    };
    this.stopCallback = function () {};
    // usually, only the root LiveView stores pending
    // join operations for all children (and itself),
    // but in case of rejoins (joinCount > 1) each child
    // stores its own events instead
    this.pendingJoinOps = [];
    this.viewHooks = {};
    this.formSubmits = [];
    this.children = this.parent ? null : {};
    this.root.children[this.id] = {};
    this.formsForRecovery = {};
    this.channel = this.liveSocket.channel(`lv:${this.id}`, () => {
      const url = this.href && this.expandURL(this.href);
      return {
        redirect: this.redirect ? url : undefined,
        url: this.redirect ? undefined : url || undefined,
        params: this.connectParams(liveReferer),
        session: this.getSession(),
        static: this.getStatic(),
        flash: this.flash,
        sticky: this.el.hasAttribute(PHX_STICKY),
      };
    });
    this.portalElementIds = new Set();
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
    const manifest = DOM.all(document, `[${this.binding(PHX_TRACK_STATIC)}]`)
      .map((node) => node.src || node.href)
      .filter((url) => typeof url === "string");

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

  destroy(callback = function () {}) {
    this.destroyAllChildren();
    this.destroyPortalElements();
    this.destroyed = true;
    DOM.deletePrivate(this.el, "view");
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

    DOM.markPhxChildDestroyed(this.el);

    this.log("destroyed", () => ["the child has been removed from the parent"]);
    this.channel
      .leave()
      .receive("ok", onFinished)
      .receive("error", onFinished)
      .receive("timeout", onFinished);
  }

  setContainerClasses(...classes) {
    this.el.classList.remove(
      PHX_CONNECTED_CLASS,
      PHX_LOADING_CLASS,
      PHX_ERROR_CLASS,
      PHX_CLIENT_ERROR_CLASS,
      PHX_SERVER_ERROR_CLASS,
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
    DOM.all(this.el, `[${binding}]`, (el) =>
      this.liveSocket.execJS(el, el.getAttribute(binding)),
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

  transition(time, onStart, onDone = function () {}) {
    this.liveSocket.transition(time, onStart, onDone);
  }

  // calls the callback with the view and target element for the given phxTarget
  // targets can be:
  //  * an element itself, then it is simply passed to liveSocket.owner;
  //  * a CID (Component ID), then we first search the component's element in the DOM
  //  * a selector, then we search the selector in the DOM and call the callback
  //    for each element found with the corresponding owner view
  withinTargets(phxTarget, callback, dom = document) {
    // in the form recovery case we search in a template fragment instead of
    // the real dom, therefore we optionally pass dom and viewEl

    if (phxTarget instanceof HTMLElement || phxTarget instanceof SVGElement) {
      return this.liveSocket.owner(phxTarget, (view) =>
        callback(view, phxTarget),
      );
    }

    if (isCid(phxTarget)) {
      const targets = DOM.findComponentNodeList(this.id, phxTarget, dom);
      if (targets.length === 0) {
        logError(`no component found matching phx-target of ${phxTarget}`);
      } else {
        callback(this, parseInt(phxTarget));
      }
    } else {
      const targets = Array.from(dom.querySelectorAll(phxTarget));
      if (targets.length === 0) {
        logError(
          `nothing found matching the phx-target selector "${phxTarget}"`,
        );
      }
      targets.forEach((target) =>
        this.liveSocket.owner(target, (view) => callback(view, target)),
      );
    }
  }

  applyDiff(type, rawDiff, callback) {
    this.log(type, () => ["", clone(rawDiff)]);
    const { diff, reply, events, title } = Rendered.extract(rawDiff);
    callback({ diff, reply, events });
    if (typeof title === "string" || (type == "mount" && this.isMain())) {
      window.requestAnimationFrame(() => DOM.putTitle(title));
    }
  }

  onJoin(resp) {
    const { rendered, container, liveview_version, pid } = resp;
    if (container) {
      const [tag, attrs] = container;
      this.el = DOM.replaceRootContainer(this.el, tag, attrs);
    }
    this.childJoins = 0;
    this.joinPending = true;
    this.flash = null;
    if (this.root === this) {
      this.formsForRecovery = this.getFormsForRecovery();
    }
    if (this.isMain() && window.history.state === null) {
      // set initial history entry if this is the first page load (no history)
      Browser.pushState("replace", {
        type: "patch",
        id: this.id,
        position: this.liveSocket.currentHistoryPosition,
      });
    }

    if (liveview_version !== this.liveSocket.version()) {
      console.error(
        `LiveView asset version mismatch. JavaScript version ${this.liveSocket.version()} vs. server ${liveview_version}. To avoid issues, please ensure that your assets use the same version as the server.`,
      );
    }

    // The pid is only sent if
    //
    //    config :phoenix_live_view, :debug_attributes
    //
    // if set to true. It is to help debugging in development.
    if (pid) {
      this.el.setAttribute(PHX_LV_PID, pid);
    }

    Browser.dropLocal(
      this.liveSocket.localStorage,
      window.location.pathname,
      CONSECUTIVE_RELOADS,
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
    DOM.all(document, `[${PHX_REF_SRC}="${this.refSrc()}"]`, (el) => {
      el.removeAttribute(PHX_REF_LOADING);
      el.removeAttribute(PHX_REF_SRC);
      el.removeAttribute(PHX_REF_LOCK);
    });
  }

  onJoinComplete({ live_patch }, html, streams, events) {
    // In order to provide a better experience, we want to join
    // all LiveViews first and only then apply their patches.
    if (this.joinCount > 1 || (this.parent && !this.parent.isJoinPending())) {
      return this.applyJoinPatch(live_patch, html, streams, events);
    }

    // One downside of this approach is that we need to find phxChildren
    // in the html fragment, instead of directly on the DOM. The fragment
    // also does not include PHX_STATIC, so we need to copy it over from
    // the DOM.
    const newChildren = DOM.findPhxChildrenInFragment(html, this.id).filter(
      (toEl) => {
        const fromEl = toEl.id && this.el.querySelector(`[id="${toEl.id}"]`);
        const phxStatic = fromEl && fromEl.getAttribute(PHX_STATIC);
        if (phxStatic) {
          toEl.setAttribute(PHX_STATIC, phxStatic);
        }
        // set PHX_ROOT_ID to prevent events from being dispatched to the root view
        // while the child join is still pending
        if (fromEl) {
          fromEl.setAttribute(PHX_ROOT_ID, this.root.id);
        }
        return this.joinChild(toEl);
      },
    );

    if (newChildren.length === 0) {
      if (this.parent) {
        this.root.pendingJoinOps.push([
          this,
          () => this.applyJoinPatch(live_patch, html, streams, events),
        ]);
        this.parent.ackJoin(this);
      } else {
        this.onAllChildJoinsComplete();
        this.applyJoinPatch(live_patch, html, streams, events);
      }
    } else {
      this.root.pendingJoinOps.push([
        this,
        () => this.applyJoinPatch(live_patch, html, streams, events),
      ]);
    }
  }

  attachTrueDocEl() {
    this.el = DOM.byId(this.id);
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
        DOM.maintainPrivateHooks(
          hookEl,
          hookEl,
          phxViewportTop,
          phxViewportBottom,
        );
        this.maybeAddNewHook(hookEl);
      },
    );
    this.all(
      parent,
      `[${this.binding(PHX_HOOK)}], [data-phx-${PHX_HOOK}]`,
      (hookEl) => {
        this.maybeAddNewHook(hookEl);
      },
    );
    this.all(parent, `[${this.binding(PHX_MOUNTED)}]`, (el) => {
      this.maybeMounted(el);
    });
  }

  all(parent, selector, callback) {
    DOM.all(parent, selector, (el) => {
      if (this.ownsElement(el)) {
        callback(el);
      }
    });
  }

  applyJoinPatch(live_patch, html, streams, events) {
    // in case of rejoins, we need to manually perform all
    // pending ops
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
    const isIgnored = hook && DOM.isIgnored(fromEl, this.binding(PHX_UPDATE));
    if (
      hook &&
      !fromEl.isEqualNode(toEl) &&
      !(isIgnored && isEqualObj(fromEl.dataset, toEl.dataset))
    ) {
      hook.__beforeUpdate();
      return hook;
    }
  }

  maybeMounted(el) {
    const phxMounted = el.getAttribute(this.binding(PHX_MOUNTED));
    const hasBeenInvoked = phxMounted && DOM.private(el, "mounted");
    if (phxMounted && !hasBeenInvoked) {
      this.liveSocket.execJS(el, phxMounted);
      DOM.putPrivate(el, "mounted", true);
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
    const updatedHookIds = new Set();

    this.liveSocket.triggerDOM("onPatchStart", [patch.targetContainer]);

    patch.after("added", (el) => {
      this.liveSocket.triggerDOM("onNodeAdded", [el]);
      const phxViewportTop = this.binding(PHX_VIEWPORT_TOP);
      const phxViewportBottom = this.binding(PHX_VIEWPORT_BOTTOM);
      DOM.maintainPrivateHooks(el, el, phxViewportTop, phxViewportBottom);
      this.maybeAddNewHook(el);
      if (el.getAttribute) {
        this.maybeMounted(el);
      }
    });

    patch.after("phxChildAdded", (el) => {
      if (DOM.isPhxSticky(el)) {
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
      // trigger JS specific update logic (for example for JS.ignore_attributes)
      JS.onBeforeElUpdated(fromEl, toEl);
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

    patch.after("transitionsDiscarded", (els) =>
      this.afterElementsRemoved(els, pruneCids),
    );
    patch.perform(isJoinPatch);
    this.afterElementsRemoved(removedEls, pruneCids);

    this.liveSocket.triggerDOM("onPatchEnd", [patch.targetContainer]);
    return phxChildrenAdded;
  }

  afterElementsRemoved(elements, pruneCids) {
    const destroyedCIDs = [];
    elements.forEach((parent) => {
      const components = DOM.all(
        parent,
        `[${PHX_VIEW_REF}="${this.id}"][${PHX_COMPONENT}]`,
      );
      const hooks = DOM.all(
        parent,
        `[${this.binding(PHX_HOOK)}], [data-phx-hook]`,
      );
      components.concat(parent).forEach((el) => {
        const cid = this.componentID(el);
        if (
          isCid(cid) &&
          destroyedCIDs.indexOf(cid) === -1 &&
          el.getAttribute(PHX_VIEW_REF) === this.id
        ) {
          destroyedCIDs.push(cid);
        }
      });
      hooks.concat(parent).forEach((hookEl) => {
        const hook = this.getHook(hookEl);
        hook && this.destroyHook(hook);
      });
    });
    // We should not pruneCids on joins. Otherwise, in case of
    // rejoins, we may notify cids that no longer belong to the
    // current LiveView to be removed.
    if (pruneCids) {
      this.maybePushComponentsDestroyed(destroyedCIDs);
    }
  }

  joinNewChildren() {
    DOM.findPhxChildren(document, this.id).forEach((el) => this.joinChild(el));
  }

  maybeRecoverForms(html, callback) {
    const phxChange = this.binding("change");
    const oldForms = this.root.formsForRecovery;
    // So why do we create a template element here?
    // One way to recover forms would be to immediately apply the mount
    // patch and then afterwards recover the forms. However, this would
    // cause a flicker, because the mount patch would remove the form content
    // until it is restored. Therefore LV decided to do form recovery with the
    // raw HTML before it is applied and delay the mount patch until the form
    // recovery events are done.
    const template = document.createElement("template");
    template.innerHTML = html;

    // we special case <.portal> here and teleport it into our temporary DOM for recovery
    // as we'd otherwise not find teleported forms
    DOM.all(template.content, `[${PHX_PORTAL}]`).forEach((portalTemplate) => {
      template.content.firstElementChild.appendChild(
        portalTemplate.content.firstElementChild,
      );
    });

    // because we work with a template element, we must manually copy the attributes
    // otherwise the owner / target helpers don't work properly
    const rootEl = template.content.firstElementChild;
    rootEl.id = this.id;
    rootEl.setAttribute(PHX_ROOT_ID, this.root.id);
    rootEl.setAttribute(PHX_SESSION, this.getSession());
    rootEl.setAttribute(PHX_STATIC, this.getStatic());
    rootEl.setAttribute(PHX_PARENT_ID, this.parent ? this.parent.id : null);

    // we go over all form elements in the new HTML for the LV
    // and look for old forms in the `formsForRecovery` object;
    // the formsForRecovery can also contain forms from child views
    const formsToRecover =
      // we go over all forms in the new DOM; because this is only the HTML for the current
      // view, we can be sure that all forms are owned by this view:
      DOM.all(template.content, "form")
        // only recover forms that have an id and are in the old DOM
        .filter((newForm) => newForm.id && oldForms[newForm.id])
        // abandon forms we already tried to recover to prevent looping a failed state
        .filter((newForm) => !this.pendingForms.has(newForm.id))
        // only recover if the form has the same phx-change value
        .filter(
          (newForm) =>
            oldForms[newForm.id].getAttribute(phxChange) ===
            newForm.getAttribute(phxChange),
        )
        .map((newForm) => {
          return [oldForms[newForm.id], newForm];
        });

    if (formsToRecover.length === 0) {
      return callback();
    }

    formsToRecover.forEach(([oldForm, newForm], i) => {
      this.pendingForms.add(newForm.id);
      // it is important to use the firstElementChild of the template content
      // because when traversing a documentFragment using parentNode, we won't ever arrive at
      // the fragment; as the template is always a LiveView, we can be sure that there is only
      // one child on the root level
      this.pushFormRecovery(
        oldForm,
        newForm,
        template.content.firstElementChild,
        () => {
          this.pendingForms.delete(newForm.id);
          // we only call the callback once all forms have been recovered
          if (i === formsToRecover.length - 1) {
            callback();
          }
        },
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
      const view = new View(el, this.liveSocket, this);
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
    // we can clear pending form recoveries now that we've joined.
    // They either all resolved or were abandoned
    this.pendingForms.clear();
    // we can also clear the formsForRecovery object to not keep old form elements around
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
    if (
      this.isJoinPending() ||
      (this.liveSocket.hasPendingLink() && this.root.isMain())
    ) {
      // don't mutate if this is already a pending diff
      if (!isPending) {
        this.pendingDiffs.push({ diff, events });
      }
      return false;
    }

    this.rendered.mergeDiff(diff);
    let phxChildrenAdded = false;

    // When the diff only contains component diffs, then walk components
    // and patch only the parent component containers found in the diff.
    // Otherwise, patch entire LV container.
    if (this.rendered.isComponentOnlyDiff(diff)) {
      this.liveSocket.time("component patch complete", () => {
        const parentCids = DOM.findExistingParentCIDs(
          this.id,
          this.rendered.componentCIDs(diff),
        );
        parentCids.forEach((parentCID) => {
          if (
            this.componentPatch(
              this.rendered.getComponent(diff, parentCID),
              parentCID,
            )
          ) {
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
      // Don't skip any component in the diff nor any marked as pruned
      // (as they may have been added back)
      const cids = diff ? this.rendered.componentCIDs(diff) : null;
      const { buffer: html, streams } = this.rendered.toString(cids);
      return [`<${tag}>${html}</${tag}>`, streams];
    });
  }

  componentPatch(diff, cid) {
    if (isEmpty(diff)) return false;
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

    // only ever try to add hooks to elements owned by this view
    if (el.getAttribute && !this.ownsElement(el)) {
      return;
    }

    if (hookElId && !this.viewHooks[hookElId]) {
      // hook created, but not attached (createHook for web component)
      const hook =
        DOM.getCustomElHook(el) ||
        logError(`no hook found for custom element: ${el.id}`);
      this.viewHooks[hookElId] = hook;
      hook.__attachView(this);
      return hook;
    } else if (hookElId || !el.getAttribute) {
      // no hook found
      return;
    } else {
      // new hook found with phx-hook attribute
      const hookName =
        el.getAttribute(`data-phx-${PHX_HOOK}`) ||
        el.getAttribute(this.binding(PHX_HOOK));

      if (!hookName) {
        return;
      }

      const hookDefinition = this.liveSocket.getHookDefinition(hookName);

      if (hookDefinition) {
        if (!el.id) {
          logError(
            `no DOM ID for hook "${hookName}". Hooks require a unique ID on each element.`,
            el,
          );
          return;
        }

        let hookInstance;
        try {
          if (
            typeof hookDefinition === "function" &&
            hookDefinition.prototype instanceof ViewHook
          ) {
            // It's a class constructor (subclass of ViewHook)
            hookInstance = new hookDefinition(this, el); // `this` is the View instance
          } else if (
            typeof hookDefinition === "object" &&
            hookDefinition !== null
          ) {
            // It's an object literal, pass it to the ViewHook constructor for wrapping
            hookInstance = new ViewHook(this, el, hookDefinition);
          } else {
            logError(
              `Invalid hook definition for "${hookName}". Expected a class extending ViewHook or an object definition.`,
              el,
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
    // __destroyed clears the elementID from the hook, therefore
    // we need to get it before calling __destroyed
    const hookId = ViewHook.elementID(hook.el);
    hook.__destroyed();
    hook.__cleanup__();
    delete this.viewHooks[hookId];
  }

  applyPendingUpdates() {
    // To prevent race conditions where we might still be pending a new
    // navigation or the join is still pending, `this.update` returns false
    // if the diff was not applied.
    this.pendingDiffs = this.pendingDiffs.filter(
      ({ diff, events }) => !this.update(diff, events, true),
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
        // in case this is a rejoin (joinCount > 1) we store our own join ops
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
    // The diff event should be handled by the regular update operations.
    // All other operations are queued to be applied only after join.
    this.liveSocket.onChannel(this.channel, "diff", (rawDiff) => {
      this.liveSocket.requestDOMUpdate(() => {
        this.applyDiff("update", rawDiff, ({ diff, events }) =>
          this.update(diff, events),
        );
      });
    });
    this.onChannel("redirect", ({ to, flash }) =>
      this.onRedirect({ to, flash }),
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
      detail: { to, kind, flash },
    });
    this.liveSocket.historyRedirect(e, url, kind, flash);
  }

  onLivePatch(redir) {
    const { to, kind } = redir;
    this.href = this.expandURL(to);
    this.liveSocket.historyPatch(to, kind);
  }

  expandURL(to) {
    return to.startsWith("/")
      ? `${window.location.protocol}//${window.location.host}${to}`
      : to;
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
        kind: "initial",
      });
    }
    this.joinCallback = (onDone) => {
      onDone = onDone || function () {};
      callback ? callback(this.joinCount, onDone) : onDone();
    };

    this.wrapPush(() => this.channel.join(), {
      ok: (resp) => this.liveSocket.requestDOMUpdate(() => this.onJoin(resp)),
      error: (error) => this.onJoinError(error),
      timeout: () => this.onJoinError({ reason: "timeout" }),
    });
  }

  onJoinError(resp) {
    if (resp.reason === "reload") {
      this.log("error", () => [
        `failed mount with ${resp.status}. Falling back to page reload`,
        resp,
      ]);
      this.onRedirect({ to: this.root.href, reloadToken: resp.token });
      return;
    } else if (resp.reason === "unauthorized" || resp.reason === "stale") {
      this.log("error", () => [
        "unauthorized live_redirect. Falling back to page request",
        resp,
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
        { unstructuredError: resp, errorKind: "server" },
      );
      if (this.liveSocket.isConnected()) {
        this.liveSocket.reloadWithJitter(this);
      }
    } else {
      if (this.joinAttempts >= MAX_CHILD_JOIN_ATTEMPTS) {
        // put the root review into permanent error state, but don't destroy it as it can remain active
        this.root.displayError(
          [PHX_LOADING_CLASS, PHX_ERROR_CLASS, PHX_SERVER_ERROR_CLASS],
          { unstructuredError: resp, errorKind: "server" },
        );
        this.log("error", () => [
          `giving up trying to mount after ${MAX_CHILD_JOIN_ATTEMPTS} tries`,
          resp,
        ]);
        this.destroy();
      }
      const trueChildEl = DOM.byId(this.el.id);
      if (trueChildEl) {
        DOM.mergeAttrs(trueChildEl, this.el);
        this.displayError(
          [PHX_LOADING_CLASS, PHX_ERROR_CLASS, PHX_SERVER_ERROR_CLASS],
          { unstructuredError: resp, errorKind: "server" },
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
    if (
      this.isMain() &&
      this.liveSocket.hasPendingLink() &&
      reason !== "leave"
    ) {
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
          { unstructuredError: reason, errorKind: "server" },
        );
      } else {
        this.displayError(
          [PHX_LOADING_CLASS, PHX_ERROR_CLASS, PHX_CLIENT_ERROR_CLASS],
          { unstructuredError: reason, errorKind: "client" },
        );
      }
    }
  }

  displayError(classes, details = {}) {
    if (this.isMain()) {
      DOM.dispatchEvent(window, "phx:page-loading-start", {
        detail: { to: this.href, kind: "error", ...details },
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
    const withLatency = latency
      ? (cb) => setTimeout(() => !this.isDestroyed() && cb(), latency)
      : (cb) => !this.isDestroyed() && cb();

    withLatency(() => {
      callerPush()
        .receive("ok", (resp) =>
          withLatency(() => receives.ok && receives.ok(resp)),
        )
        .receive("error", (reason) =>
          withLatency(() => receives.error && receives.error(reason)),
        )
        .receive("timeout", () =>
          withLatency(() => receives.timeout && receives.timeout()),
        );
    });
  }

  pushWithReply(refGenerator, event, payload) {
    if (!this.isConnected()) {
      return Promise.reject(new Error("no connection"));
    }

    const [ref, [el], opts] = refGenerator
      ? refGenerator({ payload })
      : [null, [], {}];
    const oldJoinCount = this.joinCount;
    let onLoadingDone = function () {};
    if (opts.page_loading) {
      onLoadingDone = this.liveSocket.withPageLoading({
        kind: "element",
        target: el,
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
            resolve({ resp: resp, reply: hookReply, ref });
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
        error: (reason) =>
          reject(new Error(`failed with reason: ${JSON.stringify(reason)}`)),
        timeout: () => {
          reject(new Error("timeout"));
          if (this.joinCount === oldJoinCount) {
            this.liveSocket.reloadWithJitter(this, () => {
              this.log("timeout", () => [
                "received timeout while communicating with server. Falling back to hard refresh for recovery",
              ]);
            });
          }
        },
      });
    });
  }

  undoRefs(ref, phxEvent, onlyEls) {
    if (!this.isConnected()) {
      return;
    } // exit if external form triggered
    const selector = `[${PHX_REF_SRC}="${this.refSrc()}"]`;

    if (onlyEls) {
      onlyEls = new Set(onlyEls);
      DOM.all(document, selector, (parent) => {
        if (onlyEls && !onlyEls.has(parent)) {
          return;
        }
        // undo any child refs within parent first
        DOM.all(parent, selector, (child) =>
          this.undoElRef(child, ref, phxEvent),
        );
        this.undoElRef(parent, ref, phxEvent);
      });
    } else {
      DOM.all(document, selector, (el) => this.undoElRef(el, ref, phxEvent));
    }
  }

  undoElRef(el, ref, phxEvent) {
    const elRef = new ElementRef(el);

    elRef.maybeUndo(ref, phxEvent, (clonedTree) => {
      // we need to perform a full patch on unlocked elements
      // to perform all the necessary logic (like calling updated for hooks, etc.)
      const patch = new DOMPatch(this, el, this.id, clonedTree, [], null, {
        undoRef: ref,
      });
      const phxChildrenAdded = this.performPatch(patch, true);
      DOM.all(el, `[${PHX_REF_SRC}="${this.refSrc()}"]`, (child) =>
        this.undoElRef(child, ref, phxEvent),
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
      const loadingEls = DOM.all(document, opts.loading).map((el) => {
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

      if (
        !loading ||
        (opts.submitter && !(el === opts.submitter || el === opts.form))
      ) {
        continue;
      }

      const lockCompletePromise = new Promise((resolve) => {
        el.addEventListener(`phx:undo-lock:${newRef}`, () => resolve(detail), {
          once: true,
        });
      });

      const loadingCompletePromise = new Promise((resolve) => {
        el.addEventListener(
          `phx:undo-loading:${newRef}`,
          () => resolve(detail),
          { once: true },
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
        // PHX_DISABLED could have already been set in disableForm
        el.setAttribute(
          PHX_DISABLED,
          el.getAttribute(PHX_DISABLED) || el.disabled,
        );
        el.setAttribute("disabled", "");
      }

      const detail = {
        event: phxEvent,
        eventType: eventType,
        ref: newRef,
        isLoading: loading,
        isLocked: lock,
        lockElements: elements.filter(({ lock }) => lock).map(({ el }) => el),
        loadingElements: elements
          .filter(({ loading }) => loading)
          .map(({ el }) => el),
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
              { once: true },
            );
          });
        },
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
          detail: detail,
          bubbles: true,
          cancelable: false,
        }),
      );
      if (phxEvent) {
        el.dispatchEvent(
          new CustomEvent(`phx:push:${phxEvent}`, {
            detail: detail,
            bubbles: true,
            cancelable: false,
          }),
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

    const cidOrSelector =
      opts.target || target.getAttribute(this.binding("target"));
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
        (el) => this.ownsElement(el) && this.componentID(el),
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
        payload,
      ]);
      return Promise.reject(
        new Error("unable to push hook event. LiveView not connected"),
      );
    }

    const refGenerator = () =>
      this.putRef([{ el, loading: true, lock: true }], event, "hook", {
        payload,
        target: targetCtx,
      });

    return this.pushWithReply(refGenerator, "event", {
      type: "hook",
      event: event,
      value: payload,
      cid: this.closestComponentID(targetCtx),
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
    if (el.value !== undefined && !(el instanceof HTMLFormElement)) {
      if (!meta) {
        meta = {};
      }
      meta.value = el.value;

      if (
        el.tagName === "INPUT" &&
        CHECKABLE_INPUTS.indexOf(el.type) >= 0 &&
        !el.checked
      ) {
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
      (maybePayload) =>
        this.putRef([{ el, loading: true, lock: true }], phxEvent, type, {
          ...opts,
          payload: maybePayload?.payload,
        }),
      "event",
      {
        type: type,
        event: phxEvent,
        value: this.extractMeta(el, meta, opts.value),
        cid: this.targetComponentID(el, targetCtx, opts),
      },
    )
      .then(({ reply }) => onReply && onReply(reply))
      .catch((error) => logError("Failed to push event", error));
  }

  pushFileProgress(fileEl, entryRef, progress, onReply = function () {}) {
    this.liveSocket.withinOwners(fileEl.form, (view, targetCtx) => {
      view
        .pushWithReply(null, "progress", {
          event: fileEl.getAttribute(view.binding(PHX_PROGRESS)),
          ref: fileEl.getAttribute(PHX_UPLOAD_REF),
          entry_ref: entryRef,
          progress: progress,
          cid: view.targetComponentID(fileEl.form, targetCtx),
        })
        .then(() => onReply())
        .catch((error) => logError("Failed to push file progress", error));
    });
  }

  pushInput(inputEl, targetCtx, forceCid, phxEvent, opts, callback) {
    if (!inputEl.form) {
      throw new Error("form events require the input to be inside a form");
    }

    let uploads;
    const cid = isCid(forceCid)
      ? forceCid
      : this.targetComponentID(inputEl.form, targetCtx, opts);
    const refGenerator = (maybePayload) => {
      return this.putRef(
        [
          { el: inputEl, loading: true, lock: true },
          { el: inputEl.form, loading: true, lock: true },
        ],
        phxEvent,
        "change",
        { ...opts, payload: maybePayload?.payload },
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
    if (
      DOM.isUploadInput(inputEl) &&
      inputEl.files &&
      inputEl.files.length > 0
    ) {
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
        ...meta,
      },
      uploads: uploads,
      cid: cid,
    };
    this.pushWithReply(refGenerator, "event", event)
      .then(({ resp }) => {
        if (DOM.isUploadInput(inputEl) && DOM.isAutoUpload(inputEl)) {
          // the element could be inside a locked parent for other unrelated changes;
          // we can only start uploads when the tree is unlocked and the
          // necessary data attributes are set in the real DOM
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
                },
              );
            }
          });
        } else {
          callback && callback(resp);
        }
      })
      .catch((error) => logError("Failed to push input event", error));
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
    return this.formSubmits.find(([el, _ref, _opts, _callback]) =>
      el.isSameNode(formEl),
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
      },
    );
  }

  disableForm(formEl, phxEvent, opts = {}) {
    const filterIgnored = (el) => {
      const userIgnored = closestPhxBinding(
        el,
        `${this.binding(PHX_UPDATE)}=ignore`,
        el.form,
      );
      return !(
        userIgnored || closestPhxBinding(el, "data-phx-update=ignore", el.form)
      );
    };
    const filterDisables = (el) => {
      return el.hasAttribute(this.binding(PHX_DISABLE_WITH));
    };
    const filterButton = (el) => el.tagName == "BUTTON";

    const filterInput = (el) =>
      ["INPUT", "TEXTAREA", "SELECT"].includes(el.tagName);

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
    const formEls = disables
      .concat(buttons)
      .concat(inputs)
      .map((el) => {
        return { el, loading: true, lock: true };
      });

    // we reverse the order so form children are already locked by the time
    // the form is locked
    const els = [{ el: formEl, loading: true, lock: false }]
      .concat(formEls)
      .reverse();
    return this.putRef(els, phxEvent, "submit", opts);
  }

  pushFormSubmit(formEl, targetCtx, phxEvent, submitter, opts, onReply) {
    const refGenerator = (maybePayload) =>
      this.disableForm(formEl, phxEvent, {
        ...opts,
        form: formEl,
        payload: maybePayload?.payload,
        submitter: submitter,
      });
    // store the submitter in the form element in order to trigger it
    // for phx-trigger-action
    DOM.putPrivate(formEl, "submitter", submitter);
    const cid = this.targetComponentID(formEl, targetCtx);
    if (LiveUploader.hasUploadsInProgress(formEl)) {
      const [ref, _els] = refGenerator();
      const push = () =>
        this.pushFormSubmit(
          formEl,
          targetCtx,
          phxEvent,
          submitter,
          opts,
          onReply,
        );
      return this.scheduleSubmit(formEl, ref, opts, push);
    } else if (LiveUploader.inputsAwaitingPreflight(formEl).length > 0) {
      const [ref, els] = refGenerator();
      const proxyRefGen = () => [ref, els, opts];
      this.uploadFiles(formEl, phxEvent, targetCtx, ref, cid, (_uploads) => {
        // if we still having pending preflights it means we have invalid entries
        // and the phx-submit cannot be completed
        if (LiveUploader.inputsAwaitingPreflight(formEl).length > 0) {
          return this.undoRefs(ref, phxEvent);
        }
        const meta = this.extractMeta(formEl, {}, opts.value);
        const formData = serializeForm(formEl, { submitter });
        this.pushWithReply(proxyRefGen, "event", {
          type: "form",
          event: phxEvent,
          value: formData,
          meta: meta,
          cid: cid,
        })
          .then(({ resp }) => onReply(resp))
          .catch((error) => logError("Failed to push form submit", error));
      });
    } else if (
      !(
        formEl.hasAttribute(PHX_REF_SRC) &&
        formEl.classList.contains("phx-submit-loading")
      )
    ) {
      const meta = this.extractMeta(formEl, {}, opts.value);
      const formData = serializeForm(formEl, { submitter });
      this.pushWithReply(refGenerator, "event", {
        type: "form",
        event: phxEvent,
        value: formData,
        meta: meta,
        cid: cid,
      })
        .then(({ resp }) => onReply(resp))
        .catch((error) => logError("Failed to push form submit", error));
    }
  }

  uploadFiles(formEl, phxEvent, targetCtx, ref, cid, onComplete) {
    const joinCountAtUpload = this.joinCount;
    const inputEls = LiveUploader.activeFileInputs(formEl);
    let numFileInputsInProgress = inputEls.length;

    // get each file input
    inputEls.forEach((inputEl) => {
      const uploader = new LiveUploader(inputEl, this, () => {
        numFileInputsInProgress--;
        if (numFileInputsInProgress === 0) {
          onComplete();
        }
      });

      const entries = uploader
        .entries()
        .map((entry) => entry.toPreflightPayload());

      if (entries.length === 0) {
        numFileInputsInProgress--;
        return;
      }

      const payload = {
        ref: inputEl.getAttribute(PHX_UPLOAD_REF),
        entries: entries,
        cid: this.targetComponentID(inputEl.form, targetCtx),
      };

      this.log("upload", () => ["sending preflight request", payload]);

      this.pushWithReply(null, "allow_upload", payload)
        .then(({ resp }) => {
          this.log("upload", () => ["got preflight response", resp]);
          // the preflight will reject entries beyond the max entries
          // so we error and cancel entries on the client that are missing from the response
          uploader.entries().forEach((entry) => {
            if (resp.entries && !resp.entries[entry.ref]) {
              this.handleFailedEntryPreflight(
                entry.ref,
                "failed preflight",
                uploader,
              );
            }
          });
          // for auto uploads, we may have an empty entries response from the server
          // for form submits that contain invalid entries
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
        })
        .catch((error) => logError("Failed to push upload", error));
    });
  }

  handleFailedEntryPreflight(uploadRef, reason, uploader) {
    if (uploader.isAutoUpload()) {
      // uploadRef may be top level upload config ref or entry ref
      const entry = uploader
        .entries()
        .find((entry) => entry.ref === uploadRef.toString());
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
    const inputs = DOM.findUploadInputs(targetElement).filter(
      (el) => el.name === name,
    );
    if (inputs.length === 0) {
      logError(`no live file inputs found matching the name "${name}"`);
    } else if (inputs.length > 1) {
      logError(`duplicate live file inputs found matching the name "${name}"`);
    } else {
      DOM.dispatchEvent(inputs[0], PHX_TRACK_UPLOADS, {
        detail: { files: filesOrBlobs },
      });
    }
  }

  targetCtxElement(targetCtx) {
    if (isCid(targetCtx)) {
      const [target] = DOM.findComponentNodeList(this.id, targetCtx);
      return target;
    } else if (targetCtx) {
      return targetCtx;
    } else {
      return null;
    }
  }

  pushFormRecovery(oldForm, newForm, templateDom, callback) {
    // we are only recovering forms inside the current view, therefore it is safe to
    // skip withinOwners here and always use this when referring to the view
    const phxChange = this.binding("change");
    const phxTarget = newForm.getAttribute(this.binding("target")) || newForm;
    const phxEvent =
      newForm.getAttribute(this.binding(PHX_AUTO_RECOVER)) ||
      newForm.getAttribute(this.binding("change"));
    const inputs = Array.from(oldForm.elements).filter(
      (el) => DOM.isFormInput(el) && el.name && !el.hasAttribute(phxChange),
    );
    if (inputs.length === 0) {
      callback();
      return;
    }

    // we must clear tracked uploads before recovery as they no longer have valid refs
    inputs.forEach(
      (input) =>
        input.hasAttribute(PHX_UPLOAD_REF) && LiveUploader.clearFiles(input),
    );
    // pushInput assumes that there is a source element that initiated the change;
    // because this is not the case when we recover forms, we provide the first input we find
    const input = inputs.find((el) => el.type !== "hidden") || inputs[0];

    // in the case that there are multiple targets, we count the number of pending recovery events
    // and only call the callback once all events have been processed
    let pending = 0;
    // withinTargets(phxTarget, callback, dom, viewEl)
    this.withinTargets(
      phxTarget,
      (targetView, targetCtx) => {
        const cid = this.targetComponentID(newForm, targetCtx);
        pending++;
        let e = new CustomEvent("phx:form-recovery", {
          detail: { sourceElement: oldForm },
        });
        JS.exec(e, "change", phxEvent, this, input, [
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
            },
          },
        ]);
      },
      templateDom,
    );
  }

  pushLinkPatch(e, href, targetEl, callback) {
    const linkRef = this.liveSocket.setPendingLink(href);
    // only add loading states if event is trusted (it was triggered by user, such as click) and
    // it's not a forward/back navigation from popstate
    const loading = e.isTrusted && e.type !== "popstate";
    const refGen = targetEl
      ? () =>
          this.putRef(
            [{ el: targetEl, loading: loading, lock: true }],
            null,
            "click",
          )
      : null;
    const fallback = () => this.liveSocket.redirect(window.location.href);
    const url = href.startsWith("/")
      ? `${location.protocol}//${location.host}${href}`
      : href;

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
      ({ error: _error, timeout: _timeout }) => fallback(),
    );
  }

  getFormsForRecovery() {
    // Form recovery is complex in LiveView:
    // We want to support nested LiveViews and also provide a good user experience.
    // Therefore, when the channel rejoins, we copy all forms that are eligible for
    // recovery to be able to access them later.
    // Why do we need to copy them? Because when the main LiveView joins, any forms
    // in nested LiveViews would be lost.
    //
    // We should rework this in the future to serialize the form payload here
    // instead of cloning the DOM nodes, but making this work correctly is tedious,
    // as sending the correct form payload relies on JS.push to extract values
    // from JS commands (phx-change={JS.push("event", value: ..., target: ...)}),
    // as well as view.pushInput, which expects DOM elements.

    if (this.joinCount === 0) {
      return {};
    }

    const phxChange = this.binding("change");

    return DOM.all(
      document,
      `#${CSS.escape(this.id)} form[${phxChange}], [${PHX_TELEPORTED_REF}="${CSS.escape(this.id)}"] form[${phxChange}]`,
    )
      .filter((form) => form.id)
      .filter((form) => form.elements.length > 0)
      .filter(
        (form) =>
          form.getAttribute(this.binding(PHX_AUTO_RECOVER)) !== "ignore",
      )
      .map((form) => {
        // We need to clone the whole form, as relying on form.elements can lead to
        // situations where we have
        //
        //   <form><fieldset disabled><input name="foo" value="bar"></fieldset></form>
        //
        // and form.elements returns both the fieldset and the input separately.
        // Because the fieldset is disabled, the input should NOT be sent though.
        // We can only reliably serialize the form by cloning it fully.
        const clonedForm = form.cloneNode(true);
        // we call morphdom to copy any special state
        // like the selected option of a <select> element;
        // any also copy over privates (which contain information about touched fields)
        morphdom(clonedForm, form, {
          onBeforeElUpdated: (fromEl, toEl) => {
            DOM.copyPrivates(fromEl, toEl);
            return true;
          },
        });
        // next up, we also need to clone any elements with form="id" parameter
        const externalElements = document.querySelectorAll(
          `[form="${form.id}"]`,
        );
        Array.from(externalElements).forEach((el) => {
          if (form.contains(el)) {
            return;
          }
          const clonedEl = el.cloneNode(true);
          morphdom(clonedEl, el);
          DOM.copyPrivates(clonedEl, el);
          clonedForm.appendChild(clonedEl);
        });
        return clonedForm;
      })
      .reduce((acc, form) => {
        acc[form.id] = form;
        return acc;
      }, {});
  }

  maybePushComponentsDestroyed(destroyedCIDs) {
    let willDestroyCIDs = destroyedCIDs.filter((cid) => {
      return DOM.findComponentNodeList(this.id, cid).length === 0;
    });

    const onError = (error) => {
      if (!this.isDestroyed()) {
        logError("Failed to push components destroyed", error);
      }
    };

    if (willDestroyCIDs.length > 0) {
      // we must reset the render change tracking for cids that
      // could be added back from the server so we don't skip them
      willDestroyCIDs.forEach((cid) => this.rendered.resetRender(cid));

      this.pushWithReply(null, "cids_will_destroy", { cids: willDestroyCIDs })
        .then(() => {
          // we must wait for pending transitions to complete before determining
          // if the cids were added back to the DOM in the meantime (#3139)
          this.liveSocket.requestDOMUpdate(() => {
            // See if any of the cids we wanted to destroy were added back,
            // if they were added back, we don't actually destroy them.
            let completelyDestroyCIDs = willDestroyCIDs.filter((cid) => {
              return DOM.findComponentNodeList(this.id, cid).length === 0;
            });

            if (completelyDestroyCIDs.length > 0) {
              this.pushWithReply(null, "cids_destroyed", {
                cids: completelyDestroyCIDs,
              })
                .then(({ resp }) => {
                  this.rendered.pruneCIDs(resp.cids);
                })
                .catch(onError);
            }
          });
        })
        .catch(onError);
    }
  }

  ownsElement(el) {
    let parentViewEl = DOM.closestViewEl(el);
    return (
      el.getAttribute(PHX_PARENT_ID) === this.id ||
      (parentViewEl && parentViewEl.id === this.id) ||
      (!parentViewEl && this.isDead)
    );
  }

  submitForm(form, targetCtx, phxEvent, submitter, opts = {}) {
    DOM.putPrivate(form, PHX_HAS_SUBMITTED, true);
    const inputs = Array.from(form.elements);
    inputs.forEach((input) => DOM.putPrivate(input, PHX_HAS_SUBMITTED, true));
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
}
