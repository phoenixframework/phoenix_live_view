import {
  PHX_COMPONENT,
  PHX_DISABLE_WITH,
  PHX_FEEDBACK_FOR,
  PHX_PRUNE,
  PHX_ROOT_ID,
  PHX_SESSION,
  PHX_SKIP,
  PHX_STATIC,
  PHX_TRIGGER_ACTION,
  PHX_UPDATE
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

  constructor(view, container, id, html, targetCID){
    this.view = view
    this.liveSocket = view.liveSocket
    this.container = container
    this.id = id
    this.rootID = view.root.id
    this.html = html
    this.targetCID = targetCID
    this.cidPatch = isCid(this.targetCID)
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
    DOM.all(this.container, "[phx-update=append] > *, [phx-update=prepend] > *", el => {
      el.setAttribute(PHX_PRUNE, "")
    })
  }

  perform(){
    let {view, liveSocket, container, html} = this
    let targetContainer = this.isCIDPatch() ? this.targetCIDContainer(html) : container
    if(this.isCIDPatch() && !targetContainer){ return }

    let focused = liveSocket.getActiveElement()
    let {selectionStart, selectionEnd} = focused && DOM.hasSelectionRange(focused) ? focused : {}
    let phxUpdate = liveSocket.binding(PHX_UPDATE)
    let phxFeedbackFor = liveSocket.binding(PHX_FEEDBACK_FOR)
    let disableWith = liveSocket.binding(PHX_DISABLE_WITH)
    let phxTriggerExternal = liveSocket.binding(PHX_TRIGGER_ACTION)
    let phxRemove = liveSocket.binding("remove")
    let added = []
    let updates = []
    let appendPrependUpdates = []
    let pendingRemoves = []
    let externalFormTriggered = null

    let diffHTML = liveSocket.time("premorph container prep", () => {
      return this.buildDiffHTML(container, html, phxUpdate, targetContainer)
    })

    this.trackBefore("added", container)
    this.trackBefore("updated", container, container)

    liveSocket.time("morphdom", () => {
      morphdom(targetContainer, diffHTML, {
        childrenOnly: targetContainer.getAttribute(PHX_COMPONENT) === null,
        getNodeKey: (node) => {
          return DOM.isPhxDestroyed(node) ? null : node.id
        },
        onBeforeNodeAdded: (el) => {
          this.trackBefore("added", el)
          return el
        },
        onNodeAdded: (el) => {
          // hack to fix Safari handling of img srcset and video tags
          if(el instanceof HTMLImageElement && el.srcset){
            el.srcset = el.srcset
          } else if(el instanceof HTMLVideoElement && el.autoplay){
            el.play()
          }
          if(DOM.isNowTriggerFormExternal(el, phxTriggerExternal)){
            externalFormTriggered = el
          }
          //input handling
          DOM.discardError(targetContainer, el, phxFeedbackFor)
          // nested view handling
          if(DOM.isPhxChild(el) && view.ownsElement(el)){
            this.trackAfter("phxChildAdded", el)
          }
          added.push(el)
        },
        onNodeDiscarded: (el) => {
          // nested view handling
          if(DOM.isPhxChild(el)){ liveSocket.destroyViewByEl(el) }
          this.trackAfter("discarded", el)
        },
        onBeforeNodeDiscarded: (el) => {
          if(el.getAttribute && el.getAttribute(PHX_PRUNE) !== null){ return true }
          if(el.parentNode !== null && DOM.isPhxUpdate(el.parentNode, phxUpdate, ["append", "prepend"]) && el.id){ return false }
          if(el.getAttribute && el.getAttribute(phxRemove)){
            pendingRemoves.push(el)
            return false
          }
          if(this.skipCIDSibling(el)){ return false }
          return true
        },
        onElUpdated: (el) => {
          if(DOM.isNowTriggerFormExternal(el, phxTriggerExternal)){
            externalFormTriggered = el
          }
          updates.push(el)
        },
        onBeforeElUpdated: (fromEl, toEl) => {
          DOM.cleanChildNodes(toEl, phxUpdate)
          if(this.skipCIDSibling(toEl)){ return false }
          if(DOM.isIgnored(fromEl, phxUpdate)){
            this.trackBefore("updated", fromEl, toEl)
            DOM.mergeAttrs(fromEl, toEl, {isIgnored: true})
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
          DOM.discardError(targetContainer, toEl, phxFeedbackFor)

          let isFocusedFormEl = focused && fromEl.isSameNode(focused) && DOM.isFormInput(fromEl)
          if(isFocusedFormEl){
            this.trackBefore("updated", fromEl, toEl)
            DOM.mergeFocusedInput(fromEl, toEl)
            DOM.syncAttrsToProps(fromEl)
            updates.push(fromEl)
            DOM.applyStickyOperations(fromEl)
            return false
          } else {
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
    })

    if(liveSocket.isDebugEnabled()){ detectDuplicateIds() }

    if(appendPrependUpdates.length > 0){
      liveSocket.time("post-morph append/prepend restoration", () => {
        appendPrependUpdates.forEach(update => update.perform())
      })
    }

    liveSocket.silenceEvents(() => DOM.restoreFocus(focused, selectionStart, selectionEnd))
    DOM.dispatchEvent(document, "phx:update")
    added.forEach(el => this.trackAfter("added", el))
    updates.forEach(el => this.trackAfter("updated", el))

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

    if(externalFormTriggered){
      liveSocket.disconnect()
      externalFormTriggered.submit()
    }
    return true
  }

  isCIDPatch(){ return this.cidPatch }

  skipCIDSibling(el){
    return el.nodeType === Node.ELEMENT_NODE && el.getAttribute(PHX_SKIP) !== null
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

  // builds HTML for morphdom patch
  // - for full patches of LiveView or a component with a single
  //   root node, simply returns the HTML
  // - for patches of a component with multiple root nodes, the
  //   parent node becomes the target container and non-component
  //   siblings are marked as skip.
  buildDiffHTML(container, html, phxUpdate, targetContainer){
    let isCIDPatch = this.isCIDPatch()
    let isCIDWithSingleRoot = isCIDPatch && targetContainer.getAttribute(PHX_COMPONENT) === this.targetCID.toString()
    if(!isCIDPatch || isCIDWithSingleRoot){
      return html
    } else {
      // component patch with multiple CID roots
      let diffContainer = null
      let template = document.createElement("template")
      diffContainer = DOM.cloneNode(targetContainer)
      let [firstComponent, ...rest] = DOM.findComponentNodeList(diffContainer, this.targetCID)
      template.innerHTML = html
      rest.forEach(el => el.remove())
      Array.from(diffContainer.childNodes).forEach(child => {
        // we can only skip trackable nodes with an ID
        if(child.id && child.nodeType === Node.ELEMENT_NODE && child.getAttribute(PHX_COMPONENT) !== this.targetCID.toString()){
          child.setAttribute(PHX_SKIP, "")
          child.innerHTML = ""
        }
      })
      Array.from(template.content.childNodes).forEach(el => diffContainer.insertBefore(el, firstComponent))
      firstComponent.remove()
      return diffContainer.outerHTML
    }
  }
}
