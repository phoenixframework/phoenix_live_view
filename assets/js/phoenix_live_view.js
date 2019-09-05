/*
================================================================================
Phoenix LiveView JavaScript Client
================================================================================

See the hexdocs at `https://hexdocs.pm/phoenix_live_view` for documentation.

*/

import morphdom from "morphdom"
import {Socket} from "phoenix"

const PHX_VIEW = "data-phx-view"
const PHX_LIVE_LINK = "data-phx-live-link"
const PHX_CONNECTED_CLASS = "phx-connected"
const PHX_LOADING_CLASS = "phx-loading"
const PHX_DISCONNECTED_CLASS = "phx-disconnected"
const PHX_ERROR_CLASS = "phx-error"
const PHX_PARENT_ID = "data-phx-parent-id"
const PHX_VIEW_SELECTOR = `[${PHX_VIEW}]`
const PHX_ERROR_FOR = "data-phx-error-for"
const PHX_HAS_FOCUSED = "phx-has-focused"
const PHX_BOUND = "data-phx-bound"
const FOCUSABLE_INPUTS = ["text", "textarea", "number", "email", "password", "search", "tel", "url"]
const PHX_HAS_SUBMITTED = "phx-has-submitted"
const PHX_SESSION = "data-phx-session"
const PHX_STATIC = "data-phx-static"
const PHX_READONLY = "data-phx-readonly"
const PHX_DISABLED = "data-phx-disabled"
const PHX_DISABLE_WITH = "disable-with"
const PHX_HOOK = "hook"
const PHX_UPDATE = "update"
const LOADER_TIMEOUT = 1
const BEFORE_UNLOAD_LOADER_TIMEOUT = 200
const BINDING_PREFIX = "phx-"
const PUSH_TIMEOUT = 30000
const LINK_HEADER = "x-requested-with"
const PHX_PREV_APPEND = "phxPrevAppend"

export let debug = (view, kind, msg, obj) => {
  console.log(`${view.id} ${kind}: ${msg} - `, obj)
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

let maybe = (el, key) => {
  if(el){
    return el[key]
  } else {
    return null
  }
}

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
      if(targetVal.dynamics && !val.dynamics){ delete targetVal.dynamics}
      recursiveMerge(targetVal, val)
    } else {
      target[key] = val
    }
  }
}

let Session = {
  get(el){ return el.getAttribute(PHX_SESSION) },

  isEqual(el1, el2){ return this.get(el1) === this.get(el2) }
}


export let Rendered = {
  mergeDiff(source, diff){
    if(this.isNewFingerprint(diff)){
      return diff
    } else {
      recursiveMerge(source, diff)
      return source
    }
  },

  isNewFingerprint(diff = {}){ return !!diff.static },

  toString(rendered){
    let output = {buffer: ""}
    this.toOutputBuffer(rendered, output)
    return output.buffer
  },

  toOutputBuffer(rendered, output){
    if(rendered.dynamics){ return this.comprehensionToBuffer(rendered, output) }
    let {static: statics} = rendered

    output.buffer += statics[0]
    for(let i = 1; i < statics.length; i++){
      this.dynamicToBuffer(rendered[i - 1], output)
      output.buffer += statics[i]
    }
  },

  comprehensionToBuffer(rendered, output){
    let {dynamics: dynamics, static: statics} = rendered

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
    if(isObject(rendered)){
      this.toOutputBuffer(rendered, output)
    } else {
      output.buffer += rendered
    }
  }
}

