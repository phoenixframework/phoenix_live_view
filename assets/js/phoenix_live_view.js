/*
================================================================================
Phoenix LiveView Javascript Client 
================================================================================

## Usage

Instantiate a single LiveSocket instances to enable LiveView
client/server interaction, for example:

    import LiveSocket from "live_view"

    let liveSocket = new LiveSocket("/live")
    liveSocket.connect()

A LiveSocket can also be created from an existing socket:

    import { Socket } from "phoenix"
    import LiveSocket from "live_view"

    let socket = new Socket("/live")
    let liveSocket = new LiveSocket(socket)
    liveSocket.connect()

All options are passed directly to the `Phoenix.Socket` constructor,
except for the following LiveView specific options:

  * `bindingPrefix` - the prefix to use for phoenix bindings. Defaults `"phx-"`

## Events

### Click Events

When pushed, the value sent to the server will be chosen with the
following priority:

  - An optional `"phx-value"` binding on the clicked element
  - The clicked element's `value` property
  - An empty string

### Key Events

The onkeypress, onkeydown, and onkeyup events are supported via
the `phx-keypress`, `phx-keydown`, and `phx-keyup` bindings. By
default, the bound element will be the event listener, but an
optional `phx-target` may be provided which may be `"document"`,
`"window"`, or the DOM id of a target element.

When pushed, the value sent to the server will be the event's keyCode.

## Loading state and Errors

By default, the following classes are applied to the Live View's parent
container:

  - `"phx-connected"` - applied when the view has connected to the server
  - `"phx-disconnected"` - applied when the view is not connected to the server
  - `"phx-error"` - applied when an error occurs on the server. Note, this
    class will be applied in conjunction with `"phx-disconnected"` connection
    to the server is lost.

In addition to applied classes, an empty `"phx-loader"` exists adjacent
to every LiveView, and its display status is toggled automatically based on
connection and error class changes. This behavior may be disabled by overriding
`.phx-loader` in your css to `display: none!important`.
*/

import {Socket} from "phoenix"
import morphdom from "morphdom"

const PHX_VIEW = "data-phx-view"
const PHX_CONNECTED_CLASS = "phx-connected"
const PHX_DISCONNECTED_CLASS = "phx-disconnected"
const PHX_ERROR_CLASS = "phx-error"
const PHX_PARENT_ID = "data-phx-parent-id"
const PHX_VIEW_SELECTOR = `[${PHX_VIEW}]`
const PHX_ERROR_FOR = "data-phx-error-for"
const PHX_HAS_FOCUSED = "data-phx-has-focused"
const PHX_BOUND = "data-phx-bound"
const FOCUSABLE_INPUTS = ["text", "textarea", "password"]
const PHX_HAS_SUBMITTED = "data-phx-has-submitted"
const PHX_SESSION = "data-phx-session"
const LOADER_TIMEOUT = 100
const LOADER_ZOOM = 2
const BINDING_PREFIX = "phx-"
const PUSH_TIMEOUT = 20000

export let debug = (view, kind, msg, obj) => {
  console.log(`${view.id} ${kind}: ${msg} - `, obj)
}

let isObject = (obj) => {
  return typeof(obj) === "object" && !(obj instanceof Array)
}

let isEmpty = (obj) => {
  return Object.keys(obj).length === 0
}

let maybe = (el, key) => {
  if(el){
    return el[key]
  } else {
    return null
  }
}

let recursiveMerge = (target, source) => {
  for(let key in source){
    let val = source[key]
    if(isObject(val) && target[key]){
      recursiveMerge(target[key], val)
    } else {
      target[key] = val
    }
  }
}

