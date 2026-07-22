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

import { detectDuplicateIds, detectInvalidStreamInserts } from "./utils";
import ElementRef from "./element_ref";
import DOM from "./dom";
import DOMPostMorphRestorer from "./dom_post_morph_restorer";
import morphdom from "morphdom";
import View from "./view";
import LiveSocket from "./live_socket";

type Stream = Set<any>;
type MorphdomOptions = Parameters<typeof morphdom>[2] & {
  // morphdom's types are outdated
  onBeforeElUpdated: (fromEl: Element, toEl: Element) => boolean | Element;
};
type BeforeUpdatedCallback = (fromEl: Element, toEl: Element) => void;
type AfterAddedCallback = (el: Node) => void;
type AfterUpdatedCallback = (el: Element) => void;
type AfterPhxChildAddedCallback = (el: Element) => void;
type AfterDiscardedCallback = (el: Node) => void;
type AfterTransitionsDiscardedCallback = (els: Element[]) => void;

export default class DOMPatch {
  private view: View;
  private liveSocket: LiveSocket;
  private container: Element;
  private rootID: string;
  private html: string | Node;
  private streams: Stream;
  private streamInserts: Record<string, any>;
  private streamComponentRestore: Record<string, any>;
  private targetCID: number | null;
  private pendingRemoves: any[];
  private phxRemove: string;
  private targetContainer: Element;
  private beforeUpdatedCallbacks: BeforeUpdatedCallback[];
  private afterAddedCallbacks: AfterAddedCallback[];
  private afterUpdatedCallbacks: AfterUpdatedCallback[];
  private afterPhxChildAddedCallbacks: AfterPhxChildAddedCallback[];
  private afterDiscardedCallbacks: AfterDiscardedCallback[];
  private afterTransitionsDiscardedCallbacks: AfterTransitionsDiscardedCallback[];
  private withChildren: boolean;
  private undoRef: number | null;

  constructor(
    view: View,
    container: Element,
    html: string | Node,
    streams: Set<Stream>,
    targetCID: number | null,
    opts: { withChildren?: boolean; undoRef?: number } = {},
  ) {
    this.view = view;
    this.liveSocket = view.liveSocket;
    this.container = container;
    this.rootID = view.root.id;
    this.html = html;
    this.streams = streams;
    this.streamInserts = {};
    this.streamComponentRestore = {};
    this.targetCID = targetCID;
    this.pendingRemoves = [];
    this.phxRemove = this.liveSocket.binding("remove");
    // If we patch a component, we always pass a string
    this.targetContainer = targetCID
      ? DOM.getComponent(this.view.id, targetCID)
      : container;
    this.beforeUpdatedCallbacks = [];
    this.afterAddedCallbacks = [];
    this.afterUpdatedCallbacks = [];
    this.afterPhxChildAddedCallbacks = [];
    this.afterDiscardedCallbacks = [];
    this.afterTransitionsDiscardedCallbacks = [];
    // unlock patches pass undoRef and must morph the locked element itself, not
    // only its children. The first client ref is 0, so this must check for the
    // option's presence rather than truthiness.
    this.withChildren =
      opts.withChildren || opts.undoRef !== undefined || false;
    this.undoRef = opts.undoRef ?? null;
  }

  beforeUpdated(callback: BeforeUpdatedCallback) {
    this.beforeUpdatedCallbacks.push(callback);
  }

  afterAdded(callback: AfterAddedCallback) {
    this.afterAddedCallbacks.push(callback);
  }

  afterUpdated(callback: AfterUpdatedCallback) {
    this.afterUpdatedCallbacks.push(callback);
  }

  afterPhxChildAdded(callback: AfterPhxChildAddedCallback) {
    this.afterPhxChildAddedCallbacks.push(callback);
  }

  afterDiscarded(callback: AfterDiscardedCallback) {
    this.afterDiscardedCallbacks.push(callback);
  }