// todo document LiveSocket specific options like viewLogger
export class LiveSocket {
  constructor(url, opts = {}){
    this.unloaded = false
    this.socket = new Socket(url, opts)
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
    this.linkRef = 0
    this.href = window.location.href
    this.pendingLink = null
    this.currentLocation = clone(window.location)
    this.hooks = opts.hooks || {}

    this.socket.onOpen(() => {
      if(this.isUnloaded()){
        this.destroyAllViews()
        this.joinRootViews()
      }
      this.unloaded = false
    })
    window.addEventListener("beforeunload", e => {
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
    } else {
      document.addEventListener("DOMContentLoaded", () => {
        this.joinRootViews()
      })
    }
    return this.socket.connect()
  }

  disconnect(){ this.socket.disconnect() }

  // private

  getHookCallbacks(hookName){ return this.hooks[hookName] }

  isUnloaded(){ return this.unloaded }

  getBindingPrefix(){ return this.bindingPrefix }

  binding(kind){ return `${this.getBindingPrefix()}${kind}` }

  channel(topic, params){ return this.socket.channel(topic, params) }

  joinRootViews(){
    Browser.all(document, `${PHX_VIEW_SELECTOR}:not([${PHX_PARENT_ID}])`, rootEl => {
      let view = this.joinView(rootEl, null, this.getHref())
      this.root = this.root || view
    })
  }

  replaceRoot(href, callback = null, linkRef = this.setPendingLink(href)){
    this.root.showLoader(LOADER_TIMEOUT)
    let rootEl = this.root.el
    let rootID = this.root.id
    let wasLoading = this.root.isLoading()

    Browser.fetchPage(href, (status, html) => {
      if(status !== 200){ return Browser.redirect(href) }

      let div = document.createElement("div")
      div.innerHTML = html
      this.joinView(div.firstChild, null, href, newRoot => {
        if(!this.commitPendingLink(linkRef)){
          newRoot.destroy()
          return
        }
        callback && callback()
        this.destroyViewById(rootID)
        rootEl.replaceWith(newRoot.el)
        this.root = newRoot
        if(wasLoading){ this.root.showLoader() }
      })
    })
  }

  joinView(el, parentView, href, callback){
    if(this.getViewById(el.id)){ return }

    let view = new View(el, this, parentView, href)
    this.views[view.id] = view
    view.join(callback)
    return view
  }

  owner(childEl, callback){
    let view = this.getViewById(maybe(childEl.closest(PHX_VIEW_SELECTOR), "id"))
    if(view){ callback(view) }
  }

  getViewById(id){ return this.views[id] }

  onViewError(view){
    this.dropActiveElement(view)
  }

  destroyAllViews(){
    for(let id in this.views){ this.destroyViewById(id) }
  }

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
    this.bindTargetable({keyup: "keyup", keydown: "keydown"}, (e, type, view, target, phxEvent, phxTarget) => {
      view.pushKey(target, type, phxEvent, {
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
    this.bindTargetable({blur: "focusout", focus: "focusin"}, (e, type, view, targetEl, phxEvent, phxTarget) => {
      if(!phxTarget){
        view.pushEvent(type, targetEl, phxEvent, {type: "focus"})
      }
    })
    this.bindTargetable({blur: "blur", focus: "focus"}, (e, type, view, targetEl, phxEvent, phxTarget) => {
      // blur and focus are triggered on document and window. Discard one to avoid dups
      if(phxTarget && !phxTarget !== "window"){
        view.pushEvent(type, targetEl, phxEvent, {type: e.type})
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

  bindTargetable(events, callback){
    for(let event in events){
      let browserEventName = events[event]

      this.on(browserEventName, e => {
        let binding = this.binding(event)
        let bindTarget = this.binding("target")
        let targetPhxEvent = e.target.getAttribute && e.target.getAttribute(binding)
        if(targetPhxEvent && !e.target.getAttribute(bindTarget)){
          this.owner(e.target, view => callback(e, event, view, e.target, targetPhxEvent, null))
        } else {
          Browser.all(document, `[${binding}][${bindTarget}=window]`, el => {
            let phxEvent = el.getAttribute(binding)
            this.owner(el, view => callback(e, event, view, el, phxEvent, "window"))
          })
        }
      })
    }
  }

  bindClicks(){
    window.addEventListener("click", e => {
      let click = this.binding("click")
      let target = closestPhxBinding(e.target, click)
      let phxEvent = target && target.getAttribute(click)
      if(!phxEvent){ return }

      e.stopPropagation()

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
      }

      this.owner(target, view => view.pushEvent("click", target, phxEvent, meta))
    }, false)
  }

  bindNav(){
    if(!Browser.canPushState()){ return }
    window.onpopstate = (event) => {
      if(!this.registerNewLocation(window.location)){ return }

      let href = window.location.href

      if(this.root.isConnected()) {
        this.root.pushInternalLink(href)
      } else {
        this.replaceRoot(href)
      }
    }
    window.addEventListener("click", e => {
      let target = closestPhxBinding(e.target, PHX_LIVE_LINK)
      let phxEvent = target && target.getAttribute(PHX_LIVE_LINK)
      if(!phxEvent){ return }
      let href = target.href
      e.preventDefault()
      this.root.pushInternalLink(href, () => {
        Browser.pushState(phxEvent, {}, href)
        this.registerNewLocation(window.location)
      })
    }, false)
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
      this.owner(e.target, view => view.submitForm(e.target, phxEvent))
    }, false)

    for(let type of ["change", "input"]){
      this.on(type, e => {
        let input = e.target
        let key = input.type === "checkbox" ? "checked" : "value"
        if(this.prevInput === input && this.prevValue === input[key]){ return }

        this.prevInput = input
        this.prevValue = input[key]
        let phxEvent = input.form && input.form.getAttribute(this.binding("change"))
        if(!phxEvent){ return }
        this.owner(input, view => {
          if(DOM.isTextualInput(input)){
            input[PHX_HAS_FOCUSED] = true
          } else {
            this.setActiveElement(input)
          }
          view.pushInput(input, phxEvent, e)
        })
      }, false)
    }
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
  all(node, query, callback){
    node.querySelectorAll(query).forEach(callback)
  },

  canPushState(){ return (typeof(history.pushState) !== "undefined") },

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
      if(to !== window.location.href){ history[kind + "State"](meta, "", to) }
    } else {
      this.redirect(to)
    }
  },

  dispatchEvent(target, eventString){
    let event = null
    if(typeof(Event) === "function"){
      event = new Event(eventString)
    } else {
      event = document.createEvent("Event")
      event.initEvent(eventString, true, true)
    }
    target.dispatchEvent(event)
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
  }
}

let DOM = {

  disableForm(form, prefix){
    let disableWith = `${prefix}${PHX_DISABLE_WITH}`
    form.classList.add(PHX_LOADING_CLASS)
    Browser.all(form, `[${disableWith}]`, el => {
      let value = el.getAttribute(disableWith)
      el.setAttribute(`${disableWith}-restore`, el.innerText)
      el.innerText = value
    })
    Browser.all(form, "button", button => {
      button.setAttribute(PHX_DISABLED, button.disabled)
      button.disabled = true
    })
    Browser.all(form, "input", input => {
      input.setAttribute(PHX_READONLY, input.readOnly)
      input.readOnly = true
    })
  },

  restoreDisabledForm(form, prefix){
    let disableWith = `${prefix}${PHX_DISABLE_WITH}`
    form.classList.remove(PHX_LOADING_CLASS)

    Browser.all(form, `[${disableWith}]`, el => {
      let value = el.getAttribute(`${disableWith}-restore`)
      if(value){
        if(el.nodeName === "INPUT") {
          el.value = value
        } else {
          el.innerText = value
        }
        el.removeAttribute(`${disableWith}-restore`)
      }
    })
    Browser.all(form, "button", button => {
      let prev = button.getAttribute(PHX_DISABLED)
      if(prev){
        button.disabled = prev === "true"
        button.removeAttribute(PHX_DISABLED)
      }
    })
    Browser.all(form, "input", input => {
      let prev = input.getAttribute(PHX_READONLY)
      if(prev){
        input.readOnly = prev === "true"
        input.removeAttribute(PHX_READONLY)
      }
    })
  },

  discardError(el){
    let field = el.getAttribute && el.getAttribute(PHX_ERROR_FOR)
    if(!field) { return }
    let input = document.getElementById(field)

    if(field && !(input[PHX_HAS_FOCUSED] || input.form[PHX_HAS_SUBMITTED])){
      el.style.display = "none"
    }
  },

  isPhxChild(node){
    return node.getAttribute && node.getAttribute(PHX_PARENT_ID)
  },

  applyPhxUpdate(fromEl, toEl, phxUpdate, phxHook, changes){
    let type = toEl.getAttribute && toEl.getAttribute(phxUpdate)
    if(!type || type === "replace"){
      return false
    } else {
      DOM.mergeAttrs(fromEl, toEl)
    }

    switch(type){
      case "ignore": break
      case "append":
      case "prepend":
        let newHTML = toEl.innerHTML
        if(fromEl[PHX_PREV_APPEND] === newHTML){ break }

        fromEl[PHX_PREV_APPEND] = newHTML
        toEl.querySelectorAll("[id]").forEach(el => {
          let existing = fromEl.querySelector(`[id="${el.id}"]`)
          if(existing){
            changes.discarded.push(existing)
            el.remove()
            existing.replaceWith(el)
          }
        })
        let operation = type === "append" ? "beforeend" : "afterbegin"
        fromEl.insertAdjacentHTML(operation, toEl.innerHTML)
        fromEl.querySelectorAll(`[${phxHook}]`).forEach(el => changes.added.push(el))
        break
      default: throw new Error(`unsupported phx-update "${type}"`)
    }
    changes.updated.push({fromEl, toEl: fromEl})
    return true
  },

  patch(view, container, id, html){
    let changes = {added: [], updated: [], discarded: []}
    let focused = view.liveSocket.getActiveElement()
    let selectionStart = null
    let selectionEnd = null
    let phxUpdate = view.liveSocket.binding(PHX_UPDATE)
    let phxHook = view.liveSocket.binding(PHX_HOOK)
    let diffContainer = container.cloneNode()
    diffContainer.innerHTML = html

    if(DOM.isTextualInput(focused)){
      selectionStart = focused.selectionStart
      selectionEnd = focused.selectionEnd
    }

    morphdom(container, diffContainer, {
      childrenOnly: true,
      onBeforeNodeAdded: function(el){
        //input handling
        DOM.discardError(el)
        return el
      },
      onNodeAdded: function(el){
        // nested view handling
        if(DOM.isPhxChild(el) && view.ownsElement(el)){
          view.onNewChildAdded()
          return true
        } else {
          changes.added.push(el)
        }
      },
      onBeforeNodeDiscarded: function(el){
        // nested view handling
        if(DOM.isPhxChild(el)){
          view.liveSocket.destroyViewById(el.id)
          return true
        }
        changes.discarded.push(el)
      },
      onBeforeElUpdated: function(fromEl, toEl) {
        if(fromEl.isEqualNode(toEl)){ return false } // Skip subtree if both elems and children are equal

        if (fromEl.type === "number") {
          // We need to treat number inputs differently. Chrome will clear values if
          // report bad inputs so we want to do nothing
          // eg. 1..
          if (fromEl.validity && fromEl.validity.badInput) {
            return false
          }

          // Moreover, Firefox will delete the separator when going from `1.1` to `1.`
          // So we should never update the input if it is the currently active element
          // This is the "safe" route and approaches other communities like React have taken
          if (fromEl.ownerDocument.activeElement === fromEl) {
            return false
          }
        }

        if(DOM.applyPhxUpdate(fromEl, toEl, phxUpdate, phxHook, changes)){
          return false
        }

        // nested view handling
        if(DOM.isPhxChild(toEl)){
          let prevStatic = fromEl.getAttribute(PHX_STATIC)

          if(!Session.isEqual(toEl, fromEl)){
            view.liveSocket.destroyViewById(fromEl.id)
            view.onNewChildAdded()
          }
          DOM.mergeAttrs(fromEl, toEl)
          fromEl.setAttribute(PHX_STATIC, prevStatic)
          return false
        }

        // input handling
        if(fromEl.getAttribute && fromEl[PHX_HAS_SUBMITTED]){
          toEl[PHX_HAS_SUBMITTED] = true
        }
        if(fromEl[PHX_HAS_FOCUSED]){
          toEl[PHX_HAS_FOCUSED] = true
        }
        DOM.discardError(toEl)

        if(DOM.isTextualInput(fromEl) && fromEl === focused){
          DOM.mergeInputs(fromEl, toEl)
          changes.updated.push({fromEl, toEl: fromEl})
          return false
        } else {
          changes.updated.push({fromEl, toEl})
          return true
        }
      }
    })

    view.liveSocket.silenceEvents(() => {
      DOM.restoreFocus(focused, selectionStart, selectionEnd)
    })
    Browser.dispatchEvent(document, "phx:update")
    return changes
  },

  mergeAttrs(target, source){
    var attrs = source.attributes
    for (let i = 0, length = attrs.length; i < length; i++){
      let name = attrs[i].name
      let value = source.getAttribute(name)
      target.setAttribute(name, value)
    }
  },

  mergeInputs(target, source){
    DOM.mergeAttrs(target, source)
    target.readOnly = source.readOnly
  },

  restoreFocus(focused, selectionStart, selectionEnd){
    if(!DOM.isTextualInput(focused)){ return }
    if(focused.value === "" || focused.readOnly){ focused.blur()}
    focused.focus()
    if(focused.setSelectionRange && focused.type === "text" || focused.type === "textarea"){
      focused.setSelectionRange(selectionStart, selectionEnd)
    }
  },

  isTextualInput(el){
    return FOCUSABLE_INPUTS.indexOf(el.type) >= 0
  }
}

export class View {
  constructor(el, liveSocket, parentView, href){
    this.liveSocket = liveSocket
    this.parent = parentView
    this.newChildrenAdded = false
    this.gracefullyClosed = false
    this.el = el
    this.id = this.el.id
    this.view = this.el.getAttribute(PHX_VIEW)
    this.loaderTimer = null
    this.pendingDiffs = []
    this.href = href
    this.joinedOnce = false
    this.viewHooks = {}
    this.channel = this.liveSocket.channel(`lv:${this.id}`, () => {
      return {
        url: this.href || this.liveSocket.root.href,
        params: this.liveSocket.params(this.view),
        session: this.getSession(),
        static: this.getStatic()
      }
    })
    this.showLoader(LOADER_TIMEOUT)
    this.bindChannel()
  }

  isConnected(){ return this.channel.canPush() }

  getSession(){ return Session.get(this.el) }

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
    for(let id in this.viewHooks){ this.viewHooks[id].__trigger__("reconnected") }
    this.setContainerClasses(PHX_CONNECTED_CLASS)
  }

  log(kind, msgCallback){
    this.liveSocket.log(this, kind, msgCallback)
  }

  onJoin({rendered, live_redirect}){
    this.log("join", () => ["", JSON.stringify(rendered)])
    this.rendered = rendered
    this.hideLoader()
    let changes = DOM.patch(this, this.el, this.id, Rendered.toString(this.rendered))
    changes.added.push(this.el)
    Browser.all(this.el, `[${this.binding(PHX_HOOK)}]`, hookEl => changes.added.push(hookEl))
    this.triggerHooks(changes)
    this.joinNewChildren()
    if(live_redirect){
      let {kind, to} = live_redirect
      Browser.pushState(kind, {}, to)
    }
  }

  joinNewChildren(){
    Browser.all(document, `${PHX_VIEW_SELECTOR}[${PHX_PARENT_ID}="${this.id}"]`, el => {
      let child = this.liveSocket.getViewById(el.id)
      if(!child){
        this.liveSocket.joinView(el, this)
      }
    })
  }

  update(diff){
    if(isEmpty(diff)){ return }
    if(this.liveSocket.hasPendingLink()){ return this.pendingDiffs.push(diff) }

    this.log("update", () => ["", JSON.stringify(diff)])
    this.rendered = Rendered.mergeDiff(this.rendered, diff)
    let html = Rendered.toString(this.rendered)
    this.newChildrenAdded = false
    this.triggerHooks(DOM.patch(this, this.el, this.id, html))
    if(this.newChildrenAdded){ this.joinNewChildren() }
  }

  getHook(el){ return this.viewHooks[ViewHook.elementID(el)] }

  addHook(el){ if(ViewHook.elementID(el) || !el.getAttribute){ return }
    let callbacks = this.liveSocket.getHookCallbacks(el.getAttribute(this.binding(PHX_HOOK)))
    if(callbacks && this.ownsElement(el)){
      let hook = new ViewHook(this, el, callbacks)
      this.viewHooks[ViewHook.elementID(hook.el)] = hook
      hook.__trigger__("mounted")
    }
  }

  destroyHook(hook){
    hook.__trigger__("destroyed")
    delete this.viewHooks[ViewHook.elementID(hook.el)]
  }

  triggerHooks(changes){
    changes.updated.push({fromEl: this.el, toEl: this.el})
    changes.added.forEach(el => this.addHook(el))
    changes.updated.forEach(({fromEl, toEl}) => {
      let hook = this.getHook(fromEl)
      let phxAttr = this.binding(PHX_HOOK)
      if(hook && toEl.getAttribute && fromEl.getAttribute(phxAttr) === toEl.getAttribute(phxAttr)){
        hook.__trigger__("updated")
      } else if(hook){
        this.destroyHook(hook)
        this.addHook(fromEl)
      }
    })
    changes.discarded.forEach(el => {
      let hook = this.getHook(el)
      hook && this.destroyHook(hook)
    })
  }

  applyPendingUpdates(){
    this.pendingDiffs.forEach(diff => this.update(diff))
    this.pendingDiffs = []
  }

  onNewChildAdded(){
    this.newChildrenAdded = true
  }

  bindChannel(){
    this.channel.on("diff", (diff) => this.update(diff))
    this.channel.on("redirect", ({to, flash}) => this.onRedirect({to, flash}))
    this.channel.on("live_redirect", ({to, kind}) => this.onLiveRedirect({to, kind}))
    this.channel.on("external_live_redirect", ({to, kind}) => this.onExternalLiveRedirect({to, kind}))
    this.channel.on("session", ({token}) => this.el.setAttribute(PHX_SESSION, token))
    this.channel.onError(reason => this.onError(reason))
    this.channel.onClose(() => this.onGracefulClose())
  }

  onGracefulClose(){
    this.gracefullyClosed = true
    this.liveSocket.destroyViewById(this.id)
  }

  onExternalLiveRedirect({to, kind}){
    this.liveSocket.replaceRoot(to, () => Browser.pushState(kind, {}, to))
  }

  onLiveRedirect({to, kind}){
    Browser.pushState(kind, {}, to)
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
        if(!this.joinedOnce){ callback && callback(this) }
        this.joinedOnce = true
        this.onJoin(data)
      })
      .receive("error", resp => this.onJoinError(resp))
      .receive("timeout", () => this.onJoinError("timeout"))
  }

  onJoinError(resp){
    if(resp.redirect){ return this.onRedirect(resp.redirect) }
    if(resp.external_live_redirect){ return this.onExternalLiveRedirect(resp.external_live_redirect) }
    this.displayError()
    this.log("error", () => ["unable to join", resp])
  }

  onError(reason){
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
    return(
      this.channel.push(event, payload, PUSH_TIMEOUT).receive("ok", resp => {
        if(resp.diff){ this.update(resp.diff) }
        if(resp.redirect){ this.onRedirect(resp.redirect) }
        if(resp.live_redirect){ this.onLiveRedirect(resp.live_redirect) }
        if(resp.external_live_redirect){ this.onExternalLiveRedirect(resp.external_live_redirect) }
        onReply(resp)
      })
    )
  }

  pushEvent(type, el, phxEvent, meta){
    let prefix = this.binding("value-")
    for(let key of el.getAttributeNames()){ if(!key.startsWith(prefix)){ continue }
      meta[key.replace(prefix, "")] = el.getAttribute(key)
    }
    if(el.value !== undefined){ meta.value = el.value }

    this.pushWithReply("event", {
      type: type,
      event: phxEvent,
      value: meta
    })
  }

  pushKey(keyElement, kind, phxEvent, meta){
    if(keyElement.value !== undefined){ meta.value = keyElement.value }

    this.pushWithReply("event", {
      type: kind,
      event: phxEvent,
      value: meta
    })
  }

  pushInput(inputEl, phxEvent, e){
    this.pushWithReply("event", {
      type: "form",
      event: phxEvent,
      value: serializeForm(inputEl.form, {_target: e.target.name})
    })
  }

  pushFormSubmit(formEl, phxEvent, onReply){
    this.pushWithReply("event", {
      type: "form",
      event: phxEvent,
      value: serializeForm(formEl)
    }, onReply)
  }

  pushInternalLink(href, callback){
    if(!this.isLoading()){ this.showLoader(LOADER_TIMEOUT) }
    let linkRef = this.liveSocket.setPendingLink(href)
    this.pushWithReply("link", {url: href}, resp => {
      if(resp.link_redirect){
        this.liveSocket.replaceRoot(href, callback, linkRef)
      } else if(this.liveSocket.commitPendingLink(linkRef)){
        this.href = href
        this.applyPendingUpdates()
        this.hideLoader()
        callback && callback()
      }
    }).receive("timeout", () => Browser.redirect(window.location.href))
  }

  ownsElement(element){
    return element.getAttribute(PHX_PARENT_ID) === this.id ||
           maybe(element.closest(PHX_VIEW_SELECTOR), "id") === this.id
  }

  submitForm(form, phxEvent){
    let prefix = this.liveSocket.getBindingPrefix()
    form[PHX_HAS_SUBMITTED] = "true"
    DOM.disableForm(form, prefix)
    this.liveSocket.blurActiveElement(this)
    this.pushFormSubmit(form, phxEvent, () => {
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
    this.__callbacks = callbacks
    this.el = el
    this.viewName = view.view
    this.el.phxHookId = this.constructor.makeID()
    for(let key in this.__callbacks){ this[key] = this.__callbacks[key] }
  }

  pushEvent(event, payload = {}){
    this.__view.pushWithReply("event", {type: "hook", event: event, value: payload})
  }
  __trigger__(kind){
    let callback = this.__callbacks[kind]
    callback && callback.call(this)
  }
}

export default LiveSocket
