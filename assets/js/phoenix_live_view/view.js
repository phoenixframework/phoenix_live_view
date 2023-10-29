import {
  BEFORE_UNLOAD_LOADER_TIMEOUT,
  CHECKABLE_INPUTS,
  CONSECUTIVE_RELOADS,
  PHX_AUTO_RECOVER,
  PHX_COMPONENT,
  PHX_CONNECTED_CLASS,
  PHX_DISABLE_WITH,
  PHX_DISABLE_WITH_RESTORE,
  PHX_DISABLED,
  PHX_LOADING_CLASS,
  PHX_EVENT_CLASSES,
  PHX_ERROR_CLASS,
  PHX_CLIENT_ERROR_CLASS,
  PHX_SERVER_ERROR_CLASS,
  PHX_FEEDBACK_FOR,
  PHX_HAS_SUBMITTED,
  PHX_HOOK,
  PHX_PAGE_LOADING,
  PHX_PARENT_ID,
  PHX_PROGRESS,
  PHX_READONLY,
  PHX_REF,
  PHX_REF_SRC,
  PHX_ROOT_ID,
  PHX_SESSION,
  PHX_STATIC,
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
} from "./constants"

import {
  clone,
  closestPhxBinding,
  isEmpty,
  isEqualObj,
  logError,
  maybe,
  isCid,
} from "./utils"

import Browser from "./browser"
import DOM from "./dom"
import DOMPatch from "./dom_patch"
import LiveUploader from "./live_uploader"
import Rendered from "./rendered"
import ViewHook from "./view_hook"
import JS from "./js"

/** @typedef {import('./rendered').RenderedDiffNode} RenderedDiffNode */

/**
 * URL-safe encoding of data in the given form element
 * @param {HTMLFormElement} form 
 * @param {{submitter: HTMLElement | null | undefined, _target: string}} metadata 
 * @param {string[]} onlyNames 
 * @returns {string} URL-encoded data
 */
let serializeForm = (form, metadata, onlyNames = []) => {
  let {submitter, ...meta} = metadata

  // TODO: Replace with `new FormData(form, submitter)` when supported by latest browsers,
  //       and mention `formdata-submitter-polyfill` in the docs.
  let formData = new FormData(form)

  // TODO: Remove when FormData constructor supports the submitter argument.
  if(submitter && submitter.hasAttribute("name") && submitter.form && submitter.form === form){
    formData.append(submitter.name, submitter.value)
  }

  let toRemove = []

  formData.forEach((val, key, _index) => {
    if(val instanceof File){ toRemove.push(key) }
  })

  // Cleanup after building fileData
  toRemove.forEach(key => formData.delete(key))

  let params = new URLSearchParams()
  for(let [key, val] of formData.entries()){
    if(onlyNames.length === 0 || onlyNames.indexOf(key) >= 0){
      params.append(key, val)
    }
  }
  for(let metaKey in meta){ params.append(metaKey, meta[metaKey]) }

  return params.toString()
}

export default class View {
  /**
   * Constructor
   * @param {HTMLElement} el 
   * @param {import('./live_socket').default} liveSocket 
   * @param {View|null} parentView 
   * @param {string|null} flash 
   * @param {string} liveReferer 
   */
  constructor(el, liveSocket, parentView, flash, liveReferer){
    this.isDead = false
    this.liveSocket = liveSocket
    this.flash = flash
    this.parent = parentView
    /** @type {View} */
    this.root = parentView ? parentView.root : this
    this.el = el
    this.id = this.el.id
    this.ref = 0
    this.childJoins = 0
    this.loaderTimer = null
    /** @type {{diff: RenderedDiffNode, events: [event: string, payload: any]}[]} */
    this.pendingDiffs = []
    this.pruningCIDs = []
    this.redirect = false
    this.href = null
    this.joinCount = this.parent ? this.parent.joinCount - 1 : 0
    this.joinPending = true
    this.destroyed = false
    this.joinCallback = function(onDone){ onDone && onDone() }
    this.stopCallback = function(){ }
    this.pendingJoinOps = this.parent ? null : []
    /** @type {{[key:string]: ViewHook}} */
    this.viewHooks = {}
    /** @type {{[key:Element]: LiveUploader}} */
    this.uploaders = {}

    /** @type {Array<[el: HTMLFormElement, ref: number, opts: object, cb: () => void]>} */
    this.formSubmits = []
    /** @type {{[key: string]: View}|null} */
    this.children = this.parent ? null : {}
    this.root.children[this.id] = {}
    this.channel = this.liveSocket.channel(`lv:${this.id}`, () => {
      let url = this.href && this.expandURL(this.href)
      return {
        redirect: this.redirect ? url : undefined,
        url: this.redirect ? undefined : url || undefined,
        params: this.connectParams(liveReferer),
        session: this.getSession(),
        static: this.getStatic(),
        flash: this.flash,
      }
    })
  }

  /**
   * Setter for href
   * @param {string} href 
   */
  setHref(href){ this.href = href }

  /**
   * Set href and enable redirect
   * @param {string} href 
   */
  setRedirect(href){
    this.redirect = true
    this.href = href
  }

  /**
   * Is this view/element the main liveview container 
   * @returns {boolean}
   */
  isMain(){ return this.el.hasAttribute(PHX_MAIN) }

  /**
   * Set socket connection params
   * @param {string} liveReferer 
   * @returns {object}
   */
  connectParams(liveReferer){
    let params = this.liveSocket.params(this.el)
    let manifest =
      DOM.all(document, `[${this.binding(PHX_TRACK_STATIC)}]`)
        .map(node => node.src || node.href).filter(url => typeof (url) === "string")

    if(manifest.length > 0){ params["_track_static"] = manifest }
    params["_mounts"] = this.joinCount
    params["_live_referer"] = liveReferer

    return params
  }

  /**
   * Is the socket channel connected?
   * @returns {boolean}
   */
  isConnected(){ return this.channel.canPush() }

  /**
   * Lookup the phoenix session
   * @returns {string}
   */
  getSession(){ return this.el.getAttribute(PHX_SESSION) }

  /**
   * Lookup the phoenix static information
   * @returns {string|null}
   */
  getStatic(){
    let val = this.el.getAttribute(PHX_STATIC)
    return val === "" ? null : val
  }

  /**
   * Destroy view, all child views, and hooks
   * @param {() => void} [callback] - will execute callback on completion
   */
  destroy(callback = function (){ }){
    this.destroyAllChildren()
    this.destroyed = true
    delete this.root.children[this.id]
    if(this.parent){ delete this.root.children[this.parent.id][this.id] }
    clearTimeout(this.loaderTimer)
    let onFinished = () => {
      callback()
      for(let id in this.viewHooks){
        this.destroyHook(this.viewHooks[id])
      }
    }

    DOM.markPhxChildDestroyed(this.el)

    this.log("destroyed", () => ["the child has been removed from the parent"])
    this.channel.leave()
      .receive("ok", onFinished)
      .receive("error", onFinished)
      .receive("timeout", onFinished)
  }

