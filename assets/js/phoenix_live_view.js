/*
================================================================================
Phoenix LiveView JavaScript Client
================================================================================

## Usage

Instantiate a single LiveSocket instance to enable LiveView
client/server interaction, for example:

    import LiveSocket from "phoenix_live_view"

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

The onkeydown and onkeyup events are supported via
the `phx-keydown`, and `phx-keyup` bindings. By
default, the bound element will be the event listener, but an
optional `phx-target` may be provided which may be `"window"`.

When pushed, the value sent to the server will be the event's `key`.

### Focus and Blur Events

Focus and blur events may be bound to DOM elements that emit
such events, using the `phx-blur`, and `phx-focus` bindings, for example:

    <input name="email" phx-focus="myfocus" phx-blur="myblur"/>

To detect when the page itself has receive focus or blur,
`phx-target` may be specified as `"window"`. Like other
bindings, a `phx-value` can be provided on the bound element,
otherwise the input's value will be used. For example:

    <div class="container"
        phx-focus="page-active"
        phx-blur="page-inactive"
        phx-target="window">
    ...
    </div>

## Forms and input handling

The JavaScript client is always the source of truth for current
input values. For any given input with focus, LiveView will never
overwrite the input's current value, even if it deviates from
the server's rendered updates. This works well for updates where
major side effects are not expected, such as form validation errors,
or additive UX around the user's input values as they fill out a form.
For these use cases, the `phx-change` input does not concern itself
with disabling input editing while an event to the server is inflight.

The `phx-submit` event is used for form submissions where major side-effects
typically happen, such as rendering new containers, calling an external
service, or redirecting to a new page. For these use-cases, the form inputs
are set to `readonly` on submit, and any submit button is disabled until
the client gets an acknowledgment that the server has processed the
`phx-submit` event. Following an acknowledgment, any updates are patched
to the DOM as normal, and the last input with focus is restored if the
user has not otherwise focused on a new input during submission.

To handle latent form submissions, any HTML tag can be annotated with
`phx-disable-with`, which swaps the element's `innerText` with the provided
value during form submission. For example, the following code would change
the "Save" button to "Saving...", and restore it to "Save" on acknowledgment:

    <button type="submit" phx-disable-with="Saving...">Save</button>


## Loading state and Errors

By default, the following classes are applied to the live view's parent
container:

  - `"phx-connected"` - applied when the view has connected to the server
  - `"phx-disconnected"` - applied when the view is not connected to the server
  - `"phx-error"` - applied when an error occurs on the server. Note, this
    class will be applied in conjunction with `"phx-disconnected"` if connection
    to the server is lost.

When a form bound with `phx-submit` is submitted, the `phx-loading` class
is applied to the form, which is removed on update.

## Interop with client controlled DOM

A container can be marked with `phx-ignore`, allowing the DOM patch
operations to avoid updating or removing portions of the LiveView. This
is useful for client-side interop with existing libraries that do their
own DOM operations.
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
const PHX_HAS_FOCUSED = "data-phx-has-focused"
const PHX_BOUND = "data-phx-bound"
const FOCUSABLE_INPUTS = ["text", "textarea", "number", "email", "password", "search", "tel", "url"]
const PHX_HAS_SUBMITTED = "data-phx-has-submitted"
const PHX_SESSION = "data-phx-session"
const PHX_STATIC = "data-phx-static"
const PHX_READONLY = "data-phx-readonly"
const PHX_DISABLED = "data-phx-disabled"
const PHX_DISABLE_WITH = "disable-with"
const LOADER_TIMEOUT = 1
const BEFORE_UNLOAD_LOADER_TIMEOUT = 500
const BINDING_PREFIX = "phx-"
const PUSH_TIMEOUT = 30000
const LINK_HEADER = "x-requested-with"
const TAP_START_CLASS = "tap-started"

export let debug = (view, kind, msg, obj) => {
  console.log(`${view.id} ${kind}: ${msg} - `, obj)
}

let closestPhxBinding = (el, binding) => {
  do {
    if(el.matches(`[${binding}]`)){ return el }
    el = el.parentElement || el.parentNode
  } while(el !== null && el.nodeType === 1 && !el.matches(PHX_VIEW_SELECTOR))
  return null
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

let serializeForm = (form) => {
  let formData = new FormData(form)
  let params = new URLSearchParams()
  for(let [key, val] of formData.entries()){ params.append(key, val) }
  return params.toString()
}

let recursiveMerge = (target, source) => {
  for(let key in source){
    let val = source[key]
    let targetVal = target[key]
    if(isObject(val) && targetVal){
      if(isObject(targetVal) && targetVal.dynamics && !val.dynamics){ delete targetVal.dynamics}
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
    this.params = opts.params || {}
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

  isUnloaded(){ return this.unloaded }

  getBindingPrefix(){ return this.bindingPrefix }

  binding(kind){ return `${this.getBindingPrefix()}${kind}` }

  channel(topic, params){ return this.socket.channel(topic, params || {}) }

  joinRootViews(){
    Browser.all(document, `${PHX_VIEW_SELECTOR}:not([${PHX_PARENT_ID}])`, rootEl => {
      let view = this.joinView(rootEl, null, this.getHref())
      this.root = this.root || view
    })
  }

  replaceRoot(href, linkRef = this.setPendingLink(href)){
    this.root.showLoader(LOADER_TIMEOUT)
    Browser.fetchPage(href, (status, html) => {
      if(status !== 200){ return Browser.redirect(href) }
      
      let div = document.createElement("div")
      div.innerHTML = html
      this.joinView(div.firstChild, null, href, newRoot => {
        if(!this.commitPendingLink(linkRef)){
          newRoot.destroy()
          return
        }
        Browser.pushState("push", {}, href)
        let rootEl = this.root.el
        let wasLoading = this.root.isLoading()
        this.destroyViewById(this.root.id)
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
    if ("ontouchstart" in window) {
      this.bindTouchstarts()
      this.bindTouchmoves()
      this.bindClicks("touchend")
    } else {
      this.bindClicks("click")
    }

    this.bindNav()
    this.bindForms()
    this.bindTargetable({keyup: "keyup", keydown: "keydown"}, (e, type, view, target, phxEvent, phxTarget) => {
      view.pushKey(target, type, e, phxEvent)
    })
    this.bindTargetable({blur: "focusout", focus: "focusin"}, (e, type, view, targetEl, phxEvent, phxTarget) => {
      if(!phxTarget){
        view.pushEvent(type, targetEl, phxEvent)
      }
    })
    this.bindTargetable({blur: "blur", focus: "focus"}, (e, type, view, targetEl, phxEvent, phxTarget) => {
      // blur and focus are triggered on document and window. Discard one to avoid dups
      if(phxTarget && !phxTarget !== "window"){
        view.pushEvent(type, targetEl, phxEvent)
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

  bindTouchstarts(){
    window.addEventListener("touchstart", e => {
      e.target.classList.add(TAP_START_CLASS)
    })
  }

  bindTouchmoves(){
    window.addEventListener("touchmove", e => {
      e.target.classList.remove(TAP_START_CLASS)
    })
  }

  bindClicks(listener){
    window.addEventListener(listener, e => {
      const el = e.target

      if (listener === "touchend") {
        // not a tap
        if (!el.classList.contains(TAP_START_CLASS)) return

        // is a tap
        el.classList.remove(TAP_START_CLASS)
      }

      let click = this.binding("click")
      let target = closestPhxBinding(el, click)
      let phxEvent = target && target.getAttribute(click)
      if(!phxEvent){ return }
      e.preventDefault()
      this.owner(target, view => view.pushEvent("click", target, phxEvent))
    }, false)
  }

  bindNav(){
    if(!Browser.canPushState()){ return }
    window.onpopstate = (event) => {
      let href = window.location.href
      if (this.root.isConnected()) {
        this.root.pushInternalLink(href)
      } else {
        this.replaceRoot(href)
      }
    }
    window.addEventListener("click", e => {
      let target = closestPhxBinding(e.target, PHX_LIVE_LINK)
      let phxEvent = target && target.getAttribute(PHX_LIVE_LINK)
      if (!phxEvent) { return }
      let href = target.href
      e.preventDefault()
      this.root.pushInternalLink(href, () => Browser.pushState(phxEvent, {}, href))
    }, false)
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
            input.setAttribute(PHX_HAS_FOCUSED, true)
          } else {
            this.setActiveElement(input)
          }
          view.pushInput(input, phxEvent)
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
    req.setRequestHeader("cache-control", "max-age=0, no-cache, must-revalidate, post-check=0, pre-check=0")
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

  pushState(kind, meta, to, callback){ 
    if(this.canPushState()){
      if(to !== window.location.href){ history[kind + "State"](meta, "", to) }
      callback && callback()
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
        el.innerText = value
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

    if(field && !(input.getAttribute(PHX_HAS_FOCUSED) || input.form.getAttribute(PHX_HAS_SUBMITTED))){
      el.style.display = "none"
    }
  },

  isPhxChild(node){
    return node.getAttribute && node.getAttribute(PHX_PARENT_ID)
  },

  isIgnored(el, phxIgnore){
    return (el.getAttribute && el.getAttribute(phxIgnore) != null) ||
           (el.parentNode && el.parentNode.getAttribute(phxIgnore) != null)
  },

  patch(view, container, id, html){
    let focused = view.liveSocket.getActiveElement()
    let selectionStart = null
    let selectionEnd = null
    let phxIgnore = view.liveSocket.binding("ignore")

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
          view.onNewChildAdded()
          return true
        }
      },
      onBeforeNodeDiscarded: function(el){
        if(DOM.isIgnored(el, phxIgnore)){ return false }
        // nested view handling
        if(DOM.isPhxChild(el)){
          view.liveSocket.destroyViewById(el.id)
          return true
        }
      },
      onBeforeElUpdated: function(fromEl, toEl) {
        if(DOM.isIgnored(fromEl, phxIgnore)){ return false }
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

    view.liveSocket.silenceEvents(() => {
      DOM.restoreFocus(focused, selectionStart, selectionEnd)
    })
    Browser.dispatchEvent(document, "phx:update")
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
    this.pendingDiffs = []
    this.href = href
    this.joinedOnce = false
    this.channel = this.liveSocket.channel(`lv:${this.id}`, () => {
      return {
        url: this.href || this.liveSocket.root.href,
        params: this.liveSocket.params,
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
      this.setContainerClasses(PHX_DISCONNECTED_CLASS)
    }
  }

  hideLoader(){
    clearTimeout(this.loaderTimer)
    this.setContainerClasses(PHX_CONNECTED_CLASS)
  }

  log(kind, msgCallback){
    this.liveSocket.log(this, kind, msgCallback)
  }

  onJoin({rendered, live_redirect}){
    this.log("join", () => ["", JSON.stringify(rendered)])
    this.rendered = rendered
    this.hideLoader()
    DOM.patch(this, this.el, this.id, Rendered.toString(this.rendered))
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
    DOM.patch(this, this.el, this.id, html)
    if(this.newChildrenAdded){ this.joinNewChildren() }
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
    this.channel.on("external_live_redirect", ({to, kind}) => this.onExternalLiveRedirect(to))
    this.channel.on("session", ({token}) => this.el.setAttribute(PHX_SESSION, token))
    this.channel.onError(reason => this.onError(reason))
    this.channel.onClose(() => this.onGracefulClose())
  }

  onGracefulClose(){
    this.gracefullyClosed = true
    this.liveSocket.destroyViewById(this.id)
  }

  onExternalLiveRedirect(href, linkRef){
    if(linkRef){
      this.liveSocket.replaceRoot(href, linkRef)
    } else {
      this.liveSocket.replaceRoot(href)
    }
  }
  onLiveRedirect({to, kind}){
    this.liveSocket.root.pushInternalLink(to, () => Browser.pushState(kind, {}, to)) 
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
    if(resp.external_live_redirect){
      let {to} = resp.external_live_redirect
      return this.onExternalLiveRedirect(to)
    }
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
        if(resp.live_redirect){ this.onLiveRedirect(resp.live_redirect) }
        if(resp.redirect && event !== "link"){ this.onRedirect(resp.redirect) }
        onReply(resp)
      })
    )
  }

  pushEvent(type, el, phxEvent){
    let val = el.getAttribute(this.binding("value")) || el.value || ""
    this.pushWithReply("event", {
      type: type,
      event: phxEvent,
      value: val
    })
  }

  pushKey(keyElement, kind, event, phxEvent){
    this.pushWithReply("event", {
      type: kind,
      event: phxEvent,
      value: keyElement.value || event.key
    })
  }

  pushInput(inputEl, phxEvent){
    this.pushWithReply("event", {
      type: "form",
      event: phxEvent,
      value: serializeForm(inputEl.form)
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
      if(resp.redirect){
        this.onExternalLiveRedirect(href, linkRef)
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
    form.setAttribute(PHX_HAS_SUBMITTED, "true")
    DOM.disableForm(form, prefix)
    this.liveSocket.blurActiveElement(this)
    this.pushFormSubmit(form, phxEvent, () => {
      DOM.restoreDisabledForm(form, prefix)
      this.liveSocket.restorePreviouslyActiveFocus()
    })
  }

  binding(kind){ return this.liveSocket.binding(kind)}
}

export default LiveSocket
