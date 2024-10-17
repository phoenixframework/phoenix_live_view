/** Initializes the LiveSocket
 *
 *
 * @param {string} endPoint - The string WebSocket endpoint, ie, `"wss://example.com/live"`,
 *                                               `"/live"` (inherited host & protocol)
 * @param {Phoenix.Socket} socket - the required Phoenix Socket class imported from "phoenix". For example:
 *
 *     import {Socket} from "phoenix"
 *     import {LiveSocket} from "phoenix_live_view"
 *     let liveSocket = new LiveSocket("/live", Socket, {...})
 *
 * @param {Object} [opts] - Optional configuration. Outside of keys listed below, all
 * configuration is passed directly to the Phoenix Socket constructor.
 * @param {Object} [opts.defaults] - The optional defaults to use for various bindings,
 * such as `phx-debounce`. Supports the following keys:
 *
 *   - debounce - the millisecond phx-debounce time. Defaults 300
 *   - throttle - the millisecond phx-throttle time. Defaults 300
 *
 * @param {Function} [opts.params] - The optional function for passing connect params.
 * The function receives the element associated with a given LiveView. For example:
 *
 *     (el) => {view: el.getAttribute("data-my-view-name", token: window.myToken}
 *
 * @param {string} [opts.bindingPrefix] - The optional prefix to use for all phx DOM annotations.
 * Defaults to "phx-".
 * @param {Object} [opts.hooks] - The optional object for referencing LiveView hook callbacks.
 * @param {Object} [opts.uploaders] - The optional object for referencing LiveView uploader callbacks.
 * @param {integer} [opts.loaderTimeout] - The optional delay in milliseconds to wait before apply
 * loading states.
 * @param {integer} [opts.maxReloads] - The maximum reloads before entering failsafe mode.
 * @param {integer} [opts.reloadJitterMin] - The minimum time between normal reload attempts.
 * @param {integer} [opts.reloadJitterMax] - The maximum time between normal reload attempts.
 * @param {integer} [opts.failsafeJitter] - The time between reload attempts in failsafe mode.
 * @param {Function} [opts.viewLogger] - The optional function to log debug information. For example:
 *
 *     (view, kind, msg, obj) => console.log(`${view.id} ${kind}: ${msg} - `, obj)
 *
 * @param {Object} [opts.metadata] - The optional object mapping event names to functions for
 * populating event metadata. For example:
 *
 *     metadata: {
 *       click: (e, el) => {
 *         return {
 *           ctrlKey: e.ctrlKey,
 *           metaKey: e.metaKey,
 *           detail: e.detail || 1,
 *         }
 *       },
 *       keydown: (e, el) => {
 *         return {
 *           key: e.key,
 *           ctrlKey: e.ctrlKey,
 *           metaKey: e.metaKey,
 *           shiftKey: e.shiftKey
 *         }
 *       }
 *     }
 * @param {Object} [opts.sessionStorage] - An optional Storage compatible object
 * Useful when LiveView won't have access to `sessionStorage`.  For example, This could
 * happen if a site loads a cross-domain LiveView in an iframe.  Example usage:
 *
 *     class InMemoryStorage {
 *       constructor() { this.storage = {} }
 *       getItem(keyName) { return this.storage[keyName] || null }
 *       removeItem(keyName) { delete this.storage[keyName] }
 *       setItem(keyName, keyValue) { this.storage[keyName] = keyValue }
 *     }
 *
 * @param {Object} [opts.localStorage] - An optional Storage compatible object
 * Useful for when LiveView won't have access to `localStorage`.
 * See `opts.sessionStorage` for examples.
*/

import {
  BINDING_PREFIX,
  CONSECUTIVE_RELOADS,
  DEFAULTS,
  FAILSAFE_JITTER,
  LOADER_TIMEOUT,
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
  PHX_RELOAD_STATUS
} from "./constants"

import {
  clone,
  closestPhxBinding,
  closure,
  debug,
  maybe
} from "./utils"

import Browser from "./browser"
import DOM from "./dom"
import Hooks from "./hooks"
import LiveUploader from "./live_uploader"
import View from "./view"
import JS from "./js"

export let isUsedInput = (el) => DOM.isUsedInput(el)