let Rendered = {

  mergeDiff(source, diff){
    if(this.isNewFingerprint(diff)){
      return diff
    } else {
      recursiveMerge(source, diff)
      return source
    }
  },

  isNewFingerprint(diff){ return diff.static },

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
  constructor(urlOrSocket, opts = {}){
    this.unloaded = false
    window.addEventListener("beforeunload", e => {
      this.unloaded = true
    })
    this.socket = this.buildSocket(urlOrSocket, opts)
    this.socket.onOpen(() => this.unloaded = false)
    this.bindingPrefix = opts.bindingPrefix || BINDING_PREFIX
    this.opts = opts
    this.views = {}
    this.viewLogger = opts.viewLogger
    this.activeElement = null
    this.prevActive = null
  }

  buildSocket(urlOrSocket, opts){
    if(typeof urlOrSocket !== "string"){ return urlOrSocket }

    if(!opts.reconnectAfterMs){
      opts.reconnectAfterMs = (tries) => {
        if(this.unloaded){
          return [50, 100, 250][tries - 1] || 500
        } else {
          return [1000, 2000, 5000, 10000][tries - 1] || 10000
        }
      }
    }
    return new Socket(urlOrSocket, opts)
  }

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

  disconnect(){ return this.socket.disconnect()}

  channel(topic, params){ return this.socket.channel(topic, params || {}) }

  joinRootViews(){
    document.querySelectorAll(`${PHX_VIEW_SELECTOR}:not([${PHX_PARENT_ID}])`).forEach(rootEl => {
      this.joinView(rootEl)
    })
  }

  joinView(el, parentView){
    let view = new View(el, this, parentView)
    this.views[view.id] = view
    view.join()
  }

  getViewById(id){ return this.views[id] }

  onViewError(view){
    this.dropActiveElement(view)
  }

  destroyViewById(id){
    let view = this.views[id]
    if(view){
      delete this.views[view.id]
      view.destroy()
    }
  }

  getBindingPrefix(){ return this.bindingPrefix }

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
}

