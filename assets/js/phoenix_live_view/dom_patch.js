import {
  PHX_COMPONENT,
  PHX_DISABLE_WITH,
  PHX_FEEDBACK_FOR,
  PHX_FEEDBACK_GROUP,
  PHX_PRUNE,
  PHX_ROOT_ID,
  PHX_SESSION,
  PHX_SKIP,
  PHX_MAGIC_ID,
  PHX_STATIC,
  PHX_TRIGGER_ACTION,
  PHX_UPDATE,
  PHX_STREAM,
  PHX_STREAM_REF,
  PHX_VIEWPORT_TOP,
  PHX_VIEWPORT_BOTTOM,
} from "./constants"

import {
  detectDuplicateIds,
  isCid
} from "./utils"

import DOM from "./dom"
import DOMPostMorphRestorer from "./dom_post_morph_restorer"
import morphdom from "morphdom"

export default class DOMPatch {
  static patchEl(fromEl, toEl, activeElement){
    morphdom(fromEl, toEl, {
      childrenOnly: false,
      onBeforeElUpdated: (fromEl, toEl) => {
        if(activeElement && activeElement.isSameNode(fromEl) && DOM.isFormInput(fromEl)){
          DOM.mergeFocusedInput(fromEl, toEl)
          return false
        }
      }
    })
  }

  constructor(view, container, id, html, streams, targetCID){
    this.view = view
    this.liveSocket = view.liveSocket
    this.container = container
    this.id = id
    this.rootID = view.root.id
    this.html = html
    this.streams = streams
    this.streamInserts = {}
    this.streamComponentRestore = {}
    this.targetCID = targetCID
    this.cidPatch = isCid(this.targetCID)
    this.pendingRemoves = []
    this.phxRemove = this.liveSocket.binding("remove")
    this.callbacks = {
      beforeadded: [], beforeupdated: [], beforephxChildAdded: [],
      afteradded: [], afterupdated: [], afterdiscarded: [], afterphxChildAdded: [],
      aftertransitionsDiscarded: []
    }
  }

  before(kind, callback){ this.callbacks[`before${kind}`].push(callback) }
  after(kind, callback){ this.callbacks[`after${kind}`].push(callback) }

  trackBefore(kind, ...args){
    this.callbacks[`before${kind}`].forEach(callback => callback(...args))
  }

  trackAfter(kind, ...args){
    this.callbacks[`after${kind}`].forEach(callback => callback(...args))
  }

  markPrunableContentForRemoval(){
    let phxUpdate = this.liveSocket.binding(PHX_UPDATE)
    DOM.all(this.container, `[${phxUpdate}=append] > *, [${phxUpdate}=prepend] > *`, el => {
      el.setAttribute(PHX_PRUNE, "")
    })
  }