export default class LiveSocket {
  constructor(url, phxSocket, opts = {}){
    this.unloaded = false
    if(!phxSocket || phxSocket.constructor.name === "Object"){
      throw new Error(`
      a phoenix Socket must be provided as the second argument to the LiveSocket constructor. For example:

          import {Socket} from "phoenix"
          import {LiveSocket} from "phoenix_live_view"
          let liveSocket = new LiveSocket("/live", Socket, {...})
      `)
    }
    this.socket = new phxSocket(url, opts)
    this.bindingPrefix = opts.bindingPrefix || BINDING_PREFIX
    this.opts = opts
    this.params = closure(opts.params || {})
    this.viewLogger = opts.viewLogger
    this.metadataCallbacks = opts.metadata || {}
    this.defaults = Object.assign(clone(DEFAULTS), opts.defaults || {})
    this.activeElement = null
    this.prevActive = null
    this.silenced = false
    this.main = null
    this.outgoingMainEl = null
    this.clickStartedAtTarget = null
    this.linkRef = 1
    this.roots = {}
    this.href = window.location.href
    this.pendingLink = null
    this.currentLocation = clone(window.location)
    this.hooks = opts.hooks || {}
    this.uploaders = opts.uploaders || {}
    this.loaderTimeout = opts.loaderTimeout || LOADER_TIMEOUT
    this.reloadWithJitterTimer = null
    this.maxReloads = opts.maxReloads || MAX_RELOADS
    this.reloadJitterMin = opts.reloadJitterMin || RELOAD_JITTER_MIN
    this.reloadJitterMax = opts.reloadJitterMax || RELOAD_JITTER_MAX
    this.failsafeJitter = opts.failsafeJitter || FAILSAFE_JITTER
    this.localStorage = opts.localStorage || window.localStorage
    this.sessionStorage = opts.sessionStorage || window.sessionStorage
    this.boundTopLevelEvents = false
    this.boundEventNames = new Set()
    this.serverCloseRef = null
    this.domCallbacks = Object.assign({
      jsQuerySelectorAll: null,
      onPatchStart: closure(),
      onPatchEnd: closure(),
      onNodeAdded: closure(),
      onBeforeElUpdated: closure()},
    opts.dom || {})
    this.transitions = new TransitionSet()
    window.addEventListener("pagehide", _e => {
      this.unloaded = true
    })
    this.socket.onOpen(() => {
      if(this.isUnloaded()){
        // reload page if being restored from back/forward cache and browser does not emit "pageshow"
        window.location.reload()
      }
    })
  }

  // public

  version(){ return LV_VSN }

  isProfileEnabled(){ return this.sessionStorage.getItem(PHX_LV_PROFILE) === "true" }

  isDebugEnabled(){ return this.sessionStorage.getItem(PHX_LV_DEBUG) === "true" }

  isDebugDisabled(){ return this.sessionStorage.getItem(PHX_LV_DEBUG) === "false" }

  enableDebug(){ this.sessionStorage.setItem(PHX_LV_DEBUG, "true") }

  enableProfiling(){ this.sessionStorage.setItem(PHX_LV_PROFILE, "true") }

  disableDebug(){ this.sessionStorage.setItem(PHX_LV_DEBUG, "false") }

  disableProfiling(){ this.sessionStorage.removeItem(PHX_LV_PROFILE) }

  enableLatencySim(upperBoundMs){
    this.enableDebug()
    console.log("latency simulator enabled for the duration of this browser session. Call disableLatencySim() to disable")
    this.sessionStorage.setItem(PHX_LV_LATENCY_SIM, upperBoundMs)
  }

  disableLatencySim(){ this.sessionStorage.removeItem(PHX_LV_LATENCY_SIM) }

  getLatencySim(){
    let str = this.sessionStorage.getItem(PHX_LV_LATENCY_SIM)
    return str ? parseInt(str) : null
  }

  getSocket(){ return this.socket }

  connect(){
    // enable debug by default if on localhost and not explicitly disabled
    if(window.location.hostname === "localhost" && !this.isDebugDisabled()){ this.enableDebug() }
    let doConnect = () => {
      this.resetReloadStatus()
      if(this.joinRootViews()){
        this.bindTopLevelEvents()
        this.socket.connect()
      } else if(this.main){
        this.socket.connect()
      } else {
        this.bindTopLevelEvents({dead: true})
      }
      this.joinDeadView()
    }
    if(["complete", "loaded", "interactive"].indexOf(document.readyState) >= 0){
      doConnect()
    } else {
      document.addEventListener("DOMContentLoaded", () => doConnect())
    }
  }