  /**
   * Add CSS classes to the container element.
   * NOTE: Will remove liveview-managed transient classes for errors, loading, etc.
   * @param  {...string} classes 
   */
  setContainerClasses(...classes){
    this.el.classList.remove(
      PHX_CONNECTED_CLASS,
      PHX_LOADING_CLASS,
      PHX_ERROR_CLASS,
      PHX_CLIENT_ERROR_CLASS,
      PHX_SERVER_ERROR_CLASS
    )
    this.el.classList.add(...classes)
  }

  /**
   * Set loading classes and call disconnect on hooks
   * @param {number} [timeout] 
   */
  showLoader(timeout){
    clearTimeout(this.loaderTimer)
    if(timeout){
      this.loaderTimer = setTimeout(() => this.showLoader(), timeout)
    } else {
      for(let id in this.viewHooks){ this.viewHooks[id].__disconnected() }
      this.setContainerClasses(PHX_LOADING_CLASS)
    }
  }

  /**
   * Run execJS for associated binding
   * @param {string} binding 
   */
  execAll(binding){
    DOM.all(this.el, `[${binding}]`, el => this.liveSocket.execJS(el, el.getAttribute(binding)))
  }

  /**
   * Remove the loader and transition to connected
   */
  hideLoader(){
    clearTimeout(this.loaderTimer)
    this.setContainerClasses(PHX_CONNECTED_CLASS)
    this.execAll(this.binding("connected"))
  }

  /**
   * Call reconnected callback for viewHooks
   */
  triggerReconnected(){
    for(let id in this.viewHooks){ this.viewHooks[id].__reconnected() }
  }

  /**
   * Log over the LiveSocket
   * @param {string} kind 
   * @param {() => [msg: string, obj: any]} msgCallback 
   */
  log(kind, msgCallback){
    this.liveSocket.log(this, kind, msgCallback)
  }

  /**
   * Add a managed transition
   * @param {number} time 
   * @param {() => void} onStart 
   * @param {() => void} [onDone] 
   */
  transition(time, onStart, onDone = function(){}){
    this.liveSocket.transition(time, onStart, onDone)
  }

  /**
   * Execute callback within the context of the view owning the target
   * @param {Element|string|number} phxTarget 
   * @param {(view: View, targetCtx: number|Element) => void} callback 
   */
  withinTargets(phxTarget, callback){
    if(phxTarget instanceof HTMLElement || phxTarget instanceof SVGElement){
      return this.liveSocket.owner(phxTarget, view => callback(view, phxTarget))
    }

    if(isCid(phxTarget)){
      let targets = DOM.findComponentNodeList(this.el, phxTarget)
      if(targets.length === 0){
        logError(`no component found matching phx-target of ${phxTarget}`)
      } else {
        callback(this, parseInt(phxTarget))
      }
    } else {
      let targets = Array.from(document.querySelectorAll(phxTarget))
      if(targets.length === 0){ logError(`nothing found matching the phx-target selector "${phxTarget}"`) }
      targets.forEach(target => this.liveSocket.owner(target, view => callback(view, target)))
    }
  }

  /**
   * Apply the given raw diff
   * @param {"mount"|"update"} type 
   * @param {RenderedDiffNode} rawDiff - The LiveView diff wire protocol
   * @param {({diff: RenderedDiffNode, reply: number|null, events: any[]}) => void} callback 
   */
  applyDiff(type, rawDiff, callback){
    this.log(type, () => ["", clone(rawDiff)])
    let {diff, reply, events, title} = Rendered.extract(rawDiff)
    callback({diff, reply, events})
    if(title){ window.requestAnimationFrame(() => DOM.putTitle(title)) }
  }

  /**
   * Handle successful channel join
   * @param {{rendered: RenderedDiffNode, container?: [string, object]}} resp 
   */
  onJoin(resp){
    let {rendered, container} = resp
    if(container){
      let [tag, attrs] = container
      this.el = DOM.replaceRootContainer(this.el, tag, attrs)
    }
    this.childJoins = 0
    this.joinPending = true
    this.flash = null

    Browser.dropLocal(this.liveSocket.localStorage, window.location.pathname, CONSECUTIVE_RELOADS)
    this.applyDiff("mount", rendered, ({diff, events}) => {
      this.rendered = new Rendered(this.id, diff)
      let [html, streams] = this.renderContainer(null, "join")
      this.dropPendingRefs()
      let forms = this.formsForRecovery(html)
      this.joinCount++

      if(forms.length > 0){
        // eslint-disable-next-line no-unused-vars
        forms.forEach(([form, newForm, newCid], i) => {
          this.pushFormRecovery(form, newCid, resp => {
            if(i === forms.length - 1){
              this.onJoinComplete(resp, html, streams, events)
            }
          })
        })
      } else {
        this.onJoinComplete(resp, html, streams, events)
      }
    })
  }

  /**
   * Remove all pending element ref attrs on page
   */
  dropPendingRefs(){
    DOM.all(document, `[${PHX_REF_SRC}="${this.id}"][${PHX_REF}]`, el => {
      el.removeAttribute(PHX_REF)
      el.removeAttribute(PHX_REF_SRC)
    })
  }

  /**
   * Handle successful join result
   * @param {object} resp 
   * @param {any} resp.live_patch
   * @param {string} html 
   * @param {Set<Stream>} streams 
   * @param {[event: string, payload: any][]} events 
   */
  onJoinComplete({live_patch}, html, streams, events){
    // In order to provide a better experience, we want to join
    // all LiveViews first and only then apply their patches.
    if(this.joinCount > 1 || (this.parent && !this.parent.isJoinPending())){
      return this.applyJoinPatch(live_patch, html, streams, events)
    }

    // One downside of this approach is that we need to find phxChildren
    // in the html fragment, instead of directly on the DOM. The fragment
    // also does not include PHX_STATIC, so we need to copy it over from
    // the DOM.
    let newChildren = DOM.findPhxChildrenInFragment(html, this.id).filter(toEl => {
      let fromEl = toEl.id && this.el.querySelector(`[id="${toEl.id}"]`)
      let phxStatic = fromEl && fromEl.getAttribute(PHX_STATIC)
      if(phxStatic){ toEl.setAttribute(PHX_STATIC, phxStatic) }
      return this.joinChild(toEl)
    })

    if(newChildren.length === 0){
      if(this.parent){
        this.root.pendingJoinOps.push([this, () => this.applyJoinPatch(live_patch, html, streams, events)])
        this.parent.ackJoin(this)
      } else {
        this.onAllChildJoinsComplete()
        this.applyJoinPatch(live_patch, html, streams, events)
      }
    } else {
      this.root.pendingJoinOps.push([this, () => this.applyJoinPatch(live_patch, html, streams, events)])
    }
  }

  /**
   * Lookup element with ID and set on self
   */
  attachTrueDocEl(){
    this.el = DOM.byId(this.id)
    this.el.setAttribute(PHX_ROOT_ID, this.root.id)
  }

  /**
   * Add and mount a hook if appropriate
   */
  execNewMounted(){
    let phxViewportTop = this.binding(PHX_VIEWPORT_TOP)
    let phxViewportBottom = this.binding(PHX_VIEWPORT_BOTTOM)
    DOM.all(this.el, `[${phxViewportTop}], [${phxViewportBottom}]`, hookEl => {
      DOM.maybeAddPrivateHooks(hookEl, phxViewportTop, phxViewportBottom)
      this.maybeAddNewHook(hookEl)
    })
    DOM.all(this.el, `[${this.binding(PHX_HOOK)}], [data-phx-${PHX_HOOK}]`, hookEl => {
      this.maybeAddNewHook(hookEl)
    })
    DOM.all(this.el, `[${this.binding(PHX_MOUNTED)}]`, el => this.maybeMounted(el))
  }

