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
  PHX_HAS_FOCUSED,
  PHX_HAS_SUBMITTED,
  PHX_HOOK,
  PHX_PAGE_LOADING,
  PHX_PARENT_ID,
  PHX_PROGRESS,
  PHX_READONLY,
  PHX_REF_LOADING,
  PHX_REF_SRC,
  PHX_REF_LOCK,
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
import ElementRef from "./element_ref"
import DOMPatch from "./dom_patch"
import LiveUploader from "./live_uploader"
import Rendered from "./rendered"
import ViewHook from "./view_hook"
import JS from "./js"

export let prependFormDataKey = (key, prefix) => {
  let isArray = key.endsWith("[]")
  // Remove the "[]" if it's an array
  let baseKey = isArray ? key.slice(0, -2) : key
  // Replace last occurrence of key before a closing bracket or the end with key plus suffix
  baseKey = baseKey.replace(/([^\[\]]+)(\]?$)/, `${prefix}$1$2`)
  // Add back the "[]" if it was an array
  if(isArray){ baseKey += "[]" }
  return baseKey
}

let serializeForm = (form, metadata, onlyNames = []) => {
  const {submitter, ...meta} = metadata

  // We must inject the submitter in the order that it exists in the DOM
  // releative to other inputs. For example, for checkbox groups, the order must be maintained.
  let injectedElement
  if(submitter && submitter.name){
    const input = document.createElement("input")
    input.type = "hidden"
    // set the form attribute if the submitter has one;
    // this can happen if the element is outside the actual form element
    const formId = submitter.getAttribute("form")
    if(formId){
      input.setAttribute("form", formId)
    }
    input.name = submitter.name
    input.value = submitter.value
    submitter.parentElement.insertBefore(input, submitter)
    injectedElement = input
  }

  const formData = new FormData(form)
  const toRemove = []

  formData.forEach((val, key, _index) => {
    if(val instanceof File){ toRemove.push(key) }
  })

  // Cleanup after building fileData
  toRemove.forEach(key => formData.delete(key))

  const params = new URLSearchParams()

  let elements = Array.from(form.elements)
  for(let [key, val] of formData.entries()){
    if(onlyNames.length === 0 || onlyNames.indexOf(key) >= 0){
      let inputs = elements.filter(input => input.name === key)
      let isUnused = !inputs.some(input => (DOM.private(input, PHX_HAS_FOCUSED) || DOM.private(input, PHX_HAS_SUBMITTED)))
      let hidden = inputs.every(input => input.type === "hidden")
      if(isUnused && !(submitter && submitter.name == key) && !hidden){
        params.append(prependFormDataKey(key, "_unused_"), "")
      }
      params.append(key, val)
    }
  }

  // remove the injected element again
  // (it would be removed by the next dom patch anyway, but this is cleaner)
  if(submitter && injectedElement){
    submitter.parentElement.removeChild(injectedElement)
  }

  for(let metaKey in meta){ params.append(metaKey, meta[metaKey]) }

  return params.toString()
}