  disconnect(callback){
    clearTimeout(this.reloadWithJitterTimer)
    // remove the socket close listener to avoid trying to handle
    // a server close event when it is actually caused by us disconnecting
    if(this.serverCloseRef){
      this.socket.off(this.serverCloseRef)
      this.serverCloseRef = null
    }
    this.socket.disconnect(callback)
  }

  replaceTransport(transport){
    clearTimeout(this.reloadWithJitterTimer)
    this.socket.replaceTransport(transport)
    this.connect()
  }

  execJS(el, encodedJS, eventType = null){
    let e = new CustomEvent("phx:exec", {detail: {sourceElement: el}})
    this.owner(el, view => JS.exec(e, eventType, encodedJS, view, el))
  }

  // private

  execJSHookPush(el, phxEvent, data, callback){
    this.withinOwners(el, view => {
      let e = new CustomEvent("phx:exec", {detail: {sourceElement: el}})
      JS.exec(e, "hook", phxEvent, view, el, ["push", {data, callback}])
    })
  }

  unload(){
    if(this.unloaded){ return }
    if(this.main && this.isConnected()){ this.log(this.main, "socket", () => ["disconnect for page nav"]) }
    this.unloaded = true
    this.destroyAllViews()
    this.disconnect()
  }

  triggerDOM(kind, args){ this.domCallbacks[kind](...args) }

  time(name, func){
    if(!this.isProfileEnabled() || !console.time){ return func() }
    console.time(name)
    let result = func()
    console.timeEnd(name)
    return result
  }

  log(view, kind, msgCallback){
    if(this.viewLogger){
      let [msg, obj] = msgCallback()
      this.viewLogger(view, kind, msg, obj)
    } else if(this.isDebugEnabled()){
      let [msg, obj] = msgCallback()
      debug(view, kind, msg, obj)
    }
  }

  requestDOMUpdate(callback){
    this.transitions.after(callback)
  }

  transition(time, onStart, onDone = function(){}){
    this.transitions.addTransition(time, onStart, onDone)
  }

  onChannel(channel, event, cb){
    channel.on(event, data => {
      let latency = this.getLatencySim()
      if(!latency){
        cb(data)
      } else {
        setTimeout(() => cb(data), latency)
      }
    })
  }

  reloadWithJitter(view, log){
    clearTimeout(this.reloadWithJitterTimer)
    this.disconnect()
    let minMs = this.reloadJitterMin
    let maxMs = this.reloadJitterMax
    let afterMs = Math.floor(Math.random() * (maxMs - minMs + 1)) + minMs
    let tries = Browser.updateLocal(this.localStorage, window.location.pathname, CONSECUTIVE_RELOADS, 0, count => count + 1)
    if(tries >= this.maxReloads){
      afterMs = this.failsafeJitter
    }
    this.reloadWithJitterTimer = setTimeout(() => {
      // if view has recovered, such as transport replaced, then cancel
      if(view.isDestroyed() || view.isConnected()){ return }
      view.destroy()
      log ? log() : this.log(view, "join", () => [`encountered ${tries} consecutive reloads`])
      if(tries >= this.maxReloads){
        this.log(view, "join", () => [`exceeded ${this.maxReloads} consecutive reloads. Entering failsafe mode`])
      }
      if(this.hasPendingLink()){
        window.location = this.pendingLink
      } else {
        window.location.reload()
      }
    }, afterMs)
  }

  getHookCallbacks(name){
    return name && name.startsWith("Phoenix.") ? Hooks[name.split(".")[1]] : this.hooks[name]
  }

  isUnloaded(){ return this.unloaded }

  isConnected(){ return this.socket.isConnected() }

  getBindingPrefix(){ return this.bindingPrefix }

  binding(kind){ return `${this.getBindingPrefix()}${kind}` }

  channel(topic, params){ return this.socket.channel(topic, params) }

  joinDeadView(){
    let body = document.body
    if(body && !this.isPhxView(body) && !this.isPhxView(document.firstElementChild)){
      let view = this.newRootView(body)
      view.setHref(this.getHref())
      view.joinDead()
      if(!this.main){ this.main = view }
      window.requestAnimationFrame(() => view.execNewMounted())
    }
  }

  joinRootViews(){
    let rootsFound = false
    DOM.all(document, `${PHX_VIEW_SELECTOR}:not([${PHX_PARENT_ID}])`, rootEl => {
      if(!this.getRootById(rootEl.id)){
        let view = this.newRootView(rootEl)
        view.setHref(this.getHref())
        view.join()
        if(rootEl.hasAttribute(PHX_MAIN)){ this.main = view }
      }
      rootsFound = true
    })
    return rootsFound
  }