  /**
   * Apply initial patch after socket join completes
   * @param {{kind: "push"|"replace", to: string}} [live_patch] 
   * @param {string} html 
   * @param {Set<Stream>} streams 
   * @param {[event: string, payload: any][]} events 
   */
  applyJoinPatch(live_patch, html, streams, events){
    this.attachTrueDocEl()
    let patch = new DOMPatch(this, this.el, this.id, html, streams, null)
    patch.markPrunableContentForRemoval()
    this.performPatch(patch, false)
    this.joinNewChildren()
    this.execNewMounted()

    this.joinPending = false
    this.liveSocket.dispatchEvents(events)
    this.applyPendingUpdates()

    if(live_patch){
      let {kind, to} = live_patch
      this.liveSocket.historyPatch(to, kind)
    }
    this.hideLoader()
    if(this.joinCount > 1){ this.triggerReconnected() }
    this.stopCallback()
  }

  /**
   * Trigger beforeUpdate hook lifecycle 
   * @param {Element} fromEl 
   * @param {Element} toEl 
   * @returns {ViewHook|undefined} if hook found for fromEl, return it
   */
  triggerBeforeUpdateHook(fromEl, toEl){
    this.liveSocket.triggerDOM("onBeforeElUpdated", [fromEl, toEl])
    let hook = this.getHook(fromEl)
    let isIgnored = hook && DOM.isIgnored(fromEl, this.binding(PHX_UPDATE))
    if(hook && !fromEl.isEqualNode(toEl) && !(isIgnored && isEqualObj(fromEl.dataset, toEl.dataset))){
      hook.__beforeUpdate()
      return hook
    }
  }

  /**
   * Maybe run mount JS
   * @param {Element} el 
   */
  maybeMounted(el){
    let phxMounted = el.getAttribute(this.binding(PHX_MOUNTED))
    let hasBeenInvoked = phxMounted && DOM.private(el, "mounted")
    if(phxMounted && !hasBeenInvoked){
      this.liveSocket.execJS(el, phxMounted)
      DOM.putPrivate(el, "mounted", true)
    }
  }

  /**
   * @param {Element} el 
   * @param {boolean} [force] 
   */
  // eslint-disable-next-line no-unused-vars
  maybeAddNewHook(el, force){
    let newHook = this.addHook(el)
    if(newHook){ newHook.__mounted() }
  }

  /**
   * Perform DOM patch
   * @param {DOMPatch} patch 
   * @param {boolean} pruneCids - prune components associated in patch?
   * @returns {boolean} were children added?
   */
  performPatch(patch, pruneCids){
    let removedEls = []
    let phxChildrenAdded = false
    let updatedHookIds = new Set()

    patch.after("added", el => {
      this.liveSocket.triggerDOM("onNodeAdded", [el])
      this.maybeAddNewHook(el)
      if(el.getAttribute){ this.maybeMounted(el) }
    })

    patch.after("phxChildAdded", el => {
      if(DOM.isPhxSticky(el)){
        this.liveSocket.joinRootViews()
      } else {
        phxChildrenAdded = true
      }
    })

    patch.before("updated", (fromEl, toEl) => {
      let hook = this.triggerBeforeUpdateHook(fromEl, toEl)
      if(hook){ updatedHookIds.add(fromEl.id) }
    })

    patch.after("updated", el => {
      if(updatedHookIds.has(el.id)){ this.getHook(el).__updated() }
    })

    patch.after("discarded", (el) => {
      if(el.nodeType === Node.ELEMENT_NODE){ removedEls.push(el) }
    })

    patch.after("transitionsDiscarded", els => this.afterElementsRemoved(els, pruneCids))
    patch.perform()
    this.afterElementsRemoved(removedEls, pruneCids)

    return phxChildrenAdded
  }

  /**
   * Remove elements and destroy their components and hooks if applicable 
   * @param {Element[]} elements 
   * @param {boolean} pruneCids 
   */
  afterElementsRemoved(elements, pruneCids){
    let destroyedCIDs = []
    elements.forEach(parent => {
      let components = DOM.all(parent, `[${PHX_COMPONENT}]`)
      let hooks = DOM.all(parent, `[${this.binding(PHX_HOOK)}]`)
      components.concat(parent).forEach(el => {
        let cid = this.componentID(el)
        if(isCid(cid) && destroyedCIDs.indexOf(cid) === -1){ destroyedCIDs.push(cid) }
      })
      hooks.concat(parent).forEach(hookEl => {
        let hook = this.getHook(hookEl)
        hook && this.destroyHook(hook)
      })
    })
    // We should not pruneCids on joins. Otherwise, in case of
    // rejoins, we may notify cids that no longer belong to the
    // current LiveView to be removed.
    if(pruneCids){
      this.maybePushComponentsDestroyed(destroyedCIDs)
    }
  }

  /**
   * For all children elements, join their views 
   */
  joinNewChildren(){
    DOM.findPhxChildren(this.el, this.id).forEach(el => this.joinChild(el))
  }

  /**
   * Get child views by ID
   * @param {string} id 
   * @returns {View|undefined}
   */
  getChildById(id){ return this.root.children[this.id][id] }

  /**
   * Lookup a child view (or self) by element
   * @param {HTMLElement} el 
   * @returns {View}
   */
  getDescendentByEl(el){
    if(el.id === this.id){
      return this
    } else {
      return this.children[el.getAttribute(PHX_PARENT_ID)][el.id]
    }
  }

  /**
   * Destroy child view matching ID
   * @param {string} id 
   */
  destroyDescendent(id){
    for(let parentId in this.root.children){
      for(let childId in this.root.children[parentId]){
        if(childId === id){ return this.root.children[parentId][childId].destroy() }
      }
    }
  }

  /**
   * Ensure a child view for given element exists and was joined
   * @param {HTMLElement} el 
   * @returns {boolean} true if child did
   */
  joinChild(el){
    let child = this.getChildById(el.id)
    if(!child){
      let view = new View(el, this.liveSocket, this)
      this.root.children[this.id][view.id] = view
      view.join()
      this.childJoins++
      return true
    }
  }

  /**
   * Is join still pending?
   * @returns {boolean}
   */
  isJoinPending(){ return this.joinPending }

  /**
   * Notify parents up the chain of join if all children are joined
   * @param {View} _child 
   */
  ackJoin(_child){
    this.childJoins--

    if(this.childJoins === 0){
      if(this.parent){
        this.parent.ackJoin(this)
      } else {
        this.onAllChildJoinsComplete()
      }
    }
  }

  /**
   * Execute pending join callbacks once all children complete joins
   */
  onAllChildJoinsComplete(){
    this.joinCallback(() => {
      this.pendingJoinOps.forEach(([view, op]) => {
        if(!view.isDestroyed()){ op() }
      })
      this.pendingJoinOps = []
    })
  }

