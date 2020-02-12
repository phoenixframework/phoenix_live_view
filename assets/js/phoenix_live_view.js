/*
================================================================================
Phoenix LiveView JavaScript Client
================================================================================

See the hexdocs at `https://hexdocs.pm/phoenix_live_view` for documentation.

*/

import morphdom from "morphdom"

const CLIENT_OUTDATED = "outdated"
const JOIN_CRASHED = "join crashed"
const CONSECUTIVE_RELOADS = "consecutive-reloads"
const MAX_RELOADS = 10
const RELOAD_JITTER = [1000, 3000]
const FAILSAFE_JITTER = 30000
const PHX_VIEW = "data-phx-view"
const PHX_COMPONENT = "data-phx-component"
const PHX_LIVE_LINK = "data-phx-link"
const PHX_LINK_STATE = "data-phx-link-state"
const PHX_CONNECTED_CLASS = "phx-connected"
const PHX_LOADING_CLASS = "phx-loading"
const PHX_DISCONNECTED_CLASS = "phx-disconnected"
const PHX_ERROR_CLASS = "phx-error"
const PHX_PARENT_ID = "data-phx-parent-id"
const PHX_VIEW_SELECTOR = `[${PHX_VIEW}]`
const PHX_MAIN_VIEW_SELECTOR = `[data-phx-main=true]`
const PHX_ERROR_FOR = "data-phx-error-for"
const PHX_HAS_FOCUSED = "phx-has-focused"
const FOCUSABLE_INPUTS = ["text", "textarea", "number", "email", "password", "search", "tel", "url"]
const PHX_HAS_SUBMITTED = "phx-has-submitted"
const PHX_SESSION = "data-phx-session"
const PHX_STATIC = "data-phx-static"
const PHX_READONLY = "data-phx-readonly"
const PHX_DISABLED = "data-phx-disabled"
const PHX_DISABLE_WITH = "disable-with"
const PHX_HOOK = "hook"
const PHX_DEBOUNCE = "debounce"
const PHX_THROTTLE = "throttle"
const PHX_CHANGE_EVENT = "phx-change"
const PHX_UPDATE = "update"
const PHX_KEY = "key"
const PHX_PRIVATE = "phxPrivate"
const PHX_AUTO_RECOVER = "auto-recover"
const LOADER_TIMEOUT = 1
const BEFORE_UNLOAD_LOADER_TIMEOUT = 200
const BINDING_PREFIX = "phx-"
const PUSH_TIMEOUT = 30000
const LINK_HEADER = "x-requested-with"
const DEBOUNCE_BLUR = "debounce-blur"
const DEBOUNCE_TIMER = "debounce-timer"
const DEBOUNCE_PREV_KEY = "debounce-prev-key"
// Rendered
const DYNAMICS = "d"
const STATIC = "s"
const COMPONENTS = "c"

let DEBUG = process.env.NODE_ENV !== 'production';
let logError = (msg, obj) => console.error && console.error(msg, obj)

function detectDuplicateIds() {
  let ids = new Set()
  let elems = document.querySelectorAll('*[id]')
  for (let i = 0, len = elems.length; i < len; i++) {
    if (ids.has(elems[i].id)) {
      console.error(`Multiple IDs detected: ${elems[i].id}. Ensure unique element ids.`)
    } else {
      ids.add(elems[i].id)
    }
  }
}

export let debug = (view, kind, msg, obj) => {
  if (DEBUG) {
    console.log(`${view.id} ${kind}: ${msg} - `, obj)
  }
}

// wraps value in closure or returns closure
let closure = (val) => typeof val === "function" ? val : function(){ return val }

let clone = (obj) => { return JSON.parse(JSON.stringify(obj)) }

let closestPhxBinding = (el, binding) => {
  do {
    if(el.matches(`[${binding}]`)){ return el }
    el = el.parentElement || el.parentNode
  } while(el !== null && el.nodeType === 1 && !el.matches(PHX_VIEW_SELECTOR))
  return null
}

let isObject = (obj) => {
  return obj !== null && typeof obj === "object" && !(obj instanceof Array)
}

let isEmpty = (obj) => {
  for (let x in obj){ return false }
  return true
}

let maybe = (el, callback) => el && callback(el)

let serializeForm = (form, meta = {}) => {
  let formData = new FormData(form)
  let params = new URLSearchParams()
  for(let [key, val] of formData.entries()){ params.append(key, val) }
  for(let metaKey in meta){ params.append(metaKey, meta[metaKey]) }

  return params.toString()
}

let recursiveMerge = (target, source) => {
  for(let key in source){
    let val = source[key]
    let targetVal = target[key]
    if(isObject(val) && isObject(targetVal)){
      if(targetVal[DYNAMICS] && !val[DYNAMICS]){ delete targetVal[DYNAMICS] }
      recursiveMerge(targetVal, val)
    } else {
      target[key] = val
    }
  }
}

export let Rendered = {
  mergeDiff(source, diff){
    if(!diff[COMPONENTS] && this.isNewFingerprint(diff)){
      return diff
    } else {
      recursiveMerge(source, diff)
      return source
    }
  },

  isNewFingerprint(diff = {}){ return !!diff[STATIC] },

  componentToString(components, cid){
    let component = components[cid] || logError(`no component for CID ${cid}`, components)
    let template = document.createElement("template")
    template.innerHTML = this.toString(component, components)
    let container = template.content
    Array.from(container.childNodes).forEach(child => {
      if(child.nodeType === Node.ELEMENT_NODE){
        child.setAttribute(PHX_COMPONENT, cid)
      } else {
        if(child.nodeValue.trim() !== ""){
          logError(`only HTML element tags are allowed at the root of components.\n\n` +
                   `got: "${child.nodeValue.trim()}"\n\n` +
                   `within:\n`, template.innerHTML.trim())

          let span = document.createElement("span")
          span.innerText = child.nodeValue
          span.setAttribute(PHX_COMPONENT, cid)
          child.replaceWith(span)
        } else {
          child.remove()
        }
      }
    })

    return template.innerHTML
  },


  toString(rendered, components = rendered[COMPONENTS] || {}){
    let output = {buffer: "", components: components}
    this.toOutputBuffer(rendered, output)
    return output.buffer
  },

  toOutputBuffer(rendered, output){
    if(rendered[DYNAMICS]){ return this.comprehensionToBuffer(rendered, output) }
    let {[STATIC]: statics} = rendered

    output.buffer += statics[0]
    for(let i = 1; i < statics.length; i++){
      this.dynamicToBuffer(rendered[i - 1], output)
      output.buffer += statics[i]
    }
  },

  comprehensionToBuffer(rendered, output){
    let {[DYNAMICS]: dynamics, [STATIC]: statics} = rendered

    for(let d = 0; d < dynamics.length; d++){
      let dynamic = dynamics[d]
      output.buffer += statics[0]
      for(let i = 1; i < statics.length; i++){
        this.dynamicToBuffer(dynamic[i - 1], output)
        output.buffer += statics[i]
      }
    }
  },

  dynamicToBuffer(rendered, output){
    if(typeof(rendered) === "number"){
      output.buffer += this.componentToString(output.components, rendered)
   } else if(isObject(rendered)){
      this.toOutputBuffer(rendered, output)
    } else {
      output.buffer += rendered
    }
  },

  pruneCIDs(rendered, cids){
    cids.forEach(cid => delete rendered[COMPONENTS][cid])
    return rendered
  }
}

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
 * @param {Function} [opts.params] - The optional function for passing connect params.
 * The function receives the viewName associated with a given LiveView. For example:
 *
 *     (viewName) => {view: viewName, token: window.myToken}
 *
 * @param {string} [opts.bindingPrefix] - The optional prefix to use for all phx DOM annotations.
 * Defaults to "phx-".
 * @param {string} [opts.hooks] - The optional object for referencing LiveView hook callbacks.
 * @param {integer} [opts.loaderTimeout] - The optional delay in milliseconds to wait before apply
 * loading states.
 * @param {Function} [opts.viewLogger] - The optional function to log debug information. For example:
 *
 *     (view, kind, msg, obj) => console.log(`${view.id} ${kind}: ${msg} - `, obj)