let Browser = {
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

  discardError(el){
    let field = el.getAttribute && el.getAttribute(PHX_ERROR_FOR)
    if(!field) { return }
    let input = document.getElementById(field)

    if(field && !(input.getAttribute(PHX_HAS_FOCUSED) || input.form.getAttribute(PHX_HAS_SUBMITTED))){
      el.style.display = "none"
    }
  },

  isPhxChild(node){
    return node.getAttribute && node.getAttribute(PHX_PARENT_ID)
  },

  patch(view, container, id, html){
    let focused = view.liveSocket.getActiveElement()
    let selectionStart = null
    let selectionEnd = null
    if(DOM.isTextualInput(focused)){
      selectionStart = focused.selectionStart
      selectionEnd = focused.selectionEnd
    }

    morphdom(container, `<div>${html}</div>`, {
      childrenOnly: true,
      onBeforeNodeAdded: function(el){
        //input handling
        DOM.discardError(el)
        return el
      },
      onNodeAdded: function(el){
        // nested view handling
        if(DOM.isPhxChild(el) && view.ownsElement(el)){
          view.onNewChildAdded(el)
          return true
        }
        view.maybeBindAddedNode(el)
      },
      onBeforeNodeDiscarded: function(el){
        // nested view handling
        if(DOM.isPhxChild(el)){
          view.liveSocket.destroyViewById(el.id)
          return true
        }
      },
      onBeforeElUpdated: function(fromEl, toEl) {
        // nested view handling
        if(DOM.isPhxChild(toEl)){
          DOM.mergeAttrs(fromEl, toEl)
          return false
        }

        // input handling
        if(fromEl.getAttribute && fromEl.getAttribute(PHX_HAS_SUBMITTED)){
          toEl.setAttribute(PHX_HAS_SUBMITTED, true)
        }
        if(fromEl.getAttribute && fromEl.getAttribute(PHX_HAS_FOCUSED)){
          toEl.setAttribute(PHX_HAS_FOCUSED, true)
        }
        DOM.discardError(toEl)

        if(DOM.isTextualInput(fromEl) && fromEl === focused){
          DOM.mergeInputs(fromEl, toEl)
          return false
        } else {
          return true
        }
      }
    })

    DOM.restoreFocus(focused, selectionStart, selectionEnd)
    document.dispatchEvent(new Event("phx:update"))
  },

  mergeAttrs(target, source){
    source.getAttributeNames().forEach(name => {
      let value = source.getAttribute(name)
      target.setAttribute(name, value)
    })
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

class View {
  constructor(el, liveSocket, parentView){
    this.liveSocket = liveSocket
    this.parent = parentView
    this.newChildrenAdded = false
    this.gracefullyClosed = false
    this.el = el
    this.prevKey = null
    this.bindingPrefix = liveSocket.getBindingPrefix()
    this.loader = this.el.nextElementSibling
    this.id = this.el.id
    this.view = this.el.getAttribute(PHX_VIEW)
    this.hasBoundUI = false
    this.channel = this.liveSocket.channel(`lv:${this.id}`, () => {
      return {session: this.getSession()}
    })
    this.loaderTimer = setTimeout(() => this.showLoader(), LOADER_TIMEOUT)
    this.bindChannel()
  }

  getSession(){
    return this.el.getAttribute(PHX_SESSION)|| this.parent.getSession()
  }

  destroy(callback = function(){}){
    if(this.hasGracefullyClosed()){
      this.log("destroyed", () => ["the server view has gracefully closed"])
      callback()
    } else {
      this.log("destroyed", () => ["the child has been removed from the parent"])
      this.channel.leave()
        .receive("ok", callback)
        .receive("error", callback)
        .receive("timeout", callback)
    }
  }

  hideLoader(){
    clearTimeout(this.loaderTimer)
    this.loader.style.display = "none"
  }

  showLoader(){
    clearTimeout(this.loaderTimer)
    this.el.classList = PHX_DISCONNECTED_CLASS
    this.loader.style.display = "block"
    let middle = Math.floor(this.el.clientHeight / LOADER_ZOOM)
    this.loader.style.top = `-${middle}px`
  }

  log(kind, msgCallback){
    this.liveSocket.log(this, kind, msgCallback)
  }
  
  onJoin({rendered}){
    this.log("join", () => ["", JSON.stringify(rendered)])
    this.rendered = rendered
    this.hideLoader()
    this.el.classList = PHX_CONNECTED_CLASS
    DOM.patch(this, this.el, this.id, Rendered.toString(this.rendered))
    if(!this.hasBoundUI){ this.bindUI() }
    this.hasBoundUI = true
    this.joinNewChildren()
  }

  joinNewChildren(){
    let selector = `${PHX_VIEW_SELECTOR}[${PHX_PARENT_ID}="${this.id}"]`
    document.querySelectorAll(selector).forEach(childEl => {
      let child = this.liveSocket.getViewById(childEl.id)
      if(!child){
        this.liveSocket.joinView(childEl, this)
      }
    })
  }

  update(diff){
    if(isEmpty(diff)){ return }
    this.log("update", () => ["", JSON.stringify(diff)])
    this.rendered = Rendered.mergeDiff(this.rendered, diff)
    let html = Rendered.toString(this.rendered)
    this.newChildrenAdded = false
    DOM.patch(this, this.el, this.id, html)
    if(this.newChildrenAdded){ this.joinNewChildren() }
  }

  onNewChildAdded(el){
    this.newChildrenAdded = true
  }

  bindChannel(){
    this.channel.on("render", (diff) => this.update(diff))
    this.channel.on("redirect", ({to, flash}) => Browser.redirect(to, flash) )
    this.channel.on("session", ({token}) => this.el.setAttribute(PHX_SESSION, token))
    this.channel.onError(reason => this.onError(reason))
    this.channel.onClose(() => this.onGracefulClose())
  }

  onGracefulClose(){
    this.gracefullyClosed = true
    this.liveSocket.destroyViewById(this.id)
  }

  hasGracefullyClosed(){ return this.gracefullyClosed }

  join(){
    if(this.parent){ this.parent.channel.onError(() => this.channel.leave())}
    this.channel.join()
      .receive("ok", data => this.onJoin(data))
      .receive("error", resp => this.onJoinError(resp))
  }

  onJoinError(resp){
    this.displayError()
    this.log("error", () => ["unable to join", resp])
  }

  onError(reason){
    this.log("error", () => ["view crashed", reason])
    this.liveSocket.onViewError(this)
    document.activeElement.blur()
    this.displayError()
  }

  displayError(){
    this.showLoader()
    this.el.classList = `${PHX_DISCONNECTED_CLASS} ${PHX_ERROR_CLASS}`
  }

  pushWithReply(event, payload, onReply = function(){ }){
    this.channel.push(event, payload, PUSH_TIMEOUT)
      .receive("ok", diff => {
        this.update(diff)
        onReply()
      })
  }

  pushClick(clickedEl, event, phxEvent){
    event.preventDefault()
    let val = clickedEl.getAttribute(this.binding("value")) || clickedEl.value || ""
    this.pushWithReply("event", {
      type: "click",
      event: phxEvent,
      id: clickedEl.id,
      value: val
    })
  }

  pushKey(keyElement, kind, event, phxEvent){
    if(this.prevKey === event.key){ return }
    this.prevKey = event.key
    this.pushWithReply("event", {
      type: `key${kind}`,
      event: phxEvent,
      id: event.target.id,
      value: keyElement.value || event.key
    })
  }

  pushInput(inputEl, event, phxEvent){
    this.pushWithReply("event", {
      type: "form",
      event: phxEvent,
      id: event.target.id,
      value: this.serializeForm(inputEl.form)
    })
  }
  
  pushFormSubmit(formEl, event, phxEvent, onReply){
    if(event){ event.target.disabled = true }
    this.pushWithReply("event", {
      type: "form",
      event: phxEvent,
      id: event && event.target.id || null,
      value: this.serializeForm(formEl)
    }, onReply)
  }

  eachChild(selector, each){
    return this.el.querySelectorAll(selector).forEach(child => {
      if(this.ownsElement(child)){ each(child) }
    })
  }

  ownsElement(element){
    return element.getAttribute(PHX_PARENT_ID) === this.id ||
           maybe(element.closest(PHX_VIEW_SELECTOR), "id") === this.id
  }

  bindUI(){
    this.bindForms()
    this.eachChild(`[${this.binding("click")}]`, el => this.bindClick(el))
    this.eachChild(`[${this.binding("keyup")}]`, el => this.bindKey(el, "up"))
    this.eachChild(`[${this.binding("keydown")}]`, el => this.bindKey(el, "down"))
    this.eachChild(`[${this.binding("keypress")}]`, el => this.bindKey(el, "press"))
  }

  bindClick(el){
    this.bindOwnAddedNode(el, el, this.binding("click"), phxEvent => {
      el.addEventListener("click", e => this.pushClick(el, e, phxEvent))
    })
  }

  bindKey(el, kind){
    let event = `key${kind}`
    this.bindOwnAddedNode(el, el, this.binding(event), (phxEvent) => {
      let phxTarget = this.target(el)
      phxTarget.addEventListener(event, e => {
        this.pushKey(el, kind, e, phxEvent)
      })
    })
  }

  bindForms(){
    let change = this.binding("change")
    this.eachChild(`form[${change}] input`, input => {
      this.bindChange(input)
    })
    this.eachChild(`form[${change}] select`, input => {
      this.bindChange(input)
    })
    this.eachChild(`form[${change}] textarea`, textarea => {
      this.bindChange(textarea)
    })

    let submit = this.binding("submit")
    this.eachChild(`form[${submit}]`, form => {
      this.bindSubmit(form)
    })
  }

  bindChange(input){
    this.onInput(input, (phxEvent, e) => {
      if(DOM.isTextualInput(input)){
        input.setAttribute(PHX_HAS_FOCUSED, true)
      } else {
        this.liveSocket.setActiveElement(e.target)
      }
      this.pushInput(input, e, phxEvent)
    })
  }

  bindSubmit(form){
    this.bindOwnAddedNode(form, form, this.binding("submit"), phxEvent => {
      form.addEventListener("submit", e => {
        e.preventDefault()
        this.submitForm(form, phxEvent, e)
      })
      this.scheduleSubmit(form, phxEvent)
    })
  }

  submitForm(form, phxEvent, e){
    form.setAttribute(PHX_HAS_SUBMITTED, "true")
    form.querySelectorAll("input").forEach(input => input.readOnly = true)
    this.liveSocket.blurActiveElement(this)
    this.pushFormSubmit(form, e, phxEvent, () => {
      this.liveSocket.restorePreviouslyActiveFocus()
    })
  }

  scheduleSubmit(form, phxEvent){
    let everyMs = parseInt(form.getAttribute(this.binding("submit-every")))
    if(everyMs && this.el.contains(form)){
      setTimeout(() => {
        this.submitForm(form, phxEvent)
        this.scheduleSubmit(form, phxEvent)
      }, everyMs)
    }
  }

  maybeBindAddedNode(el){
    if(!el.getAttribute || !this.ownsElement(el)) { return }

    this.bindClick(el)
    this.bindSubmit(el)
    this.bindChange(el)
    this.bindKey(el, "up")
    this.bindKey(el, "down")
    this.bindKey(el, "press")

  }

  binding(kind){ return `${this.bindingPrefix}${kind}` }

  // private

  serializeForm(form){
   return((new URLSearchParams(new FormData(form))).toString())
  }

  bindOwnAddedNode(el, targetEl, event, callback){
    if(targetEl && !targetEl.getAttribute){ return }
    let phxEvent = targetEl.getAttribute(event)

    if(phxEvent && !el.getAttribute(PHX_BOUND) && this.ownsElement(el)){
      el.setAttribute(PHX_BOUND, true)
      callback(phxEvent)
    }
  }

  onInput(input, callback){
    if(!input.form){ return }
    this.bindOwnAddedNode(input, input.form, this.binding("change"), phxEvent => {
      let event = input.type === "radio" ? "change" : "input"
      input.addEventListener(event, e => callback(phxEvent, e))
    })
  }

  target(el){
    let target = el.getAttribute(this.binding("target"))
    if(target === "window"){
      return window
    }else if(target === "document"){
      return document
    } else if(target){
      return document.getElementById(target)
    } else {
      return el
    }
  }
}