  /**
   * Update DOM for a diff and collection of events
   * @param {RenderedDiffNode} diff 
   * @param {[event: string, payload: any][]} events 
   * @returns {void}
   */
  update(diff, events){
    if(this.isJoinPending() || (this.liveSocket.hasPendingLink() && this.root.isMain())){
      return this.pendingDiffs.push({diff, events})
    }

    this.rendered.mergeDiff(diff)
    let phxChildrenAdded = false

    // When the diff only contains component diffs, then walk components
    // and patch only the parent component containers found in the diff.
    // Otherwise, patch entire LV container.
    if(this.rendered.isComponentOnlyDiff(diff)){
      this.liveSocket.time("component patch complete", () => {
        let parentCids = DOM.findParentCIDs(this.el, this.rendered.componentCIDs(diff))
        parentCids.forEach(parentCID => {
          if(this.componentPatch(this.rendered.getComponent(diff, parentCID), parentCID)){ phxChildrenAdded = true }
        })
      })
    } else if(!isEmpty(diff)){
      this.liveSocket.time("full patch complete", () => {
        let [html, streams] = this.renderContainer(diff, "update")
        let patch = new DOMPatch(this, this.el, this.id, html, streams, null)
        phxChildrenAdded = this.performPatch(patch, true)
      })
    }

    this.liveSocket.dispatchEvents(events)
    if(phxChildrenAdded){ this.joinNewChildren() }
  }

  /**
   * Render container element for a diff
   * @param {RenderedDiffNode} diff 
   * @param {string} kind 
   * @returns {[string, Set<Stream>]}
   */
  renderContainer(diff, kind){
    return this.liveSocket.time(`toString diff (${kind})`, () => {
      let tag = this.el.tagName
      // Don't skip any component in the diff nor any marked as pruned
      // (as they may have been added back)
      let cids = diff ? this.rendered.componentCIDs(diff).concat(this.pruningCIDs) : null
      let [html, streams] = this.rendered.toString(cids)
      return [`<${tag}>${html}</${tag}>`, streams]
    })
  }

  /**
   * Render a DOM patch for component
   * @param {RenderedDiffNode} diff 
   * @param {string|number} cid 
   * @returns {boolean} were children added?
   */
  componentPatch(diff, cid){
    if(isEmpty(diff)) return false
    let [html, streams] = this.rendered.componentToString(cid)
    let patch = new DOMPatch(this, this.el, this.id, html, streams, cid)
    let childrenAdded = this.performPatch(patch, true)
    return childrenAdded
  }

  /**
   * Lookup ViewHook by Element ID
   * @param {Element} el 
   * @returns {ViewHook|undefined}
   */
  getHook(el){ return this.viewHooks[ViewHook.elementID(el)] }

  /**
   * Add a ViewHook for this element if one was specified
   * @param {Element} el 
   * @returns {ViewHook|undefind}
   */
  addHook(el){
    if(ViewHook.elementID(el) || !el.getAttribute){ return }
    let hookName = el.getAttribute(`data-phx-${PHX_HOOK}`) || el.getAttribute(this.binding(PHX_HOOK))
    if(hookName && !this.ownsElement(el)){ return }
    let callbacks = this.liveSocket.getHookCallbacks(hookName)

    if(callbacks){
      if(!el.id){ logError(`no DOM ID for hook "${hookName}". Hooks require a unique ID on each element.`, el) }
      let hook = new ViewHook(this, el, callbacks)
      this.viewHooks[ViewHook.elementID(hook.el)] = hook
      return hook
    } else if(hookName !== null){
      logError(`unknown hook found for "${hookName}"`, el)
    }
  }

  /**
   * Call ViewHook teardown functions and delete from view
   * @param {ViewHook} hook 
   */
  destroyHook(hook){
    hook.__destroyed()
    hook.__cleanup__()
    delete this.viewHooks[ViewHook.elementID(hook.el)]
  }

  /**
   * Apply pending diff updates for self and each child
   */
  applyPendingUpdates(){
    this.pendingDiffs.forEach(({diff, events}) => this.update(diff, events))
    this.pendingDiffs = []
    this.eachChild(child => child.applyPendingUpdates())
  }

  /**
   * Run callback for each child view
   * @param {(view: View|undefined) => void} callback 
   */
  eachChild(callback){
    let children = this.root.children[this.id] || {}
    for(let id in children){ callback(this.getChildById(id)) }
  }

  /**
   * Register callback for events on channel
   * @param {string} event - events to listen for on channel
   * @param {(resp: any) => void} cb - callback to execute on each channel response
   */
  onChannel(event, cb){
    this.liveSocket.onChannel(this.channel, event, resp => {
      if(this.isJoinPending()){
        this.root.pendingJoinOps.push([this, () => cb(resp)])
      } else {
        this.liveSocket.requestDOMUpdate(() => cb(resp))
      }
    })
  }

  /**
   * Bind handlers to important liveview events
   */
  bindChannel(){
    // The diff event should be handled by the regular update operations.
    // All other operations are queued to be applied only after join.
    this.liveSocket.onChannel(this.channel, "diff", (rawDiff) => {
      this.liveSocket.requestDOMUpdate(() => {
        this.applyDiff("update", rawDiff, ({diff, events}) => this.update(diff, events))
      })
    })
    this.onChannel("redirect", ({to, flash}) => this.onRedirect({to, flash}))
    this.onChannel("live_patch", (redir) => this.onLivePatch(redir))
    this.onChannel("live_redirect", (redir) => this.onLiveRedirect(redir))
    this.channel.onError(reason => this.onError(reason))
    this.channel.onClose(reason => this.onClose(reason))
  }

  /**
   * Destroy all child nodes
   */
  destroyAllChildren(){ this.eachChild(child => child.destroy()) }

  /**
   * Handle live redirect navigation
   * @param {{to: string, kind: ("push"|"replace"), flash: string|null}} redir 
   */
  onLiveRedirect(redir){
    let {to, kind, flash} = redir
    let url = this.expandURL(to)
    this.liveSocket.historyRedirect(url, kind, flash)
  }

  /**
   * Handle live patch navigation
   * @param {{to: string, kind: ("push"|"replace")}} redir 
   */
  onLivePatch(redir){
    let {to, kind} = redir
    this.href = this.expandURL(to)
    this.liveSocket.historyPatch(to, kind)
  }

  /**
   * Ensure relative URLs are expanded to full URLs
   * @param {string} to 
   * @returns {string}
   */
  expandURL(to){
    return to.startsWith("/") ? `${window.location.protocol}//${window.location.host}${to}` : to
  }

  /**
   * Handle full browser redirect events (not Live redirects)
   * @param {{to: string, flash: string|null}} resp
   */
  onRedirect({to, flash}){ this.liveSocket.redirect(to, flash) }

  /**
   * Is this view destroyed?
   * @returns {boolean}
   */
  isDestroyed(){ return this.destroyed }

  /**
   * Mark this view dead
   */
  joinDead(){ this.isDead = true }