  afterTransitionsDiscarded(callback: AfterTransitionsDiscardedCallback) {
    this.afterTransitionsDiscardedCallbacks.push(callback);
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
    const reportError = (code, message, metadata?) =>
      view.logError(code, message, metadata);
    let targetContainer = this.targetContainer;

    if (this.targetCID) {
      // https://github.com/phoenixframework/phoenix_live_view/pull/3942
      // we need to ensure that no parent is locked
      const closestLock = targetContainer.closest(`[${PHX_REF_LOCK}]`);
      // If the targetContainer itself is locked, that's okay.
      // https://github.com/phoenixframework/phoenix_live_view/issues/4088
      if (closestLock && !closestLock.isSameNode(targetContainer)) {
        const clonedTree = DOM.private(closestLock, PHX_REF_LOCK);
        if (clonedTree) {
          // if a parent is locked with a cloned tree, we need to patch the cloned tree instead
          targetContainer = clonedTree.querySelector(
            `[data-phx-component="${this.targetCID}"]`,
          );
          // The visible DOM can still contain the target CID while the locked
          // clone has gone stale and no longer does. In that case there is no
          // safe clone target for this component diff, so leave the visible DOM
          // locked and wait for a later patch instead of throwing or patching
          // outside the locked tree.
          if (!targetContainer) return;
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
    const added: Array<Node> = [];
    const updates: Array<Element> = [];
    const appendPrependUpdates: Array<DOMPostMorphRestorer> = [];

    // as the portal target itself could be at the end of the DOM,
    // it may not be present while morphing previous parts;
    // therefore we apply all teleports after the morphing is done+
    let portalCallbacks: Array<() => void> = [];

    let externalFormTriggered: Element | null = null;

    const morph = (
      targetContainer,
      source,
      withChildren = this.withChildren,
    ) => {
      const morphCallbacks: MorphdomOptions = {
        // normally, we are running with childrenOnly, as the patch HTML for a LV
        // does not include the LV attrs (data-phx-session, etc.)
        // when we are patching a live component, we do want to patch the root element as well;
        // another case is the recursive patch of a stream item that was kept on reset (-> onBeforeNodeAdded)
        childrenOnly:
          targetContainer.getAttribute(PHX_COMPONENT) === null && !withChildren,
        getNodeKey: (node) => {
          if (!(node instanceof Element)) return null;
          if (DOM.isPhxDestroyed(node)) {
            return null;
          }
          // If we have a join patch, then by definition there was no PHX_MAGIC_ID.
          // This is important to reduce the amount of elements morphdom discards.
          if (isJoinPatch) {
            return node.id;
          }

          // If ID was touched by JavaScript hook, use PHX_MAGIC_ID for matching.
          // This ensures morphdom can match elements even when JS modifies their IDs.
          if (DOM.private(node, "clientsideIdAttribute")) {
            return node.getAttribute(PHX_MAGIC_ID);
          }

          return node.id || node.getAttribute(PHX_MAGIC_ID);
        },
        // skip indexing from children when container is stream
        skipFromChildren: (from) => {
          return from.getAttribute(phxUpdate) === PHX_STREAM;
        },
        // tell morphdom how to add a child
        addChild: (parent: Element, child: Element) => {
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
              parent.insertBefore(child, nonStreamChild ?? null);
            } else {
              parent.appendChild(child);
            }
          } else if (streamAt > 0) {
            const sibling = Array.from(parent.children)[streamAt];
            parent.insertBefore(child, sibling);
          }
        },
        onBeforeNodeAdded: (el) => {
          if (!(el instanceof Element)) {
            return el;
          }

          // don't add update_only nodes if they did not already exist
          if (
            this.getStreamInsert(el)?.updateOnly &&
            !this.streamComponentRestore[el.id]
          ) {
            return false;
          }

          DOM.maintainPrivateHooks(el, el, phxViewportTop, phxViewportBottom);

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
          if (!(el instanceof Element)) {
            added.push(el);
            return;
          }

          this.maybeReOrderStream(el, true);

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
            this.trackAfterPhxChildAdded(el);
          }

          // data-phx-runtime-hook
          if (el.nodeName === "SCRIPT" && el.hasAttribute(PHX_RUNTIME_HOOK)) {
            this.handleRuntimeHook(el as HTMLScriptElement, source);
          }

          added.push(el);
        },
        onNodeDiscarded: (el) => this.onNodeDiscarded(el),
        onBeforeNodeDiscarded: (el) => {
          // Non-element nodes can always be discarded
          if (!(el instanceof Element)) {
            return true;
          }

          if (el.getAttribute(PHX_PRUNE) !== null) {
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
          if (el.getAttribute(PHX_TELEPORTED_REF)) {
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
              el.content.firstElementChild?.id || "",
            );
            if (teleportedEl) {
              teleportedEl.remove();
              morphCallbacks.onNodeDiscarded!(teleportedEl);
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
            morphCallbacks.onNodeDiscarded!(fromEl);
            fromEl.replaceWith(toEl);
            return morphCallbacks.onNodeAdded!(toEl);
          }
          DOM.syncPendingAttrs(fromEl, toEl);
          DOM.maintainPrivateHooks(
            fromEl,
            toEl,
            phxViewportTop,
            phxViewportBottom,
          );
          DOM.cleanChildNodes(toEl, phxUpdate, reportError);
          const isFocusedFormEl =
            focused &&
            fromEl.isSameNode(focused) &&
            DOM.isEditableInput(fromEl);
          const focusedSelectChanged =
            isFocusedFormEl && this.isChangedSelect(fromEl, toEl);
          if (this.skipCIDSibling(toEl)) {
            // A skipped update returns before the normal update path below, so
            // it must still perform the lock bookkeeping that keeps private
            // cloned trees in sync.
            this.maybeCloneLockedElement(fromEl, isFocusedFormEl);
            this.copyNestedPrivateLock(fromEl, toEl);
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
            this.trackBeforeUpdated(fromEl, toEl);
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
          fromEl = this.maybeCloneLockedElement(fromEl, isFocusedFormEl);

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

          // If we are undoing a lock, copy potentially nested clones over.
          // This keeps an inner locked subtree's private clone alive while an
          // ancestor lock is being reconciled.
          this.copyNestedPrivateLock(fromEl, toEl);
          // now copy regular DOM.private data
          DOM.copyPrivates(toEl, fromEl);

          // phx-portal handling
          if (DOM.isPortalTemplate(toEl)) {
            portalCallbacks.push(() => this.teleport(toEl, morph));
            // for the magicId optimization we need to ensure that the template contents
            // are properly updated as they are used when restoring a cloned tree
            // Note: we can't write fromEl.innerHTML = toEl.innerHTML because in Chrome
            // the HTML parser would drop nested forms, even when it should not.
            // https://issues.chromium.org/issues/490290430
            fromEl.content.replaceChildren(toEl.content.cloneNode(true));
            return false;
          }

          // skip patching focused inputs unless focus is a select that has changed options
          if (
            isFocusedFormEl &&
            fromEl.type !== "hidden" &&
            !focusedSelectChanged
          ) {
            this.trackBeforeUpdated(fromEl, toEl);
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
            this.trackBeforeUpdated(fromEl, toEl);
            return fromEl;
          }
        },
      };

      morphdom(targetContainer, source, morphCallbacks);
    };

    this.trackBeforeUpdated(container, container);

    liveSocket.time("morphdom", () => {
      this.streams.forEach(([ref, inserts, deleteIds, reset]) => {
        inserts.forEach(([key, streamAt, limit, updateOnly]) => {
          this.streamInserts[key] = { ref, streamAt, limit, reset, updateOnly };
        });
        if (reset !== undefined) {
          DOM.all(document, `[${PHX_STREAM_REF}="${ref}"]`, (child) => {
            this.removeStreamChildElement(child);
          });
        }
        deleteIds.forEach((id) => {
          const child = document.getElementById(id);
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
      // and handle nested teleportation up to depth 5
      let teleportCount = 0;
      while (portalCallbacks.length > 0 && teleportCount < 5) {
        const copy = portalCallbacks.slice();
        portalCallbacks = [];
        copy.forEach((callback) => callback());
        teleportCount++;
      }

      // check for any teleported elements that are not in the view any more
      // and remove them
      this.view.portalElementIds.forEach((id) => {
        const el = document.getElementById(id);
        if (el) {
          const srcId = el.getAttribute(PHX_TELEPORTED_SRC);
          if (srcId) {
            const source = document.getElementById(srcId);
            if (!source) {
              el.remove();
              this.onNodeDiscarded(el);
              this.view.dropPortalElementId(id);
            }
          }
        }
      });
    });

    if (liveSocket.isDebugEnabled()) {
      detectDuplicateIds(reportError);
      detectInvalidStreamInserts(this.streamInserts, reportError);
      // warn if there are any inputs named "id"
      Array.from(document.querySelectorAll("input[name=id]")).forEach(
        (node) => {
          if (node instanceof HTMLInputElement && node.form) {
            reportError(
              "dom.form-input-name-id",
              'Detected an input with name="id" inside a form! This will cause problems when patching the DOM.\n',
              { el: node },
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
    added.forEach((el) => this.trackAfterAdded(el));
    updates.forEach((el) => this.trackAfterUpdated(el));

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

  private trackBeforeUpdated(fromEl: Element, toEl: Element) {
    this.beforeUpdatedCallbacks.forEach((cb) => cb(fromEl, toEl));
  }

  private trackAfterAdded(el: Node) {
    this.afterAddedCallbacks.forEach((cb) => cb(el));
  }

  private trackAfterUpdated(el: Element) {
    this.afterUpdatedCallbacks.forEach((cb) => cb(el));
  }

  private trackAfterPhxChildAdded(el: Element) {
    this.afterPhxChildAddedCallbacks.forEach((cb) => cb(el));
  }

  private trackAfterDiscarded(el: Node) {
    this.afterDiscardedCallbacks.forEach((cb) => cb(el));
  }

  private trackAfterTransitionsDiscarded(els: Element[]) {
    this.afterTransitionsDiscardedCallbacks.forEach((cb) => cb(els));
  }

  private onNodeDiscarded(el) {
    // nested view handling
    if (DOM.isPhxChild(el) || DOM.isPhxSticky(el)) {
      this.liveSocket.destroyViewByEl(el);
    }
    this.trackAfterDiscarded(el);
  }

  private maybePendingRemove(node) {
    if (node.getAttribute && node.getAttribute(this.phxRemove) !== null) {
      this.pendingRemoves.push(node);
      return true;
    } else {
      return false;
    }
  }

  private removeStreamChildElement(child, force = false) {
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

  private getStreamInsert(el) {
    const insert = el.id ? this.streamInserts[el.id] : {};
    return insert || {};
  }

  private setStreamRef(el, ref) {
    DOM.putSticky(el, PHX_STREAM_REF, (el) =>
      el.setAttribute(PHX_STREAM_REF, ref),
    );
  }

  private maybeReOrderStream(el: Element, isNew = false) {
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
      this.moveOrInsertBefore(
        el.parentElement,
        el,
        el.parentElement.firstElementChild,
      );
    } else if (streamAt > 0) {
      const children = Array.from(el.parentElement.children);
      const oldIndex = children.indexOf(el);
      if (streamAt >= children.length - 1) {
        this.moveOrInsertBefore(el.parentElement, el, null);
      } else {
        const sibling = children[streamAt];
        if (oldIndex > streamAt) {
          this.moveOrInsertBefore(el.parentElement, el, sibling);
        } else {
          this.moveOrInsertBefore(
            el.parentElement,
            el,
            sibling.nextElementSibling,
          );
        }
      }
    }

    this.maybeLimitStream(el);
  }

  // Reorder a child within its parent. When supported, use the atomic
  // moveBefore (https://developer.mozilla.org/en-US/docs/Web/API/Node/moveBefore)
  // so connected custom elements (and other state-bearing nodes like iframes)
  // are not disconnected and reconnected by the move. Falls back to
  // insertBefore otherwise. Passing `ref === null` moves to the end.
  // See also https://github.com/phoenixframework/phoenix_live_view/issues/4212.
  private moveOrInsertBefore(parent, child, ref) {
    if (typeof parent.moveBefore === "function") {
      try {
        parent.moveBefore(child, ref);
        return;
      } catch {
        // moveBefore can throw (e.g. HierarchyRequestError) in cases where
        // an atomic move is not possible; fall back to insertBefore.
      }
    }
    parent.insertBefore(child, ref);
  }

  private maybeLimitStream(el) {
    const { limit } = this.getStreamInsert(el);
    if (limit !== null) {
      const children = Array.from(el.parentElement.children);
      if (limit < 0 && children.length > limit * -1) {
        children
          .slice(0, children.length + limit)
          .forEach((child) => this.removeStreamChildElement(child));
      } else if (limit >= 0 && children.length > limit) {
        children
          .slice(limit)
          .forEach((child) => this.removeStreamChildElement(child));
      }
    }
  }

  private transitionPendingRemoves() {
    const { pendingRemoves, liveSocket } = this;
    if (pendingRemoves.length > 0) {
      liveSocket.transitionRemoves(pendingRemoves, this.view, () => {
        pendingRemoves.forEach((el) => {
          const child = DOM.firstPhxChild(el);
          if (child) {
            liveSocket.destroyViewByEl(child);
          }
          el.remove();
        });
        this.trackAfterTransitionsDiscarded(pendingRemoves);
      });
    }
  }

  private isChangedSelect(fromEl, toEl) {
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

  private skipCIDSibling(el) {
    return el.nodeType === Node.ELEMENT_NODE && el.hasAttribute(PHX_SKIP);
  }

  private maybeCloneLockedElement(fromEl, isFocusedFormEl) {
    if (!fromEl.hasAttribute(PHX_REF_SRC)) return fromEl;

    const ref = new ElementRef(fromEl);
    // Only perform the clone step while the element remains locked. lockRef and
    // undoRef can be 0 for the first event, so compare against null explicitly.
    if (
      !fromEl.hasAttribute(PHX_REF_LOCK) ||
      (this.undoRef !== null && ref.isLockUndoneBy(this.undoRef))
    ) {
      return fromEl;
    }

    DOM.applyStickyOperations(fromEl);
    const clone = fromEl.hasAttribute(PHX_REF_LOCK)
      ? DOM.private(fromEl, PHX_REF_LOCK) || fromEl.cloneNode(true)
      : null;
    if (!clone) return fromEl;

    DOM.putPrivate(fromEl, PHX_REF_LOCK, clone);
    return isFocusedFormEl ? fromEl : clone;
  }

  private copyNestedPrivateLock(fromEl, toEl) {
    // During unlock morphs, toEl may be the private clone that accumulated a
    // nested locked subtree. Copy that private clone back to fromEl before the
    // outer unlock finishes so the nested element can apply its own ack later.
    // undoRef can be 0, so presence is checked against null.
    if (this.undoRef === null || !DOM.private(toEl, PHX_REF_LOCK)) return;

    DOM.putPrivate(fromEl, PHX_REF_LOCK, DOM.private(toEl, PHX_REF_LOCK));
  }

  private indexOf(parent, child) {
    return Array.from(parent.children).indexOf(child);
  }

  private teleport(el, morph) {
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

  private handleRuntimeHook(el: HTMLScriptElement, source: string) {
    // usually, scripts are not executed when morphdom adds them to the DOM
    // we special case runtime colocated hooks
    const name = el.getAttribute(PHX_RUNTIME_HOOK)!;
    let nonce = el.hasAttribute("nonce") ? el.getAttribute("nonce") : null;
    if (el.hasAttribute("nonce")) {
      const template = document.createElement("template");
      template.innerHTML = source;
      nonce =
        template.content
          .querySelector(`script[${PHX_RUNTIME_HOOK}="${CSS.escape(name)}"]`)
          ?.getAttribute("nonce") ?? null;
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
