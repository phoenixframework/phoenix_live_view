/*
================================================================================
Phoenix LiveView JavaScript Client
================================================================================

## Usage

Instantiate a single LiveSocket instance to enable LiveView
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
    class will be applied in conjunction with `"phx-disconnected"` connection
    to the server is lost.

When a form bound with `phx-submit` is submitted, the `phx-loading` class
is applied to the form, which is removed on update.

In addition to applied classes, an empty `"phx-loader"` exists adjacent
to every LiveView, and its display status is toggled automatically based on
connection and error class changes. This behavior may be disabled by overriding
`.phx-loader` in your css to `display: none !important`.


## Interop with client controlled DOM

A container can be marked with `phx-ignore`, allowing the DOM patch
operations to avoid updating or removing portions of the LiveView. This
is useful for client-side interop with existing libraries that do their
own DOM operations.
*/

import morphdom from "morphdom"
import {Socket} from "phoenix"

const PHX_VIEW = "data-phx-view"
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
const LOADER_TIMEOUT = 100
const LOADER_ZOOM = 2
const BINDING_PREFIX = "phx-"
const PUSH_TIMEOUT = 20000

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
  return((new URLSearchParams(new FormData(form))).toString())
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

let all = function(node, query, callback) {
  let nodeList = node.querySelectorAll(query)
  for (let i = 0, len = nodeList.length; i < len; i++) {
    callback(nodeList[i])
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
    this.bindingPrefix = opts.bindingPrefix || BINDING_PREFIX
    this.opts = opts
    this.views = {}
    this.viewLogger = opts.viewLogger
    this.activeElement = null
    this.prevActive = null
    this.prevInput = null
    this.prevValue = null
    this.silenced = false
    this.bindTopLevelEvents()
  }

  isUnloaded(){ return this.unloaded }

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

  getBindingPrefix(){ return this.bindingPrefix }

  binding(kind){ return `${this.getBindingPrefix()}${kind}` }

  disconnect(){
    this.socket.disconnect()
  }

  channel(topic, params){ return this.socket.channel(topic, params || {}) }

  joinRootViews(){
    all(document, `${PHX_VIEW_SELECTOR}:not([${PHX_PARENT_ID}])`, rootEl => {
      this.joinView(rootEl)
    })
  }

  joinView(el, parentView){
    if(this.getViewById(el.id)){ return }

    let view = new View(el, this, parentView)
    this.views[view.id] = view
    view.join()
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

  // private

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
          all(document, `[${binding}][${bindTarget}=window]`, el => {
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
      e.preventDefault()
      this.owner(target, view => view.pushEvent("click", target, phxEvent))
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
    all(form, `[${disableWith}]`, el => {
      let value = el.getAttribute(disableWith)
      el.setAttribute(`${disableWith}-restore`, el.innerText)
      el.innerText = value
    })
    all(form, "button", button => {
      button.setAttribute(PHX_DISABLED, button.disabled)
      button.disabled = true
    })
    all(form, "input", input => {
      input.setAttribute(PHX_READONLY, input.readOnly)
      input.readOnly = true
    })
  },

  restoreDisabledForm(form, prefix){
    let disableWith = `${prefix}${PHX_DISABLE_WITH}`
    form.classList.remove(PHX_LOADING_CLASS)
    all(form, `[${disableWith}]`, el => {
      let value = el.getAttribute(`${disableWith}-restore`)
      if(value){
        el.innerText = value
        el.removeAttribute(`${disableWith}-restore`)
      }
    })
    all(form, "button", button => {
      let prev = button.getAttribute(PHX_DISABLED)
      if(prev){
        button.disabled = prev === "true"
        button.removeAttribute(PHX_DISABLED)
      }
    })
    all(form, "input", input => {
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
        if((el.getAttribute && el.getAttribute(phxIgnore) != null) ||
           (el.parentNode && el.parentNode.getAttribute(phxIgnore) != null)){
          return false
        }
        // nested view handling
        if(DOM.isPhxChild(el)){
          view.liveSocket.destroyViewById(el.id)
          return true
        }
      },
      onBeforeElUpdated: function(fromEl, toEl) {
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

export class View {
  constructor(el, liveSocket, parentView){
    this.liveSocket = liveSocket
    this.parent = parentView
    this.newChildrenAdded = false
    this.gracefullyClosed = false
    this.el = el
    this.loader = this.el.nextElementSibling
    this.id = this.el.id
    this.view = this.el.getAttribute(PHX_VIEW)
    this.channel = this.liveSocket.channel(`lv:${this.id}`, () => {
      return {session: this.getSession(), static: this.getStatic()}
    })
    this.loaderTimer = setTimeout(() => this.showLoader(), LOADER_TIMEOUT)
    this.bindChannel()
  }

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
    this.joinNewChildren()
  }

  joinNewChildren(){
    all(document, `${PHX_VIEW_SELECTOR}[${PHX_PARENT_ID}="${this.id}"]`, el => {
      let child = this.liveSocket.getViewById(el.id)
      if(!child){
        this.liveSocket.joinView(el, this)
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

  onNewChildAdded(){
    this.newChildrenAdded = true
  }

  bindChannel(){
    this.channel.on("render", (diff) => this.update(diff))
    this.channel.on("redirect", ({to, flash}) => Browser.redirect(to, flash))
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
    if(this.parent){
      this.parent.channel.onClose(() => this.onGracefulClose())
      this.parent.channel.onError(() => this.liveSocket.destroyViewById(this.id))
    }
    this.channel.join()
      .receive("ok", data => this.onJoin(data))
      .receive("error", resp => this.onJoinError(resp))
      .receive("timeout", () => this.onJoinError("timeout"))
  }

  onJoinError(resp){
    this.displayError()
    this.log("error", () => ["unable to join", resp])
  }

  onError(reason){
    this.log("error", () => ["view crashed", reason])
    this.liveSocket.onViewError(this)
    document.activeElement.blur()
    if(this.liveSocket.isUnloaded()){
      this.showLoader()
    } else {
      this.displayError()
    }
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
