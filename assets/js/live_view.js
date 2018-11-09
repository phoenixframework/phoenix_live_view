import {Socket} from "./phoenix"
import morphdom from "morphdom"

const PHX_VIEW_SELECTOR = "[data-phx-view]"
const PHX_PARENT_ID = "data-phx-parent-id"
const PHX_HAS_FOCUSED = "data-phx-has-focused"
const PHX_BOUND = "data-phx-bound"
const FOCUSABLE_INPUTS = ["text", "textarea", "password"]
const PHX_HAS_SUBMITTED = "data-phx-has-submitted"
const SESSION_SELECTOR = "data-phx-session"
const LOADER_TIMEOUT = 100
const LOADER_ZOOM = 2
const BINDING_PREFIX = "phx-"

export default class LiveSocket {
  constructor(url, opts = {}){
    this.bindingPrefix = opts.bindingPrefix || BINDING_PREFIX
    this.url = url
    this.opts = opts
    this.views = {}
    this.socket = new Socket(url, opts)
  }

  connect(){
    if(["complete", "loaded","interactive"].indexOf(document.readyState) >= 0){
      joinViewChannels()
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
    let field = el.getAttribute && el.getAttribute("phx-error-field")
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
    let focused = document.activeElement
    let {selectionStart, selectionEnd} = focused
    let div = document.createElement("div")
    div.innerHTML = html

    morphdom(container, div, {
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
    return this.el.getAttribute(SESSION_SELECTOR)|| this.parent.getSession()
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
    this.el.classList = "phx-disconnected"
    this.loader.style.display = "block"
    let middle = Math.floor(this.el.clientHeight / LOADER_ZOOM)
    this.loader.style.top = `-${middle}px`
  }
  
  update(html){
    DOM.patch(this, this.el, this.id, html)
  }

  bindChannel(){
    this.channel.on("render", ({html}) => this.update(html))
    this.channel.on("redirect", ({to, flash}) => Browser.redirect(to, flash) )
    this.channel.on("session", ({token}) => this.joinParams.session = token)
    this.channel.onError(() => this.onError())
  }

  join(){
    this.channel.join()
      .receive("ok", data => this.onJoin(data))
      .receive("error", resp => this.onJoinError(resp))
  }

  onJoin({html}){
    this.hideLoader()
    this.el.classList = "phx-connected"
    DOM.patch(this, this.el, this.id, html)
    if(!this.hasBoundUI){ this.bindUI() }
    this.hasBoundUI = true
  }

  onJoinError(resp){
    this.showLoader()
    this.el.classList = "phx-disconnected phx-error"
    console.log("Unable to join", resp)
  }

  onError(){
    document.activeElement.blur()
    this.showLoader()
    this.el.classList = "phx-disconnected phx-error"
  }

  pushClick(clickedElement, event, phxEvent){
    event.preventDefault()
    this.channel.push("event", {
      type: "click",
      event: phxEvent,
      id: clickedElement.id,
      value: clickedElement.getAttribute("phx-value") || clickedElement.value || ""
    })
  }

  pushKeyup(keyElement, event, phxEvent){
    this.channel.push("event", {
      type: "keyup",
      event: phxEvent,
      id: event.target.id,
      value: keyElement.value
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
    this.eachChild(`[${this.binding("keyup")}]`, el => this.bindKeyUp(el, view))
  }

  bindClick(el){
    let phxEvent = el.getAttribute(this.binding("click"))
    if(phxEvent && !el.getAttribute(PHX_BOUND) && this.ownsElement(el)){
      el.setAttribute(PHX_BOUND, true)
      el.addEventListener("click", e => this.pushClick(el, e, phxEvent))
    } 
  }

  bindKeyUp(el){
    let phxEvent = el.getAttribute(this.binding("keyup"))
    if(phxEvent){
      el.addEventListener("keyup", e => this.pushKeyup(el, e, phxEvent))
    }
  }

  bindForms(){
    let change = this.binding("change")
    this.eachChild(`form[${change}] input`, input => {
      let phxEvent = input.form.getAttribute(change)
      input.addEventListener("input", e => {
      if(DOM.isTextualInput(input)){ input.setAttribute(PHX_HAS_FOCUSED, true) }
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
    this.bindKeyUp(el)
  }

  binding(kind){ return `${this.bindingPrefix}${kind}` }

  // private

  serializeForm(form){
   return((new URLSearchParams(new FormData(form))).toString())
 }
}