  /**
   * Join the websocket channel
   * @param {(joinCount: number, onDone: () => void) => void} [callback] 
   */
  join(callback){
    this.showLoader(this.liveSocket.loaderTimeout)
    this.bindChannel()
    if(this.isMain()){
      this.stopCallback = this.liveSocket.withPageLoading({to: this.href, kind: "initial"})
    }
    this.joinCallback = (onDone) => {
      onDone = onDone || function(){}
      callback ? callback(this.joinCount, onDone) : onDone()
    }
    this.liveSocket.wrapPush(this, {timeout: false}, () => {
      return this.channel.join()
        .receive("ok", data => {
          if(!this.isDestroyed()){
            this.liveSocket.requestDOMUpdate(() => this.onJoin(data))
          }
        })
        .receive("error", resp => !this.isDestroyed() && this.onJoinError(resp))
        .receive("timeout", () => !this.isDestroyed() && this.onJoinError({reason: "timeout"}))
    })
  }

  /**
   * Handle failed channel join
   * @param {{reason?: string, redirect?: string, live_redirect?: object}} resp 
   */
  onJoinError(resp){
    if(resp.reason === "reload"){
      this.log("error", () => [`failed mount with ${resp.status}. Falling back to page request`, resp])
      if(this.isMain()){ this.onRedirect({to: this.href}) }
      return
    } else if(resp.reason === "unauthorized" || resp.reason === "stale"){
      this.log("error", () => ["unauthorized live_redirect. Falling back to page request", resp])
      if(this.isMain()){ this.onRedirect({to: this.href}) }
      return
    }
    if(resp.redirect || resp.live_redirect){
      this.joinPending = false
      this.channel.leave()
    }
    if(resp.redirect){ return this.onRedirect(resp.redirect) }
    if(resp.live_redirect){ return this.onLiveRedirect(resp.live_redirect) }
    this.displayError([PHX_LOADING_CLASS, PHX_ERROR_CLASS, PHX_SERVER_ERROR_CLASS])
    this.log("error", () => ["unable to join", resp])
    if(this.liveSocket.isConnected()){ this.liveSocket.reloadWithJitter(this) }
  }

  /**
   * Callback to clean-up resources on close
   * @param {string} reason 
   */
  onClose(reason){
    if(this.isDestroyed()){ return }
    if(this.liveSocket.hasPendingLink() && reason !== "leave"){
      return this.liveSocket.reloadWithJitter(this)
    }
    this.destroyAllChildren()
    this.liveSocket.dropActiveElement(this)
    // document.activeElement can be null in Internet Explorer 11
    if(document.activeElement){ document.activeElement.blur() }
    if(this.liveSocket.isUnloaded()){
      this.showLoader(BEFORE_UNLOAD_LOADER_TIMEOUT)
    }
  }

  /**
   * Callback to clean-up resources on error and display error message
   * @param {string} reason 
   */
  onError(reason){
    this.onClose(reason)
    if(this.liveSocket.isConnected()){ this.log("error", () => ["view crashed", reason]) }
    if(!this.liveSocket.isUnloaded()){
      if(this.liveSocket.isConnected()){
        this.displayError([PHX_LOADING_CLASS, PHX_ERROR_CLASS, PHX_SERVER_ERROR_CLASS])
      } else {
        this.displayError([PHX_LOADING_CLASS, PHX_ERROR_CLASS, PHX_CLIENT_ERROR_CLASS])
      }
    }
  }

  /**
   * Dispatch events for error state and disconnected bindings and update page styles
   * @param {string[]} classes - CSS classes to set on the container
   */
  displayError(classes){
    if(this.isMain()){ DOM.dispatchEvent(window, "phx:page-loading-start", {detail: {to: this.href, kind: "error"}}) }
    this.showLoader()
    this.setContainerClasses(...classes)
    this.execAll(this.binding("disconnected"))
  }

  /**
   * Push event with payload over channel
   * @param {() => [number|null, HTMLElement[], object]} refGenerator 
   * @param {string} event 
   * @param {object} payload 
   * @param {(resp: any, hookReply: any) => void} [onReply] 
   */
  pushWithReply(refGenerator, event, payload, onReply = function (){ }){
    if(!this.isConnected()){ return }

    let [ref, [el], opts] = refGenerator ? refGenerator() : [null, [], {}]
    let onLoadingDone = function(){ }
    if(opts.page_loading || (el && (el.getAttribute(this.binding(PHX_PAGE_LOADING)) !== null))){
      onLoadingDone = this.liveSocket.withPageLoading({kind: "element", target: el})
    }

    if(typeof (payload.cid) !== "number"){ delete payload.cid }
    return (
      this.liveSocket.wrapPush(this, {timeout: true}, () => {
        return this.channel.push(event, payload, PUSH_TIMEOUT).receive("ok", resp => {
          let finish = (hookReply) => {
            if(resp.redirect){ this.onRedirect(resp.redirect) }
            if(resp.live_patch){ this.onLivePatch(resp.live_patch) }
            if(resp.live_redirect){ this.onLiveRedirect(resp.live_redirect) }
            onLoadingDone()
            onReply(resp, hookReply)
          }
          if(resp.diff){
            this.liveSocket.requestDOMUpdate(() => {
              this.applyDiff("update", resp.diff, ({diff, reply, events}) => {
                if(ref !== null){ this.undoRefs(ref) }
                this.update(diff, events)
                finish(reply)
              })
            })
          } else {
            if(ref !== null){ this.undoRefs(ref) }
            finish(null)
          }
        })
      })
    )
  }

  /**
   * Unset ref attrs from all child elements with matching ref set
   * @param {number} ref 
   */
  undoRefs(ref){
    if(!this.isConnected()){ return } // exit if external form triggered

    DOM.all(document, `[${PHX_REF_SRC}="${this.id}"][${PHX_REF}="${ref}"]`, el => {
      let disabledVal = el.getAttribute(PHX_DISABLED)
      // remove refs
      el.removeAttribute(PHX_REF)
      el.removeAttribute(PHX_REF_SRC)
      // restore inputs
      if(el.getAttribute(PHX_READONLY) !== null){
        el.readOnly = false
        el.removeAttribute(PHX_READONLY)
      }
      if(disabledVal !== null){
        el.disabled = disabledVal === "true" ? true : false
        el.removeAttribute(PHX_DISABLED)
      }
      // remove classes
      PHX_EVENT_CLASSES.forEach(className => DOM.removeClass(el, className))
      // restore disables
      let disableRestore = el.getAttribute(PHX_DISABLE_WITH_RESTORE)
      if(disableRestore !== null){
        el.innerText = disableRestore
        el.removeAttribute(PHX_DISABLE_WITH_RESTORE)
      }
      let toEl = DOM.private(el, PHX_REF)
      if(toEl){
        let hook = this.triggerBeforeUpdateHook(el, toEl)
        DOMPatch.patchEl(el, toEl, this.liveSocket.getActiveElement())
        if(hook){ hook.__updated() }
        DOM.deletePrivate(el, PHX_REF)
      }
    })
  }