  perform(isJoinPatch){
    let {view, liveSocket, container, html} = this
    let targetContainer = this.isCIDPatch() ? this.targetCIDContainer(html) : container
    if(this.isCIDPatch() && !targetContainer){ return }

    let focused = liveSocket.getActiveElement()
    let {selectionStart, selectionEnd} = focused && DOM.hasSelectionRange(focused) ? focused : {}
    let phxUpdate = liveSocket.binding(PHX_UPDATE)
    let phxFeedbackFor = liveSocket.binding(PHX_FEEDBACK_FOR)
    let phxFeedbackGroup = liveSocket.binding(PHX_FEEDBACK_GROUP)
    let disableWith = liveSocket.binding(PHX_DISABLE_WITH)
    let phxViewportTop = liveSocket.binding(PHX_VIEWPORT_TOP)
    let phxViewportBottom = liveSocket.binding(PHX_VIEWPORT_BOTTOM)
    let phxTriggerExternal = liveSocket.binding(PHX_TRIGGER_ACTION)
    let added = []
    let feedbackContainers = []
    let updates = []
    let appendPrependUpdates = []

    let externalFormTriggered = null

    function morph(targetContainer, source, withChildren=false){
      morphdom(targetContainer, source, {
        // normally, we are running with childrenOnly, as the patch HTML for a LV
        // does not include the LV attrs (data-phx-session, etc.)
        // when we are patching a live component, we do want to patch the root element as well;
        // another case is the recursive patch of a stream item that was kept on reset (-> onBeforeNodeAdded)
        childrenOnly: targetContainer.getAttribute(PHX_COMPONENT) === null && !withChildren,
        getNodeKey: (node) => {
          if(DOM.isPhxDestroyed(node)){ return null }
          // If we have a join patch, then by definition there was no PHX_MAGIC_ID.
          // This is important to reduce the amount of elements morphdom discards.
          if(isJoinPatch){ return node.id }
          return node.id || (node.getAttribute && node.getAttribute(PHX_MAGIC_ID))
        },
        // skip indexing from children when container is stream
        skipFromChildren: (from) => { return from.getAttribute(phxUpdate) === PHX_STREAM },
        // tell morphdom how to add a child
        addChild: (parent, child) => {
          let {ref, streamAt} = this.getStreamInsert(child)
          if(ref === undefined){ return parent.appendChild(child) }

          this.setStreamRef(child, ref)

          // streaming
          if(streamAt === 0){
            parent.insertAdjacentElement("afterbegin", child)
          } else if(streamAt === -1){
            parent.appendChild(child)
          } else if(streamAt > 0){
            let sibling = Array.from(parent.children)[streamAt]
            parent.insertBefore(child, sibling)
          }
        },
        onBeforeNodeAdded: (el) => {
          DOM.maybeAddPrivateHooks(el, phxViewportTop, phxViewportBottom)
          this.trackBefore("added", el)

          let morphedEl = el
          // this is a stream item that was kept on reset, recursively morph it
          if(!isJoinPatch && this.streamComponentRestore[el.id]){
            morphedEl = this.streamComponentRestore[el.id]
            delete this.streamComponentRestore[el.id]
            morph.call(this, morphedEl, el, true)
          }

          return morphedEl
        },
        onNodeAdded: (el) => {
          if(el.getAttribute){ this.maybeReOrderStream(el, true) }
          if(DOM.isFeedbackContainer(el, phxFeedbackFor)) feedbackContainers.push(el)

          // hack to fix Safari handling of img srcset and video tags
          if(el instanceof HTMLImageElement && el.srcset){
            el.srcset = el.srcset
          } else if(el instanceof HTMLVideoElement && el.autoplay){
            el.play()
          }
          if(DOM.isNowTriggerFormExternal(el, phxTriggerExternal)){
            externalFormTriggered = el
          }

          // nested view handling
          if((DOM.isPhxChild(el) && view.ownsElement(el)) || DOM.isPhxSticky(el) && view.ownsElement(el.parentNode)){
            this.trackAfter("phxChildAdded", el)
          }
          added.push(el)
        },
        onNodeDiscarded: (el) => this.onNodeDiscarded(el),
        onBeforeNodeDiscarded: (el) => {
          if(el.getAttribute && el.getAttribute(PHX_PRUNE) !== null){ return true }
          if(el.parentElement !== null && el.id &&
            DOM.isPhxUpdate(el.parentElement, phxUpdate, [PHX_STREAM, "append", "prepend"])){
            return false
          }
          if(this.maybePendingRemove(el)){ return false }
          if(this.skipCIDSibling(el)){ return false }

          return true
        },
        onElUpdated: (el) => {
          if(DOM.isNowTriggerFormExternal(el, phxTriggerExternal)){
            externalFormTriggered = el
          }
          updates.push(el)
          this.maybeReOrderStream(el, false)
        },
        onBeforeElUpdated: (fromEl, toEl) => {
          DOM.maybeAddPrivateHooks(toEl, phxViewportTop, phxViewportBottom)
          // mark both from and to els as feedback containers, as we don't know yet which one will be used
          // and we also need to remove the phx-no-feedback class when the phx-feedback-for attribute is removed
          if(DOM.isFeedbackContainer(fromEl, phxFeedbackFor) || DOM.isFeedbackContainer(toEl, phxFeedbackFor)){
            feedbackContainers.push(fromEl)
            feedbackContainers.push(toEl)
          }
          DOM.cleanChildNodes(toEl, phxUpdate)
          if(this.skipCIDSibling(toEl)){
            // if this is a live component used in a stream, we may need to reorder it
            this.maybeReOrderStream(fromEl)
            return false
          }
          if(DOM.isPhxSticky(fromEl)){ return false }
          if(DOM.isIgnored(fromEl, phxUpdate) || (fromEl.form && fromEl.form.isSameNode(externalFormTriggered))){
            this.trackBefore("updated", fromEl, toEl)
            DOM.mergeAttrs(fromEl, toEl, {isIgnored: DOM.isIgnored(fromEl, phxUpdate)})
            updates.push(fromEl)
            DOM.applyStickyOperations(fromEl)
            return false
          }
          if(fromEl.type === "number" && (fromEl.validity && fromEl.validity.badInput)){ return false }
          if(!DOM.syncPendingRef(fromEl, toEl, disableWith)){
            if(DOM.isUploadInput(fromEl)){
              this.trackBefore("updated", fromEl, toEl)
              updates.push(fromEl)
            }
            DOM.applyStickyOperations(fromEl)
            return false
          }

          // nested view handling
          if(DOM.isPhxChild(toEl)){
            let prevSession = fromEl.getAttribute(PHX_SESSION)
            DOM.mergeAttrs(fromEl, toEl, {exclude: [PHX_STATIC]})
            if(prevSession !== ""){ fromEl.setAttribute(PHX_SESSION, prevSession) }
            fromEl.setAttribute(PHX_ROOT_ID, this.rootID)
            DOM.applyStickyOperations(fromEl)
            return false
          }

          // input handling
          DOM.copyPrivates(toEl, fromEl)

          let isFocusedFormEl = focused && fromEl.isSameNode(focused) && DOM.isFormInput(fromEl)
          // skip patching focused inputs unless focus is a select that has changed options
          let focusedSelectChanged = isFocusedFormEl && this.isChangedSelect(fromEl, toEl)
          if(isFocusedFormEl && fromEl.type !== "hidden" && !focusedSelectChanged){
            this.trackBefore("updated", fromEl, toEl)
            DOM.mergeFocusedInput(fromEl, toEl)
            DOM.syncAttrsToProps(fromEl)
            updates.push(fromEl)
            DOM.applyStickyOperations(fromEl)
            return false
          } else {
            // blur focused select if it changed so native UI is updated (ie safari won't update visible options)
            if(focusedSelectChanged){ fromEl.blur() }
            if(DOM.isPhxUpdate(toEl, phxUpdate, ["append", "prepend"])){
              appendPrependUpdates.push(new DOMPostMorphRestorer(fromEl, toEl, toEl.getAttribute(phxUpdate)))
            }

            DOM.syncAttrsToProps(toEl)
            DOM.applyStickyOperations(toEl)
            this.trackBefore("updated", fromEl, toEl)
            return true
          }
        }
      })
    }

    this.trackBefore("added", container)
    this.trackBefore("updated", container, container)

    liveSocket.time("morphdom", () => {
      this.streams.forEach(([ref, inserts, deleteIds, reset]) => {
        inserts.forEach(([key, streamAt, limit]) => {
          this.streamInserts[key] = {ref, streamAt, limit, reset}
        })
        if(reset !== undefined){
          DOM.all(container, `[${PHX_STREAM_REF}="${ref}"]`, child => {
            this.removeStreamChildElement(child)
          })
        }
        deleteIds.forEach(id => {
          let child = container.querySelector(`[id="${id}"]`)
          if(child){ this.removeStreamChildElement(child) }
        })
      })

      // clear stream items from the dead render if they are not inserted again
      if(isJoinPatch){
        DOM.all(this.container, `[${phxUpdate}=${PHX_STREAM}]`, el => {
          // make sure to only remove elements owned by the current view
          // see https://github.com/phoenixframework/phoenix_live_view/issues/3047
          this.liveSocket.owner(el, (view) => {
            if(view === this.view){
              Array.from(el.children).forEach(child => {
                this.removeStreamChildElement(child)
              })
            }
          })
        })
      }

      morph.call(this, targetContainer, html)
    })

    if(liveSocket.isDebugEnabled()){
      detectDuplicateIds()
      // warn if there are any inputs named "id"
      Array.from(document.querySelectorAll("input[name=id]")).forEach(node => {
        if(node.form){
          console.error("Detected an input with name=\"id\" inside a form! This will cause problems when patching the DOM.\n", node)
        }
      })
    }

    if(appendPrependUpdates.length > 0){
      liveSocket.time("post-morph append/prepend restoration", () => {
        appendPrependUpdates.forEach(update => update.perform())
      })
    }

    DOM.maybeHideFeedback(targetContainer, feedbackContainers, phxFeedbackFor, phxFeedbackGroup)

    liveSocket.silenceEvents(() => DOM.restoreFocus(focused, selectionStart, selectionEnd))
    DOM.dispatchEvent(document, "phx:update")
    added.forEach(el => this.trackAfter("added", el))
    updates.forEach(el => this.trackAfter("updated", el))

    this.transitionPendingRemoves()

    if(externalFormTriggered){
      liveSocket.unload()
      // use prototype's submit in case there's a form control with name or id of "submit"
      // https://developer.mozilla.org/en-US/docs/Web/API/HTMLFormElement/submit
      Object.getPrototypeOf(externalFormTriggered).submit.call(externalFormTriggered)
    }
    return true
  }

