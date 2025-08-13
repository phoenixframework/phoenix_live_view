import {
  PHX_COMPONENT,
  PHX_PRUNE,
  PHX_ROOT_ID,
  PHX_SESSION,
  PHX_SKIP,
  PHX_MAGIC_ID,
  PHX_STATIC,
  PHX_TRIGGER_ACTION,
  PHX_UPDATE,
  PHX_REF_SRC,
  PHX_REF_LOCK,
  PHX_STREAM,
  PHX_STREAM_REF,
  PHX_VIEWPORT_TOP,
  PHX_VIEWPORT_BOTTOM,
  PHX_PORTAL,
  PHX_TELEPORTED_REF,
  PHX_TELEPORTED_SRC,
  PHX_RUNTIME_HOOK,
} from "./constants";

import { detectDuplicateIds, detectInvalidStreamInserts, isCid } from "./utils";
import ElementRef from "./element_ref";
import DOM from "./dom";
import DOMPostMorphRestorer from "./dom_post_morph_restorer";
import morphdom from "morphdom";

export default class DOMPatch {
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
    this.targetContainer = this.isCIDPatch()
      ? this.targetCIDContainer(html)
      : container;
    this.callbacks = {
      beforeadded: [],
      beforeupdated: [],
      beforephxChildAdded: [],
      afteradded: [],
      afterupdated: [],
      afterdiscarded: [],
      afterphxChildAdded: [],
      aftertransitionsDiscarded: [],
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
    DOM.all(
      this.container,
      `[${phxUpdate}=append] > *, [${phxUpdate}=prepend] > *`,
      (el) => {
        el.setAttribute(PHX_PRUNE, "");
      },
    );
  }