  /**
   * Put ref as attribute on elements
   * @param {HTMLElement[]} elements 
   * @param {string} event 
   * @param {{loading?: boolean}} opts 
   * @returns {[newRef: number, elements: HTMLElement[], opts: object]}
   */
  putRef(elements, event, opts = {}){
    let newRef = this.ref++
    let disableWith = this.binding(PHX_DISABLE_WITH)
    if(opts.loading){ elements = elements.concat(DOM.all(document, opts.loading))}

    elements.forEach(el => {
      el.classList.add(`phx-${event}-loading`)
      el.setAttribute(PHX_REF, newRef)
      el.setAttribute(PHX_REF_SRC, this.el.id)
      let disableText = el.getAttribute(disableWith)
      if(disableText !== null){
        if(!el.getAttribute(PHX_DISABLE_WITH_RESTORE)){
          el.setAttribute(PHX_DISABLE_WITH_RESTORE, el.innerText)
        }
        if(disableText !== ""){ el.innerText = disableText }
        el.setAttribute("disabled", "")
      }
    })
    return [newRef, elements, opts]
  }

  /**
   * Get component ID from element if it is set
   * @param {HTMLElement} el 
   * @returns {number|null}
   */
  componentID(el){
    let cid = el.getAttribute && el.getAttribute(PHX_COMPONENT)
    return cid ? parseInt(cid) : null
  }

  /**
   * Find component ID of target
   * @param {HTMLElement} target 
   * @param {string|number|HTMLElement} targetCtx 
   * @param {{target?: number|string}} opts 
   * @returns {number|string}
   */
  targetComponentID(target, targetCtx, opts = {}){
    if(isCid(targetCtx)){ return targetCtx }

    let cidOrSelector = opts.target || target.getAttribute(this.binding("target"))
    if(isCid(cidOrSelector)){
      return parseInt(cidOrSelector)
    } else if(targetCtx && (cidOrSelector !== null || opts.target)){
      return this.closestComponentID(targetCtx)
    } else {
      return null
    }
  }

  /**
   * Find closest component ID to the target: self or closest parent
   * @param {number|string|HTMLElement} targetCtx 
   * @returns {number|string|null}
   */
  closestComponentID(targetCtx){
    if(isCid(targetCtx)){
      return targetCtx
    } else if(targetCtx){
      return maybe(targetCtx.closest(`[${PHX_COMPONENT}]`), el => this.ownsElement(el) && this.componentID(el))
    } else {
      return null
    }
  }

  /**
   * Push hook event and handle reply
   * @param {HTMLElement} el 
   * @param {number|string|HTMLElement} targetCtx 
   * @param {string} event 
   * @param {object} payload 
   * @param {(reply: any, ref: number) => void} onReply 
   * @returns {number} ref
   */
  pushHookEvent(el, targetCtx, event, payload, onReply){
    if(!this.isConnected()){
      this.log("hook", () => ["unable to push hook event. LiveView not connected", event, payload])
      return false
    }
    let [ref, els, opts] = this.putRef([el], "hook")
    this.pushWithReply(() => [ref, els, opts], "event", {
      type: "hook",
      event: event,
      value: payload,
      cid: this.closestComponentID(targetCtx)
    }, (resp, reply) => onReply(reply, ref))

    return ref
  }

  /**
   * Extract metadata from element attributes
   * @template {{[key: string]: any}} T
   * @param {HTMLElement} el - element to check attrs for metadata
   * @param {T} [meta] - initial meta object to mutate by adding data from el attrs
   * @param {T} [value] - copy value properties to meta object
   * @returns {T} meta
   */
  extractMeta(el, meta, value){
    let prefix = this.binding("value-")
    for(let i = 0; i < el.attributes.length; i++){
      if(!meta){ meta = {} }
      let name = el.attributes[i].name
      if(name.startsWith(prefix)){ meta[name.replace(prefix, "")] = el.getAttribute(name) }
    }
    if(el.value !== undefined && !(el instanceof HTMLFormElement)){
      if(!meta){ meta = {} }
      meta.value = el.value

      if(el.tagName === "INPUT" && CHECKABLE_INPUTS.indexOf(el.type) >= 0 && !el.checked){
        delete meta.value
      }
    }
    if(value){
      if(!meta){ meta = {} }
      for(let key in value){ meta[key] = value[key] }
    }
    return meta
  }


  /**
   * Push event and optionally handle reply
   * @param {string} type 
   * @param {HTMLElement} el 
   * @param {string|number|HTMLElement} targetCtx 
   * @param {string} phxEvent 
   * @param {{[key: string]: anu}} meta 
   * @param {{loading?: boolean, value?: object, target?: string | number}} opts 
   * @param {(reply: any) => void} [onReply] 
   */
  pushEvent(type, el, targetCtx, phxEvent, meta, opts = {}, onReply){
    this.pushWithReply(() => this.putRef([el], type, opts), "event", {
      type: type,
      event: phxEvent,
      value: this.extractMeta(el, meta, opts.value),
      cid: this.targetComponentID(el, targetCtx, opts)
    }, (resp, reply) => onReply && onReply(reply))
  }

  /**
   * Push file progress event and optionally handle reply
   * @param {HTMLInputElement} fileEl 
   * @param {string} entryRef 
   * @param {number|{error: string}} progress 
   * @param {(resp: any, reply: any) => void} [onReply] 
   */
  pushFileProgress(fileEl, entryRef, progress, onReply = function (){ }){
    this.liveSocket.withinOwners(fileEl.form, (view, targetCtx) => {
      view.pushWithReply(null, "progress", {
        event: fileEl.getAttribute(view.binding(PHX_PROGRESS)),
        ref: fileEl.getAttribute(PHX_UPLOAD_REF),
        entry_ref: entryRef,
        progress: progress,
        cid: view.targetComponentID(fileEl.form, targetCtx)
      }, onReply)
    })
  }

  /**
   * Push form input data over channel
   * @param {HTMLElement} inputEl 
   * @param {string|number|HTMLElement} targetCtx 
   * @param {string|number|null} forceCid 
   * @param {string} phxEvent 
   * @param {object} opts 
   * @param {boolean} [opts.loading]
   * @param {HTMLElement | null} [opts.submitter]
   * @param {string|number} [opts.target]
   * @param {string} [opts._target]
   * @param {(resp: any) => void} [callback] 
   */
  pushInput(inputEl, targetCtx, forceCid, phxEvent, opts, callback){
    let uploads
    let cid = isCid(forceCid) ? forceCid : this.targetComponentID(inputEl.form, targetCtx, opts)
    let refGenerator = () => this.putRef([inputEl, inputEl.form], "change", opts)
    let formData
    let meta  = this.extractMeta(inputEl.form)
    if(inputEl.getAttribute(this.binding("change"))){
      formData = serializeForm(inputEl.form, {_target: opts._target, ...meta}, [inputEl.name])
    } else {
      formData = serializeForm(inputEl.form, {_target: opts._target, ...meta})
    }
    if(DOM.isUploadInput(inputEl) && inputEl.files && inputEl.files.length > 0){
      LiveUploader.trackFiles(inputEl, Array.from(inputEl.files))
    }
    uploads = LiveUploader.serializeUploads(inputEl)

    let event = {
      type: "form",
      event: phxEvent,
      value: formData,
      uploads: uploads,
      cid: cid
    }
    this.pushWithReply(refGenerator, "event", event, resp => {
      DOM.showError(inputEl, this.liveSocket.binding(PHX_FEEDBACK_FOR))
      if(DOM.isUploadInput(inputEl) && DOM.isAutoUpload(inputEl)){
        if(LiveUploader.filesAwaitingPreflight(inputEl).length > 0){
          let [ref, _els] = refGenerator()
          this.uploadFiles(inputEl.form, targetCtx, ref, cid, (_uploads) => {
            callback && callback(resp)
            this.triggerAwaitingSubmit(inputEl.form)
          })
        }
      } else {
        callback && callback(resp)
      }
    })
  }