  onNodeDiscarded(el){
    // nested view handling
    if(DOM.isPhxChild(el) || DOM.isPhxSticky(el)){ this.liveSocket.destroyViewByEl(el) }
    this.trackAfter("discarded", el)
  }

  maybePendingRemove(node){
    if(node.getAttribute && node.getAttribute(this.phxRemove) !== null){
      this.pendingRemoves.push(node)
      return true
    } else {
      return false
    }
  }

  removeStreamChildElement(child){
    // we need to store the node if it is actually re-added in the same patch
    // we do NOT want to execute phx-remove, we do NOT want to call onNodeDiscarded
    if(this.streamInserts[child.id]){
      this.streamComponentRestore[child.id] = child
      child.remove()
    } else {
      // only remove the element now if it has no phx-remove binding
      if(!this.maybePendingRemove(child)){
        child.remove()
        this.onNodeDiscarded(child)
      }
    }
  }

  getStreamInsert(el){
    let insert = el.id ? this.streamInserts[el.id] : {}
    return insert || {}
  }

  setStreamRef(el, ref){
    DOM.putSticky(el, PHX_STREAM_REF, el => el.setAttribute(PHX_STREAM_REF, ref))
  }

  maybeReOrderStream(el, isNew){
    let {ref, streamAt, reset} = this.getStreamInsert(el)
    if(streamAt === undefined){ return }

    // we need to set the PHX_STREAM_REF here as well as addChild is invoked only for parents
    this.setStreamRef(el, ref)

    if(!reset && !isNew){
      // we only reorder if the element is new or it's a stream reset
      return
    }

    // check if the element has a parent element;
    // it doesn't if we are currently recursively morphing (restoring a saved stream child)
    // because the element is not yet added to the real dom;
    // reordering does not make sense in that case anyway
    if(!el.parentElement){ return }

    if(streamAt === 0){
      el.parentElement.insertBefore(el, el.parentElement.firstElementChild)
    } else if(streamAt > 0){
      let children = Array.from(el.parentElement.children)
      let oldIndex = children.indexOf(el)
      if(streamAt >= children.length - 1){
        el.parentElement.appendChild(el)
      } else {
        let sibling = children[streamAt]
        if(oldIndex > streamAt){
          el.parentElement.insertBefore(el, sibling)
        } else {
          el.parentElement.insertBefore(el, sibling.nextElementSibling)
        }
      }
    }

    this.maybeLimitStream(el)
  }

