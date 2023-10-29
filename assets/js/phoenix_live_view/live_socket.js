/**
 * Module dependencies
 * 
 * Phoenix:
 * @typedef {import('phoenix').Socket} Socket
 * @typedef {typeof import('phoenix').Socket} SocketCls
 * @typedef {import('phoenix').Channel} Channel
 * @typedef {import('phoenix').Push} Push
 * 
 * Local:
 * @typedef {import('./view_hook.js').default} ViewHook
 * @typedef {import('./view_hook.js').HookCallbacks} HookCallbacks
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
  PHX_FEEDBACK_FOR,
  RELOAD_JITTER_MIN,
  RELOAD_JITTER_MAX,
  PHX_REF,
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

export default class LiveSocket {
  /** Constructor - Initializes the LiveSocket
   *
   * @param {string} url - The WebSocket endpoint, ie, `"wss://example.com/live"`, `"/live"` (inherited host & protocol)
   * @param {SocketCls} phxSocket - The required Phoenix Socket class imported from "phoenix". For example:
   *
   *     import {Socket} from "phoenix"
   *     import {LiveSocket} from "phoenix_live_view"
   *     let liveSocket = new LiveSocket("/live", Socket, {...})
   * 
   * @param {Object} opts - Optional configuration. Outside of keys listed below, all
   * configuration is passed directly to the Phoenix Socket constructor.
   * 
   * @param {{debounce: number, throttle: number}} [opts.defaults] - The optional defaults to use for various bindings,
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
   * @param {{[key:string]: HookCallbacks}} [opts.hooks] - The optional object for referencing LiveView hook callbacks.
   * @param {{[key:string]: function}} [opts.uploaders] - The optional object for referencing LiveView uploader callbacks.
   * @param {integer} [opts.loaderTimeout] - The optional delay in milliseconds to wait before apply
   * loading states.
   * @param {integer} [opts.maxReloads] - The maximum reloads before entering failsafe mode.
   * @param {integer} [opts.reloadJitterMin] - The minimum time between normal reload attempts.
   * @param {integer} [opts.reloadJitterMax] - The maximum time between normal reload attempts.
   * @param {integer} [opts.failsafeJitter] - The time between reload attempts in failsafe mode.
   * @param {(view: View, kind: string, msg: string, obj: any) => void} [opts.viewLogger] - The optional function to log debug information. For example:
   *
   *     (view, kind, msg, obj) => console.log(`${view.id} ${kind}: ${msg} - `, obj)
   *
   * @param {{[key:string]: (e: Event, targetEl: Element) => any}} [opts.metadata] - The optional object mapping event names to functions for
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
    /** @type {{[key: string]: View}} */
    this.roots = {}
    this.href = window.location.href
    this.pendingLink = null
    this.currentLocation = clone(window.location)
    /** @type {{[key: string]: HookCallbacks}} */
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
    this.domCallbacks = Object.assign({onNodeAdded: closure(), onBeforeElUpdated: closure()}, opts.dom || {})
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

  /**
   * Is profiling mode enabled?
   * @returns {boolean}
   */
  isProfileEnabled(){ return this.sessionStorage.getItem(PHX_LV_PROFILE) === "true" }

  /**
   * Is debug mode enabled?
   * @returns {boolean}
   */
  isDebugEnabled(){ return this.sessionStorage.getItem(PHX_LV_DEBUG) === "true" }

  /**
   * Is debug mode disabled?
   * @returns {boolean}
   */
  isDebugDisabled(){ return this.sessionStorage.getItem(PHX_LV_DEBUG) === "false" }

  /**
   * Enable debug mode
   */
  enableDebug(){ this.sessionStorage.setItem(PHX_LV_DEBUG, "true") }

  /**
   * Enable profiling mode
   */
  enableProfiling(){ this.sessionStorage.setItem(PHX_LV_PROFILE, "true") }

  /**
   * Disable debug mode
   */
  disableDebug(){ this.sessionStorage.setItem(PHX_LV_DEBUG, "false") }

  /**
   * Disable profiling mode
   */
  disableProfiling(){ this.sessionStorage.removeItem(PHX_LV_PROFILE) }


  /**
   * Enable latency simulation mode
   * @param {number} upperBoundMs 
   */
  enableLatencySim(upperBoundMs){
    this.enableDebug()
    console.log("latency simulator enabled for the duration of this browser session. Call disableLatencySim() to disable")
    this.sessionStorage.setItem(PHX_LV_LATENCY_SIM, upperBoundMs)
  }

  /**
   * Disable latency simulation mode
   */
  disableLatencySim(){ this.sessionStorage.removeItem(PHX_LV_LATENCY_SIM) }

  /**
   * Get simulated latency value if set
   * @returns {number|null}
   */
  getLatencySim(){
    let str = this.sessionStorage.getItem(PHX_LV_LATENCY_SIM)
    return str ? parseInt(str) : null
  }

  /**
   * Get the underlying socket object
   */
  getSocket(){ return this.socket }

  /**
   * Connect on socket and join views
   */
  connect(){
    // enable debug by default if on localhost and not explicitly disabled
    if(window.location.hostname === "localhost" && !this.isDebugDisabled()){ this.enableDebug() }
    let doConnect = () => {
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

  /**
   * Disconnect
   * @param {() => void | Promise<void>} callback 
   */
  disconnect(callback){
    clearTimeout(this.reloadWithJitterTimer)
    this.socket.disconnect(callback)
  }

  /**
   * Replace socket transport object
   * @param {new(endpoint: string) => object} transport - Class/Constructor implementing transport interface
   */
  replaceTransport(transport){
    clearTimeout(this.reloadWithJitterTimer)
    this.socket.replaceTransport(transport)
    this.connect()
  }

  /**
   * Execute JS against element
   * @param {Element} el 
   * @param {string} encodedJS 
   * @param {string} [eventType] 
   */
  execJS(el, encodedJS, eventType = null){
    this.owner(el, view => JS.exec(eventType, encodedJS, view, el))
  }

  // private

  /**
   * @param {HTMLElement} el 
   * @param {string} phxEvent 
   * @param {object} data 
   * @param {() => void} callback 
   */
  execJSHookPush(el, phxEvent, data, callback){
    this.withinOwners(el, view => {
      JS.exec("hook", phxEvent, view, el, ["push", {data, callback}])
    })
  }

  /**
   * Disconnect socket, unload, and destroy all views
   */
  unload(){
    if(this.unloaded){ return }
    if(this.main && this.isConnected()){ this.log(this.main, "socket", () => ["disconnect for page nav"]) }
    this.unloaded = true
    this.destroyAllViews()
    this.disconnect()
  }

  /**
   * Run registered DOM callbacks matching kind
   * @param {string} kind 
   * @param {any[]} args 
   */
  triggerDOM(kind, args){ this.domCallbacks[kind](...args) }

  /**
   * Execute the given function in a timer and log to the console
   * @template T
   * @param {string} name 
   * @param {() => T} func 
   * @returns {T}
   */
  time(name, func){
    if(!this.isProfileEnabled() || !console.time){ return func() }
    console.time(name)
    let result = func()
    console.timeEnd(name)
    return result
  }

  /**
   * Debug log
   * @param {View} view 
   * @param {string} kind 
   * @param {() => [string, any]} msgCallback - only called if opt.viewLogger given or isDebugEnabled
   */
  log(view, kind, msgCallback){
    if(this.viewLogger){
      let [msg, obj] = msgCallback()
      this.viewLogger(view, kind, msg, obj)
    } else if(this.isDebugEnabled()){
      let [msg, obj] = msgCallback()
      debug(view, kind, msg, obj)
    }
  }

  /**
   * Execute callback after next DOM update transition finishes
   * @param {() => void} callback 
   */
  requestDOMUpdate(callback){
    this.transitions.after(callback)
  }

  /**
   * Add a managed transition
   * @param {number} time 
   * @param {() => void} onStart 
   * @param {() => void} [onDone] 
   */
  transition(time, onStart, onDone = function(){}){
    this.transitions.addTransition(time, onStart, onDone)
  }

  /**
   * Subscribe to event on channel
   * @param {Channel} channel - channel to listen on 
   * @param {string} event - event to listen for
   * @param {(response?: object) => void} cb - callback to invoke on each event
   */
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

  /**
   * Wrap Channel Push with additional management behavior
   * @param {View} view 
   * @param {{timeout: boolean}} opts 
   * @param {() => Push} push 
   * @returns {Push}
   */
  wrapPush(view, opts, push){
    let latency = this.getLatencySim()
    let oldJoinCount = view.joinCount
    if(!latency){
      if(this.isConnected() && opts.timeout){
        return push().receive("timeout", () => {
          if(view.joinCount === oldJoinCount && !view.isDestroyed()){
            this.reloadWithJitter(view, () => {
              this.log(view, "timeout", () => ["received timeout while communicating with server. Falling back to hard refresh for recovery"])
            })
          }
        })
      } else {
        return push()
      }
    }

    let fakePush = {
      receives: [],
      receive(kind, cb){ this.receives.push([kind, cb]) }
    }
    setTimeout(() => {
      if(view.isDestroyed()){ return }
      fakePush.receives.reduce((acc, [kind, cb]) => acc.receive(kind, cb), push())
    }, latency)
    return fakePush
  }

  /**
   * Reload page with simulated network jitter
   * @param {View} view 
   * @param {() => void} [log] 
   */
  reloadWithJitter(view, log){
    clearTimeout(this.reloadWithJitterTimer)
    this.disconnect()
    let minMs = this.reloadJitterMin
    let maxMs = this.reloadJitterMax
    let afterMs = Math.floor(Math.random() * (maxMs - minMs + 1)) + minMs
    let tries = Browser.updateLocal(this.localStorage, window.location.pathname, CONSECUTIVE_RELOADS, 0, count => count + 1)
    if(tries > this.maxReloads){
      afterMs = this.failsafeJitter
    }
    this.reloadWithJitterTimer = setTimeout(() => {
      // if view has recovered, such as transport replaced, then cancel
      if(view.isDestroyed() || view.isConnected()){ return }
      view.destroy()
      log ? log() : this.log(view, "join", () => [`encountered ${tries} consecutive reloads`])
      if(tries > this.maxReloads){
        this.log(view, "join", () => [`exceeded ${this.maxReloads} consecutive reloads. Entering failsafe mode`])
      }
      if(this.hasPendingLink()){
        window.location = this.pendingLink
      } else {
        window.location.reload()
      }
    }, afterMs)
  }

  /**
   * Lookup hook
   * @param {string} [name] 
   * @returns {HookCallbacks|undefined}
   */
  getHookCallbacks(name){
    return name && name.startsWith("Phoenix.") ? Hooks[name.split(".")[1]] : this.hooks[name]
  }

  /**
   * Is the socket unloaded?
   * @returns {boolean}
   */
  isUnloaded(){ return this.unloaded }

  /**
   * Is the socket connected?
   * @returns {boolean}
   */
  isConnected(){ return this.socket.isConnected() }

  /**
   * Get the prefix for attribute bindings
   * @returns {string}
   */
  getBindingPrefix(){ return this.bindingPrefix }

  /**
   * Create prefixed binding name
   * @param {string} kind 
   * @returns {string}
   */
  binding(kind){ return `${this.getBindingPrefix()}${kind}` }

  /**
   * Get socket channel for this topic
   * @param {string} topic 
   * @param {object} [params] 
   * @returns {Channel}
   */
  channel(topic, params){ return this.socket.channel(topic, params) }

  /**
   * If no live root views, join the dead views
   */
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

  /**
   * Find all root views and join()
   * @returns {boolean} were root views found?
   */
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

  /**
   * Execute browser redirect
   * @param {string} to 
   * @param {string|null} flash 
   */
  redirect(to, flash){
    this.unload()
    Browser.redirect(to, flash)
  }

  /**
   * Replace a new root view and main element
   * @param {string} href 
   * @param {string|null} flash 
   * @param {(linkRef: number) => void} [callback] 
   * @param {number} [linkRef] 
   */
  replaceMain(href, flash, callback = null, linkRef = this.setPendingLink(href)){
    let liveReferer = this.currentLocation.href
    this.outgoingMainEl = this.outgoingMainEl || this.main.el
    let newMainEl = DOM.cloneNode(this.outgoingMainEl, "")
    this.main.showLoader(this.loaderTimeout)
    this.main.destroy()

    this.main = this.newRootView(newMainEl, flash, liveReferer)
    this.main.setRedirect(href)
    this.transitionRemoves()
    this.main.join((joinCount, onDone) => {
      if(joinCount === 1 && this.commitPendingLink(linkRef)){
        this.requestDOMUpdate(() => {
          DOM.findPhxSticky(document).forEach(el => newMainEl.appendChild(el))
          this.outgoingMainEl.replaceWith(newMainEl)
          this.outgoingMainEl = null
          callback && requestAnimationFrame(() => callback(linkRef))
          onDone()
        })
      }
    })
  }

  /**
   * Dispatch remove JS events for given elements or elements with "remove" binding
   * @param {Element[]} [elements] 
   */
  transitionRemoves(elements){
    let removeAttr = this.binding("remove")
    elements = elements || DOM.all(document, `[${removeAttr}]`)
    elements.forEach(el => {
      this.execJS(el, el.getAttribute(removeAttr), "remove")
    })
  }

  /**
   * Is element part of a view?
   * @param {Element} el 
   * @returns {boolean}
   */
  isPhxView(el){ return el.getAttribute && el.getAttribute(PHX_SESSION) !== null }

  /**
   * Create a root view
   * @param {HTMLElement} el 
   * @param {*} flash 
   * @param {string} liveReferer - URL of location that initiated the new view
   * @returns {View}
   */
  newRootView(el, flash, liveReferer){
    let view = new View(el, this, null, flash, liveReferer)
    this.roots[view.id] = view
    return view
  }

  /**
   * Run callback with owning View
   * @param {HTMLElement} childEl 
   * @param {(view: View) => void} callback 
   */
  owner(childEl, callback){
    let view = maybe(childEl.closest(PHX_VIEW_SELECTOR), el => this.getViewByEl(el)) || this.main
    if(view){ callback(view) }
  }

  /**
   * Execute callback for view owning given element
   * @template {HTMLElement} T
   * @param {T} childEl 
   * @param {(view: View, childEl: T) => void} callback 
   */
  withinOwners(childEl, callback){
    this.owner(childEl, view => callback(view, childEl))
  }

  /**
   * Get view owning the element
   * @param {Element} el 
   * @returns {View}
   */
  getViewByEl(el){
    let rootId = el.getAttribute(PHX_ROOT_ID)
    return maybe(this.getRootById(rootId), root => root.getDescendentByEl(el))
  }

  /**
   * Get root view by ID
   * @param {string} id 
   * @returns {View}
   */
  getRootById(id){ return this.roots[id] }

  /**
   * Destroy all root views
   */
  destroyAllViews(){
    for(let id in this.roots){
      this.roots[id].destroy()
      delete this.roots[id]
    }
    this.main = null
  }

  /**
   * Destroy root view for element
   * @param {Element} el 
   */
  destroyViewByEl(el){
    let root = this.getRootById(el.getAttribute(PHX_ROOT_ID))
    if(root && root.id === el.id){
      root.destroy()
      delete this.roots[root.id]
    } else if(root){
      root.destroyDescendent(el.id)
    }
  }

  /**
   * Set target as the new active element
   * @param {Element} target 
   */
  setActiveElement(target){
    if(this.activeElement === target){ return }
    this.activeElement = target
    let cancel = () => {
      if(target === this.activeElement){ this.activeElement = null }
      target.removeEventListener("mouseup", this)
      target.removeEventListener("touchend", this)
    }
    target.addEventListener("mouseup", cancel)
    target.addEventListener("touchend", cancel)
  }

  /**
   * Get document's active element
   * @returns {Element}
   */
  getActiveElement(){
    if(document.activeElement === document.body){
      return this.activeElement || document.activeElement
    } else {
      // document.activeElement can be null in Internet Explorer 11
      return document.activeElement || document.body
    }
  }

  /**
   * Unset the existing active element if it's owned by given view
   * @param {View} view 
   */
  dropActiveElement(view){
    if(this.prevActive && view.ownsElement(this.prevActive)){
      this.prevActive = null
    }
  }

  /**
   * Restore focus to the previously active element
   */
  restorePreviouslyActiveFocus(){
    if(this.prevActive && this.prevActive !== document.body){
      this.prevActive.focus()
    }
  }

  /**
   * Blur the active element after tracking it for potential future focus
   * restore.
   */
  blurActiveElement(){
    this.prevActive = this.getActiveElement()
    if(this.prevActive !== document.body){ this.prevActive.blur() }
  }

  /**
   * @param {{dead?: boolean}} args 
   */
  bindTopLevelEvents({dead} = {}){
    if(this.boundTopLevelEvents){ return }

    this.boundTopLevelEvents = true
    // enter failsafe reload if server has gone away intentionally, such as "disconnect" broadcast
    this.socket.onClose(event => {
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
    this.bind({keyup: "keyup", keydown: "keydown"}, (e, type, view, targetEl, phxEvent, _eventTarget) => {
      let matchKey = targetEl.getAttribute(this.binding(PHX_KEY))
      let pressedKey = e.key && e.key.toLowerCase() // chrome clicked autocompletes send a keydown without key
      if(matchKey && matchKey.toLowerCase() !== pressedKey){ return }

      let data = {key: e.key, ...this.eventMeta(type, e, targetEl)}
      JS.exec(type, phxEvent, view, targetEl, ["push", {data}])
    })
    this.bind({blur: "focusout", focus: "focusin"}, (e, type, view, targetEl, phxEvent, eventTarget) => {
      if(!eventTarget){
        let data = {key: e.key, ...this.eventMeta(type, e, targetEl)}
        JS.exec(type, phxEvent, view, targetEl, ["push", {data}])
      }
    })
    this.bind({blur: "blur", focus: "focus"}, (e, type, view, targetEl, targetCtx, phxEvent, phxTarget) => {
      // blur and focus are triggered on document and window. Discard one to avoid dups
      if(phxTarget === "window"){
        let data = this.eventMeta(type, e, targetEl)
        JS.exec(type, phxEvent, view, targetEl, ["push", {data}])
      }
    })
    window.addEventListener("dragover", e => e.preventDefault())
    window.addEventListener("drop", e => {
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

  /**
   * @param {string} eventName 
   * @param {Event} e 
   * @param {Element} targetEl 
   * @returns {object}
   */
  eventMeta(eventName, e, targetEl){
    let callback = this.metadataCallbacks[eventName]
    return callback ? callback(e, targetEl) : {}
  }

  /**
   * @param {string} href 
   * @returns {number}
   */
  setPendingLink(href){
    this.linkRef++
    this.pendingLink = href
    return this.linkRef
  }

  /**
   * @param {number} linkRef 
   * @returns {boolean}
   */
  commitPendingLink(linkRef){
    if(this.linkRef !== linkRef){
      return false
    } else {
      this.href = this.pendingLink
      this.pendingLink = null
      return true
    }
  }

  /**
   * @returns {string}
   */
  getHref(){ return this.href }

  /**
   * @returns {boolean}
   */
  hasPendingLink(){ return !!this.pendingLink }

  /**
   * Bind handler to multiple browser events
   * @param {{[key:string]: string}} events 
   * @param {(e: Event, eventType: string, view: View, targetEl: Element, phxEvent: string, eventTarget: Element) => void} callback 
   */
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

  /**
   * Bind to all window click events to dispatch internally
   */
  bindClicks(){
    window.addEventListener("click", e => this.clickStartedAtTarget = e.target)
    this.bindClick("click", "click", false)
    this.bindClick("mousedown", "capture-click", true)
  }

  /**
   * @param {string} eventName 
   * @param {string} bindingName 
   * @param {boolean} capture 
   */
  bindClick(eventName, bindingName, capture){
    let click = this.binding(bindingName)
    window.addEventListener(eventName, e => {
      let target = null
      if(capture){
        target = e.target.matches(`[${click}]`) ? e.target : e.target.querySelector(`[${click}]`)
      } else {
        let clickStartedAtTarget = this.clickStartedAtTarget || e.target
        target = closestPhxBinding(clickStartedAtTarget, click)
        this.dispatchClickAway(e, clickStartedAtTarget)
        this.clickStartedAtTarget = null
      }
      let phxEvent = target && target.getAttribute(click)
      if(!phxEvent){
        if(!capture && DOM.isNewPageClick(e, window.location)){ this.unload() }
        return
      }

      if(target.getAttribute("href") === "#"){ e.preventDefault() }

      // noop if we are in the middle of awaiting an ack for this el already
      if(target.hasAttribute(PHX_REF)){ return }

      this.debounce(target, e, "click", () => {
        this.withinOwners(target, view => {
          JS.exec("click", phxEvent, view, target, ["push", {data: this.eventMeta("click", e, target)}])
        })
      })
    }, capture)
  }

  /**
   * Dispatch click-away events
   * @param {Event} e 
   * @param {Element} clickStartedAt 
   */
  dispatchClickAway(e, clickStartedAt){
    let phxClickAway = this.binding("click-away")
    DOM.all(document, `[${phxClickAway}]`, el => {
      if(!(el.isSameNode(clickStartedAt) || el.contains(clickStartedAt))){
        this.withinOwners(e.target, view => {
          let phxEvent = el.getAttribute(phxClickAway)
          if(JS.isVisible(el)){
            JS.exec("click", phxEvent, view, el, ["push", {data: this.eventMeta("click", e, e.target)}])
          }
        })
      }
    })
  }

  /**
   * Bind navigation events to dispatch internally
   * 
   * NOTE: tracking scrolls to restore scroll when necessary
   */
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
          this.main.pushLinkPatch(href, null, () => {
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

      let href = target.href
      let linkState = target.getAttribute(PHX_LINK_STATE)
      e.preventDefault()
      e.stopImmediatePropagation() // do not bubble click to regular phx-click bindings
      if(this.pendingLink === href){ return }

      this.requestDOMUpdate(() => {
        if(type === "patch"){
          this.pushHistoryPatch(href, linkState, target)
        } else if(type === "redirect"){
          this.historyRedirect(href, linkState)
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

  /**
   * Scroll if value given
   * @param {number} [scroll] 
   */
  maybeScroll(scroll){
    if(typeof(scroll) === "number"){
      requestAnimationFrame(() => {
        window.scrollTo(0, scroll)
      }) // the body needs to render before we scroll.
    }
  }

  /**
   * Dispatch event on window
   * @param {string} event 
   * @param {any} [payload] 
   */
  dispatchEvent(event, payload = {}){
    DOM.dispatchEvent(window, `phx:${event}`, {detail: payload})
  }

  /**
   * Dispatch each event on window
   * @param {[eventName: string, payload: any][]} events 
   */
  dispatchEvents(events){
    events.forEach(([event, payload]) => this.dispatchEvent(event, payload))
  }

  /**
   * Dispatch phx:page-loading-start and return callback to end loading
   * @template T
   * @param {any} [info] - optional data to provide in event detail
   * @param {(stopLoadingCb: ()=>void) => T} [callback] - if given, call with callback that dispatches stop-loading event
   * @returns {T|()=>void} either a callback to dispatch stop-loading event, or result of callback if given
   */
  withPageLoading(info, callback){
    DOM.dispatchEvent(window, "phx:page-loading-start", {detail: info})
    let done = () => DOM.dispatchEvent(window, "phx:page-loading-stop", {detail: info})
    return callback ? callback(done) : done
  }

  /**
   * Push a location history patch
   * @param {string} href 
   * @param {("push"|"replace")} linkState 
   * @param {HTMLElement} targetEl 
   */
  pushHistoryPatch(href, linkState, targetEl){
    if(!this.isConnected()){ return Browser.redirect(href) }

    this.withPageLoading({to: href, kind: "patch"}, done => {
      this.main.pushLinkPatch(href, targetEl, linkRef => {
        this.historyPatch(href, linkState, linkRef)
        done()
      })
    })
  }

  /**
   * Perform browser history update for patching
   * @param {string} href 
   * @param {("push"|"replace")} linkState 
   * @param {number} linkRef 
   */
  historyPatch(href, linkState, linkRef = this.setPendingLink(href)){
    if(!this.commitPendingLink(linkRef)){ return }

    Browser.pushState(linkState, {type: "patch", id: this.main.id}, href)
    DOM.dispatchEvent(window, "phx:navigate", {detail: {patch: true, href, pop: false}})
    this.registerNewLocation(window.location)
  }

  /**
   * Perform browser history update for redirect
   * @param {string} href 
   * @param {("push"|"replace")} linkState 
   * @param {string|null} flash 
   */
  historyRedirect(href, linkState, flash){
    // convert to full href if only path prefix
    if(!this.isConnected()){ return Browser.redirect(href, flash) }
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

  /**
   * Replace root in browser history state
   */
  replaceRootHistory(){
    Browser.pushState("replace", {root: true, type: "patch", id: this.main.id})
  }

  /**
   * Set new location as current location
   * @param {Location} newLocation 
   * @returns {boolean}
   */
  registerNewLocation(newLocation){
    let {pathname, search} = this.currentLocation
    if(pathname + search === newLocation.pathname + newLocation.search){
      return false
    } else {
      this.currentLocation = clone(newLocation)
      return true
    }
  }

  /**
   * Bind Forms
   */
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
    }, true)

    this.on("submit", e => {
      let phxEvent = e.target.getAttribute(this.binding("submit"))
      if(!phxEvent){
        if(DOM.isUnloadableFormSubmit(e)){ this.unload() }
        return
      }
      e.preventDefault()
      e.target.disabled = true
      this.withinOwners(e.target, view => {
        JS.exec("submit", phxEvent, view, e.target, ["push", {submitter: e.submitter}])
      })
    }, false)

    for(let type of ["change", "input"]){
      this.on(type, e => {
        let phxChange = this.binding("change")
        let input = e.target
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
            if(!DOM.isTextualInput(input)){
              this.setActiveElement(input)
            }
            JS.exec("change", phxEvent, view, input, ["push", {_target: e.target.name, dispatcher: dispatcher}])
          })
        })
      }, false)
    }
    this.on("reset", (e) => {
      let form = e.target
      DOM.resetForm(form, this.binding(PHX_FEEDBACK_FOR))
      let input = Array.from(form.elements).find(el => el.type === "reset")
      // wait until next tick to get updated input value
      window.requestAnimationFrame(() => {
        input.dispatchEvent(new Event("input", {bubbles: true, cancelable: false}))
      })
    })
  }

  /**
   * @private
   * @param {Element} el 
   * @param {Event} event 
   * @param {string} eventType 
   * @param {string} callback 
   */
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

  /**
   * Disable event listeners, execute callback, enable event listeners
   * @param {() => void} callback 
   */
  silenceEvents(callback){
    this.silenced = true
    callback()
    this.silenced = false
  }

  /**
   * Attach handler for event
   * @param {string} event 
   * @param {(e: Event) => void} callback 
   */
  on(event, callback){
    window.addEventListener(event, e => {
      if(!this.silenced){ callback(e) }
    })
  }
}

class TransitionSet {
  constructor(){
    /** @type {Set<number>} @private */
    this.transitions = new Set()
    /** @type {function[]} */
    this.pendingOps = []
  }

  /**
   * Clear all transitions and flush any pending operations
   */
  reset(){
    this.transitions.forEach(timer => {
      clearTimeout(timer)
      this.transitions.delete(timer)
    })
    this.flushPendingOps()
  }

  /**
   * Register given callback for execution after next transition finishes.
   * Executes immediately if no transition is in-flight.
   * @param {() => void} callback 
   */
  after(callback){
    if(this.size() === 0){
      callback()
    } else {
      this.pushPendingOp(callback)
    }
  }

  /**
   * Add a transition.
   * @param {number} time 
   * @param {() => void} onStart 
   * @param {() => void} onDone 
   */
  addTransition(time, onStart, onDone){
    onStart()
    let timer = setTimeout(() => {
      this.transitions.delete(timer)
      onDone()
      this.flushPendingOps()
    }, time)
    this.transitions.add(timer)
  }

  /**
   * Register operation for execution after next transition
   * @private
   * @param {() => void} op 
   */
  pushPendingOp(op){ this.pendingOps.push(op) }

  /**
   * Get the size of current transition set.
   * @returns {number}
   */
  size(){ return this.transitions.size }

  /**
   * Execute all registered pending operations
   * @private
   */
  flushPendingOps(){
    if(this.size() > 0){ return }
    let op = this.pendingOps.shift()
    if(op){
      op()
      this.flushPendingOps()
    }
  }
}
