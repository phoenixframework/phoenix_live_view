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
  PHX_UPDATE,
  PHX_STREAM,
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
    DOM.all(this.container, `[${phxUpdate}=${PHX_STREAM}]`, el => el.innerHTML = "")
    DOM.all(this.container, `[${phxUpdate}=append] > *, [${phxUpdate}=prepend] > *`, el => {
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
    let added = []
    let updates = []
    let appendPrependUpdates = []

    let externalFormTriggered = null

    let diffHTML = liveSocket.time("premorph container prep", () => {
      return this.buildDiffHTML(container, html, phxUpdate, targetContainer)
    })

    this.trackBefore("added", container)
    this.trackBefore("updated", container, container)

    liveSocket.time("morphdom", () => {
      this.streams.forEach(([inserts, deleteIds]) => {
        this.streamInserts = Object.assign(this.streamInserts, inserts)
        deleteIds.forEach(id => {
          let child = container.querySelector(`[id="${id}"]`)
          if(child){
            if(!this.maybePendingRemove(child)){
              child.remove()
              this.onNodeDiscarded(child)
            }
          }
        })
      })

      morphdom(targetContainer, diffHTML, {
        childrenOnly: targetContainer.getAttribute(PHX_COMPONENT) === null,
        getNodeKey: (node) => {
          return DOM.isPhxDestroyed(node) ? null : node.id
        },
        // skip indexing from children when container is stream
        skipFromChildren: (from) => { return from.getAttribute(phxUpdate) === PHX_STREAM },
        // tell morphdom how to add a child
        addChild: (parent, child) => {
          let streamAt = child.id ? this.streamInserts[child.id] : undefined
          if(streamAt === undefined) { return parent.appendChild(child) }

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
          this.maybeReOrderStream(el)
        },
        onBeforeElUpdated: (fromEl, toEl) => {
          DOM.cleanChildNodes(toEl, phxUpdate)
          if(this.skipCIDSibling(toEl)){ return false }
          if(DOM.isPhxSticky(fromEl)){ return false }
          if(DOM.isIgnored(fromEl, phxUpdate) || (fromEl.form && fromEl.form.isSameNode(externalFormTriggered))){
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
          if(isFocusedFormEl && fromEl.type !== "hidden"){
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

    this.transitionPendingRemoves()

    if(externalFormTriggered){
      liveSocket.unload()
      externalFormTriggered.submit()
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

  maybeReOrderStream(el){
    let streamAt = el.id ? this.streamInserts[el.id] : undefined
    if(streamAt === undefined){ return }

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

  indexOf(parent, child){ return Array.from(parent.children).indexOf(child) }
}