*/
export class LiveSocket {
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
    this.views = {}
    this.params = closure(opts.params || {})
    this.viewLogger = opts.viewLogger
    this.activeElement = null
    this.prevActive = null
    this.prevInput = null
    this.prevValue = null
    this.silenced = false
    this.root = null
    this.main = null
    this.linkRef = 0
    this.href = window.location.href
    this.pendingLink = null
    this.currentLocation = clone(window.location)
    this.hooks = opts.hooks || {}
    this.loaderTimeout = opts.loaderTimeout || LOADER_TIMEOUT

    this.socket.onOpen(() => {
      if(this.isUnloaded()){
        this.destroyAllViews()
        this.joinRootViews()
        this.detectMainView()
      }
      this.unloaded = false
    })
    window.addEventListener("unload", e => {
      this.unloaded = true
    })
    this.bindTopLevelEvents()
  }

  getSocket(){ return this.socket }

  log(view, kind, msgCallback){
    if(this.viewLogger){
      let [msg, obj] = msgCallback()
      this.viewLogger(view, kind, msg, obj)
    }
  }

  connect(){
    if(["complete", "loaded","interactive"].indexOf(document.readyState) >= 0){
      this.joinRootViews()
      this.detectMainView()
    } else {
      document.addEventListener("DOMContentLoaded", () => {
        this.joinRootViews()
        this.detectMainView()
      })
    }
    return this.socket.connect()
  }

  disconnect(){ this.socket.disconnect() }

  // private

  reloadWithJitter(view){
    this.disconnect()
    let [minMs, maxMs] = RELOAD_JITTER
    let afterMs = Math.floor(Math.random() * (maxMs - minMs + 1)) + minMs
    let tries = Browser.updateLocal(view.name(), CONSECUTIVE_RELOADS, 0, count => count + 1)
    this.log(view, "join", () => [`ecountered ${tries} consecutive reloads`])
    if(tries > MAX_RELOADS){
      this.log(view, "join", () => [`exceeded ${MAX_RELOADS} consecutive reloads. Entering failsafe mode`])
      afterMs = FAILSAFE_JITTER
    }
    setTimeout(() => window.location.reload(), afterMs)
  }

  getHookCallbacks(hookName){ return this.hooks[hookName] }

  isUnloaded(){ return this.unloaded }

  isConnected(){ return this.socket.isConnected() }

  getBindingPrefix(){ return this.bindingPrefix }

  binding(kind){ return `${this.getBindingPrefix()}${kind}` }

  channel(topic, params){ return this.socket.channel(topic, params) }

  joinRootViews(){
    DOM.all(document, `${PHX_VIEW_SELECTOR}:not([${PHX_PARENT_ID}])`, rootEl => {
      let view = this.joinView(rootEl, null, this.getHref())
      this.root = this.root || view
    })
  }

  detectMainView(){
    DOM.all(document, `${PHX_MAIN_VIEW_SELECTOR}`, el => {
      let hasPreviousMain = !!this.main
      let main = this.getViewByEl(el)
      if(main) {
        this.main = main
        if(!hasPreviousMain){ this.replaceRootHistory() }
      }
    })
  }

  replaceMain(href, flash, callback = null, linkRef = this.setPendingLink(href)){
    let mainEl = this.main.el
    let mainID = this.main.id
    this.destroyAllViews()
    this.main.showLoader(this.loaderTimeout)

    Browser.fetchPage(href, (status, html) => {
      if(status !== 200){ return Browser.redirect(href) }

      let template = document.createElement("template")
      template.innerHTML = html
      let el = template.content.childNodes[0]
      if(!el || !this.isPhxView(el)){ return Browser.redirect(href) }

      this.joinView(el, null, href, flash, newMain => {
        if(!this.commitPendingLink(linkRef)){
          newMain.destroy()
          return
        }
        this.destroyViewById(mainID)
        mainEl.replaceWith(newMain.el)
        this.main = newMain
        this.main.showLoader()
        callback && callback()
      })
    })
  }

  isPhxView(el){ return el.getAttribute && el.getAttribute(PHX_VIEW) !== null }

  joinView(el, parentView, href, flash, callback){
    if(this.getViewByEl(el)){ return }

    let view = new View(el, this, parentView, href, flash)
    this.views[view.id] = view
    view.join(callback)
    return view
  }

  owner(childEl, callback){
    let view = maybe(childEl.closest(PHX_VIEW_SELECTOR), el => this.getViewByEl(el))
    if(view){ callback(view) }
  }

  withinTargets(phxTarget, callback){
    let targetChildren = Array.from(document.querySelectorAll(phxTarget))
    if(targetChildren.length > 0){
      targetChildren.forEach(targetEl => {
        this.owner(targetEl, view => callback(view, targetEl))
      })
    } else {
      throw new Error(`no phx-target's found matching selector "${phxTarget}"`)
    }
  }

  withinOwners(childEl, callback){
    let phxTarget = childEl.getAttribute(this.binding("target"))
    if(phxTarget === null){
      this.owner(childEl, view => callback(view, childEl))
    } else {
      this.withinTargets(phxTarget, callback)
    }
  }

  getViewByEl(el){ return this.getViewById(el.id) }

  getViewById(id){ return this.views[id] }

  onViewError(view){
    this.dropActiveElement(view)
  }

  destroyAllViews(){
    for(let id in this.views){ this.destroyViewById(id) }
  }

  destroyViewByEl(el){ return this.destroyViewById(el.id) }

  destroyViewById(id){
    let view = this.views[id]
    if(view){
      delete this.views[view.id]
      if(this.root && view.id === this.root.id){ this.root = null }
      view.destroy()
    }
  }

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

  getActiveElement(){
    if(document.activeElement === document.body){
      return this.activeElement || document.activeElement
    } else {
      return document.activeElement
    }
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

  bindTopLevelEvents(){
    this.bindClicks()
    this.bindNav()
    this.bindForms()
    this.bind({keyup: "keyup", keydown: "keydown"}, (e, type, view, target, targetCtx, phxEvent, phxTarget) => {
      let matchKey = target.getAttribute(this.binding(PHX_KEY))
      if(matchKey && matchKey.toLowerCase() !== e.key.toLowerCase()){ return }

      view.pushKey(target, targetCtx, type, phxEvent, {
        altGraphKey: e.altGraphKey,
        altKey: e.altKey,
        charCode: e.charCode,
        code: e.code,
        ctrlKey: e.ctrlKey,
        key: e.key,
        keyCode: e.keyCode,
        keyIdentifier: e.keyIdentifier,
        keyLocation: e.keyLocation,
        location: e.location,
        metaKey: e.metaKey,
        repeat: e.repeat,
        shiftKey: e.shiftKey,
        which: e.which
      })
    })
    this.bind({blur: "focusout", focus: "focusin"}, (e, type, view, targetEl, targetCtx, phxEvent, phxTarget) => {
      if(!phxTarget){
        view.pushEvent(type, targetEl, targetCtx, phxEvent, {type: type})
      }
    })
    this.bind({blur: "blur", focus: "focus"}, (e, type, view, targetEl, targetCtx, phxEvent, phxTarget) => {
      // blur and focus are triggered on document and window. Discard one to avoid dups
      if(phxTarget && !phxTarget !== "window"){
        view.pushEvent(type, targetEl, targetCtx, phxEvent, {type: e.type})
      }
    })

  }

  setPendingLink(href){
    this.linkRef++
    let ref = this.linkRef
    this.pendingLink = href
    return this.linkRef
  }

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
          this.debounce(e.target, e, () => {
            this.withinOwners(e.target, (view, targetCtx) => {
              callback(e, event, view, e.target, targetCtx, targetPhxEvent, null)
            })
          })
        } else {
          DOM.all(document, `[${windowBinding}]`, el => {
            let phxEvent = el.getAttribute(windowBinding)
            this.debounce(el, e, () => {
              this.withinOwners(el, (view, targetCtx) => {
                callback(e, event, view, el, targetCtx, phxEvent, "window")
              })
            })
          })
        }
      })
    }
  }

  bindClicks(){
    [true, false].forEach(capture => {
      let click = capture ? this.binding("capture-click") : this.binding("click")
      window.addEventListener("click", e => {
        let target = null
        if(capture){
          target = e.target.matches(`[${click}]`) ? e.target : e.target.querySelector(`[${click}]`)
        } else {
          target = closestPhxBinding(e.target, click)
        }
        let phxEvent = target && target.getAttribute(click)
        if(!phxEvent){ return }
        if(target.getAttribute("href") === "#"){ e.preventDefault() }

        let meta = {
          altKey: e.altKey,
          shiftKey: e.shiftKey,
          ctrlKey: e.ctrlKey,
          metaKey: e.metaKey,
          x: e.x || e.clientX,
          y: e.y || e.clientY,
          pageX: e.pageX,
          pageY: e.pageY,
          screenX: e.screenX,
          screenY: e.screenY,
          offsetX: e.offsetX,
          offsetY: e.offsetY,
        }

        this.debounce(target, e, () => {
          this.withinOwners(target, (view, targetCtx) => {
            view.pushEvent("click", target, targetCtx, phxEvent, meta)
          })
        })
      }, capture)
    })
  }

  bindNav(){
    if(!Browser.canPushState()){ return }
    window.onpopstate = (event) => {
      if(!this.registerNewLocation(window.location)){ return }
      let {type, id, root} = event.state || {}
      let href = window.location.href

      if(this.main.isConnected() && (type === "patch" && id  === this.main.id)){
        this.main.pushLinkPatch(href)
      } else {
        this.replaceMain(href, null, () => {
          if(root){ this.replaceRootHistory() }
        })
      }
    }
    window.addEventListener("click", e => {
      let target = closestPhxBinding(e.target, PHX_LIVE_LINK)
      let type = target && target.getAttribute(PHX_LIVE_LINK)
      let wantsNewTab = e.metaKey || e.ctrlKey || e.button === 1
      if(!type || !this.isConnected() || wantsNewTab){ return }
      let href = target.href
      let linkState = target.getAttribute(PHX_LINK_STATE)
      e.preventDefault()
      if(this.pendingLink === href){ return }

      if(type === "patch"){
        this.pushHistoryPatch(href, linkState)
      } else if(type === "redirect") {
        this.historyRedirect(href, linkState)
      } else {
        throw new Error(`expected ${PHX_LIVE_LINK} to be "patch" or "redirect", got: ${type}`)
      }
    }, false)
  }

  pushHistoryPatch(href, linkState){
    this.main.pushLinkPatch(href, () => this.historyPatch(href, linkState))
  }

  historyPatch(href, linkState){
    Browser.pushState(linkState, {type: "patch", id: this.main.id}, href)
    this.registerNewLocation(window.location)
  }

  historyRedirect(href, linkState, flash){
    this.replaceMain(href, flash, () => {
      Browser.pushState(linkState, {type: "redirect", id: this.main.id}, href)
      this.registerNewLocation(window.location)
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
    this.on("submit", e => {
      let phxEvent = e.target.getAttribute(this.binding("submit"))
      if(!phxEvent){ return }
      e.preventDefault()
      e.target.disabled = true
      this.withinOwners(e.target, (view, targetCtx) => view.submitForm(e.target, targetCtx, phxEvent))
    }, false)

    for(let type of ["change", "input"]){
      this.on(type, e => {
        let input = e.target
        let phxEvent = input.form && input.form.getAttribute(this.binding("change"))
        if(!phxEvent){ return }

        let value = JSON.stringify((new FormData(input.form)).getAll(input.name))
        if(this.prevInput === input && this.prevValue === value){ return }
        if(input.type === "number" && input.validity && input.validity.badInput){ return }

        this.prevInput = input
        this.prevValue = value
        this.debounce(input, e, () => {
          this.withinOwners(input.form, (view, targetCtx) => {
            if(DOM.isTextualInput(input)){
              DOM.putPrivate(input, PHX_HAS_FOCUSED, true)
            } else {
              this.setActiveElement(input)
            }
            if(!DOM.isTextualInput(input)){ input.blur() }
            view.pushInput(input, targetCtx, phxEvent, e.target)
          })
        })
      }, false)
    }
  }

  debounce(el, event, callback){
    DOM.debounce(el, event, this.binding(PHX_DEBOUNCE), this.binding(PHX_THROTTLE), callback)
  }

  silenceEvents(callback){
    this.silenced = true
    callback()
    this.silenced = false
  }

  on(event, callback){
    window.addEventListener(event, e => {
      if(!this.silenced){ callback(e) }
    })
  }
}

export let Browser = {
  canPushState(){ return (typeof(history.pushState) !== "undefined") },

  dropLocal(namespace, subkey){
    return window.localStorage.removeItem(this.localKey(namespace, subkey))
  },

  updateLocal(namespace, subkey, initial, func){
    let current = this.getLocal(namespace, subkey)
    let key = this.localKey(namespace, subkey)
    let newVal = current === null ? initial : func(current)
    window.localStorage.setItem(key, JSON.stringify(newVal))
    return newVal
  },

  getLocal(namespace, subkey){
    return JSON.parse(window.localStorage.getItem(this.localKey(namespace, subkey)))
  },

  fetchPage(href, callback){
    let req = new XMLHttpRequest()
    req.open("GET", href, true)
    req.timeout = PUSH_TIMEOUT
    req.setRequestHeader("content-type", "text/html")
    req.setRequestHeader("cache-control", "max-age=0, no-cache, no-store, must-revalidate, post-check=0, pre-check=0")
    req.setRequestHeader(LINK_HEADER, "live-link")
    req.onerror = () => callback(400)
    req.ontimeout = () => callback(504)
    req.onreadystatechange = () => {
      if(req.readyState !== 4){ return }
      if(req.getResponseHeader(LINK_HEADER) !== "live-link"){ return callback(400) }
      if(req.status !== 200){ return callback(req.status) }
      callback(200, req.responseText)
    }
    req.send()
  },

  pushState(kind, meta, to){
    if(this.canPushState()){
      if(to !== window.location.href){
        history[kind + "State"](meta, "", to)
        let hashEl = this.getHashTargetEl(window.location.hash)

        if(hashEl) {
          hashEl.scrollIntoView()
        } else if(meta.type === "redirect"){
          window.scroll(0, 0)
        }
      }
    } else {
      this.redirect(to)
    }
  },

  setCookie(name, value){
    document.cookie = `${name}=${value}`
  },

  getCookie(name){
    return document.cookie.replace(new RegExp(`(?:(?:^|.*;\s*)${name}\s*\=\s*([^;]*).*$)|^.*$`), "$1")
  },

  redirect(toURL, flash){
    if(flash){ Browser.setCookie("__phoenix_flash__", flash + "; max-age=60000; path=/") }
    window.location = toURL
  },

  localKey(namespace, subkey){ return `${namespace}-${subkey}` },

  getHashTargetEl(hash){
    if(hash.toString() === ""){ return }
    return document.getElementById(hash) || document.querySelector(`a[name="${hash.substring(1)}"]`)
  }
}

export let DOM = {
  all(node, query, callback){
    let array = Array.from(node.querySelectorAll(query))
    return callback ? array.forEach(callback) : array
  },

  findComponentNodeList(node, cid){ return this.all(node, `[${PHX_COMPONENT}="${cid}"]`) },

  private(el, key){ return el[PHX_PRIVATE] && el[PHX_PRIVATE][key] },

  deletePrivate(el, key){ el[PHX_PRIVATE] && delete(el[PHX_PRIVATE][key]) },

  putPrivate(el, key, value){
    if(!el[PHX_PRIVATE]){ el[PHX_PRIVATE] = {} }
    el[PHX_PRIVATE][key] = value
  },

  copyPrivates(target, source){
    if(source[PHX_PRIVATE]){
      target[PHX_PRIVATE] = clone(source[PHX_PRIVATE])
    }
  },

  putTitle(title){ document.title = title },

  debounce(el, event, phxDebounce, phxThrottle, callback){
    let debounce = el.getAttribute(phxDebounce)
    let throttle = el.getAttribute(phxThrottle)
    let value = debounce || throttle
    switch(value){
      case null: return callback()

      case "blur":
        if(this.private(el, DEBOUNCE_BLUR)){ return }
        el.addEventListener("blur", () => callback())
        this.putPrivate(el, DEBOUNCE_BLUR, value)
        return

      default:
        let timeout = parseInt(value)
        if(isNaN(timeout)){ return logError(`invalid throttle/debounce value: ${value}`) }
        if(throttle && event.type === "keydown"){
          let prevKey = this.private(el, DEBOUNCE_PREV_KEY)
          this.putPrivate(el, DEBOUNCE_PREV_KEY, event.which)
          if(prevKey !== event.which){ return callback() }
        }
        if(this.private(el, DEBOUNCE_TIMER)){ return }

        let clearTimer = (e) => {
          if(throttle && e.type === PHX_CHANGE_EVENT && e.detail.triggeredBy.name === el.name){ return }
          clearTimeout(this.private(el, DEBOUNCE_TIMER))
          this.deletePrivate(el, DEBOUNCE_TIMER)
        }
        this.putPrivate(el, DEBOUNCE_TIMER, setTimeout(() => {
          if(el.form){
            el.form.removeEventListener(PHX_CHANGE_EVENT, clearTimer)
            el.form.removeEventListener("submit", clearTimer)
          }
          this.deletePrivate(el, DEBOUNCE_TIMER)
          if(!throttle){ callback() }
        }, timeout))
        if(el.form){
          el.form.addEventListener(PHX_CHANGE_EVENT, clearTimer)
          el.form.addEventListener("submit", clearTimer)
        }
        if(throttle){ callback() }
    }
  },

  disableForm(form, prefix){
    let disableWith = `${prefix}${PHX_DISABLE_WITH}`
    form.classList.add(PHX_LOADING_CLASS)
    DOM.all(form, `[${disableWith}]`, el => {
      let value = el.getAttribute(disableWith)
      el.setAttribute(`${disableWith}-restore`, el.innerText)
      el.innerText = value
    })
    DOM.all(form, "button", button => {
      button.setAttribute(PHX_DISABLED, button.disabled)
      button.disabled = true
    })
    DOM.all(form, "input", input => {
      input.setAttribute(PHX_READONLY, input.readOnly)
      input.readOnly = true
    })
  },

  restoreDisabledForm(form, prefix){
    let disableWith = `${prefix}${PHX_DISABLE_WITH}`
    form.classList.remove(PHX_LOADING_CLASS)

    DOM.all(form, `[${disableWith}]`, el => {
      let value = el.getAttribute(`${disableWith}-restore`)
      if(value){
        if(el.nodeName === "INPUT") {
          el.setAttribute("value", value)
        } else {
          el.innerText = value
        }
        el.removeAttribute(`${disableWith}-restore`)
      }
    })
    DOM.all(form, "button", button => {
      let prev = button.getAttribute(PHX_DISABLED)
      if(prev){
        button.disabled = prev === "true"
        button.removeAttribute(PHX_DISABLED)
      }
    })
    DOM.all(form, "input", input => {
      let prev = input.getAttribute(PHX_READONLY)
      if(prev){
        input.readOnly = prev === "true"
        input.removeAttribute(PHX_READONLY)
      }
    })
  },

  discardError(container, el){
    let field = el.getAttribute && el.getAttribute(PHX_ERROR_FOR)
    if(!field) { return }
    let input = container.querySelector(`#${field}`)

    if(field && !(this.private(input, PHX_HAS_FOCUSED) || this.private(input.form, PHX_HAS_SUBMITTED))){
      el.style.display = "none"
    }
  },

  isPhxChild(node){
    return node.getAttribute && node.getAttribute(PHX_PARENT_ID)
  },

  dispatchEvent(target, eventString, detail = {}){
    let event = new CustomEvent(eventString, {bubbles: true, cancelable: true, detail: detail})
    target.dispatchEvent(event)
  },

  cloneNode(node, html){
    let cloned = node.cloneNode()
    cloned.innerHTML = typeof(html) === "undefined" ? node.innerHTML : html
    return cloned
  },

  mergeAttrs(target, source, exclude = []){
    let sourceAttrs = source.attributes
    for (let i = sourceAttrs.length - 1; i >= 0; i--){
      let name = sourceAttrs[i].name
      if(exclude.indexOf(name) < 0){ target.setAttribute(name, source.getAttribute(name)) }
    }

    let targetAttrs = target.attributes
    for (let i = targetAttrs.length - 1; i >= 0; i--){
      let name = targetAttrs[i].name
      if(!source.hasAttribute(name)){ target.removeAttribute(name) }
    }
  },

  mergeInputs(target, source){
    DOM.mergeAttrs(target, source, ["value"])
    if(source.readOnly){
      target.setAttribute("readonly", true)
    } else {
      target.removeAttribute("readonly")
    }
  },

  restoreFocus(focused, selectionStart, selectionEnd){
    if(!DOM.isTextualInput(focused)){ return }
    if(focused.readOnly){ focused.blur()}
    focused.focus()
    if(focused.setSelectionRange && focused.type === "text" || focused.type === "textarea"){
      focused.setSelectionRange(selectionStart, selectionEnd)
    }
  },

  isFormInput(el){ return /^(?:input|select|textarea|button)$/i.test(el.tagName) },

  isTextualInput(el){ return FOCUSABLE_INPUTS.indexOf(el.type) >= 0 }
}

class DOMPatch {
  constructor(view, container, id, html, targetCID){
    this.view = view,
    this.container = container
    this.id = id
    this.html = html
    this.targetCID = targetCID
    this.callbacks = {
      beforeadded: [], beforeupdated: [], beforediscarded: [], beforephxChildAdded: [],
      afteradded: [], afterupdated: [], afterdiscarded: [], afterphxChildAdded: []
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

  perform(){
    let {view, container, id, html, targetCID} = this
    let focused = view.liveSocket.getActiveElement()
    let {selectionStart, selectionEnd} = focused && DOM.isTextualInput(focused) ? focused : {}
    let phxUpdate = view.liveSocket.binding(PHX_UPDATE)
    let added = []
    let updates = []
    let [diffContainer, targetContainer] = this.buildDiffContainer(container, html, phxUpdate, targetCID)

    this.trackBefore("added", container)
    this.trackBefore("updated", container, container)

    morphdom(targetContainer, diffContainer.outerHTML, {
      childrenOnly: true,
      onBeforeNodeAdded: (el) => {
        //input handling
        DOM.discardError(targetContainer, el)
        this.trackBefore("added", el)
        return el
      },
      onNodeAdded: (el) => {
        // nested view handling
        if(DOM.isPhxChild(el) && view.ownsElement(el)){
          this.trackAfter("phxChildAdded", el)
        }
        added.push(el)
      },
      onNodeDiscarded: (el) => { this.trackAfter("discarded", el) },
      onBeforeNodeDiscarded: (el) => {
        this.trackBefore("discarded", el)
        // nested view handling
        if(DOM.isPhxChild(el)){
          view.liveSocket.destroyViewByEl(el)
          return true
        }
      },
      onElUpdated: (el) => { updates.push(el) },
      onBeforeElUpdated: (fromEl, toEl) => {
        if(fromEl.getAttribute(phxUpdate) === "ignore"){
          this.trackBefore("updated", fromEl, toEl)
          DOM.mergeAttrs(fromEl, toEl)
          updates.push(fromEl)
          return false
        }
        if(fromEl.type === "number" && (fromEl.validity && fromEl.validity.badInput)){ return false }

        // nested view handling
        if(DOM.isPhxChild(toEl)){
          let prevStatic = fromEl.getAttribute(PHX_STATIC)
          DOM.mergeAttrs(fromEl, toEl)
          fromEl.setAttribute(PHX_STATIC, prevStatic)
          return false
        }

        // input handling
        DOM.copyPrivates(toEl, fromEl)
        DOM.discardError(targetContainer, toEl)

        if(fromEl.isSameNode(focused) && DOM.isFormInput(fromEl)){
          this.trackBefore("updated", fromEl, toEl)
          DOM.mergeInputs(fromEl, toEl)
          updates.push(fromEl)
          return false
        } else {
          this.trackBefore("updated", fromEl, toEl)
          return true
        }
      }
    })

    if (DEBUG) {
      detectDuplicateIds()
    }

    added.forEach(el => this.trackAfter("added", el))
    updates.forEach(el => this.trackAfter("updated", el))

    view.liveSocket.silenceEvents(() => DOM.restoreFocus(focused, selectionStart, selectionEnd))
    DOM.dispatchEvent(document, "phx:update")
    return true
  }

  // builds container for morphdom patch
  // - precomputes append/prepend content in diff node to make it appear as if
  //   the contents had been appended/prepended on full child node list
  // - precomputes updates on existing child ids within a prepend/append child list
  //   to allow existing nodes to be updated in place rather than reordered
  buildDiffContainer(container, html, phxUpdate, targetCID){
    let targetContainer = container
    let diffContainer = null
    let elementsOnly = child => child.nodeType === Node.ELEMENT_NODE
    let idsOnly = child => child.id || logError("append/prepend children require IDs, got: ", child)
    if(typeof(targetCID) === "number"){
      targetContainer = container.querySelector(`[${PHX_COMPONENT}="${targetCID}"]`).parentNode
      diffContainer = DOM.cloneNode(targetContainer)
      let componentNodes = DOM.findComponentNodeList(diffContainer, targetCID)
      let prevSibling = componentNodes[0].previousSibling
      componentNodes.forEach(c => c.remove())
      let nextSibling = prevSibling && prevSibling.nextSibling

      if(prevSibling && nextSibling){
        let template = document.createElement("template")
        template.innerHTML = html
        Array.from(template.content.childNodes).forEach(child => diffContainer.insertBefore(child, nextSibling))
      } else if(prevSibling){
        diffContainer.insertAdjacentHTML("beforeend", html)
      } else {
        diffContainer.insertAdjacentHTML("afterbegin", html)
      }
    } else {
      diffContainer = DOM.cloneNode(container, html)
    }

    DOM.all(diffContainer, `[${phxUpdate}=append],[${phxUpdate}=prepend]`, el => {
      let id = el.id || logError("append/prepend requires an ID, got: ", el)
      let existingInContainer = container.querySelector(`#${id}`)
      if(!existingInContainer){ return }
      let existing = DOM.cloneNode(existingInContainer)
      let updateType = el.getAttribute(phxUpdate)
      let newIds = Array.from(el.childNodes).filter(elementsOnly).map(idsOnly)
      let existingIds = Array.from(existing.childNodes).filter(elementsOnly).map(idsOnly)

      if(newIds.toString() !== existingIds.toString()){
        let dupIds = newIds.filter(id => existingIds.indexOf(id) >= 0)
        dupIds.forEach(id => {
          let updatedEl = el.querySelector(`#${id}`)
          existing.querySelector(`#${id}`).replaceWith(updatedEl)
        })
        el.insertAdjacentHTML(updateType === "append" ? "afterbegin" : "beforeend", existing.innerHTML)
      }
    })

    return [diffContainer, targetContainer]
  }
}

export class View {
  constructor(el, liveSocket, parentView, href, flash){
    this.liveSocket = liveSocket
    this.flash = flash
    this.parent = parentView
    this.gracefullyClosed = false
    this.el = el
    this.id = this.el.id
    this.view = this.el.getAttribute(PHX_VIEW)
    this.loaderTimer = null
    this.pendingDiffs = []
    this.href = href
    this.joinCount = this.parent ? this.parent.joinCount - 1 : 0
    this.joinPending = true
    this.viewHooks = {}
    this.channel = this.liveSocket.channel(`lv:${this.id}`, () => {
      return {
        url: this.href,
        params: this.liveSocket.params(this.view),
        session: this.getSession(),
        static: this.getStatic(),
        flash: this.flash,
        joins: this.joinCount
      }
    })
    this.showLoader(this.liveSocket.loaderTimeout)
    this.bindChannel()
  }

  name(){ return this.view }

  isConnected(){ return this.channel.canPush() }

  getSession(){ return this.el.getAttribute(PHX_SESSION) }

  getStatic(){
    let val = this.el.getAttribute(PHX_STATIC)
    return val === "" ? null : val
  }

  destroy(callback = function(){}){
    clearTimeout(this.loaderTimer)
    let onFinished = () => {
      callback()
      for(let id in this.viewHooks){ this.destroyHook(this.viewHooks[id]) }
    }
    if(this.hasGracefullyClosed()){
      this.log("destroyed", () => ["the server view has gracefully closed"])
      onFinished()
    } else {
      this.log("destroyed", () => ["the child has been removed from the parent"])
      this.channel.leave()
        .receive("ok", onFinished)
        .receive("error", onFinished)
        .receive("timeout", onFinished)
    }
  }

  setContainerClasses(...classes){
    this.el.classList.remove(
      PHX_CONNECTED_CLASS,
      PHX_DISCONNECTED_CLASS,
      PHX_ERROR_CLASS
    )
    this.el.classList.add(...classes)
  }

  isLoading(){ return this.el.classList.contains(PHX_DISCONNECTED_CLASS)}

  showLoader(timeout){
    clearTimeout(this.loaderTimer)
    if(timeout){
      this.loaderTimer = setTimeout(() => this.showLoader(), timeout)
    } else {
      for(let id in this.viewHooks){ this.viewHooks[id].__trigger__("disconnected") }
      this.setContainerClasses(PHX_DISCONNECTED_CLASS)
    }
  }

  hideLoader(){
    clearTimeout(this.loaderTimer)
    this.setContainerClasses(PHX_CONNECTED_CLASS)
  }

  triggerReconnected(){
    for(let id in this.viewHooks){ this.viewHooks[id].__trigger__("reconnected") }
  }

  log(kind, msgCallback){
    this.liveSocket.log(this, kind, msgCallback)
  }

  onJoin(resp){
    let {rendered, live_patch} = resp
    this.log("join", () => ["", JSON.stringify(rendered)])
    if(rendered.title){ DOM.putTitle(rendered.title) }
    Browser.dropLocal(this.name(), CONSECUTIVE_RELOADS)
    this.rendered = rendered
    let html = Rendered.toString(this.rendered)
    let forms = this.formsForRecovery(html)

    if(this.joinCount > 1 && forms.length > 0){
      forms.forEach((form, i) => {
        this.pushFormRecovery(form, resp => {
          if(i === forms.length - 1){
            this.onJoinComplete(resp, html)
          }
        })
      })
    } else {
      this.onJoinComplete(resp, html)
    }
  }

  formsForRecovery(html){
    let phxChange = this.binding("change")
    let template = document.createElement("template")
    template.innerHTML = html

    return(
      DOM.all(this.el, `form[${phxChange}], form[${this.binding("submit")}]`)
         .filter(form => this.ownsElement(form))
         .filter(form => template.content.querySelector(`form[${phxChange}="${form.getAttribute(phxChange)}"]`))
    )
  }

  onJoinComplete({live_patch}, html){
    this.joinPending = false
    let patch = new DOMPatch(this, this.el, this.id, html)
    this.performPatch(patch)
    this.joinNewChildren()
    DOM.all(this.el, `[${this.binding(PHX_HOOK)}]`, hookEl => {
      let hook = this.addHook(hookEl)
      if(hook){ hook.__trigger__("mounted") }
    })

    this.applyPendingUpdates()

    if(live_patch){
      let {kind, to} = live_patch
      this.liveSocket.historyPatch(to, kind)
    }
    this.hideLoader()
    if(this.joinCount > 1){ this.triggerReconnected() }
  }

  performPatch(patch){
    let destroyedCIDs = []
    let phxChildrenAdded = false
    let updatedHookIds = new Set()

    patch.after("added", el => {
      let newHook = this.addHook(el)
      if(newHook){ newHook.__trigger__("mounted") }
    })

    patch.after("phxChildAdded", el => phxChildrenAdded = true)

    patch.before("updated", (fromEl, toEl) => {
      let hook = this.getHook(fromEl)
      if(hook && !fromEl.isEqualNode(toEl)){
        updatedHookIds.add(fromEl.id)
        hook.__trigger__("beforeUpdate")
      }
    })

    patch.after("updated", el => {
      let hook = this.getHook(el)
      if(hook && updatedHookIds.has(el.id)){ hook.__trigger__("updated") }
    })

    patch.before("discarded", (el) => {
      let hook = this.getHook(el)
      if(hook){ hook.__trigger__("beforeDestroy") }
    })

    patch.after("discarded", (el) => {
      let cid = this.componentID(el)
      if(typeof(cid) === "number" && destroyedCIDs.indexOf(cid) === -1){ destroyedCIDs.push(cid) }
      let hook = this.getHook(el)
      hook && this.destroyHook(hook)
    })
    patch.perform()

    if(phxChildrenAdded){
      this.joinNewChildren()
    }
    this.maybePushComponentsDestroyed(destroyedCIDs)
  }

  joinNewChildren(){
    DOM.all(this.el, `${PHX_VIEW_SELECTOR}[${PHX_PARENT_ID}="${this.id}"]`, el => {
      let child = this.liveSocket.getViewByEl(el)
      if(!child){
        this.liveSocket.joinView(el, this)
      }
    })
  }

  update(diff, cid){
    if(isEmpty(diff)){ return }
    if(diff.title){ DOM.putTitle(diff.title) }
    if(this.joinPending || this.liveSocket.hasPendingLink()){ return this.pendingDiffs.push({diff, cid}) }

    this.log("update", () => ["", JSON.stringify(diff)])
    this.rendered = Rendered.mergeDiff(this.rendered, diff)
    let html = typeof(cid) === "number" ?
      Rendered.componentToString(this.rendered[COMPONENTS], cid) :
      Rendered.toString(this.rendered)

    let patch = new DOMPatch(this, this.el, this.id, html, cid)
    this.performPatch(patch)
  }

  getHook(el){ return this.viewHooks[ViewHook.elementID(el)] }

  addHook(el){ if(ViewHook.elementID(el) || !el.getAttribute){ return }
    let hookName = el.getAttribute(this.binding(PHX_HOOK))
    if(hookName && !this.ownsElement(el)){ return }
    let callbacks = this.liveSocket.getHookCallbacks(hookName)

    if(callbacks){
      let hook = new ViewHook(this, el, callbacks)
      this.viewHooks[ViewHook.elementID(hook.el)] = hook
      return hook
    } else if(hookName !== null){
      logError(`unknown hook found for "${hookName}"`, el)
    }
  }

  destroyHook(hook){
    hook.__trigger__("destroyed")
    delete this.viewHooks[ViewHook.elementID(hook.el)]
  }

  applyPendingUpdates(){
    this.pendingDiffs.forEach(({diff, cid}) => this.update(diff, cid))
    this.pendingDiffs = []
  }

  bindChannel(){
    this.channel.on("diff", (diff) => this.update(diff))
    this.channel.on("redirect", ({to, flash}) => this.onRedirect({to, flash}))
    this.channel.on("live_patch", (redir) => this.onLivePatch(redir))
    this.channel.on("live_redirect", (redir) => this.onLiveRedirect(redir))
    this.channel.on("session", ({token}) => this.el.setAttribute(PHX_SESSION, token))
    this.channel.onError(reason => this.onError(reason))
    this.channel.onClose(() => this.onGracefulClose())
  }

  onGracefulClose(){
    this.gracefullyClosed = true
    this.liveSocket.destroyViewById(this.id)
  }

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

  onRedirect({to, flash}){ Browser.redirect(to, flash) }

  hasGracefullyClosed(){ return this.gracefullyClosed }

  join(callback){
    if(this.parent){
      this.parent.channel.onClose(() => this.onGracefulClose())
      this.parent.channel.onError(() => this.liveSocket.destroyViewById(this.id))
    }
    this.channel.join()
      .receive("ok", data => {
        if(this.joinCount === 0){ callback && callback(this) }
        this.joinCount++
        this.joinPending = true
        this.flash = null
        this.onJoin(data)
      })
      .receive("error", resp => this.onJoinError(resp))
      .receive("timeout", () => this.onJoinError({reason: "timeout"}))
  }

  onJoinError(resp){
    if(resp.reason === CLIENT_OUTDATED){ return this.liveSocket.reloadWithJitter(this) }
    if(resp.reason === JOIN_CRASHED){ return this.liveSocket.reloadWithJitter(this) }
    if(resp.redirect || resp.live_redirect){ this.channel.leave() }
    if(resp.redirect){ return this.onRedirect(resp.redirect) }
    if(resp.live_redirect){ return this.onLiveRedirect(resp.live_redirect) }
    this.displayError()
    this.log("error", () => ["unable to join", resp])
  }

  onError(reason){
    if(this.joinPending){ return this.liveSocket.reloadWithJitter(this) }
    this.log("error", () => ["view crashed", reason])
    this.liveSocket.onViewError(this)
    document.activeElement.blur()
    if(this.liveSocket.isUnloaded()){
      this.showLoader(BEFORE_UNLOAD_LOADER_TIMEOUT)
    } else {
      this.displayError()
    }
  }

  displayError(){
    this.showLoader()
    this.setContainerClasses(PHX_DISCONNECTED_CLASS, PHX_ERROR_CLASS)
  }

  pushWithReply(event, payload, onReply = function(){ }){
    if(typeof(payload.cid) !== "number"){ delete payload.cid }
    return(
      this.channel.push(event, payload, PUSH_TIMEOUT).receive("ok", resp => {
        if(resp.diff){ this.update(resp.diff, payload.cid) }
        if(resp.redirect){ this.onRedirect(resp.redirect) }
        if(resp.live_patch){ this.onLivePatch(resp.live_patch) }
        if(resp.live_redirect){ this.onLiveRedirect(resp.live_redirect) }
        onReply(resp)
      })
    )
  }

  componentID(el){
    let cid = el.getAttribute && el.getAttribute(PHX_COMPONENT)
    return cid ? parseInt(cid) : null
  }

  targetComponentID(target, targetCtx){
    if(target.getAttribute(this.binding("target"))){
      return this.closestComponentID(targetCtx)
    } else {
      return null
    }
  }

  closestComponentID(targetCtx){
    if(targetCtx){
      return maybe(targetCtx.closest(`[${PHX_COMPONENT}]`), el => this.ownsElement(el) && this.componentID(el))
    } else {
      return null
    }
  }

  pushHookEvent(targetCtx, event, payload){
    this.pushWithReply("event", {
      type: "hook",
      event: event,
      value: payload,
      cid: this.closestComponentID(targetCtx)
    })
  }

  extractMeta(el, meta){
    let prefix = this.binding("value-")
    for (let i = 0; i < el.attributes.length; i++){
      let name = el.attributes[i].name
      if(name.startsWith(prefix)){ meta[name.replace(prefix, "")] = el.getAttribute(name) }
    }
    if(el.value !== undefined){
      meta.value = el.value

      if (el.tagName === "INPUT" && el.type === "checkbox" && !el.checked) {
        delete meta.value
      }
    }
    return meta
  }

  pushEvent(type, el, targetCtx, phxEvent, meta){
    this.pushWithReply("event", {
      type: type,
      event: phxEvent,
      value: this.extractMeta(el, meta),
      cid: this.targetComponentID(el, targetCtx)
    })
  }

  pushKey(keyElement, targetCtx, kind, phxEvent, meta){
    this.pushWithReply("event", {
      type: kind,
      event: phxEvent,
      value: this.extractMeta(keyElement, meta),
      cid: this.targetComponentID(keyElement, targetCtx)
    })
  }

  pushInput(inputEl, targetCtx, phxEvent, eventTarget, callback){
    DOM.dispatchEvent(inputEl.form, PHX_CHANGE_EVENT, {triggeredBy: inputEl})
    this.pushWithReply("event", {
      type: "form",
      event: phxEvent,
      value: serializeForm(inputEl.form, {_target: eventTarget.name}),
      cid: this.targetComponentID(inputEl.form, targetCtx)
    }, callback)
  }

  pushFormSubmit(formEl, targetCtx, phxEvent, onReply){
    this.pushWithReply("event", {
      type: "form",
      event: phxEvent,
      value: serializeForm(formEl),
      cid: this.targetComponentID(formEl, targetCtx)
    }, onReply)
  }

  pushFormRecovery(form, callback){
    this.liveSocket.withinOwners(form, (view, targetCtx) => {
      let input = form.elements[0]
      let phxEvent = form.getAttribute(this.binding(PHX_AUTO_RECOVER)) || form.getAttribute(this.binding("change"))
      view.pushInput(input, targetCtx, phxEvent, input, callback)
    })
  }

  pushLinkPatch(href, callback){
    if(!this.isLoading()){ this.showLoader(this.liveSocket.loaderTimeout) }
    let linkRef = this.liveSocket.setPendingLink(href)
    this.pushWithReply("link", {url: href}, resp => {
      if(resp.link_redirect){
        this.liveSocket.replaceMain(href, null, callback, linkRef)
      } else if(this.liveSocket.commitPendingLink(linkRef)){
        this.href = href
        this.applyPendingUpdates()
        this.hideLoader()
        this.triggerReconnected()
        callback && callback()
      }
    }).receive("timeout", () => Browser.redirect(window.location.href))
  }

  formsForRecovery(html){
    let phxChange = this.binding("change")
    let template = document.createElement("template")
    template.innerHTML = html

    return(
      DOM.all(this.el, `form[${phxChange}]`)
         .filter(form => this.ownsElement(form))
         .filter(form => form.getAttribute(this.binding(PHX_AUTO_RECOVER)) !== "ignore")
         .filter(form => template.content.querySelector(`form[${phxChange}="${form.getAttribute(phxChange)}"]`))
    )
  }

  maybePushComponentsDestroyed(destroyedCIDs){
    let completelyDestroyedCIDs = destroyedCIDs.filter(cid => {
      return DOM.findComponentNodeList(this.el, cid).length === 0
    })
    if(completelyDestroyedCIDs.length > 0){
      this.pushWithReply("cids_destroyed", {cids: completelyDestroyedCIDs}, () => {
        this.rendered = Rendered.pruneCIDs(this.rendered, completelyDestroyedCIDs)
      })
    }
  }

  ownsElement(el){
    return el.getAttribute(PHX_PARENT_ID) === this.id ||
           maybe(el.closest(PHX_VIEW_SELECTOR), node => node.id) === this.id
  }

  submitForm(form, targetCtx, phxEvent){
    let prefix = this.liveSocket.getBindingPrefix()
    DOM.putPrivate(form, PHX_HAS_SUBMITTED, true)
    DOM.disableForm(form, prefix)
    this.liveSocket.blurActiveElement(this)
    this.pushFormSubmit(form, targetCtx, phxEvent, () => {
      DOM.restoreDisabledForm(form, prefix)
      this.liveSocket.restorePreviouslyActiveFocus()
    })
  }

  binding(kind){ return this.liveSocket.binding(kind)}
}

let viewHookID = 1
class ViewHook {
  static makeID(){ return viewHookID++ }
  static elementID(el){ return el.phxHookId }

  constructor(view, el, callbacks){
    this.__view = view
    this.__liveSocket = view.liveSocket
    this.__callbacks = callbacks
    this.el = el
    this.viewName = view.name()
    this.el.phxHookId = this.constructor.makeID()
    for(let key in this.__callbacks){ this[key] = this.__callbacks[key] }
  }

  pushEvent(event, payload = {}){
    this.__view.pushHookEvent(null, event, payload)
  }

  pushEventTo(phxTarget, event, payload = {}){
    this.__liveSocket.withinTargets(phxTarget, (view, targetCtx) => {
      view.pushHookEvent(targetCtx, event, payload)
    })
  }

  __trigger__(kind){
    let callback = this.__callbacks[kind]
    callback && callback.call(this)
  }
}

export default LiveSocket
