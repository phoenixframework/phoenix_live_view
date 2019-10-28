/*
================================================================================
Phoenix LiveView JavaScript Client
================================================================================

See the hexdocs at `https://hexdocs.pm/phoenix_live_view` for documentation.

*/

import morphdom from "morphdom"

const CLIENT_OUTDATED = "outdated"
const RELOAD_JITTER = [1000, 10000]
const PHX_VIEW = "data-phx-view"
const PHX_COMPONENT = "data-phx-component"
const PHX_LIVE_LINK = "data-phx-live-link"
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
const PHX_CHANGE = "phx-change"
const PHX_UPDATE = "update"
const PHX_PRIVATE = "phxPrivate"
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

let logError = (msg, obj) => console.error && console.error(msg, obj)

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
        }
        child.remove()
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

    this.socket.onOpen(() => {
      if(this.isUnloaded()){
        this.destroyAllViews()
        this.joinRootViews()
        this.detectMainView()
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

  reloadWithJitter(){
     this.disconnect()
     let [minMs, maxMs] = RELOAD_JITTER
     let afterMs = Math.floor(Math.random() * (maxMs - minMs + 1)) + minMs
     setTimeout(() => window.location.reload(), afterMs)
   }

  getHookCallbacks(hookName){ return this.hooks[hookName] }

  isUnloaded(){ return this.unloaded }

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
      let main = this.getViewByEl(el)
      if(main) {
        this.main = main
      }
    })
  }

  replaceMain(href, callback = null, linkRef = this.setPendingLink(href)){
    this.main.showLoader(LOADER_TIMEOUT)
    let mainEl = this.main.el
    let mainID = this.main.id
    let wasLoading = this.main.isLoading()

    Browser.fetchPage(href, (status, html) => {
      if(status !== 200){ return Browser.redirect(href) }

      let div = document.createElement("div")
      div.innerHTML = html
      this.joinView(div.firstChild, null, href, newMain => {
        if(!this.commitPendingLink(linkRef)){
          newMain.destroy()
          return
        }
        callback && callback()
        this.destroyViewById(mainID)
        mainEl.replaceWith(newMain.el)
        this.main = newMain
        if(wasLoading){ this.main.showLoader() }
      })
    })
  }

  joinView(el, parentView, href, callback){
    if(this.getViewByEl(el)){ return }

    let view = new View(el, this, parentView, href)
    this.views[view.id] = view
    view.join(callback)
    return view
  }

  owner(childEl, callback){
    let view = maybe(childEl.closest(PHX_VIEW_SELECTOR), el => this.getViewByEl(el))
    if(view){ callback(view) }
  }

  getViewByEl(el){ return this.views[el.id] }

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
        view.pushEvent(type, targetEl, phxEvent, {type: type})
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
          this.owner(e.target, view => {
            this.debounce(e.target, e, () => callback(e, event, view, e.target, targetPhxEvent, null))
          })
        } else {
          DOM.all(document, `[${binding}][${bindTarget}=window]`, el => {
            let phxEvent = el.getAttribute(binding)
            this.owner(el, view => {
              this.debounce(el, e, () => callback(e, event, view, el, phxEvent, "window"))
            })
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

      this.owner(target, view => {
        this.debounce(target, e, () => view.pushEvent("click", target, phxEvent, meta))
      })
    }, false)
  }

  bindNav(){
    if(!Browser.canPushState()){ return }
    window.onpopstate = (event) => {
      if(!this.registerNewLocation(window.location)){ return }

      let href = window.location.href

      if(this.main.isConnected()) {
        this.main.pushInternalLink(href)
      } else {
        this.replaceMain(href)
      }
    }
    window.addEventListener("click", e => {
      let target = closestPhxBinding(e.target, PHX_LIVE_LINK)
      let phxEvent = target && target.getAttribute(PHX_LIVE_LINK)
      if(!phxEvent){ return }
      let href = target.href
      e.preventDefault()
      this.main.pushInternalLink(href, () => {
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
        let phxEvent = input.form && input.form.getAttribute(this.binding("change"))
        if(!phxEvent){ return }

        let value = JSON.stringify((new FormData(input.form)).getAll(input.name))
        if(this.prevInput === input && this.prevValue === value){ return }
        if(input.type === "number" && input.validity && input.validity.badInput){ return }

        this.prevInput = input
        this.prevValue = value
        this.owner(input, view => {
          if(DOM.isTextualInput(input)){
            DOM.putPrivate(input, PHX_HAS_FOCUSED, true)
          } else {
            this.setActiveElement(input)
          }
          this.debounce(input, e, () => view.pushInput(input, phxEvent, e))
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
          if(throttle && e.type === PHX_CHANGE && e.detail.triggeredBy.name === el.name){ return }
          clearTimeout(this.private(el, DEBOUNCE_TIMER))
          this.deletePrivate(el, DEBOUNCE_TIMER)
        }
        this.putPrivate(el, DEBOUNCE_TIMER, setTimeout(() => {
          if(el.form){
            el.form.removeEventListener(PHX_CHANGE, clearTimer)
            el.form.removeEventListener("submit", clearTimer)
          }
          this.deletePrivate(el, DEBOUNCE_TIMER)
          if(!throttle){ callback() }
        }, timeout))
        if(el.form){
          el.form.addEventListener(PHX_CHANGE, clearTimer)
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
          el.value = value
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

  patch(view, container, id, html, targetCID){
    let changes = {added: [], updated: [], discarded: [], phxChildrenAdded: []}
    let focused = view.liveSocket.getActiveElement()
    let {selectionStart, selectionEnd} = focused && DOM.isTextualInput(focused) ? focused : {}
    let phxUpdate = view.liveSocket.binding(PHX_UPDATE)
    let [diffContainer, targetContainer] = this.buildDiffContainer(container, html, phxUpdate, targetCID)

    morphdom(targetContainer, diffContainer.outerHTML, {
      childrenOnly: true,
      onBeforeNodeAdded: function(el){
        //input handling
        DOM.discardError(targetContainer, el)
        return el
      },
      onNodeAdded: function(el){
        // nested view handling
        if(DOM.isPhxChild(el) && view.ownsElement(el)){
          changes.phxChildrenAdded.push(el)
        }
        changes.added.push(el)
      },
      onNodeDiscarded(el){ changes.discarded.push(el) },
      onBeforeNodeDiscarded: function(el){
        // nested view handling
        if(DOM.isPhxChild(el)){
          view.liveSocket.destroyViewByEl(el)
          return true
        }
      },
      onBeforeElUpdated: function(fromEl, toEl) {
        if(fromEl.getAttribute(phxUpdate) === "ignore"){
          DOM.mergeAttrs(fromEl, toEl)
          changes.updated.push({fromEl, toEl: fromEl})
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

    view.liveSocket.silenceEvents(() => DOM.restoreFocus(focused, selectionStart, selectionEnd))
    DOM.dispatchEvent(document, "phx:update")
    return changes
  },

  dispatchEvent(target, eventString, detail = {}){
    let event = new CustomEvent(eventString, {bubbles: true, cancelable: true, detail: detail})
    target.dispatchEvent(event)
  },

  cloneNode(node, html){
    let cloned = node.cloneNode()
    cloned.innerHTML = html || node.innerHTML
    return cloned
  },

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
      diffContainer = this.cloneNode(targetContainer)
      let componentNodes = this.findComponentNodeList(diffContainer, targetCID)
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
      diffContainer = this.cloneNode(container, html)
    }

    DOM.all(diffContainer, `[${phxUpdate}=append],[${phxUpdate}=prepend]`, el => {
      let id = el.id || logError("append/prepend requires an ID, got: ", el)
      let existingInContainer = container.querySelector(`#${id}`)
      if(!existingInContainer){ return }
      let existing = this.cloneNode(existingInContainer)
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
  },

  mergeAttrs(target, source, exclude = []){
    var attrs = source.attributes
    for (let i = 0, length = attrs.length; i < length; i++){
      let name = attrs[i].name
      if(exclude.indexOf(name) < 0){ target.setAttribute(name, source.getAttribute(name)) }
    }
  },

  mergeInputs(target, source){
    DOM.mergeAttrs(target, source, ["value"])
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
    DOM.all(this.el, `[${this.binding(PHX_HOOK)}]`, hookEl => changes.added.push(hookEl))
    this.triggerHooks(changes)
    this.joinNewChildren()
    if(live_redirect){
      let {kind, to} = live_redirect
      Browser.pushState(kind, {}, to)
    }
  }

  joinNewChildren(){
    DOM.all(document, `${PHX_VIEW_SELECTOR}[${PHX_PARENT_ID}="${this.id}"]`, el => {
      let child = this.liveSocket.getViewByEl(el)
      if(!child){
        this.liveSocket.joinView(el, this)
      }
    })
  }

  update(diff, cid){
    if(isEmpty(diff)){ return }
    if(this.liveSocket.hasPendingLink()){ return this.pendingDiffs.push({diff, cid}) }

    this.log("update", () => ["", JSON.stringify(diff)])
    this.rendered = Rendered.mergeDiff(this.rendered, diff)
    let html = typeof(cid) === "number" ?
      Rendered.componentToString(this.rendered[COMPONENTS], cid) :
      Rendered.toString(this.rendered)

    let changes = DOM.patch(this, this.el, this.id, html, cid)
    if(changes.phxChildrenAdded.length > 0){
      this.joinNewChildren()
    }
    this.triggerHooks(changes)
  }

  getHook(el){ return this.viewHooks[ViewHook.elementID(el)] }

  addHook(el){ if(ViewHook.elementID(el) || !el.getAttribute){ return }
    let hookName = el.getAttribute(this.binding(PHX_HOOK))
    if(hookName && !this.ownsElement(el)){ return }
    let callbacks = this.liveSocket.getHookCallbacks(hookName)

    if(callbacks){
      let hook = new ViewHook(this, el, callbacks)
      this.viewHooks[ViewHook.elementID(hook.el)] = hook
      hook.__trigger__("mounted")
    } else if(hookName !== null){
      logError(`unknown hook found for "${hookName}"`, el)
    }
  }

  destroyHook(hook){
    hook.__trigger__("destroyed")
    delete this.viewHooks[ViewHook.elementID(hook.el)]
  }

  triggerHooks(changes){
    let destroyedCIDs = []
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
      let cid = this.componentID(el)
      if(typeof(cid) === "number" && destroyedCIDs.indexOf(cid) === -1){ destroyedCIDs.push(cid) }
      let hook = this.getHook(el)
      hook && this.destroyHook(hook)
    })

    this.maybePushComponentsDestroyed(destroyedCIDs)
  }

  applyPendingUpdates(){
    this.pendingDiffs.forEach(({diff, cid}) => this.update(diff, cid))
    this.pendingDiffs = []
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
    this.liveSocket.replaceMain(to, () => Browser.pushState(kind, {}, to))
  }

  onLiveRedirect({to, kind}){
    this.href = to
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
    if(resp.reason === CLIENT_OUTDATED){ return this.liveSocket.reloadWithJitter() }
    if(resp.redirect || resp.external_live_redirect){ this.channel.leave() }
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
    if(typeof(payload.cid) !== "number"){ delete payload.cid }
    return(
      this.channel.push(event, payload, PUSH_TIMEOUT).receive("ok", resp => {
        if(resp.diff){ this.update(resp.diff, payload.cid) }
        if(resp.redirect){ this.onRedirect(resp.redirect) }
        if(resp.live_redirect){ this.onLiveRedirect(resp.live_redirect) }
        if(resp.external_live_redirect){ this.onExternalLiveRedirect(resp.external_live_redirect) }
        onReply(resp)
      })
    )
  }

  componentID(el){
    let cid = el.getAttribute && el.getAttribute(PHX_COMPONENT)
    return cid ? parseInt(cid) : null
  }

  targetComponentID(target){
    return maybe(target.closest(`[${PHX_COMPONENT}]`), el => this.ownsElement(el) && this.componentID(el))
  }

  pushEvent(type, el, phxEvent, meta){
    let prefix = this.binding("value-")
    for (let i = 0; i < el.attributes.length; i++){
      let name = el.attributes[i].name
      if(name.startsWith(prefix)){ meta[name.replace(prefix, "")] = el.getAttribute(name) }
    }
    if(el.value !== undefined){ meta.value = el.value }

    this.pushWithReply("event", {
      type: type,
      event: phxEvent,
      value: meta,
      cid: this.targetComponentID(el)
    })
  }

  pushKey(keyElement, kind, phxEvent, meta){
    if(keyElement.value !== undefined){ meta.value = keyElement.value }

    this.pushWithReply("event", {
      type: kind,
      event: phxEvent,
      value: meta,
      cid: this.targetComponentID(keyElement)
    })
  }

  pushInput(inputEl, phxEvent, e){
    DOM.dispatchEvent(inputEl.form, PHX_CHANGE, {triggeredBy: inputEl})
    this.pushWithReply("event", {
      type: "form",
      event: phxEvent,
      value: serializeForm(inputEl.form, {_target: e.target.name}),
      cid: this.targetComponentID(inputEl)
    })
  }

  pushFormSubmit(formEl, phxEvent, onReply){
    this.pushWithReply("event", {
      type: "form",
      event: phxEvent,
      value: serializeForm(formEl),
      cid: this.targetComponentID(formEl)
    }, onReply)
  }

  pushInternalLink(href, callback){
    if(!this.isLoading()){ this.showLoader(LOADER_TIMEOUT) }
    let linkRef = this.liveSocket.setPendingLink(href)
    this.pushWithReply("link", {url: href}, resp => {
      if(resp.link_redirect){
        this.liveSocket.replaceMain(href, callback, linkRef)
      } else if(this.liveSocket.commitPendingLink(linkRef)){
        this.href = href
        this.applyPendingUpdates()
        this.hideLoader()
        callback && callback()
      }
    }).receive("timeout", () => Browser.redirect(window.location.href))
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

  submitForm(form, phxEvent){
    let prefix = this.liveSocket.getBindingPrefix()
    DOM.putPrivate(form, PHX_HAS_SUBMITTED, true)
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