  maybeLimitStream(el){
    let {limit} = this.getStreamInsert(el)
    let children = limit !== null && Array.from(el.parentElement.children)
    if(limit && limit < 0 && children.length > limit * -1){
      children.slice(0, children.length + limit).forEach(child => this.removeStreamChildElement(child))
    } else if(limit && limit >= 0 && children.length > limit){
      children.slice(limit).forEach(child => this.removeStreamChildElement(child))
    }
  }

  transitionPendingRemoves(){
    let {pendingRemoves, liveSocket} = this
    if(pendingRemoves.length > 0){
      liveSocket.transitionRemoves(pendingRemoves)
      liveSocket.requestDOMUpdate(() => {
        pendingRemoves.forEach(el => {
          let child = DOM.firstPhxChild(el)
          if(child){ liveSocket.destroyViewByEl(child) }
          el.remove()
        })
        this.trackAfter("transitionsDiscarded", pendingRemoves)
      })
    }
  }

  isChangedSelect(fromEl, toEl){
    if(!(fromEl instanceof HTMLSelectElement) || fromEl.multiple){ return false }
    if(fromEl.options.length !== toEl.options.length){ return true }

    let fromSelected = fromEl.selectedOptions[0]
    let toSelected = toEl.selectedOptions[0]
    if(fromSelected && fromSelected.hasAttribute("selected")){
      toSelected.setAttribute("selected", fromSelected.getAttribute("selected"))
    }

    // in general we have to be very careful with using isEqualNode as it does not a reliable
    // DOM tree equality check, but for selection attributes and options it works fine
    return !fromEl.isEqualNode(toEl)
  }

  isCIDPatch(){ return this.cidPatch }

  skipCIDSibling(el){
    return el.nodeType === Node.ELEMENT_NODE && el.hasAttribute(PHX_SKIP)
  }

  targetCIDContainer(html){
    if(!this.isCIDPatch()){ return }
    let [first, ...rest] = DOM.findComponentNodeList(this.container, this.targetCID)
    if(rest.length === 0 && DOM.childNodeLength(html) === 1){
      return first
    } else {
      return first && first.parentNode
    }
  }

  indexOf(parent, child){ return Array.from(parent.children).indexOf(child) }
}