  redirect(to, flash, reloadToken){
    if(reloadToken){ Browser.setCookie(PHX_RELOAD_STATUS, reloadToken, 60) }
    this.unload()
    Browser.redirect(to, flash)
  }

  replaceMain(href, flash, callback = null, linkRef = this.setPendingLink(href)){
    let liveReferer = this.currentLocation.href
    this.outgoingMainEl = this.outgoingMainEl || this.main.el
    let removeEls = DOM.all(this.outgoingMainEl, `[${this.binding("remove")}]`)
    let newMainEl = DOM.cloneNode(this.outgoingMainEl, "")
    this.main.showLoader(this.loaderTimeout)
    this.main.destroy()

    this.main = this.newRootView(newMainEl, flash, liveReferer)
    this.main.setRedirect(href)
    this.transitionRemoves(removeEls, true)
    this.main.join((joinCount, onDone) => {
      if(joinCount === 1 && this.commitPendingLink(linkRef)){
        this.requestDOMUpdate(() => {
          // remove phx-remove els right before we replace the main element
          removeEls.forEach(el => el.remove())
          DOM.findPhxSticky(document).forEach(el => newMainEl.appendChild(el))
          this.outgoingMainEl.replaceWith(newMainEl)
          this.outgoingMainEl = null
          callback && callback(linkRef)
          onDone()
        })
      }
    })
  }

  transitionRemoves(elements, skipSticky, callback){
    let removeAttr = this.binding("remove")
    if(skipSticky){
      const stickies = DOM.findPhxSticky(document) || []
      elements = elements.filter(el => !DOM.isChildOfAny(el, stickies))
    }
    let silenceEvents = (e) => {
      e.preventDefault()
      e.stopImmediatePropagation()
    }
    elements.forEach(el => {
      // prevent all listeners we care about from bubbling to window
      // since we are removing the element
      for(let event of this.boundEventNames){
        el.addEventListener(event, silenceEvents, true)
      }
      this.execJS(el, el.getAttribute(removeAttr), "remove")
    })
    // remove the silenced listeners when transitions are done incase the element is re-used
    // and call caller's callback as soon as we are done with transitions
    this.requestDOMUpdate(() => {
      elements.forEach(el => {
        for(let event of this.boundEventNames){
          el.removeEventListener(event, silenceEvents, true)
        }
      })
      callback && callback()
    })
  }

  isPhxView(el){ return el.getAttribute && el.getAttribute(PHX_SESSION) !== null }

  newRootView(el, flash, liveReferer){
    let view = new View(el, this, null, flash, liveReferer)
    this.roots[view.id] = view
    return view
  }

  owner(childEl, callback){
    let view = maybe(childEl.closest(PHX_VIEW_SELECTOR), el => this.getViewByEl(el)) || this.main
    return view && callback ? callback(view) : view
  }

  withinOwners(childEl, callback){
    this.owner(childEl, view => callback(view, childEl))
  }

  getViewByEl(el){
    let rootId = el.getAttribute(PHX_ROOT_ID)
    return maybe(this.getRootById(rootId), root => root.getDescendentByEl(el))
  }

  getRootById(id){ return this.roots[id] }

  destroyAllViews(){
    for(let id in this.roots){
      this.roots[id].destroy()
      delete this.roots[id]
    }
    this.main = null
  }

  destroyViewByEl(el){
    let root = this.getRootById(el.getAttribute(PHX_ROOT_ID))
    if(root && root.id === el.id){
      root.destroy()
      delete this.roots[root.id]
    } else if(root){
      root.destroyDescendent(el.id)
    }
  }

  getActiveElement(){
    return document.activeElement
  }

  dropActiveElement(view){
    if(this.prevActive && view.ownsElement(this.prevActive)){
      this.prevActive = null
    }
  }

  restorePreviouslyActiveFocus(){
    if(this.prevActive && this.prevActive !== document.body){
      this.prevActive.focus()
    }
  }

  blurActiveElement(){
    this.prevActive = this.getActiveElement()
    if(this.prevActive !== document.body){ this.prevActive.blur() }
  }