  /**
   * Lookup and execute any previously scheduled submission callbacks for this form
   * @param {HTMLFormElement} formEl 
   */
  triggerAwaitingSubmit(formEl){
    let awaitingSubmit = this.getScheduledSubmit(formEl)
    if(awaitingSubmit){
      let [_el, _ref, _opts, callback] = awaitingSubmit
      this.cancelSubmit(formEl)
      callback()
    }
  }

  /**
   * Lookup any previously scheduled form submission
   * @param {HTMLFormElement} formEl 
   * @returns {[el: HTMLElement, ref: number, opts: any, cb: () => void] | undefined}
   */
  getScheduledSubmit(formEl){
    return this.formSubmits.find(([el, _ref, _opts, _callback]) => el.isSameNode(formEl))
  }

  /**
   * Schedule a form submission callback for future execution (only schedules once per element)
   * @param {HTMLFormElement} formEl 
   * @param {number} ref 
   * @param {object} opts 
   * @param {() => void} [callback] 
   * @returns {boolean} True if form already scheduled to submit
   */
  scheduleSubmit(formEl, ref, opts, callback){
    if(this.getScheduledSubmit(formEl)){ return true }
    this.formSubmits.push([formEl, ref, opts, callback])
  }

  /**
   * Cancel a form's scheduled submission callback
   * @param {HTMLFormElement} formEl 
   */
  cancelSubmit(formEl){
    this.formSubmits = this.formSubmits.filter(([el, ref, _callback]) => {
      if(el.isSameNode(formEl)){
        this.undoRefs(ref)
        return false
      } else {
        return true
      }
    })
  }

  /**
   * Disable form elements 
   * @param {HTMLFormElement} formEl 
   * @param {object} opts 
   * @param {boolean} [opts.loading]
   * @returns {[newRef: number, elements: HTMLElement[], opts: any]}
   */
  disableForm(formEl, opts = {}){
    let filterIgnored = el => {
      let userIgnored = closestPhxBinding(el, `${this.binding(PHX_UPDATE)}=ignore`, el.form)
      return !(userIgnored || closestPhxBinding(el, "data-phx-update=ignore", el.form))
    }
    let filterDisables = el => {
      return el.hasAttribute(this.binding(PHX_DISABLE_WITH))
    }
    let filterButton = el => el.tagName == "BUTTON"

    let filterInput = el => ["INPUT", "TEXTAREA", "SELECT"].includes(el.tagName)

    let formElements = Array.from(formEl.elements)
    let disables = formElements.filter(filterDisables)
    let buttons = formElements.filter(filterButton).filter(filterIgnored)
    let inputs = formElements.filter(filterInput).filter(filterIgnored)

    buttons.forEach(button => {
      button.setAttribute(PHX_DISABLED, button.disabled)
      button.disabled = true
    })
    inputs.forEach(input => {
      input.setAttribute(PHX_READONLY, input.readOnly)
      input.readOnly = true
      if(input.files){
        input.setAttribute(PHX_DISABLED, input.disabled)
        input.disabled = true
      }
    })
    formEl.setAttribute(this.binding(PHX_PAGE_LOADING), "")
    return this.putRef([formEl].concat(disables).concat(buttons).concat(inputs), "submit", opts)
  }

  /**
   * Push for submission data; will wait for any file uploads to finish
   * @param {HTMLFormElement} formEl 
   * @param {string|number|HTMLElement} targetCtx 
   * @param {string} phxEvent 
   * @param {HTMLElement | null | undefined} submitter 
   * @param {object} opts 
   * @param {function} [onReply] 
   * @returns {boolean}
   */
  pushFormSubmit(formEl, targetCtx, phxEvent, submitter, opts, onReply){
    let refGenerator = () => this.disableForm(formEl, opts)
    let cid = this.targetComponentID(formEl, targetCtx)
    if(LiveUploader.hasUploadsInProgress(formEl)){
      let [ref, _els] = refGenerator()
      let push = () => this.pushFormSubmit(formEl, targetCtx, phxEvent, submitter, opts, onReply)
      return this.scheduleSubmit(formEl, ref, opts, push)
    } else if(LiveUploader.inputsAwaitingPreflight(formEl).length > 0){
      let [ref, els] = refGenerator()
      let proxyRefGen = () => [ref, els, opts]
      this.uploadFiles(formEl, targetCtx, ref, cid, (_uploads) => {
        let meta = this.extractMeta(formEl)
        let formData = serializeForm(formEl, {submitter, ...meta})
        this.pushWithReply(proxyRefGen, "event", {
          type: "form",
          event: phxEvent,
          value: formData,
          cid: cid
        }, onReply)
      })
    } else if(!(formEl.hasAttribute(PHX_REF) && formEl.classList.contains("phx-submit-loading"))){
      let meta = this.extractMeta(formEl)
      let formData = serializeForm(formEl, {submitter, ...meta})
      this.pushWithReply(refGenerator, "event", {
        type: "form",
        event: phxEvent,
        value: formData,
        cid: cid
      }, onReply)
    }
  }

  /**
   * Perform all file uploads for inputs in this form
   * @param {HTMLFormElement} formEl 
   * @param {string|number|HTMLElement} targetCtx 
   * @param {number} ref 
   * @param {string|number} cid 
   * @param {() => void} onComplete 
   */
  uploadFiles(formEl, targetCtx, ref, cid, onComplete){
    let joinCountAtUpload = this.joinCount
    let inputEls = LiveUploader.activeFileInputs(formEl)
    let numFileInputsInProgress = inputEls.length

    // get each file input
    inputEls.forEach(inputEl => {
      let uploader = new LiveUploader(inputEl, this, () => {
        numFileInputsInProgress--
        if(numFileInputsInProgress === 0){ onComplete() }
      })

      this.uploaders[inputEl] = uploader
      let entries = uploader.entries().map(entry => entry.toPreflightPayload())

      let payload = {
        ref: inputEl.getAttribute(PHX_UPLOAD_REF),
        entries: entries,
        cid: this.targetComponentID(inputEl.form, targetCtx)
      }

      this.log("upload", () => ["sending preflight request", payload])

      this.pushWithReply(null, "allow_upload", payload, resp => {
        this.log("upload", () => ["got preflight response", resp])
        if(resp.error){
          this.undoRefs(ref)
          let [entry_ref, reason] = resp.error
          this.log("upload", () => [`error for entry ${entry_ref}`, reason])
        } else {
          let onError = (callback) => {
            this.channel.onError(() => {
              if(this.joinCount === joinCountAtUpload){ callback() }
            })
          }
          uploader.initAdapterUpload(resp, onError, this.liveSocket)
        }
      })
    })
  }