export default class View {
  constructor(el, liveSocket, parentView, flash, liveReferer){
    this.isDead = false
    this.liveSocket = liveSocket
    this.flash = flash
    this.parent = parentView
    this.root = parentView ? parentView.root : this
    this.el = el
    this.id = this.el.id
    this.ref = 0
    this.childJoins = 0
    this.loaderTimer = null
    this.pendingDiffs = []
    this.pendingForms = new Set()
    this.redirect = false
    this.href = null
    this.joinCount = this.parent ? this.parent.joinCount - 1 : 0
    this.joinPending = true
    this.destroyed = false
    this.joinCallback = function(onDone){ onDone && onDone() }
    this.stopCallback = function(){ }
    this.pendingJoinOps = this.parent ? null : []
    this.viewHooks = {}
    this.formSubmits = []
    this.children = this.parent ? null : {}
    this.root.children[this.id] = {}
    this.formsForRecovery = {}
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

  setHref(href){ this.href = href }

  setRedirect(href){
    this.redirect = true
    this.href = href
  }

  isMain(){ return this.el.hasAttribute(PHX_MAIN) }

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

  isConnected(){ return this.channel.canPush() }

  getSession(){ return this.el.getAttribute(PHX_SESSION) }

  getStatic(){
    let val = this.el.getAttribute(PHX_STATIC)
    return val === "" ? null : val
  }

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

  showLoader(timeout){
    clearTimeout(this.loaderTimer)
    if(timeout){
      this.loaderTimer = setTimeout(() => this.showLoader(), timeout)
    } else {
      for(let id in this.viewHooks){ this.viewHooks[id].__disconnected() }
      this.setContainerClasses(PHX_LOADING_CLASS)
    }
  }

  execAll(binding){
    DOM.all(this.el, `[${binding}]`, el => this.liveSocket.execJS(el, el.getAttribute(binding)))
  }

  hideLoader(){
    clearTimeout(this.loaderTimer)
    this.setContainerClasses(PHX_CONNECTED_CLASS)
    this.execAll(this.binding("connected"))
  }

  triggerReconnected(){
    for(let id in this.viewHooks){ this.viewHooks[id].__reconnected() }
  }

  log(kind, msgCallback){
    this.liveSocket.log(this, kind, msgCallback)
  }

  transition(time, onStart, onDone = function(){}){
    this.liveSocket.transition(time, onStart, onDone)
  }

  // calls the callback with the view and target element for the given phxTarget
  // targets can be:
  //  * an element itself, then it is simply passed to liveSocket.owner;
  //  * a CID (Component ID), then we first search the component's element in the DOM
  //  * a selector, then we search the selector in the DOM and call the callback
  //    for each element found with the corresponding owner view
  withinTargets(phxTarget, callback, dom = document, viewEl){
    // in the form recovery case we search in a template fragment instead of
    // the real dom, therefore we optionally pass dom and viewEl

    if(phxTarget instanceof HTMLElement || phxTarget instanceof SVGElement){
      return this.liveSocket.owner(phxTarget, view => callback(view, phxTarget))
    }

    if(isCid(phxTarget)){
      let targets = DOM.findComponentNodeList(viewEl || this.el, phxTarget)
      if(targets.length === 0){
        logError(`no component found matching phx-target of ${phxTarget}`)
      } else {
        callback(this, parseInt(phxTarget))
      }
    } else {
      let targets = Array.from(dom.querySelectorAll(phxTarget))
      if(targets.length === 0){ logError(`nothing found matching the phx-target selector "${phxTarget}"`) }
      targets.forEach(target => this.liveSocket.owner(target, view => callback(view, target)))
    }
  }

  applyDiff(type, rawDiff, callback){
    this.log(type, () => ["", clone(rawDiff)])
    let {diff, reply, events, title} = Rendered.extract(rawDiff)
    callback({diff, reply, events})
    if(typeof title === "string"){ window.requestAnimationFrame(() => DOM.putTitle(title)) }
  }

  onJoin(resp){
    let {rendered, container, liveview_version} = resp
    if(container){
      let [tag, attrs] = container
      this.el = DOM.replaceRootContainer(this.el, tag, attrs)
    }
    this.childJoins = 0
    this.joinPending = true
    this.flash = null
    if(this.root === this){
      this.formsForRecovery = this.getFormsForRecovery()
    }

    if(liveview_version !== this.liveSocket.version()){
      console.error(`LiveView asset version mismatch. JavaScript version ${this.liveSocket.version()} vs. server ${liveview_version}. To avoid issues, please ensure that your assets use the same version as the server.`)
    }

    Browser.dropLocal(this.liveSocket.localStorage, window.location.pathname, CONSECUTIVE_RELOADS)
    this.applyDiff("mount", rendered, ({diff, events}) => {
      this.rendered = new Rendered(this.id, diff)
      let [html, streams] = this.renderContainer(null, "join")
      this.dropPendingRefs()
      this.joinCount++

      this.maybeRecoverForms(html, () => {
        this.onJoinComplete(resp, html, streams, events)
      })
    })
  }

  dropPendingRefs(){
    DOM.all(document, `[${PHX_REF_SRC}="${this.refSrc()}"]`, el => {
      el.removeAttribute(PHX_REF_LOADING)
      el.removeAttribute(PHX_REF_SRC)
      el.removeAttribute(PHX_REF_LOCK)
    })
  }

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
      // set PHX_ROOT_ID to prevent events from being dispatched to the root view
      // while the child join is still pending
      if(fromEl){ fromEl.setAttribute(PHX_ROOT_ID, this.root.id) }
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

  attachTrueDocEl(){
    this.el = DOM.byId(this.id)
    this.el.setAttribute(PHX_ROOT_ID, this.root.id)
  }

  // this is invoked for dead and live views, so we must filter by
  // by owner to ensure we aren't duplicating hooks across disconnect
  // and connected states. This also handles cases where hooks exist
  // in a root layout with a LV in the body
  execNewMounted(parent = this.el){
    let phxViewportTop = this.binding(PHX_VIEWPORT_TOP)
    let phxViewportBottom = this.binding(PHX_VIEWPORT_BOTTOM)
    DOM.all(parent, `[${phxViewportTop}], [${phxViewportBottom}]`, hookEl => {
      if(this.ownsElement(hookEl)){
        DOM.maybeAddPrivateHooks(hookEl, phxViewportTop, phxViewportBottom)
        this.maybeAddNewHook(hookEl)
      }
    })
    DOM.all(parent, `[${this.binding(PHX_HOOK)}], [data-phx-${PHX_HOOK}]`, hookEl => {
      if(this.ownsElement(hookEl)){
        this.maybeAddNewHook(hookEl)
      }
    })
    DOM.all(parent, `[${this.binding(PHX_MOUNTED)}]`, el => {
      if(this.ownsElement(el)){
        this.maybeMounted(el)
      }
    })
  }

  applyJoinPatch(live_patch, html, streams, events){
    this.attachTrueDocEl()
    let patch = new DOMPatch(this, this.el, this.id, html, streams, null)
    patch.markPrunableContentForRemoval()
    this.performPatch(patch, false, true)
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

  triggerBeforeUpdateHook(fromEl, toEl){
    this.liveSocket.triggerDOM("onBeforeElUpdated", [fromEl, toEl])
    let hook = this.getHook(fromEl)
    let isIgnored = hook && DOM.isIgnored(fromEl, this.binding(PHX_UPDATE))
    if(hook && !fromEl.isEqualNode(toEl) && !(isIgnored && isEqualObj(fromEl.dataset, toEl.dataset))){
      hook.__beforeUpdate()
      return hook
    }
  }

  maybeMounted(el){
    let phxMounted = el.getAttribute(this.binding(PHX_MOUNTED))
    let hasBeenInvoked = phxMounted && DOM.private(el, "mounted")
    if(phxMounted && !hasBeenInvoked){
      this.liveSocket.execJS(el, phxMounted)
      DOM.putPrivate(el, "mounted", true)
    }
  }

  maybeAddNewHook(el, force){
    let newHook = this.addHook(el)
    if(newHook){ newHook.__mounted() }
  }

  performPatch(patch, pruneCids, isJoinPatch = false){
    let removedEls = []
    let phxChildrenAdded = false
    let updatedHookIds = new Set()

    this.liveSocket.triggerDOM("onPatchStart", [patch.targetContainer])

    patch.after("added", el => {
      this.liveSocket.triggerDOM("onNodeAdded", [el])
      let phxViewportTop = this.binding(PHX_VIEWPORT_TOP)
      let phxViewportBottom = this.binding(PHX_VIEWPORT_BOTTOM)
      DOM.maybeAddPrivateHooks(el, phxViewportTop, phxViewportBottom)
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
    patch.perform(isJoinPatch)
    this.afterElementsRemoved(removedEls, pruneCids)

    this.liveSocket.triggerDOM("onPatchEnd", [patch.targetContainer])
    return phxChildrenAdded
  }

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

  joinNewChildren(){
    DOM.findPhxChildren(this.el, this.id).forEach(el => this.joinChild(el))
  }

  maybeRecoverForms(html, callback){
    const phxChange = this.binding("change")
    const oldForms = this.root.formsForRecovery
    // So why do we create a template element here?
    // One way to recover forms would be to immediately apply the mount
    // patch and then afterwards recover the forms. However, this would
    // cause a flicker, because the mount patch would remove the form content
    // until it is restored. Therefore LV decided to do form recovery with the
    // raw HTML before it is applied and delay the mount patch until the form
    // recovery events are done.
    let template = document.createElement("template")
    template.innerHTML = html
    // because we work with a template element, we must manually copy the attributes
    // otherwise the owner / target helpers don't work properly
    const rootEl = template.content.firstElementChild
    rootEl.id = this.id
    rootEl.setAttribute(PHX_ROOT_ID, this.root.id)
    rootEl.setAttribute(PHX_SESSION, this.getSession())
    rootEl.setAttribute(PHX_STATIC, this.getStatic())
    rootEl.setAttribute(PHX_PARENT_ID, this.parent ? this.parent.id : null)

    // we go over all form elements in the new HTML for the LV
    // and look for old forms in the `formsForRecovery` object;
    // the formsForRecovery can also contain forms from child views
    const formsToRecover =
      // we go over all forms in the new DOM; because this is only the HTML for the current
      // view, we can be sure that all forms are owned by this view:
      DOM.all(template.content, "form")
        // only recover forms that have an id and are in the old DOM
        .filter(newForm => newForm.id && oldForms[newForm.id])
        // abandon forms we already tried to recover to prevent looping a failed state
        .filter(newForm => !this.pendingForms.has(newForm.id))
        // only recover if the form has the same phx-change value
        .filter(newForm => oldForms[newForm.id].getAttribute(phxChange) === newForm.getAttribute(phxChange))
        .map(newForm => {
          return [oldForms[newForm.id], newForm]
        })

    if(formsToRecover.length === 0){
      return callback()
    }

    formsToRecover.forEach(([oldForm, newForm], i) => {
      this.pendingForms.add(newForm.id)
      // it is important to use the firstElementChild of the template content
      // because when traversing a documentFragment using parentNode, we won't ever arrive at
      // the fragment; as the template is always a LiveView, we can be sure that there is only
      // one child on the root level
      this.pushFormRecovery(oldForm, newForm, template.content.firstElementChild, () => {
        this.pendingForms.delete(newForm.id)
        // we only call the callback once all forms have been recovered
        if(i === formsToRecover.length - 1){
          callback()
        }
      })
    })
  }

  getChildById(id){ return this.root.children[this.id][id] }

  getDescendentByEl(el){
    if(el.id === this.id){
      return this
    } else {
      return this.children[el.getAttribute(PHX_PARENT_ID)][el.id]
    }
  }

  destroyDescendent(id){
    for(let parentId in this.root.children){
      for(let childId in this.root.children[parentId]){
        if(childId === id){ return this.root.children[parentId][childId].destroy() }
      }
    }
  }

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

  isJoinPending(){ return this.joinPending }

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

  onAllChildJoinsComplete(){
    // we can clear pending form recoveries now that we've joined.
    // They either all resolved or were abandoned
    this.pendingForms.clear()
    // we can also clear the formsForRecovery object to not keep old form elements around
    this.formsForRecovery = {}
    this.joinCallback(() => {
      this.pendingJoinOps.forEach(([view, op]) => {
        if(!view.isDestroyed()){ op() }
      })
      this.pendingJoinOps = []
    })
  }

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
        let parentCids = DOM.findExistingParentCIDs(this.el, this.rendered.componentCIDs(diff))
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

  renderContainer(diff, kind){
    return this.liveSocket.time(`toString diff (${kind})`, () => {
      let tag = this.el.tagName
      // Don't skip any component in the diff nor any marked as pruned
      // (as they may have been added back)
      let cids = diff ? this.rendered.componentCIDs(diff) : null
      let [html, streams] = this.rendered.toString(cids)
      return [`<${tag}>${html}</${tag}>`, streams]
    })
  }

  componentPatch(diff, cid){
    if(isEmpty(diff)) return false
    let [html, streams] = this.rendered.componentToString(cid)
    let patch = new DOMPatch(this, this.el, this.id, html, streams, cid)
    let childrenAdded = this.performPatch(patch, true)
    return childrenAdded
  }

  getHook(el){ return this.viewHooks[ViewHook.elementID(el)] }

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

  destroyHook(hook){
    hook.__destroyed()
    hook.__cleanup__()
    delete this.viewHooks[ViewHook.elementID(hook.el)]
  }

  applyPendingUpdates(){
    this.pendingDiffs.forEach(({diff, events}) => this.update(diff, events))
    this.pendingDiffs = []
    this.eachChild(child => child.applyPendingUpdates())
  }

  eachChild(callback){
    let children = this.root.children[this.id] || {}
    for(let id in children){ callback(this.getChildById(id)) }
  }

  onChannel(event, cb){
    this.liveSocket.onChannel(this.channel, event, resp => {
      if(this.isJoinPending()){
        this.root.pendingJoinOps.push([this, () => cb(resp)])
      } else {
        this.liveSocket.requestDOMUpdate(() => cb(resp))
      }
    })
  }

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

  destroyAllChildren(){ this.eachChild(child => child.destroy()) }

  onLiveRedirect(redir){
    let {to, kind, flash} = redir
    let url = this.expandURL(to)
    this.liveSocket.historyRedirect(url, kind, flash)
  }

  onLivePatch(redir){
    let {to, kind} = redir
    this.href = this.expandURL(to)
    this.liveSocket.historyPatch(to, kind)
  }

  expandURL(to){
    return to.startsWith("/") ? `${window.location.protocol}//${window.location.host}${to}` : to
  }

  onRedirect({to, flash}){ this.liveSocket.redirect(to, flash) }

  isDestroyed(){ return this.destroyed }

  joinDead(){ this.isDead = true }

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

  displayError(classes){
    if(this.isMain()){ DOM.dispatchEvent(window, "phx:page-loading-start", {detail: {to: this.href, kind: "error"}}) }
    this.showLoader()
    this.setContainerClasses(...classes)
    this.execAll(this.binding("disconnected"))
  }

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

  undoRefs(ref, onlyEls){
    onlyEls = onlyEls ? new Set(onlyEls) : null
    if(!this.isConnected()){ return } // exit if external form triggered

    DOM.all(document, `[${PHX_REF_SRC}="${this.refSrc()}"]`, el => {
      if(onlyEls && !onlyEls.has(el)){ return }
      this.undoElRef(el, ref)
    })
  }

  undoElRef(el, ref){
    let elRef = new ElementRef(el)

    elRef.maybeUndo(ref, clonedTree => {
      let hook = this.triggerBeforeUpdateHook(el, clonedTree)
      DOMPatch.patchWithClonedTree(el, clonedTree, this.liveSocket)
      DOM.all(el, `[${PHX_REF_SRC}="${this.refSrc()}"]`, child => this.undoElRef(child, ref))
      this.execNewMounted(el)
      if(hook){ hook.__updated() }
    })
  }

  refSrc(){ return this.el.id }

  putRef(elements, event, opts = {}){
    let newRef = this.ref++
    let disableWith = this.binding(PHX_DISABLE_WITH)
    if(opts.loading){
      let loadingEls = DOM.all(document, opts.loading).map(el => {
        return {el, lock: true, loading: true}
      })
      elements = elements.concat(loadingEls)
    }

    for(let {el, lock, loading} of elements){
      if(!lock && !loading){ throw new Error("putRef requires lock or loading") }
      el.setAttribute(PHX_REF_SRC, this.refSrc())
      if(loading){ el.setAttribute(PHX_REF_LOADING, newRef) }
      if(lock){ el.setAttribute(PHX_REF_LOCK, newRef) }

      if(!loading || (opts.submitter && !(el === opts.submitter || el === opts.form))){ continue }

      el.classList.add(`phx-${event}-loading`)
      el.dispatchEvent(new CustomEvent(`phx:${event}-loading`, {bubbles: true, cancelable: false}))
      let disableText = el.getAttribute(disableWith)
      if(disableText !== null){
        if(!el.getAttribute(PHX_DISABLE_WITH_RESTORE)){
          el.setAttribute(PHX_DISABLE_WITH_RESTORE, el.innerText)
        }
        if(disableText !== ""){ el.innerText = disableText }
        // PHX_DISABLED could have already been set in disableForm
        el.setAttribute(PHX_DISABLED, el.getAttribute(PHX_DISABLED) || el.disabled)
        el.setAttribute("disabled", "")
      }
    }
    return [newRef, elements.map(({el}) => el), opts]
  }

  componentID(el){
    let cid = el.getAttribute && el.getAttribute(PHX_COMPONENT)
    return cid ? parseInt(cid) : null
  }

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

  closestComponentID(targetCtx){
    if(isCid(targetCtx)){
      return targetCtx
    } else if(targetCtx){
      return maybe(targetCtx.closest(`[${PHX_COMPONENT}]`), el => this.ownsElement(el) && this.componentID(el))
    } else {
      return null
    }
  }

  pushHookEvent(el, targetCtx, event, payload, onReply){
    if(!this.isConnected()){
      this.log("hook", () => ["unable to push hook event. LiveView not connected", event, payload])
      return false
    }
    let [ref, els, opts] = this.putRef([{el, loading: true, lock: true}], "hook")
    this.pushWithReply(() => [ref, els, opts], "event", {
      type: "hook",
      event: event,
      value: payload,
      cid: this.closestComponentID(targetCtx)
    }, (resp, reply) => onReply(reply, ref))

    return ref
  }

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


  pushEvent(type, el, targetCtx, phxEvent, meta, opts = {}, onReply){
    this.pushWithReply(() => this.putRef([{el, loading: true, lock: true}], type, opts), "event", {
      type: type,
      event: phxEvent,
      value: this.extractMeta(el, meta, opts.value),
      cid: this.targetComponentID(el, targetCtx, opts)
    }, (resp, reply) => onReply && onReply(reply))
  }

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

  pushInput(inputEl, targetCtx, forceCid, phxEvent, opts, callback){
    let uploads
    let cid = isCid(forceCid) ? forceCid : this.targetComponentID(inputEl.form, targetCtx, opts)
    let refGenerator = () => {
      return this.putRef([
        {el: inputEl, loading: true, lock: true},
        {el: inputEl.form, loading: true, lock: true}
      ], "change", opts)
    }
    let formData
    let meta  = this.extractMeta(inputEl.form)
    if(inputEl instanceof HTMLButtonElement){ meta.submitter = inputEl }
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
      if(DOM.isUploadInput(inputEl) && DOM.isAutoUpload(inputEl)){
        if(LiveUploader.filesAwaitingPreflight(inputEl).length > 0){
          let [ref, _els] = refGenerator()
          this.undoRefs(ref, [inputEl.form])
          this.uploadFiles(inputEl.form, targetCtx, ref, cid, (_uploads) => {
            callback && callback(resp)
            this.triggerAwaitingSubmit(inputEl.form)
            this.undoRefs(ref)
          })
        }
      } else {
        callback && callback(resp)
      }
    })
  }

  triggerAwaitingSubmit(formEl){
    let awaitingSubmit = this.getScheduledSubmit(formEl)
    if(awaitingSubmit){
      let [_el, _ref, _opts, callback] = awaitingSubmit
      this.cancelSubmit(formEl)
      callback()
    }
  }

  getScheduledSubmit(formEl){
    return this.formSubmits.find(([el, _ref, _opts, _callback]) => el.isSameNode(formEl))
  }

  scheduleSubmit(formEl, ref, opts, callback){
    if(this.getScheduledSubmit(formEl)){ return true }
    this.formSubmits.push([formEl, ref, opts, callback])
  }

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
    let formEls = disables.concat(buttons).concat(inputs).map(el => {
      return {el, loading: true, lock: true}
    })

    return this.putRef([{el: formEl, loading: true, lock: false}].concat(formEls), "submit", opts)
  }

  pushFormSubmit(formEl, targetCtx, phxEvent, submitter, opts, onReply){
    let refGenerator = () => this.disableForm(formEl, {...opts, form: formEl, submitter: submitter})
    let cid = this.targetComponentID(formEl, targetCtx)
    if(LiveUploader.hasUploadsInProgress(formEl)){
      let [ref, _els] = refGenerator()
      let push = () => this.pushFormSubmit(formEl, targetCtx, phxEvent, submitter, opts, onReply)
      return this.scheduleSubmit(formEl, ref, opts, push)
    } else if(LiveUploader.inputsAwaitingPreflight(formEl).length > 0){
      let [ref, els] = refGenerator()
      let proxyRefGen = () => [ref, els, opts]
      this.uploadFiles(formEl, targetCtx, ref, cid, (uploads) => {
        // if we still having pending preflights it means we have invalid entries
        // and the phx-submit cannot be completed
        if(LiveUploader.inputsAwaitingPreflight(formEl).length > 0){
          return this.undoRefs(ref)
        }
        let meta = this.extractMeta(formEl)
        let formData = serializeForm(formEl, {submitter, ...meta})
        this.pushWithReply(proxyRefGen, "event", {
          type: "form",
          event: phxEvent,
          value: formData,
          cid: cid
        }, onReply)
      })
    } else if(!(formEl.hasAttribute(PHX_REF_SRC) && formEl.classList.contains("phx-submit-loading"))){
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

  uploadFiles(formEl, targetCtx, ref, cid, onComplete){
    let joinCountAtUpload = this.joinCount
    let inputEls = LiveUploader.activeFileInputs(formEl)
    let numFileInputsInProgress = inputEls.length

    // get each file input
    inputEls.forEach(inputEl => {
      let uploader = new LiveUploader(inputEl, this, () => {
        numFileInputsInProgress--
        if(numFileInputsInProgress === 0){ onComplete() }
      });

      let entries = uploader.entries().map(entry => entry.toPreflightPayload())

      if(entries.length === 0) {
        numFileInputsInProgress--
        return
      }

      let payload = {
        ref: inputEl.getAttribute(PHX_UPLOAD_REF),
        entries: entries,
        cid: this.targetComponentID(inputEl.form, targetCtx)
      }

      this.log("upload", () => ["sending preflight request", payload])

      this.pushWithReply(null, "allow_upload", payload, resp => {
        this.log("upload", () => ["got preflight response", resp])
        // the preflight will reject entries beyond the max entries
        // so we error and cancel entries on the client that are missing from the response
        uploader.entries().forEach(entry => {
          if(resp.entries && !resp.entries[entry.ref]){
            this.handleFailedEntryPreflight(entry.ref, "failed preflight", uploader)
          }
        })
        // for auto uploads, we may have an empty entries response from the server
        // for form submits that contain invalid entries
        if(resp.error || Object.keys(resp.entries).length === 0){
          this.undoRefs(ref)
          let errors = resp.error || []
          errors.map(([entry_ref, reason]) => {
            this.handleFailedEntryPreflight(entry_ref, reason, uploader)
          })
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

  handleFailedEntryPreflight(uploadRef, reason, uploader){
    if(uploader.isAutoUpload()){
      // uploadRef may be top level upload config ref or entry ref
      let entry = uploader.entries().find(entry => entry.ref === uploadRef.toString())
      if(entry){ entry.cancel() }
    } else {
      uploader.entries().map(entry => entry.cancel())
    }
    this.log("upload", () => [`error for entry ${uploadRef}`, reason])
  }

  dispatchUploads(targetCtx, name, filesOrBlobs){
    let targetElement = this.targetCtxElement(targetCtx) || this.el
    let inputs = DOM.findUploadInputs(targetElement).filter(el => el.name === name)
    if(inputs.length === 0){ logError(`no live file inputs found matching the name "${name}"`) }
    else if(inputs.length > 1){ logError(`duplicate live file inputs found matching the name "${name}"`) }
    else { DOM.dispatchEvent(inputs[0], PHX_TRACK_UPLOADS, {detail: {files: filesOrBlobs}}) }
  }

  targetCtxElement(targetCtx) {
    if(isCid(targetCtx)){
      let [target] = DOM.findComponentNodeList(this.el, targetCtx)
      return target
    } else if(targetCtx) {
      return targetCtx
    } else {
      return null
    }
  }

  pushFormRecovery(oldForm, newForm, templateDom, callback){
    // we are only recovering forms inside the current view, therefore it is safe to
    // skip withinOwners here and always use this when referring to the view
    const phxChange = this.binding("change")
    const phxTarget = newForm.getAttribute(this.binding("target")) || newForm
    const phxEvent = newForm.getAttribute(this.binding(PHX_AUTO_RECOVER)) || newForm.getAttribute(this.binding("change"))
    const inputs = Array.from(oldForm.elements).filter(el => DOM.isFormInput(el) && el.name && !el.hasAttribute(phxChange))
    if(inputs.length === 0){ return }

    // we must clear tracked uploads before recovery as they no longer have valid refs
    inputs.forEach(input => input.hasAttribute(PHX_UPLOAD_REF) && LiveUploader.clearFiles(input))
    // pushInput assumes that there is a source element that initiated the change;
    // because this is not the case when we recover forms, we provide the first input we find
    let input = inputs.find(el => el.type !== "hidden") || inputs[0]

    // in the case that there are multiple targets, we count the number of pending recovery events
    // and only call the callback once all events have been processed
    let pending = 0
    // withinTargets(phxTarget, callback, dom, viewEl)
    this.withinTargets(phxTarget, (targetView, targetCtx) => {
      const cid = this.targetComponentID(newForm, targetCtx)
      pending++
      targetView.pushInput(input, targetCtx, cid, phxEvent, {_target: input.name}, () => {
        pending--
        if(pending === 0){ callback() }
      })
    }, templateDom, templateDom)
  }

  pushLinkPatch(href, targetEl, callback){
    let linkRef = this.liveSocket.setPendingLink(href)
    let refGen = targetEl ? () => this.putRef([{el: targetEl, loading: true, lock: true}], "click") : null
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

  getFormsForRecovery(){
    if(this.joinCount === 0){ return {} }

    let phxChange = this.binding("change")

    return DOM.all(this.el, `form[${phxChange}]`)
      .filter(form => form.id)
      .filter(form => form.elements.length > 0)
      .filter(form => form.getAttribute(this.binding(PHX_AUTO_RECOVER)) !== "ignore")
      .map(form => form.cloneNode(true))
      .reduce((acc, form) => {
        acc[form.id] = form
        return acc
      }, {})
  }

  maybePushComponentsDestroyed(destroyedCIDs){
    let willDestroyCIDs = destroyedCIDs.filter(cid => {
      return DOM.findComponentNodeList(this.el, cid).length === 0
    })

    if(willDestroyCIDs.length > 0){
      // we must reset the render change tracking for cids that
      // could be added back from the server so we don't skip them
      willDestroyCIDs.forEach(cid => this.rendered.resetRender(cid))

      this.pushWithReply(null, "cids_will_destroy", {cids: willDestroyCIDs}, () => {
        // we must wait for pending transitions to complete before determining
        // if the cids were added back to the DOM in the meantime (#3139)
        this.liveSocket.requestDOMUpdate(() => {
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
      })
    }
  }

  ownsElement(el){
    let parentViewEl = el.closest(PHX_VIEW_SELECTOR)
    return el.getAttribute(PHX_PARENT_ID) === this.id ||
      (parentViewEl && parentViewEl.id === this.id) ||
      (!parentViewEl && this.isDead)
  }

  submitForm(form, targetCtx, phxEvent, submitter, opts = {}){
    DOM.putPrivate(form, PHX_HAS_SUBMITTED, true)
    const inputs = Array.from(form.elements)
    inputs.forEach(input => DOM.putPrivate(input, PHX_HAS_SUBMITTED, true))
    this.liveSocket.blurActiveElement(this)
    this.pushFormSubmit(form, targetCtx, phxEvent, submitter, opts, () => {
      this.liveSocket.restorePreviouslyActiveFocus()
    })
  }

  binding(kind){ return this.liveSocket.binding(kind) }
}