  bindTopLevelEvents({dead} = {}){
    if(this.boundTopLevelEvents){ return }

    this.boundTopLevelEvents = true
    // enter failsafe reload if server has gone away intentionally, such as "disconnect" broadcast
    this.serverCloseRef = this.socket.onClose(event => {
      // failsafe reload if normal closure and we still have a main LV
      if(event && event.code === 1000 && this.main){ return this.reloadWithJitter(this.main) }
    })
    document.body.addEventListener("click", function (){ }) // ensure all click events bubble for mobile Safari
    window.addEventListener("pageshow", e => {
      if(e.persisted){ // reload page if being restored from back/forward cache
        this.getSocket().disconnect()
        this.withPageLoading({to: window.location.href, kind: "redirect"})
        window.location.reload()
      }
    }, true)
    if(!dead){ this.bindNav() }
    this.bindClicks()
    if(!dead){ this.bindForms() }
    this.bind({keyup: "keyup", keydown: "keydown"}, (e, type, view, targetEl, phxEvent, phxTarget) => {
      let matchKey = targetEl.getAttribute(this.binding(PHX_KEY))
      let pressedKey = e.key && e.key.toLowerCase() // chrome clicked autocompletes send a keydown without key
      if(matchKey && matchKey.toLowerCase() !== pressedKey){ return }

      let data = {key: e.key, ...this.eventMeta(type, e, targetEl)}
      JS.exec(e, type, phxEvent, view, targetEl, ["push", {data}])
    })
    this.bind({blur: "focusout", focus: "focusin"}, (e, type, view, targetEl, phxEvent, phxTarget) => {
      if(!phxTarget){
        let data = {key: e.key, ...this.eventMeta(type, e, targetEl)}
        JS.exec(e, type, phxEvent, view, targetEl, ["push", {data}])
      }
    })
    this.bind({blur: "blur", focus: "focus"}, (e, type, view, targetEl, phxEvent, phxTarget) => {
      // blur and focus are triggered on document and window. Discard one to avoid dups
      if(phxTarget === "window"){
        let data = this.eventMeta(type, e, targetEl)
        JS.exec(e, type, phxEvent, view, targetEl, ["push", {data}])
      }
    })
    this.on("dragover", e => e.preventDefault())
    this.on("drop", e => {
      e.preventDefault()
      let dropTargetId = maybe(closestPhxBinding(e.target, this.binding(PHX_DROP_TARGET)), trueTarget => {
        return trueTarget.getAttribute(this.binding(PHX_DROP_TARGET))
      })
      let dropTarget = dropTargetId && document.getElementById(dropTargetId)
      let files = Array.from(e.dataTransfer.files || [])
      if(!dropTarget || dropTarget.disabled || files.length === 0 || !(dropTarget.files instanceof FileList)){ return }

      LiveUploader.trackFiles(dropTarget, files, e.dataTransfer)
      dropTarget.dispatchEvent(new Event("input", {bubbles: true}))
    })
    this.on(PHX_TRACK_UPLOADS, e => {
      let uploadTarget = e.target
      if(!DOM.isUploadInput(uploadTarget)){ return }
      let files = Array.from(e.detail.files || []).filter(f => f instanceof File || f instanceof Blob)
      LiveUploader.trackFiles(uploadTarget, files)
      uploadTarget.dispatchEvent(new Event("input", {bubbles: true}))
    })
  }

  eventMeta(eventName, e, targetEl){
    let callback = this.metadataCallbacks[eventName]
    return callback ? callback(e, targetEl) : {}
  }

  setPendingLink(href){
    this.linkRef++
    this.pendingLink = href
    this.resetReloadStatus()
    return this.linkRef
  }

  // anytime we are navigating or connecting, drop reload cookie in case
  // we issue the cookie but the next request was interrupted and the server never dropped it
  resetReloadStatus(){ Browser.deleteCookie(PHX_RELOAD_STATUS) }

  commitPendingLink(linkRef){
    if(this.linkRef !== linkRef){
      return false
    } else {
      this.href = this.pendingLink
      this.pendingLink = null
      return true
    }
  }

  getHref(){ return this.href }

  hasPendingLink(){ return !!this.pendingLink }