  perform(isJoinPatch) {
    const { view, liveSocket, html, container } = this;
    let targetContainer = this.targetContainer;

    if (this.isCIDPatch() && !this.targetContainer) {
      return;
    }

    if (this.isCIDPatch()) {
      // https://github.com/phoenixframework/phoenix_live_view/pull/3942
      // we need to ensure that no parent is locked
      const closestLock = targetContainer.closest(`[${PHX_REF_LOCK}]`);
      if (closestLock) {
        const clonedTree = DOM.private(closestLock, PHX_REF_LOCK);
        if (clonedTree) {
          // if a parent is locked with a cloned tree, we need to patch the cloned tree instead
          targetContainer = clonedTree.querySelector(
            `[data-phx-component="${this.targetCID}"]`,
          );
        }
      }
    }

    const focused = liveSocket.getActiveElement();
    const { selectionStart, selectionEnd } =
      focused && DOM.hasSelectionRange(focused) ? focused : {};
    const phxUpdate = liveSocket.binding(PHX_UPDATE);
    const phxViewportTop = liveSocket.binding(PHX_VIEWPORT_TOP);
    const phxViewportBottom = liveSocket.binding(PHX_VIEWPORT_BOTTOM);
    const phxTriggerExternal = liveSocket.binding(PHX_TRIGGER_ACTION);
    const added = [];
    const updates = [];
    const appendPrependUpdates = [];

    // as the portal target itself could be at the end of the DOM,
    // it may not be present while morphing previous parts;
    // therefore we apply all teleports after the morphing is done+
    const portalCallbacks = [];

    let externalFormTriggered = null;

    const morph = (
      targetContainer,
      source,
      withChildren = this.withChildren,
    ) => {
      const morphCallbacks = {
        // normally, we are running with childrenOnly, as the patch HTML for a LV
        // does not include the LV attrs (data-phx-session, etc.)
        // when we are patching a live component, we do want to patch the root element as well;
        // another case is the recursive patch of a stream item that was kept on reset (-> onBeforeNodeAdded)
        childrenOnly:
          targetContainer.getAttribute(PHX_COMPONENT) === null && !withChildren,
        getNodeKey: (node) => {
          if (DOM.isPhxDestroyed(node)) {
            return null;
          }
          // If we have a join patch, then by definition there was no PHX_MAGIC_ID.
          // This is important to reduce the amount of elements morphdom discards.
          if (isJoinPatch) {
            return node.id;
          }
          return (
            node.id || (node.getAttribute && node.getAttribute(PHX_MAGIC_ID))
          );
        },
        // skip indexing from children when container is stream
        skipFromChildren: (from) => {
          return from.getAttribute(phxUpdate) === PHX_STREAM;
        },
        // tell morphdom how to add a child
        addChild: (parent, child) => {
          const { ref, streamAt } = this.getStreamInsert(child);
          if (ref === undefined) {
            return parent.appendChild(child);
          }

          this.setStreamRef(child, ref);

          // streaming
          if (streamAt === 0) {
            parent.insertAdjacentElement("afterbegin", child);
          } else if (streamAt === -1) {
            const lastChild = parent.lastElementChild;
            if (lastChild && !lastChild.hasAttribute(PHX_STREAM_REF)) {
              const nonStreamChild = Array.from(parent.children).find(
                (c) => !c.hasAttribute(PHX_STREAM_REF),
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
          // don't add update_only nodes if they did not already exist
          if (
            this.getStreamInsert(el)?.updateOnly &&
            !this.streamComponentRestore[el.id]
          ) {
            return false;
          }

          DOM.maintainPrivateHooks(el, el, phxViewportTop, phxViewportBottom);
          this.trackBefore("added", el);

          let morphedEl = el;
          // this is a stream item that was kept on reset, recursively morph it
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
          // phx-portal handling
          if (DOM.isPortalTemplate(el)) {
            portalCallbacks.push(() => this.teleport(el, morph));
          }

          // hack to fix Safari handling of img srcset and video tags
          if (el instanceof HTMLImageElement && el.srcset) {
            // eslint-disable-next-line no-self-assign
            el.srcset = el.srcset;
          } else if (el instanceof HTMLVideoElement && el.autoplay) {
            el.play();
          }
          if (DOM.isNowTriggerFormExternal(el, phxTriggerExternal)) {
            externalFormTriggered = el;
          }

          // nested view handling
          if (
            (DOM.isPhxChild(el) && view.ownsElement(el)) ||
            (DOM.isPhxSticky(el) && view.ownsElement(el.parentNode))
          ) {
            this.trackAfter("phxChildAdded", el);
          }

          // data-phx-runtime-hook
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
          if (
            el.parentElement !== null &&
            el.id &&
            DOM.isPhxUpdate(el.parentElement, phxUpdate, [
              PHX_STREAM,
              "append",
              "prepend",
            ])
          ) {
            return false;
          }
          // don't remove teleported elements
          if (el.getAttribute && el.getAttribute(PHX_TELEPORTED_REF)) {
            return false;
          }
          if (this.maybePendingRemove(el)) {
            return false;
          }
          if (this.skipCIDSibling(el)) {
            return false;
          }

          if (DOM.isPortalTemplate(el)) {
            // if the portal template itself is removed, remove the teleported element as well;
            // we also perform a check after morphdom is finished to catch parent removals
            const teleportedEl = document.getElementById(
              el.content.firstElementChild.id,
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
          if (DOM.isNowTriggerFormExternal(el, phxTriggerExternal)) {
            externalFormTriggered = el;
          }
          updates.push(el);
          this.maybeReOrderStream(el, false);
        },
        onBeforeElUpdated: (fromEl, toEl) => {
          // if we are patching the root target container and the id has changed, treat it as a new node
          // by replacing the fromEl with the toEl, which ensures hooks are torn down and re-created
          if (
            fromEl.id &&
            fromEl.isSameNode(targetContainer) &&
            fromEl.id !== toEl.id
          ) {
            morphCallbacks.onNodeDiscarded(fromEl);
            fromEl.replaceWith(toEl);
            return morphCallbacks.onNodeAdded(toEl);
          }
          DOM.syncPendingAttrs(fromEl, toEl);
          DOM.maintainPrivateHooks(
            fromEl,
            toEl,
            phxViewportTop,
            phxViewportBottom,
          );
          DOM.cleanChildNodes(toEl, phxUpdate);
          if (this.skipCIDSibling(toEl)) {
            // if this is a live component used in a stream, we may need to reorder it
            this.maybeReOrderStream(fromEl);
            return false;
          }
          if (DOM.isPhxSticky(fromEl)) {
            [PHX_SESSION, PHX_STATIC, PHX_ROOT_ID]
              .map((attr) => [
                attr,
                fromEl.getAttribute(attr),
                toEl.getAttribute(attr),
              ])
              .forEach(([attr, fromVal, toVal]) => {
                if (toVal && fromVal !== toVal) {
                  fromEl.setAttribute(attr, toVal);
                }
              });

            return false;
          }
          if (
            DOM.isIgnored(fromEl, phxUpdate) ||
            (fromEl.form && fromEl.form.isSameNode(externalFormTriggered))
          ) {
            this.trackBefore("updated", fromEl, toEl);
            DOM.mergeAttrs(fromEl, toEl, {
              isIgnored: DOM.isIgnored(fromEl, phxUpdate),
            });
            updates.push(fromEl);
            DOM.applyStickyOperations(fromEl);
            return false;
          }
          if (
            fromEl.type === "number" &&
            fromEl.validity &&
            fromEl.validity.badInput
          ) {
            return false;
          }
          // If the element has PHX_REF_SRC, it is loading or locked and awaiting an ack.
          // If it's locked, we clone the fromEl tree and instruct morphdom to use
          // the cloned tree as the source of the morph for this branch from here on out.
          // We keep a reference to the cloned tree in the element's private data, and
          // on ack (view.undoRefs), we morph the cloned tree with the true fromEl in the DOM to
          // apply any changes that happened while the element was locked.
          const isFocusedFormEl =
            focused && fromEl.isSameNode(focused) && DOM.isFormInput(fromEl);
          const focusedSelectChanged =
            isFocusedFormEl && this.isChangedSelect(fromEl, toEl);
          if (fromEl.hasAttribute(PHX_REF_SRC)) {
            const ref = new ElementRef(fromEl);
            // only perform the clone step if this is not a patch that unlocks
            if (
              ref.lockRef &&
              (!this.undoRef || !ref.isLockUndoneBy(this.undoRef))
            ) {
              if (DOM.isUploadInput(fromEl)) {
                DOM.mergeAttrs(fromEl, toEl, { isIgnored: true });
                this.trackBefore("updated", fromEl, toEl);
                updates.push(fromEl);
              }
              DOM.applyStickyOperations(fromEl);
              const isLocked = fromEl.hasAttribute(PHX_REF_LOCK);
              const clone = isLocked
                ? DOM.private(fromEl, PHX_REF_LOCK) || fromEl.cloneNode(true)
                : null;
              if (clone) {
                DOM.putPrivate(fromEl, PHX_REF_LOCK, clone);
                if (!isFocusedFormEl) {
                  fromEl = clone;
                }
              }
            }
          }

          // nested view handling
          if (DOM.isPhxChild(toEl)) {
            const prevSession = fromEl.getAttribute(PHX_SESSION);
            DOM.mergeAttrs(fromEl, toEl, { exclude: [PHX_STATIC] });
            if (prevSession !== "") {
              fromEl.setAttribute(PHX_SESSION, prevSession);
            }
            fromEl.setAttribute(PHX_ROOT_ID, this.rootID);
            DOM.applyStickyOperations(fromEl);
            return false;
          }

          // if we are undoing a lock, copy potentially nested clones over
          if (this.undoRef && DOM.private(toEl, PHX_REF_LOCK)) {
            DOM.putPrivate(
              fromEl,
              PHX_REF_LOCK,
              DOM.private(toEl, PHX_REF_LOCK),
            );
          }
          // now copy regular DOM.private data
          DOM.copyPrivates(toEl, fromEl);

          // phx-portal handling
          if (DOM.isPortalTemplate(toEl)) {
            portalCallbacks.push(() => this.teleport(toEl, morph));
            return false;
          }

          // skip patching focused inputs unless focus is a select that has changed options
          if (
            isFocusedFormEl &&
            fromEl.type !== "hidden" &&
            !focusedSelectChanged
          ) {
            this.trackBefore("updated", fromEl, toEl);
            DOM.mergeFocusedInput(fromEl, toEl);
            DOM.syncAttrsToProps(fromEl);
            updates.push(fromEl);
            DOM.applyStickyOperations(fromEl);
            return false;
          } else {
            // blur focused select if it changed so native UI is updated (ie safari won't update visible options)
            if (focusedSelectChanged) {
              fromEl.blur();
            }
            if (DOM.isPhxUpdate(toEl, phxUpdate, ["append", "prepend"])) {
              appendPrependUpdates.push(
                new DOMPostMorphRestorer(
                  fromEl,
                  toEl,
                  toEl.getAttribute(phxUpdate),
                ),
              );
            }

            DOM.syncAttrsToProps(toEl);
            DOM.applyStickyOperations(toEl);
            this.trackBefore("updated", fromEl, toEl);
            return fromEl;
          }
        },
      };

      morphdom(targetContainer, source, morphCallbacks);
    };

    this.trackBefore("added", container);
    this.trackBefore("updated", container, container);

    liveSocket.time("morphdom", () => {
      this.streams.forEach(([ref, inserts, deleteIds, reset]) => {
        inserts.forEach(([key, streamAt, limit, updateOnly]) => {
          this.streamInserts[key] = { ref, streamAt, limit, reset, updateOnly };
        });
        if (reset !== undefined) {
          DOM.all(container, `[${PHX_STREAM_REF}="${ref}"]`, (child) => {
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

      // clear stream items from the dead render if they are not inserted again
      if (isJoinPatch) {
        DOM.all(this.container, `[${phxUpdate}=${PHX_STREAM}]`)
          // it is important to filter the element before removing them, as
          // it may happen that streams are nested and the owner check fails if
          // a parent is removed before a child
          .filter((el) => this.view.ownsElement(el))
          .forEach((el) => {
            Array.from(el.children).forEach((child) => {
              // we already performed the owner check, each child is guaranteed to be owned
              // by the view. To prevent the nested owner check from failing in case of nested
              // streams where the parent is removed before the child, we force the removal
              this.removeStreamChildElement(child, true);
            });
          });
      }

      morph(targetContainer, html);
      // normal patch complete, teleport elements now
      portalCallbacks.forEach((callback) => callback());
      // check for any teleported elements that are not in the view any more
      // and remove them
      this.view.portalElementIds.forEach((id) => {
        const el = document.getElementById(id);
        if (el) {
          const source = document.getElementById(
            el.getAttribute(PHX_TELEPORTED_SRC),
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
      // warn if there are any inputs named "id"
      Array.from(document.querySelectorAll("input[name=id]")).forEach(
        (node) => {
          if (node instanceof HTMLInputElement && node.form) {
            console.error(
              'Detected an input with name="id" inside a form! This will cause problems when patching the DOM.\n',
              node,
            );
          }
        },
      );
    }

    if (appendPrependUpdates.length > 0) {
      liveSocket.time("post-morph append/prepend restoration", () => {
        appendPrependUpdates.forEach((update) => update.perform());
      });
    }

    liveSocket.silenceEvents(() =>
      DOM.restoreFocus(focused, selectionStart, selectionEnd),
    );
    DOM.dispatchEvent(document, "phx:update");
    added.forEach((el) => this.trackAfter("added", el));
    updates.forEach((el) => this.trackAfter("updated", el));

    this.transitionPendingRemoves();

    if (externalFormTriggered) {
      liveSocket.unload();
      // check for submitter and inject it as hidden input for external submit;
      // In theory, it could happen that the stored submitter is outdated and doesn't
      // exist in the DOM any more, but this is unlikely, so we just accept it for now.
      const submitter = DOM.private(externalFormTriggered, "submitter");
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
      // use prototype's submit in case there's a form control with name or id of "submit"
      // https://developer.mozilla.org/en-US/docs/Web/API/HTMLFormElement/submit
      Object.getPrototypeOf(externalFormTriggered).submit.call(
        externalFormTriggered,
      );
    }
    return true;
  }

  onNodeDiscarded(el) {
    // nested view handling
    if (DOM.isPhxChild(el) || DOM.isPhxSticky(el)) {
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
    // make sure to only remove elements owned by the current view
    // see https://github.com/phoenixframework/phoenix_live_view/issues/3047
    // and https://github.com/phoenixframework/phoenix_live_view/issues/3681
    if (!force && !this.view.ownsElement(child)) {
      return;
    }

    // we need to store the node if it is actually re-added in the same patch
    // we do NOT want to execute phx-remove, we do NOT want to call onNodeDiscarded
    if (this.streamInserts[child.id]) {
      this.streamComponentRestore[child.id] = child;
      child.remove();
    } else {
      // only remove the element now if it has no phx-remove binding
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
    DOM.putSticky(el, PHX_STREAM_REF, (el) =>
      el.setAttribute(PHX_STREAM_REF, ref),
    );
  }

  maybeReOrderStream(el, isNew) {
    const { ref, streamAt, reset } = this.getStreamInsert(el);
    if (streamAt === undefined) {
      return;
    }

    // we need to set the PHX_STREAM_REF here as well as addChild is invoked only for parents
    this.setStreamRef(el, ref);

    if (!reset && !isNew) {
      // we only reorder if the element is new or it's a stream reset
      return;
    }

    // check if the element has a parent element;
    // it doesn't if we are currently recursively morphing (restoring a saved stream child)
    // because the element is not yet added to the real dom;
    // reordering does not make sense in that case anyway
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
      children
        .slice(0, children.length + limit)
        .forEach((child) => this.removeStreamChildElement(child));
    } else if (limit && limit >= 0 && children.length > limit) {
      children
        .slice(limit)
        .forEach((child) => this.removeStreamChildElement(child));
    }
  }

  transitionPendingRemoves() {
    const { pendingRemoves, liveSocket } = this;
    if (pendingRemoves.length > 0) {
      liveSocket.transitionRemoves(pendingRemoves, () => {
        pendingRemoves.forEach((el) => {
          const child = DOM.firstPhxChild(el);
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

    // keep the current value
    toEl.value = fromEl.value;

    // in general we have to be very careful with using isEqualNode as it does not a reliable
    // DOM tree equality check, but for selection attributes and options it works fine
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
    const [first, ...rest] = DOM.findComponentNodeList(
      this.view.id,
      this.targetCID,
    );
    if (rest.length === 0 && DOM.childNodeLength(html) === 1) {
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
        "portal target with selector " + targetSelector + " not found",
      );
    }
    // phx-portal templates must have a single root element, so we assume this to be
    // the case here
    const toTeleport = el.content.firstElementChild;
    // the PHX_SKIP optimization can also apply inside of the <template> elements
    if (this.skipCIDSibling(toTeleport)) {
      return;
    }
    if (!toTeleport?.id) {
      throw new Error(
        "phx-portal template must have a single root element with ID!",
      );
    }
    const existing = document.getElementById(toTeleport.id);
    let portalTarget;
    if (existing) {
      // check if the element needs to be moved to another target
      if (!portalContainer.contains(existing)) {
        portalContainer.appendChild(existing);
      }
      // we already teleported in a previous patch
      portalTarget = existing;
    } else {
      // create empty target and morph it recursively
      portalTarget = document.createElement(toTeleport.tagName);
      portalContainer.appendChild(portalTarget);
    }
    // mark the target as teleported;
    // to prevent unnecessary attribute modifications, we set the attribute
    // on the source and remove it after morphing (we could also just keep it)
    // otherwise morphdom would remove it, as the ref is not present in the source
    // and we'd need to set it back after each morph
    toTeleport.setAttribute(PHX_TELEPORTED_REF, this.view.id);
    toTeleport.setAttribute(PHX_TELEPORTED_SRC, el.id);
    morph(portalTarget, toTeleport, true);
    toTeleport.removeAttribute(PHX_TELEPORTED_REF);
    toTeleport.removeAttribute(PHX_TELEPORTED_SRC);
    // store a reference to the teleported element in the view
    // to cleanup when the view is destroyed, in case the portal target
    // is outside the view itself
    this.view.pushPortalElementId(toTeleport.id);
  }

  handleRuntimeHook(el, source) {
    // usually, scripts are not executed when morphdom adds them to the DOM
    // we special case runtime colocated hooks
    const name = el.getAttribute(PHX_RUNTIME_HOOK);
    let nonce = el.hasAttribute("nonce") ? el.getAttribute("nonce") : null;
    if (el.hasAttribute("nonce")) {
      const template = document.createElement("template");
      template.innerHTML = source;
      nonce = template.content
        .querySelector(`script[${PHX_RUNTIME_HOOK}="${CSS.escape(name)}"]`)
        .getAttribute("nonce");
    }
    const script = document.createElement("script");
    script.textContent = el.textContent;
    DOM.mergeAttrs(script, el, { isIgnored: false });
    if (nonce) {
      script.nonce = nonce;
    }
    el.replaceWith(script);
    el = script;
  }
}
