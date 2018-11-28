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

By default, the following classes are applied to the liveview's parent
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

const PHX_VIEW_SELECTOR = "[data-phx-view]"
const PHX_CONNECTED_CLASS = "phx-connected"
const PHX_DISCONNECTED_CLASS = "phx-disconnected"
const PHX_ERROR_CLASS = "phx-error"
const PHX_PARENT_ID = "data-phx-parent-id"
const PHX_ERROR_FOR = "data-phx-error-for"
const PHX_HAS_FOCUSED = "data-phx-has-focused"
const PHX_BOUND = "data-phx-bound"
const FOCUSABLE_INPUTS = ["text", "textarea", "password"]
const PHX_HAS_SUBMITTED = "data-phx-has-submitted"
const PHX_SESSION = "data-phx-session"
const LOADER_TIMEOUT = 100
const LOADER_ZOOM = 2
const BINDING_PREFIX = "phx-"

let isObject = (obj) => {
  return typeof(obj) === "object" && !(obj instanceof Array)
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

  mergeDiff(source, diff){ recursiveMerge(source, diff) },

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

export default class LiveSocket {
  constructor(url, opts = {}){
    this.bindingPrefix = opts.bindingPrefix || BINDING_PREFIX
    this.url = url
    this.opts = opts
    this.views = {}
    this.activeElement = null
    this.socket = new Socket(url, opts)
  }

  connect(){
    if(["complete", "loaded","interactive"].indexOf(document.readyState) >= 0){
      this.joinViewChannels()
    } else {
      document.addEventListener("DOMContentLoaded", () => {
        this.joinViewChannels()
      })
    }
    return this.socket.connect()
  }

  disconnect(){ return this.socket.disconnect()}

  channel(topic, params){ return this.socket.channel(topic, params || {}) }

  joinViewChannels(){
    document.querySelectorAll(PHX_VIEW_SELECTOR).forEach(el => this.joinView(el))
  }

  joinView(el, parentView){
    let view = new View(el, this, parentView)
    this.views[view.id] = view
    view.join()
  }

  destroyViewById(id){
    console.log("destroying", id)
    let view = this.views[id]
    if(!view){ throw `cannot destroy view for id ${id} as it does not exist` }
    view.destroy(() => delete this.views[view.id])
  }

  getBindingPrefix(){ return this.bindingPrefix }

  setActiveElement(target){
    if(this.activeElement === target){ return }
    this.activeElement = target
    let cancel = () => {
      if(target === this.activeElement){ this.activeElement = null }
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
        if(DOM.isPhxChild(el)){
          setTimeout(() => view.liveSocket.joinView(el, view), 1)
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
        if(DOM.isPhxChild(toEl)){ return false }

        // input handling
        if(fromEl.getAttribute && fromEl.getAttribute(PHX_HAS_SUBMITTED)){
          toEl.setAttribute(PHX_HAS_SUBMITTED, true)
        }
        if(fromEl.getAttribute && fromEl.getAttribute(PHX_HAS_FOCUSED)){
          toEl.setAttribute(PHX_HAS_FOCUSED, true)
        }
        DOM.discardError(toEl)

        if(fromEl === focused){
          return false
        } else {
          return true
        }
      }
    })

    DOM.restoreFocus(focused, selectionStart, selectionEnd)
    document.dispatchEvent(new Event("phx:update"))
  },

  restoreFocus(focused, selectionStart, selectionEnd){
    if(!DOM.isTextualInput(focused)){ return }
    if(focused.value === ""){ focused.blur()}
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
    this.statics = []
    this.dynamics = []
    this.parent = parentView
    this.el = el
    this.bindingPrefix = liveSocket.getBindingPrefix()
    this.loader = this.el.nextElementSibling
    this.id = this.el.id
    this.view = this.el.getAttribute("data-view")
    this.hasBoundUI = false
    this.joinParams = {session: this.getSession()}
    this.channel = this.liveSocket.channel(`views:${this.id}`, () => this.joinParams)
    this.loaderTimer = setTimeout(() => this.showLoader(), LOADER_TIMEOUT)
    this.bindChannel()
  }

  getSession(){
    return this.el.getAttribute(PHX_SESSION)|| this.parent.getSession()
  }

  destroy(callback){
    this.channel.leave()
      .receive("ok", callback)
      .receive("error", callback)
      .receive("timeout", callback)
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
  
  onJoin({rendered}){
    // console.log("join", JSON.stringify(rendered))
    this.rendered = rendered
    this.hideLoader()
    this.el.classList = PHX_CONNECTED_CLASS
    DOM.patch(this, this.el, this.id, Rendered.toString(this.rendered))
    if(!this.hasBoundUI){ this.bindUI() }
    this.hasBoundUI = true
  }

  update(diff){
    // console.log("update", JSON.stringify(diff))
    Rendered.mergeDiff(this.rendered, diff)
    let html = Rendered.toString(this.rendered)
    DOM.patch(this, this.el, this.id, html)
  }

  bindChannel(){
    this.channel.on("render", (diff) => this.update(diff))
    this.channel.on("redirect", ({to, flash}) => Browser.redirect(to, flash) )
    this.channel.on("session", ({token}) => this.joinParams.session = token)
    this.channel.onError(() => this.onError())
  }

  join(){
    this.channel.join()
      .receive("ok", data => this.onJoin(data))
      .receive("error", resp => this.onJoinError(resp))
  }

  onJoinError(resp){
    this.displayError()
    console.log("Unable to join", resp)
  }

  onError(){
    document.activeElement.blur()
    this.displayError()
  }

  displayError(){
    this.showLoader()
    this.el.classList = `${PHX_DISCONNECTED_CLASS} ${PHX_ERROR_CLASS}`
  }

  pushClick(clickedEl, event, phxEvent){
    event.preventDefault()
    let val = clickedEl.getAttribute(this.binding("value")) || clickedEl.value || ""
    this.channel.push("event", {
      type: "click",
      event: phxEvent,
      id: clickedEl.id,
      value: val
    })
  }

  pushKey(keyElement, kind, event, phxEvent){
    this.channel.push("event", {
      type: `key${kind}`,
      event: phxEvent,
      id: event.target.id,
      value: keyElement.value || event.keyCode
    })
  }

  pushInput(inputEl, event, phxEvent){
    this.channel.push("event", {
      type: "form",
      event: phxEvent,
      id: event.target.id,
      value: this.serializeForm(inputEl.form)
    })
  }
  
  pushFormSubmit(formEl, event, phxEvent){
    event.target.disabled = true
    this.channel.push("event", {
      type: "form",
      event: phxEvent,
      id: event.target.id,
      value: this.serializeForm(formEl)
    })
  }

  eachChild(selector, each){
    return this.el.querySelectorAll(selector).forEach(child => {
      if(this.ownsElement(child)){ each(child) }
    })
  }

  ownsElement(element){
    return element.closest(PHX_VIEW_SELECTOR).id === this.id
  }

  bindUI(){
    this.bindForms()
    this.eachChild(`[${this.binding("click")}]`, el => this.bindClick(el))
    this.eachChild(`[${this.binding("keyup")}]`, el => this.bindKey(el, "up"))
    this.eachChild(`[${this.binding("keydown")}]`, el => this.bindKey(el, "down"))
    this.eachChild(`[${this.binding("keypress")}]`, el => this.bindKey(el, "press"))
  }

  bindClick(el){
    let phxEvent = el.getAttribute(this.binding("click"))
    if(phxEvent && !el.getAttribute(PHX_BOUND) && this.ownsElement(el)){
      el.setAttribute(PHX_BOUND, true)
      el.addEventListener("click", e => this.pushClick(el, e, phxEvent))
    } 
  }

  bindKey(el, kind){
    let event = `key${kind}`
    let phxEvent = el.getAttribute(this.binding(event))
    if(phxEvent){
      let phxTarget = this.target(el)
      phxTarget.addEventListener(event, e => {
        this.pushKey(el, kind, e, phxEvent)
      })
    }
  }

  bindForms(){
    let change = this.binding("change")
    this.eachChild(`form[${change}] input`, input => {
      let phxEvent = input.form.getAttribute(change)
      this.onInput(input, e => {
        if(DOM.isTextualInput(input)){
          input.setAttribute(PHX_HAS_FOCUSED, true)
        } else {
          this.liveSocket.setActiveElement(e.target)
        }
        this.pushInput(input, e, phxEvent)
      })
    })

    let submit = this.binding("submit")
    this.eachChild(`form[${submit}]`, form => {
      let phxEvent = form.getAttribute(submit)
      form.addEventListener("submit", e => {
        e.preventDefault()
        form.setAttribute(PHX_HAS_SUBMITTED, "true")
        this.pushFormSubmit(form, e, phxEvent)
      })
    })
  }

  maybeBindAddedNode(el){ if(!el.getAttribute){ return }
    this.bindClick(el)
    this.bindKey(el, "up")
    this.bindKey(el, "down")
    this.bindKey(el, "press")
  }

  binding(kind){ return `${this.bindingPrefix}${kind}` }

  // private

  serializeForm(form){
   return((new URLSearchParams(new FormData(form))).toString())
  }

  onInput(input, callback){
    let event = input.type === "radio" ? "change" : "input"
    input.addEventListener(event, callback)
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