  bind(events, callback){
    for(let event in events){
      let browserEventName = events[event]

      this.on(browserEventName, e => {
        let binding = this.binding(event)
        let windowBinding = this.binding(`window-${event}`)
        let targetPhxEvent = e.target.getAttribute && e.target.getAttribute(binding)
        if(targetPhxEvent){
          this.debounce(e.target, e, browserEventName, () => {
            this.withinOwners(e.target, view => {
              callback(e, event, view, e.target, targetPhxEvent, null)
            })
          })
        } else {
          DOM.all(document, `[${windowBinding}]`, el => {
            let phxEvent = el.getAttribute(windowBinding)
            this.debounce(el, e, browserEventName, () => {
              this.withinOwners(el, view => {
                callback(e, event, view, el, phxEvent, "window")
              })
            })
          })
        }
      })
    }
  }

  bindClicks(){
    this.on("mousedown", e => this.clickStartedAtTarget = e.target)
    this.bindClick("click", "click")
  }

  bindClick(eventName, bindingName){
    let click = this.binding(bindingName)
    window.addEventListener(eventName, e => {
      let target = null
      // a synthetic click event (detail 0) will not have caused a mousedown event,
      // therefore the clickStartedAtTarget is stale
      if(e.detail === 0) this.clickStartedAtTarget = e.target
      let clickStartedAtTarget = this.clickStartedAtTarget || e.target
      // when searching the target for the click event, we always want to
      // use the actual event target, see #3372
      target = closestPhxBinding(e.target, click)
      this.dispatchClickAway(e, clickStartedAtTarget)
      this.clickStartedAtTarget = null
      let phxEvent = target && target.getAttribute(click)
      if(!phxEvent){
        if(DOM.isNewPageClick(e, window.location)){ this.unload() }
        return
      }

      if(target.getAttribute("href") === "#"){ e.preventDefault() }

      // noop if we are in the middle of awaiting an ack for this el already
      if(target.hasAttribute(PHX_REF_SRC)){ return }

      this.debounce(target, e, "click", () => {
        this.withinOwners(target, view => {
          JS.exec(e, "click", phxEvent, view, target, ["push", {data: this.eventMeta("click", e, target)}])
        })
      })
    }, false)
  }

  dispatchClickAway(e, clickStartedAt){
    let phxClickAway = this.binding("click-away")
    DOM.all(document, `[${phxClickAway}]`, el => {
      if(!(el.isSameNode(clickStartedAt) || el.contains(clickStartedAt))){
        this.withinOwners(el, view => {
          let phxEvent = el.getAttribute(phxClickAway)
          if(JS.isVisible(el) && JS.isInViewport(el)){
            JS.exec(e, "click", phxEvent, view, el, ["push", {data: this.eventMeta("click", e, e.target)}])
          }
        })
      }
    })
  }

  bindNav(){
    if(!Browser.canPushState()){ return }
    if(history.scrollRestoration){ history.scrollRestoration = "manual" }
    let scrollTimer = null
    window.addEventListener("scroll", _e => {
      clearTimeout(scrollTimer)
      scrollTimer = setTimeout(() => {
        Browser.updateCurrentState(state => Object.assign(state, {scroll: window.scrollY}))
      }, 100)
    })
    window.addEventListener("popstate", event => {
      if(!this.registerNewLocation(window.location)){ return }
      let {type, id, root, scroll} = event.state || {}
      let href = window.location.href

      DOM.dispatchEvent(window, "phx:navigate", {detail: {href, patch: type === "patch", pop: true}})
      this.requestDOMUpdate(() => {
        if(this.main.isConnected() && (type === "patch" && id === this.main.id)){
          this.main.pushLinkPatch(event, href, null, () => {
            this.maybeScroll(scroll)
          })
        } else {
          this.replaceMain(href, null, () => {
            if(root){ this.replaceRootHistory() }
            this.maybeScroll(scroll)
          })
        }
      })
    }, false)
    window.addEventListener("click", e => {
      let target = closestPhxBinding(e.target, PHX_LIVE_LINK)
      let type = target && target.getAttribute(PHX_LIVE_LINK)
      if(!type || !this.isConnected() || !this.main || DOM.wantsNewTab(e)){ return }

      // When wrapping an SVG element in an anchor tag, the href can be an SVGAnimatedString
      let href = target.href instanceof SVGAnimatedString ? target.href.baseVal : target.href

      let linkState = target.getAttribute(PHX_LINK_STATE)
      e.preventDefault()
      e.stopImmediatePropagation() // do not bubble click to regular phx-click bindings
      if(this.pendingLink === href){ return }

      this.requestDOMUpdate(() => {
        if(type === "patch"){
          this.pushHistoryPatch(e, href, linkState, target)
        } else if(type === "redirect"){
          this.historyRedirect(e, href, linkState, null, target)
        } else {
          throw new Error(`expected ${PHX_LIVE_LINK} to be "patch" or "redirect", got: ${type}`)
        }
        let phxClick = target.getAttribute(this.binding("click"))
        if(phxClick){
          this.requestDOMUpdate(() => this.execJS(target, phxClick, "click"))
        }
      })
    }, false)
  }