  /**
   * Dispatch custom upload event to file input matching name
   * @param {string|number|HTMLElement} targetCtx 
   * @param {string} name 
   * @param {(File|Blob)[]} filesOrBlobs 
   */
  dispatchUploads(targetCtx, name, filesOrBlobs){
    let targetElement = this.targetCtxElement(targetCtx) || this.el
    let inputs = DOM.findUploadInputs(targetElement).filter(el => el.name === name)
    if(inputs.length === 0){ logError(`no live file inputs found matching the name "${name}"`) }
    else if(inputs.length > 1){ logError(`duplicate live file inputs found matching the name "${name}"`) }
    else { DOM.dispatchEvent(inputs[0], PHX_TRACK_UPLOADS, {detail: {files: filesOrBlobs}}) }
  }

  /**
   * Get element for target element
   * @param {string|number|HTMLElement} targetCtx 
   * @returns {HTMLElement|null}
   */
  targetCtxElement(targetCtx){
    if(isCid(targetCtx)){
      let [target] = DOM.findComponentNodeList(this.el, targetCtx)
      return target
    } else if(targetCtx){
      return targetCtx
    } else {
      return null
    }
  }

  /**
   * Push form recovery
   * @param {HTMLFormElement} form 
   * @param {string|number} newCid 
   * @param {function} callback 
   */
  pushFormRecovery(form, newCid, callback){
    // eslint-disable-next-line no-unused-vars
    this.liveSocket.withinOwners(form, (view, targetCtx) => {
      let phxChange = this.binding("change")
      let inputs = Array.from(form.elements).filter(el => DOM.isFormInput(el) && el.name && !el.hasAttribute(phxChange))
      if(inputs.length === 0){ return }

      // we must clear tracked uploads before recovery as they no longer have valid refs
      inputs.forEach(input => input.hasAttribute(PHX_UPLOAD_REF) && LiveUploader.clearFiles(input))
      let input = inputs.find(el => el.type !== "hidden") || inputs[0]

      let phxEvent = form.getAttribute(this.binding(PHX_AUTO_RECOVER)) || form.getAttribute(this.binding("change"))
      JS.exec("change", phxEvent, view, input, ["push", {_target: input.name, newCid: newCid, callback: callback}])
    })
  }

  /**
   * Push live patch for link
   * @param {string} href 
   * @param {HTMLElement} targetEl 
   * @param {(linkRef: number) => void} callback 
   */
  pushLinkPatch(href, targetEl, callback){
    let linkRef = this.liveSocket.setPendingLink(href)
    let refGen = targetEl ? () => this.putRef([targetEl], "click") : null
    let fallback = () => this.liveSocket.redirect(window.location.href)
    let url = href.startsWith("/") ? `${location.protocol}//${location.host}${href}` : href

    let push = this.pushWithReply(refGen, "live_patch", {url}, resp => {
      this.liveSocket.requestDOMUpdate(() => {
        if(resp.link_redirect){
          this.liveSocket.replaceMain(href, null, callback, linkRef)
        } else {
          if(this.liveSocket.commitPendingLink(linkRef)){
            this.href = href
          }
          this.applyPendingUpdates()
          callback && callback(linkRef)
        }
      })
    })

    if(push){
      push.receive("timeout", fallback)
    } else {
      fallback()
    }
  }

  /**
   * Select forms for recovery within the element bound to this view
   * @param {string} html 
   * @returns {HTMLFormElement[]}
   */
  formsForRecovery(html){
    if(this.joinCount === 0){ return [] }

    let phxChange = this.binding("change")
    let template = document.createElement("template")
    template.innerHTML = html

    return (
      DOM.all(this.el, `form[${phxChange}]`)
        .filter(form => form.id && this.ownsElement(form))
        .filter(form => form.elements.length > 0)
        .filter(form => form.getAttribute(this.binding(PHX_AUTO_RECOVER)) !== "ignore")
        .map(form => {
          // attribute given via JS module needs to be escaped as it contains the symbols []",
          // which result in an invalid css selector otherwise.
          const phxChangeValue = form.getAttribute(phxChange).replaceAll(/([\[\]"])/g, "\\$1")
          let newForm = template.content.querySelector(`form[id="${form.id}"][${phxChange}="${phxChangeValue}"]`)
          if(newForm){
            return [form, newForm, this.targetComponentID(newForm)]
          } else {
            return [form, form, this.targetComponentID(form)]
          }
        })
        // eslint-disable-next-line no-unused-vars
        .filter(([form, newForm, newCid]) => newForm)
    )
  }

  /**
   * Find child components from given component ID list and push the collection of found IDs
   * @param {(string|number)[]} destroyedCIDs 
   * @returns {boolean|undefined}
   */
  maybePushComponentsDestroyed(destroyedCIDs){
    let willDestroyCIDs = destroyedCIDs.filter(cid => {
      return DOM.findComponentNodeList(this.el, cid).length === 0
    })
    if(willDestroyCIDs.length > 0){
      this.pruningCIDs.push(...willDestroyCIDs)

      this.pushWithReply(null, "cids_will_destroy", {cids: willDestroyCIDs}, () => {
        // The cids are either back on the page or they will be fully removed,
        // so we can remove them from the pruningCIDs.
        this.pruningCIDs = this.pruningCIDs.filter(cid => willDestroyCIDs.indexOf(cid) !== -1)

        // See if any of the cids we wanted to destroy were added back,
        // if they were added back, we don't actually destroy them.
        let completelyDestroyCIDs = willDestroyCIDs.filter(cid => {
          return DOM.findComponentNodeList(this.el, cid).length === 0
        })

        if(completelyDestroyCIDs.length > 0){
          this.pushWithReply(null, "cids_destroyed", {cids: completelyDestroyCIDs}, (resp) => {
            this.rendered.pruneCIDs(resp.cids)
          })
        }
      })
    }
  }

  /**
   * Does this view own the given element?
   * @param {Element} el 
   * @returns {boolean}
   */
  ownsElement(el){
    let parentViewEl = el.closest(PHX_VIEW_SELECTOR)
    return el.getAttribute(PHX_PARENT_ID) === this.id ||
      (parentViewEl && parentViewEl.id === this.id) ||
      (!parentViewEl && this.isDead)
  }

  /**
   * Submit the data for this form element over livesocket
   * @param {HTMLFormElement} form 
   * @param {string|number|Element} targetCtx 
   * @param {string} phxEvent 
   * @param {HTMLElement|null|undefined} submitter 
   * @param {object} [opts] 
   * @param {boolean} [opts.loading] 
   * @param {boolean} [opts.page_loading] 
   * @param {any} [opts.value] 
   * @param {string|Element} [opts.target] 
   * @param {string} [opts._target] 
   */
  submitForm(form, targetCtx, phxEvent, submitter, opts = {}){
    DOM.putPrivate(form, PHX_HAS_SUBMITTED, true)
    let phxFeedback = this.liveSocket.binding(PHX_FEEDBACK_FOR)
    let inputs = Array.from(form.elements)
    inputs.forEach(input => DOM.putPrivate(input, PHX_HAS_SUBMITTED, true))
    this.liveSocket.blurActiveElement(this)
    this.pushFormSubmit(form, targetCtx, phxEvent, submitter, opts, () => {
      inputs.forEach(input => DOM.showError(input, phxFeedback))
      this.liveSocket.restorePreviouslyActiveFocus()
    })
  }

  /**
   * Get the binding matching string
   * @param {string} kind 
   * @returns {string}
   */
  binding(kind){ return this.liveSocket.binding(kind) }
}