  maybeScroll(scroll){
    if(typeof(scroll) === "number"){
      requestAnimationFrame(() => {
        window.scrollTo(0, scroll)
      }) // the body needs to render before we scroll.
    }
  }

  dispatchEvent(event, payload = {}){
    DOM.dispatchEvent(window, `phx:${event}`, {detail: payload})
  }

  dispatchEvents(events){
    events.forEach(([event, payload]) => this.dispatchEvent(event, payload))
  }

  withPageLoading(info, callback){
    DOM.dispatchEvent(window, "phx:page-loading-start", {detail: info})
    let done = () => DOM.dispatchEvent(window, "phx:page-loading-stop", {detail: info})
    return callback ? callback(done) : done
  }

  pushHistoryPatch(e, href, linkState, targetEl){
    if(!this.isConnected() || !this.main.isMain()){ return Browser.redirect(href) }

    this.withPageLoading({to: href, kind: "patch"}, done => {
      this.main.pushLinkPatch(e, href, targetEl, linkRef => {
        this.historyPatch(href, linkState, linkRef)
        done()
      })
    })
  }

  historyPatch(href, linkState, linkRef = this.setPendingLink(href)){
    if(!this.commitPendingLink(linkRef)){ return }

    Browser.pushState(linkState, {type: "patch", id: this.main.id}, href)
    DOM.dispatchEvent(window, "phx:navigate", {detail: {patch: true, href, pop: false}})
    this.registerNewLocation(window.location)
  }

  historyRedirect(e, href, linkState, flash, targetEl){
    if(targetEl && e.isTrusted && e.type !== "popstate"){ targetEl.classList.add("phx-click-loading") }
    if(!this.isConnected() || !this.main.isMain()){ return Browser.redirect(href, flash) }

    // convert to full href if only path prefix
    if(/^\/$|^\/[^\/]+.*$/.test(href)){
      let {protocol, host} = window.location
      href = `${protocol}//${host}${href}`
    }
    let scroll = window.scrollY
    this.withPageLoading({to: href, kind: "redirect"}, done => {
      this.replaceMain(href, flash, (linkRef) => {
        if(linkRef === this.linkRef){
          Browser.pushState(linkState, {type: "redirect", id: this.main.id, scroll: scroll}, href)
          DOM.dispatchEvent(window, "phx:navigate", {detail: {href, patch: false, pop: false}})
          this.registerNewLocation(window.location)
        }
        done()
      })
    })
  }

  replaceRootHistory(){
    Browser.pushState("replace", {root: true, type: "patch", id: this.main.id})
  }

  registerNewLocation(newLocation){
    let {pathname, search} = this.currentLocation
    if(pathname + search === newLocation.pathname + newLocation.search){
      return false
    } else {
      this.currentLocation = clone(newLocation)
      return true
    }
  }

  bindForms(){
    let iterations = 0
    let externalFormSubmitted = false

    // disable forms on submit that track phx-change but perform external submit
    this.on("submit", e => {
      let phxSubmit = e.target.getAttribute(this.binding("submit"))
      let phxChange = e.target.getAttribute(this.binding("change"))
      if(!externalFormSubmitted && phxChange && !phxSubmit){
        externalFormSubmitted = true
        e.preventDefault()
        this.withinOwners(e.target, view => {
          view.disableForm(e.target)
          // safari needs next tick
          window.requestAnimationFrame(() => {
            if(DOM.isUnloadableFormSubmit(e)){ this.unload() }
            e.target.submit()
          })
        })
      }
    })

    this.on("submit", e => {
      let phxEvent = e.target.getAttribute(this.binding("submit"))
      if(!phxEvent){
        if(DOM.isUnloadableFormSubmit(e)){ this.unload() }
        return
      }
      e.preventDefault()
      e.target.disabled = true
      this.withinOwners(e.target, view => {
        JS.exec(e, "submit", phxEvent, view, e.target, ["push", {submitter: e.submitter}])
      })
    })

    for(let type of ["change", "input"]){
      this.on(type, e => {
        if(e instanceof CustomEvent && e.target.form === undefined){
          throw new Error(`dispatching a custom ${type} event is only supported on input elements inside a form`)
        }
        let phxChange = this.binding("change")
        let input = e.target
        // do not fire phx-change if we are in the middle of a composition session
        // https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/isComposing
        // Safari has issues if the input is updated while composing
        // see https://github.com/phoenixframework/phoenix_live_view/issues/3322
        if(e.isComposing){
          const key = `composition-listener-${type}`
          if(!DOM.private(input, key)){
            DOM.putPrivate(input, key, true)
            input.addEventListener("compositionend", () => {
              // trigger a new input/change event
              input.dispatchEvent(new Event(type, {bubbles: true}))
              DOM.deletePrivate(input, key)
            }, {once: true})
          }
          return
        }
        let inputEvent = input.getAttribute(phxChange)
        let formEvent = input.form && input.form.getAttribute(phxChange)
        let phxEvent = inputEvent || formEvent
        if(!phxEvent){ return }
        if(input.type === "number" && input.validity && input.validity.badInput){ return }

        let dispatcher = inputEvent ? input : input.form
        let currentIterations = iterations
        iterations++
        let {at: at, type: lastType} = DOM.private(input, "prev-iteration") || {}
        // Browsers should always fire at least one "input" event before every "change"
        // Ignore "change" events, unless there was no prior "input" event.
        // This could happen if user code triggers a "change" event, or if the browser is non-conforming.
        if(at === currentIterations - 1 && type === "change" && lastType === "input"){ return }

        DOM.putPrivate(input, "prev-iteration", {at: currentIterations, type: type})

        this.debounce(input, e, type, () => {
          this.withinOwners(dispatcher, view => {
            DOM.putPrivate(input, PHX_HAS_FOCUSED, true)
            JS.exec(e, "change", phxEvent, view, input, ["push", {_target: e.target.name, dispatcher: dispatcher}])
          })
        })
      })
    }
    this.on("reset", (e) => {
      let form = e.target
      DOM.resetForm(form)
      let input = Array.from(form.elements).find(el => el.type === "reset")
      if(input){
        // wait until next tick to get updated input value
        window.requestAnimationFrame(() => {
          input.dispatchEvent(new Event("input", {bubbles: true, cancelable: false}))
        })
      }
    })
  }

  debounce(el, event, eventType, callback){
    if(eventType === "blur" || eventType === "focusout"){ return callback() }

    let phxDebounce = this.binding(PHX_DEBOUNCE)
    let phxThrottle = this.binding(PHX_THROTTLE)
    let defaultDebounce = this.defaults.debounce.toString()
    let defaultThrottle = this.defaults.throttle.toString()

    this.withinOwners(el, view => {
      let asyncFilter = () => !view.isDestroyed() && document.body.contains(el)
      DOM.debounce(el, event, phxDebounce, defaultDebounce, phxThrottle, defaultThrottle, asyncFilter, () => {
        callback()
      })
    })
  }

  silenceEvents(callback){
    this.silenced = true
    callback()
    this.silenced = false
  }

  on(event, callback){
    this.boundEventNames.add(event)
    window.addEventListener(event, e => {
      if(!this.silenced){ callback(e) }
    })
  }

  jsQuerySelectorAll(sourceEl, query, defaultQuery){
    let all = this.domCallbacks.jsQuerySelectorAll
    return all ? all(sourceEl, query, defaultQuery) : defaultQuery()
  }
}

class TransitionSet {
  constructor(){
    this.transitions = new Set()
    this.pendingOps = []
  }

  reset(){
    this.transitions.forEach(timer => {
      clearTimeout(timer)
      this.transitions.delete(timer)
    })
    this.flushPendingOps()
  }

  after(callback){
    if(this.size() === 0){
      callback()
    } else {
      this.pushPendingOp(callback)
    }
  }

  addTransition(time, onStart, onDone){
    onStart()
    let timer = setTimeout(() => {
      this.transitions.delete(timer)
      onDone()
      this.flushPendingOps()
    }, time)
    this.transitions.add(timer)
  }

  pushPendingOp(op){ this.pendingOps.push(op) }

  size(){ return this.transitions.size }

  flushPendingOps(){
    if(this.size() > 0){ return }
    let op = this.pendingOps.shift()
    if(op){
      op()
      this.flushPendingOps()
    }
  }
}
