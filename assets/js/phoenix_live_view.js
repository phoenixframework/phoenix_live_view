/*
================================================================================
Phoenix LiveView JavaScript Client
================================================================================

See the hexdocs at `https://hexdocs.pm/phoenix_live_view` for documentation.

*/

import morphdom from "morphdom"

const CONSECUTIVE_RELOADS = "consecutive-reloads"
const MAX_RELOADS = 10
const RELOAD_JITTER = [1000, 3000]
const FAILSAFE_JITTER = 30000
const PHX_VIEW = "data-phx-view"
const PHX_EVENT_CLASSES = [
  "phx-click-loading", "phx-change-loading", "phx-submit-loading",
  "phx-keydown-loading", "phx-keyup-loading", "phx-blur-loading", "phx-focus-loading"
]
const PHX_COMPONENT = "data-phx-component"
const PHX_LIVE_LINK = "data-phx-link"
const PHX_TRACK_STATIC = "track-static"
const PHX_LINK_STATE = "data-phx-link-state"
const PHX_REF = "data-phx-ref"
const PHX_UPLOAD_REF = "data-phx-upload-ref"
const PHX_PREFLIGHTED_REFS = "data-phx-preflighted-refs"
const PHX_DONE_REFS = "data-phx-done-refs"
const PHX_DROP_TARGET = "drop-target"
const PHX_ACTIVE_ENTRY_REFS = "data-phx-active-refs"
const PHX_SKIP = "data-phx-skip"
const PHX_REMOVE = "data-phx-remove"
const PHX_PAGE_LOADING = "page-loading"
const PHX_CONNECTED_CLASS = "phx-connected"
const PHX_DISCONNECTED_CLASS = "phx-disconnected"
const PHX_NO_FEEDBACK_CLASS = "phx-no-feedback"
const PHX_ERROR_CLASS = "phx-error"
const PHX_PARENT_ID = "data-phx-parent-id"
const PHX_VIEW_SELECTOR = `[${PHX_VIEW}]`
const PHX_MAIN = `data-phx-main`
const PHX_ROOT_ID = `data-phx-root-id`
const PHX_TRIGGER_ACTION = "trigger-action"
const PHX_FEEDBACK_FOR = "feedback-for"
const PHX_HAS_FOCUSED = "phx-has-focused"
const FOCUSABLE_INPUTS = ["text", "textarea", "number", "email", "password", "search", "tel", "url", "date", "time"]
const CHECKABLE_INPUTS = ["checkbox", "radio"]
const PHX_HAS_SUBMITTED = "phx-has-submitted"
const PHX_SESSION = "data-phx-session"
const PHX_STATIC = "data-phx-static"
const PHX_READONLY = "data-phx-readonly"
const PHX_DISABLED = "data-phx-disabled"
const PHX_DISABLE_WITH = "disable-with"
const PHX_DISABLE_WITH_RESTORE = "data-phx-disable-with-restore"
const PHX_HOOK = "hook"
const PHX_DEBOUNCE = "debounce"
const PHX_THROTTLE = "throttle"
const PHX_UPDATE = "update"
const PHX_KEY = "key"
const PHX_PRIVATE = "phxPrivate"
const PHX_AUTO_RECOVER = "auto-recover"
const PHX_LV_DEBUG = "phx:live-socket:debug"
const PHX_LV_PROFILE = "phx:live-socket:profiling"
const PHX_LV_LATENCY_SIM = "phx:live-socket:latency-sim"
const PHX_PROGRESS = "progress"
const LOADER_TIMEOUT = 1
const BEFORE_UNLOAD_LOADER_TIMEOUT = 200
const BINDING_PREFIX = "phx-"
const PUSH_TIMEOUT = 30000
const LINK_HEADER = "x-requested-with"
const RESPONSE_URL_HEADER = "x-response-url"
const DEBOUNCE_TRIGGER = "debounce-trigger"
const THROTTLED = "throttled"
const DEBOUNCE_PREV_KEY = "debounce-prev-key"
const DEFAULTS = {
  debounce: 300,
  throttle: 300
}

// Rendered
const DYNAMICS = "d"
const STATIC = "s"
const COMPONENTS = "c"
const EVENTS = "e"
const REPLY = "r"
const TITLE = "t"


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
  if(view.liveSocket.isDebugEnabled()){
    console.log(`${view.id} ${kind}: ${msg} - `, obj)
  }
}

// wraps value in closure or returns closure
let closure = (val) => typeof val === "function" ? val : function(){ return val }

let clone = (obj) => { return JSON.parse(JSON.stringify(obj)) }

let closestPhxBinding = (el, binding, borderEl) => {
  do {
    if(el.matches(`[${binding}]`)){ return el }
    el = el.parentElement || el.parentNode
  } while(el !== null && el.nodeType === 1 && !((borderEl && borderEl.isSameNode(el)) || el.matches(PHX_VIEW_SELECTOR)))
  return null
}

let isObject = (obj) => {
  return obj !== null && typeof obj === "object" && !(obj instanceof Array)
}

let isEqualObj = (obj1, obj2) =>  JSON.stringify(obj1) === JSON.stringify(obj2)

let isEmpty = (obj) => {
  for (let x in obj){ return false }
  return true
}

let maybe = (el, callback) => el && callback(el)

class UploadEntry {
  static isActive(fileEl, file){
    let isNew = file._phxRef === undefined
    let activeRefs = fileEl.getAttribute(PHX_ACTIVE_ENTRY_REFS).split(",")
    let isActive = activeRefs.indexOf(LiveUploader.genFileRef(file)) >= 0
    return file.size > 0 && (isNew || isActive)
  }

  static isPreflighted(fileEl, file){
    let preflightedRefs = fileEl.getAttribute(PHX_PREFLIGHTED_REFS).split(",")
    let isPreflighted = preflightedRefs.indexOf(LiveUploader.genFileRef(file)) >= 0
    return isPreflighted && this.isActive(fileEl, file)
  }

  constructor(fileEl, file, view){
    this.ref = LiveUploader.genFileRef(file)
    this.fileEl = fileEl
    this.file = file
    this.view = view
    this.meta = null
    this._isCancelled = false
    this._isDone = false
    this._progress = 0
    this._onDone = function(){}
  }

  metadata(){ return this.meta }

  progress(progress){
    this._progress = Math.floor(progress)
    if(this._progress >= 100){
      this._progress = 100
      this._isDone = true
      this.view.pushFileProgress(this.fileEl, this.ref, 100, () => {
        LiveUploader.untrackFile(this.fileEl, this.file)
        this._onDone()
      })
    } else {
      this.view.pushFileProgress(this.fileEl, this.ref, this._progress)
    }
  }

  cancel(){
    this._isCancelled = true
    this._isDone = true
    this._onDone()
  }

  isDone(){ return this._isDone }

  error(reason = "failed"){
    this.view.pushFileProgress(this.fileEl, this.ref, {error: reason})
  }

  //private

  onDone(callback){ this._onDone = callback }

  toPreflightPayload(){
    return {
      last_modified: this.file.lastModified,
      name: this.file.name,
      size: this.file.size,
      type: this.file.type,
      ref: this.ref
    }
  }

  uploader(uploaders){
    if(this.meta.uploader){
      let callback = uploaders[this.meta.uploader] || logError(`no uploader configured for ${this.meta.uploader}`)
      return {name: this.meta.uploader, callback: callback}
    } else {
      return {name: "channel", callback: channelUploader}
    }
  }

  zipPostFlight(resp){
    this.meta = resp.entries[this.ref]
    if(!this.meta){ logError(`no preflight upload response returned with ref ${this.ref}`, {input: this.fileEl, response: resp})}
  }
}

let Hooks = {}
Hooks.LiveFileUpload = {
  preflightedRefs(){ return this.el.getAttribute(PHX_PREFLIGHTED_REFS) },

  mounted(){ this.preflightedWas = this.preflightedRefs() },

  updated() {
    let newPreflights = this.preflightedRefs()
    if(this.preflightedWas !== newPreflights){
      this.preflightedWas = newPreflights
      if(newPreflights === ""){
        this.__view.cancelSubmit(this.el.form)
      }
    }
  }
}

Hooks.LiveImgPreview = {
  mounted() {
    this.ref = this.el.getAttribute("data-phx-entry-ref")
    this.inputEl = document.getElementById(this.el.getAttribute(PHX_UPLOAD_REF))
    LiveUploader.getEntryDataURL(this.inputEl, this.ref, url => this.el.src = url)
  }
}

let liveUploaderFileRef = 0
class LiveUploader {
  static genFileRef(file){
    let ref = file._phxRef
    if(ref !== undefined){
      return ref
    } else {
      file._phxRef = (liveUploaderFileRef++).toString()
      return file._phxRef
    }
  }

  static getEntryDataURL(inputEl, ref, callback){
    let file = this.activeFiles(inputEl).find(file => this.genFileRef(file) === ref)
    let reader = new FileReader()
    reader.onload = (e) => callback(e.target.result)
    reader.readAsDataURL(file)
  }

  static hasUploadsInProgress(formEl){
    let active = 0
    DOM.findUploadInputs(formEl).forEach(input => {
      if(input.getAttribute(PHX_PREFLIGHTED_REFS) !== input.getAttribute(PHX_DONE_REFS)){
        active++
      }
    })
    return active > 0
  }

  static serializeUploads(inputEl){
    let files = this.activeFiles(inputEl, "serialize")
    let fileData = {}
    files.forEach(file => {
      let entry = {path: inputEl.name}
      let uploadRef = inputEl.getAttribute(PHX_UPLOAD_REF)
      fileData[uploadRef] = fileData[uploadRef] || []
      entry.ref = this.genFileRef(file)
      entry.name = file.name
      entry.type = file.type
      entry.size = file.size
      fileData[uploadRef].push(entry)
    })
    return fileData
  }

  static clearFiles(inputEl){
    inputEl.value = null
    DOM.putPrivate(inputEl, "files", [])
  }

  static untrackFile(inputEl, file){
    DOM.putPrivate(inputEl, "files", DOM.private(inputEl, "files").filter(f => !Object.is(f, file)))
  }

  static trackFiles(inputEl, files){
    if(inputEl.getAttribute("multiple") !== null){
      let newFiles = files.filter(file => !this.activeFiles(inputEl).find(f => Object.is(f, file)))
      DOM.putPrivate(inputEl, "files", this.activeFiles(inputEl).concat(newFiles))
      inputEl.value = null
    } else {
      DOM.putPrivate(inputEl, "files", files)
    }
  }

  static activeFileInputs(formEl){
    let fileInputs = DOM.findUploadInputs(formEl)
    return Array.from(fileInputs).filter(el => el.files && this.activeFiles(el).length > 0)
  }

  static activeFiles(input){
    return (DOM.private(input, "files") || []).filter(f => UploadEntry.isActive(input, f))
  }

  static inputsAwaitingPreflight(formEl){
    let fileInputs = DOM.findUploadInputs(formEl)
    return Array.from(fileInputs).filter(input => this.filesAwaitingPreflight(input).length > 0)
  }

  static filesAwaitingPreflight(input){
    return this.activeFiles(input).filter(f => !UploadEntry.isPreflighted(input, f))
  }

  constructor(inputEl, view, onComplete){
    this.view = view
    this.onComplete = onComplete
    this._entries =
      Array.from(LiveUploader.filesAwaitingPreflight(inputEl) || [])
        .map(file => new UploadEntry(inputEl, file, view))

    this.numEntriesInProgress = this._entries.length
  }

  entries(){ return this._entries }

  initAdapterUpload(resp, onError, liveSocket){
    this._entries =
      this._entries.map(entry => {
        entry.zipPostFlight(resp)
        entry.onDone(() => {
          this.numEntriesInProgress--
          if(this.numEntriesInProgress === 0){ this.onComplete() }
        })
        return entry
      })

    let groupedEntries = this._entries.reduce((acc, entry) => {
      let {name, callback} = entry.uploader(liveSocket.uploaders)
      acc[name] = acc[name] || {callback: callback, entries: []}
      acc[name].entries.push(entry)
      return acc
    }, {})

    for(let name in groupedEntries){
      let {callback, entries} = groupedEntries[name]
      callback(entries, onError, resp, liveSocket)
    }
  }
}

let channelUploader = function(entries, onError, resp, liveSocket){
  entries.forEach(entry => {
    let entryUploader = new EntryUploader(entry, resp.config.chunk_size, liveSocket)
    entryUploader.upload()
  })
}

class EntryUploader {
  constructor(entry, chunkSize, liveSocket){
    this.liveSocket = liveSocket
    this.entry = entry
    this.offset = 0
    this.chunkSize = chunkSize
    this.uploadChannel = liveSocket.channel(`lvu:${entry.ref}`, {token: entry.metadata()})
  }

  upload(){
    this.uploadChannel.join()
      .receive("ok", data => this.readNextChunk())
      .receive("error", reason => {
        this.uploadChannel.leave()
        this.entry.error()
      })
  }

  isDone(){ return this.offset >= this.entry.file.size }

  readNextChunk(){
    let reader = new window.FileReader()
    let blob = this.entry.file.slice(this.offset, this.chunkSize + this.offset)
    reader.onload = (e) => {
      if(e.target.error === null){
        this.offset += e.target.result.byteLength
        this.pushChunk(e.target.result)
      } else {
        return logError("Read error: " + e.target.error)
      }
    }
    reader.readAsArrayBuffer(blob)
  }

  pushChunk(chunk){
    if(!this.uploadChannel.isJoined()){ return }
    this.uploadChannel.push("chunk", chunk)
      .receive("ok", () => {
        this.entry.progress((this.offset / this.entry.file.size) * 100)
        if(!this.isDone()){
          setTimeout(() => this.readNextChunk(), this.liveSocket.getLatencySim() || 0)
        }
      })
  }
}

let serializeForm = (form, meta = {}) => {
  let formData = new FormData(form)
  let toRemove = []

  formData.forEach((val, key, index) => {
    if(val instanceof File){ toRemove.push(key) }
  })

  // Cleanup after building fileData
  toRemove.forEach(key => formData.delete(key))

  let params = new URLSearchParams()
  for(let [key, val] of formData.entries()){ params.append(key, val) }
  for(let metaKey in meta){ params.append(metaKey, meta[metaKey]) }

  return params.toString()
}

export class Rendered {
  static extract(diff){
    let {[REPLY]: reply, [EVENTS]: events, [TITLE]: title} = diff
    delete diff[REPLY]
    delete diff[EVENTS]
    delete diff[TITLE]
    return {diff, title, reply: reply || null, events: events || []}
  }

  constructor(viewId, rendered){
    this.viewId = viewId
    this.rendered = {}
    this.mergeDiff(rendered)
  }

  parentViewId(){ return this.viewId }

  toString(onlyCids){
    return this.recursiveToString(this.rendered, this.rendered[COMPONENTS], onlyCids)
  }

  recursiveToString(rendered, components = rendered[COMPONENTS], onlyCids){
    onlyCids = onlyCids ? new Set(onlyCids) : null
    let output = {buffer: "", components: components, onlyCids: onlyCids}
    this.toOutputBuffer(rendered, output)
    return output.buffer
  }

  componentCIDs(diff){ return Object.keys(diff[COMPONENTS] || {}).map(i => parseInt(i)) }

  isComponentOnlyDiff(diff){
    if(!diff[COMPONENTS]){ return false }
    return Object.keys(diff).length === 1
  }

  getComponent(diff, cid){ return diff[COMPONENTS][cid] }

  mergeDiff(diff){
    let newc = diff[COMPONENTS]
    delete diff[COMPONENTS]
    this.rendered = this.recursiveMerge(this.rendered, diff)
    this.rendered[COMPONENTS] = this.rendered[COMPONENTS] || {}

    if(newc){
      let oldc = this.rendered[COMPONENTS]

      for(let cid in newc){
        let cdiff = newc[cid]
        let component = cdiff
        let stat = component[STATIC]
        if(typeof(stat) === "number"){
          while(typeof(stat) === "number"){
            component = stat > 0 ? newc[stat] : oldc[-stat]
            stat = component[STATIC]
          }
          // We need to clone because multiple components may point
          // to the same shared component, and since recursive merge
          // is destructive, we need to keep the original intact.
          //
          // Then we do a direct recursive merge because we always
          // want to merge the first level, even if cdiff[STATIC]
          // is not undefined. We put the proper static in place after
          // merge.
          //
          // The test suite covers those corner cases.
          component = clone(component)
          this.doRecursiveMerge(component, cdiff)
          component[STATIC] = stat
        } else {
          component = oldc[cid] || {}
          component = this.recursiveMerge(component, cdiff)
        }
        newc[cid] = component
      }
      for (var key in newc) { oldc[key] = newc[key] }
      diff[COMPONENTS] = newc
    }
  }

  recursiveMerge(target, source){
    if(source[STATIC] !== undefined){
      return source
    } else {
      this.doRecursiveMerge(target, source)
      return target
    }
  }

  doRecursiveMerge(target, source){
    for(let key in source){
      let val = source[key]
      let targetVal = target[key]
      if(isObject(val) && val[STATIC] === undefined && isObject(targetVal)){
        this.doRecursiveMerge(targetVal, val)
      } else {
        target[key] = val
      }
    }
  }

  componentToString(cid){ return this.recursiveCIDToString(this.rendered[COMPONENTS], cid) }

  pruneCIDs(cids){
    cids.forEach(cid => delete this.rendered[COMPONENTS][cid])
  }

  // private

  get(){ return this.rendered }

  isNewFingerprint(diff = {}){ return !!diff[STATIC] }

  toOutputBuffer(rendered, output){
    if(rendered[DYNAMICS]){ return this.comprehensionToBuffer(rendered, output) }
    let {[STATIC]: statics} = rendered

    output.buffer += statics[0]
    for(let i = 1; i < statics.length; i++){
      this.dynamicToBuffer(rendered[i - 1], output)
      output.buffer += statics[i]
    }
  }

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
  }

  dynamicToBuffer(rendered, output){
    if(typeof(rendered) === "number"){
      output.buffer += this.recursiveCIDToString(output.components, rendered, output.onlyCids)
   } else if(isObject(rendered)){
      this.toOutputBuffer(rendered, output)
    } else {
      output.buffer += rendered
    }
  }

  recursiveCIDToString(components, cid, onlyCids){
    let component = components[cid] || logError(`no component for CID ${cid}`, components)
    let template = document.createElement("template")
    template.innerHTML = this.recursiveToString(component, components, onlyCids)
    let container = template.content
    let skip = onlyCids && !onlyCids.has(cid)

    let [hasChildNodes, hasChildComponents] =
      Array.from(container.childNodes).reduce(([hasNodes, hasComponents], child, i) => {
        if(child.nodeType === Node.ELEMENT_NODE){
          if(child.getAttribute(PHX_COMPONENT)){
            return [hasNodes, true]
          }
          child.setAttribute(PHX_COMPONENT, cid)
          if(!child.id){ child.id = `${this.parentViewId()}-${cid}-${i}`}
          if(skip){
            child.setAttribute(PHX_SKIP, "")
            child.innerHTML = ""
          }
          return [true, hasComponents]
        } else {
          if(child.nodeValue.trim() !== ""){
            logError(`only HTML element tags are allowed at the root of components.\n\n` +
                    `got: "${child.nodeValue.trim()}"\n\n` +
                    `within:\n`, template.innerHTML.trim())
            child.replaceWith(this.createSpan(child.nodeValue, cid))
            return [true, hasComponents]
          } else {
            child.remove()
            return [hasNodes, hasComponents]
          }
        }
      }, [false, false])

    if(!hasChildNodes && !hasChildComponents){
      logError(`expected at least one HTML element tag inside a component, but the component is empty:\n`,
               template.innerHTML.trim())
      return this.createSpan("", cid).outerHTML
    } else if(!hasChildNodes && hasChildComponents){
      logError(`expected at least one HTML element tag directly inside a component, but only subcomponents were found. A component must render at least one HTML tag directly inside itself.`,
               template.innerHTML.trim())
      return template.innerHTML
    } else {
      return template.innerHTML
    }
  }

  createSpan(text, cid) {
    let span = document.createElement("span")
    span.innerText = text
    span.setAttribute(PHX_COMPONENT, cid)
    return span
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
 * @param {Object} [opts.defaults] - The optional defaults to use for various bindings,
 * such as `phx-debounce`. Supports the following keys:
 *
 *   - debounce - the millisecond phx-debounce time. Defaults 300
 *   - throttle - the millisecond phx-throttle time. Defaults 300
 *
 * @param {Function} [opts.params] - The optional function for passing connect params.
 * The function receives the viewName associated with a given LiveView. For example:
 *
 *     (viewName) => {view: viewName, token: window.myToken}
 *
 * @param {string} [opts.bindingPrefix] - The optional prefix to use for all phx DOM annotations.
 * Defaults to "phx-".
 * @param {Object} [opts.hooks] - The optional object for referencing LiveView hook callbacks.
 * @param {integer} [opts.loaderTimeout] - The optional delay in milliseconds to wait before apply
 * loading states.
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
    this.params = closure(opts.params || {})
    this.viewLogger = opts.viewLogger
    this.metadataCallbacks = opts.metadata || {}
    this.defaults = Object.assign(clone(DEFAULTS), opts.defaults || {})
    this.activeElement = null
    this.prevActive = null
    this.silenced = false
    this.main = null
    this.linkRef = 0
    this.roots = {}
    this.href = window.location.href
    this.pendingLink = null
    this.currentLocation = clone(window.location)
    this.hooks = opts.hooks || {}
    this.uploaders = opts.uploaders || {}
    this.loaderTimeout = opts.loaderTimeout || LOADER_TIMEOUT
    this.boundTopLevelEvents = false
    this.domCallbacks = Object.assign({onNodeAdded: closure(), onBeforeElUpdated: closure()}, opts.dom || {})
    window.addEventListener("unload", e => {
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

  isProfileEnabled(){ return sessionStorage.getItem(PHX_LV_PROFILE) === "true" }

  isDebugEnabled(){ return sessionStorage.getItem(PHX_LV_DEBUG) === "true" }

  enableDebug(){ sessionStorage.setItem(PHX_LV_DEBUG, "true") }

  enableProfiling(){ sessionStorage.setItem(PHX_LV_PROFILE, "true") }

  disableDebug(){ sessionStorage.removeItem(PHX_LV_DEBUG) }

  disableProfiling(){ sessionStorage.removeItem(PHX_LV_PROFILE) }

  enableLatencySim(upperBoundMs){
    this.enableDebug()
    console.log("latency simulator enabled for the duration of this browser session. Call disableLatencySim() to disable")
    sessionStorage.setItem(PHX_LV_LATENCY_SIM, upperBoundMs)
  }

  disableLatencySim(){ sessionStorage.removeItem(PHX_LV_LATENCY_SIM) }

  getLatencySim(){
    let str = sessionStorage.getItem(PHX_LV_LATENCY_SIM)
    return str ? parseInt(str) : null
  }

  getSocket(){ return this.socket }

  connect(){
    let doConnect = () => {
      if(this.joinRootViews()){
        this.bindTopLevelEvents()
        this.socket.connect()
      }
    }
    if(["complete", "loaded","interactive"].indexOf(document.readyState) >= 0){
      doConnect()
    } else {
      document.addEventListener("DOMContentLoaded", () => doConnect())
    }
  }

  disconnect(callback){ this.socket.disconnect(callback) }

  // private

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

  onChannel(channel, event, cb){
    channel.on(event, data => {
      let latency = this.getLatencySim()
      if(!latency){
        cb(data)
      } else {
        console.log(`simulating ${latency}ms of latency from server to client`)
        setTimeout(() => cb(data), latency)
      }
    })
  }

  wrapPush(view, opts, push){
    let latency = this.getLatencySim()
    let oldJoinCount = view.joinCount
    if(!latency){
      if(opts.timeout){
        return push().receive("timeout", () => {
          if(view.joinCount === oldJoinCount){
            this.reloadWithJitter(view, () => {
              this.log(view, "timeout", () => [`received timeout while communicating with server. Falling back to hard refresh for recovery`])
            })
          }
        })
      } else {
        return push()
      }
    }

    console.log(`simulating ${latency}ms of latency from client to server`)
    let fakePush = {
      receives: [],
      receive(kind, cb){ this.receives.push([kind, cb])}
    }
    setTimeout(() => {
      fakePush.receives.reduce((acc, [kind, cb]) => acc.receive(kind, cb), push())
    }, latency)
    return fakePush
  }

  reloadWithJitter(view, log){
    view.destroy()
    this.disconnect()
    let [minMs, maxMs] = RELOAD_JITTER
    let afterMs = Math.floor(Math.random() * (maxMs - minMs + 1)) + minMs
    let tries = Browser.updateLocal(view.name(), CONSECUTIVE_RELOADS, 0, count => count + 1)
    log ? log() : this.log(view, "join", () => [`encountered ${tries} consecutive reloads`])
    if(tries > MAX_RELOADS){
      this.log(view, "join", () => [`exceeded ${MAX_RELOADS} consecutive reloads. Entering failsafe mode`])
      afterMs = FAILSAFE_JITTER
    }
    setTimeout(() => {
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

  joinRootViews(){
    let rootsFound = false
    DOM.all(document, `${PHX_VIEW_SELECTOR}:not([${PHX_PARENT_ID}])`, rootEl => {
      if(!this.getRootById(rootEl.id)){
        let view = this.joinRootView(rootEl, this.getHref())
        this.root = this.root || view
        if(rootEl.getAttribute(PHX_MAIN)){ this.main = view }
      }
      rootsFound = true
    })
    return rootsFound
  }

  redirect(to, flash){
    this.disconnect()
    Browser.redirect(to, flash)
  }

  replaceMain(href, flash, callback = null, linkRef = this.setPendingLink(href)){
    let mainEl = this.main.el
    this.main.showLoader(this.loaderTimeout)
    this.main.destroy()

    Browser.fetchPage(href, (status, html) => {
      if(status !== 200){ return this.redirect(href) }

      let template = document.createElement("template")
      template.innerHTML = html
      let el = template.content.childNodes[0]
      if(!el || !this.isPhxView(el)){ return this.redirect(href) }

      this.joinRootView(el, href, flash, (newMain, joinCount) => {
        if(joinCount !== 1){ return }
        if(!this.commitPendingLink(linkRef)){
          newMain.destroy()
          return
        }
        mainEl.replaceWith(newMain.el)
        this.main = newMain
        callback && callback()
      })
    })
  }

  isPhxView(el){ return el.getAttribute && el.getAttribute(PHX_VIEW) !== null }

  joinRootView(el, href, flash, callback){
    let view = new View(el, this, null, href, flash)
    this.roots[view.id] = view
    view.join(callback)
    return view
  }

  owner(childEl, callback){
    let view = maybe(childEl.closest(PHX_VIEW_SELECTOR), el => this.getViewByEl(el))
    if(view){ callback(view) }
  }

  withinOwners(childEl, callback){
    this.owner(childEl, view => {
      let phxTarget = childEl.getAttribute(this.binding("target"))
      if(phxTarget === null){
        callback(view, childEl)
      } else {
        view.withinTargets(phxTarget, callback)
      }
    })
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
  }

  destroyViewByEl(el){
    let root = this.getRootById(el.getAttribute(PHX_ROOT_ID))
    if(root){ root.destroyDescendent(el.id) }
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
      // document.activeElement can be null in Internet Explorer 11
      return document.activeElement || document.body;
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
    if(this.boundTopLevelEvents){ return }

    this.boundTopLevelEvents = true
    document.body.addEventListener("click", function(){}) // ensure all click events bubble for mobile Safari
    window.addEventListener("pageshow", e => {
      if(e.persisted){ // reload page if being restored from back/forward cache
        this.withPageLoading({to: window.location.href, kind: "redirect"})
        window.location.reload()
      }
    })
    this.bindClicks()
    this.bindNav()
    this.bindForms()
    this.bind({keyup: "keyup", keydown: "keydown"}, (e, type, view, target, targetCtx, phxEvent, phxTarget) => {
      let matchKey = target.getAttribute(this.binding(PHX_KEY))
      let pressedKey = e.key && e.key.toLowerCase() // chrome clicked autocompletes send a keydown without key
      if(matchKey && matchKey.toLowerCase() !== pressedKey){ return }

      view.pushKey(target, targetCtx, type, phxEvent, {key: e.key, ...this.eventMeta(type, e, target)})
    })
    this.bind({blur: "focusout", focus: "focusin"}, (e, type, view, targetEl, targetCtx, phxEvent, phxTarget) => {
      if(!phxTarget){
        view.pushEvent(type, targetEl, targetCtx, phxEvent, this.eventMeta(type, e, targetEl))
      }
    })
    this.bind({blur: "blur", focus: "focus"}, (e, type, view, targetEl, targetCtx, phxEvent, phxTarget) => {
      // blur and focus are triggered on document and window. Discard one to avoid dups
      if(phxTarget && !phxTarget !== "window"){
        view.pushEvent(type, targetEl, targetCtx, phxEvent, this.eventMeta(type, e, targetEl))
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

      LiveUploader.trackFiles(dropTarget, files)
      dropTarget.dispatchEvent(new Event("input", {bubbles: true}))
    })
  }

  eventMeta(eventName, e, targetEl){
    let callback = this.metadataCallbacks[eventName]
    return callback ? callback(e, targetEl) : {}
  }

  setPendingLink(href){
    this.linkRef++
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
    this.bindClick("click", "click", false)
    this.bindClick("mousedown", "capture-click", true)
  }

  bindClick(eventName, bindingName, capture){
    let click = this.binding(bindingName)
    window.addEventListener(eventName, e => {
      if(!this.isConnected()){ return }
      let target = null
      if(capture){
        target = e.target.matches(`[${click}]`) ? e.target : e.target.querySelector(`[${click}]`)
      } else {
        target = closestPhxBinding(e.target, click)
      }
      let phxEvent = target && target.getAttribute(click)
      if(!phxEvent){ return }
      if(target.getAttribute("href") === "#"){ e.preventDefault() }

      this.debounce(target, e, () => {
        this.withinOwners(target, (view, targetCtx) => {
          view.pushEvent("click", target, targetCtx, phxEvent, this.eventMeta("click", e, target))
        })
      })
    }, capture)
  }

  bindNav(){
    if(!Browser.canPushState()){ return }
    if(history.scrollRestoration){ history.scrollRestoration = "manual" }
    let scrollTimer = null
    window.addEventListener("scroll", e => {
      clearTimeout(scrollTimer)
      scrollTimer = setTimeout(() => {
        Browser.updateCurrentState(state => Object.assign(state, {scroll: window.scrollY}))
      }, 100)
    })
    window.addEventListener("popstate", event => {
      if(!this.registerNewLocation(window.location)){ return }
      let {type, id, root, scroll} = event.state || {}
      let href = window.location.href

      if(this.main.isConnected() && (type === "patch" && id  === this.main.id)){
        this.main.pushLinkPatch(href, null)
      } else {
        this.replaceMain(href, null, () => {
          if(root){ this.replaceRootHistory() }
          if(typeof(scroll) === "number"){
            setTimeout(() => {
              window.scrollTo(0, scroll)
            }, 0) // the body needs to render before we scroll.
          }
        })
      }
    }, false)
    window.addEventListener("click", e => {
      let target = closestPhxBinding(e.target, PHX_LIVE_LINK)
      let type = target && target.getAttribute(PHX_LIVE_LINK)
      let wantsNewTab = e.metaKey || e.ctrlKey || e.button === 1
      if(!type || !this.isConnected() || !this.main || wantsNewTab){ return }
      let href = target.href
      let linkState = target.getAttribute(PHX_LINK_STATE)
      e.preventDefault()
      if(this.pendingLink === href){ return }

      if(type === "patch"){
        this.pushHistoryPatch(href, linkState, target)
      } else if(type === "redirect") {
        this.historyRedirect(href, linkState)
      } else {
        throw new Error(`expected ${PHX_LIVE_LINK} to be "patch" or "redirect", got: ${type}`)
      }
    }, false)
  }

  withPageLoading(info, callback){
    DOM.dispatchEvent(window, "phx:page-loading-start", info)
    let done = () => DOM.dispatchEvent(window, "phx:page-loading-stop", info)
    return callback ? callback(done) : done
  }

  pushHistoryPatch(href, linkState, targetEl){
    this.withPageLoading({to: href, kind: "patch"}, done => {
      this.main.pushLinkPatch(href, targetEl, () => {
        this.historyPatch(href, linkState)
        done()
      })
    })
  }

  historyPatch(href, linkState){
    Browser.pushState(linkState, {type: "patch", id: this.main.id}, href)
    this.registerNewLocation(window.location)
  }

  historyRedirect(href, linkState, flash){
    let scroll = window.scrollY
    this.withPageLoading({to: href, kind: "redirect"}, done => {
      this.replaceMain(href, flash, () => {
        Browser.pushState(linkState, {type: "redirect", id: this.main.id, scroll: scroll}, href)
        this.registerNewLocation(window.location)
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
        if(input.type === "number" && input.validity && input.validity.badInput){ return }
        let currentIterations = iterations
        iterations++
        let {at: at, type: lastType} = DOM.private(input, "prev-iteration") || {}
        // detect dup because some browsers dispatch both "input" and "change"
        if(at === currentIterations - 1 && type !== lastType){ return }

        DOM.putPrivate(input, "prev-iteration", {at: currentIterations, type: type})

        this.debounce(input, e, () => {
          this.withinOwners(input.form, (view, targetCtx) => {
            DOM.putPrivate(input, PHX_HAS_FOCUSED, true)
            if(!DOM.isTextualInput(input)){
              this.setActiveElement(input)
            }
            view.pushInput(input, targetCtx, phxEvent, e.target)
          })
        })
      }, false)
    }
  }

  debounce(el, event, callback){
    let phxDebounce = this.binding(PHX_DEBOUNCE)
    let phxThrottle = this.binding(PHX_THROTTLE)
    let defaultDebounce = this.defaults.debounce.toString()
    let defaultThrottle = this.defaults.throttle.toString()
    DOM.debounce(el, event, phxDebounce, defaultDebounce, phxThrottle, defaultThrottle, callback)
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
      let requestURL = new URL(href)
      let requestPath = requestURL.pathname + requestURL.search
      let responseURL = maybe(req.getResponseHeader(RESPONSE_URL_HEADER) || req.responseURL, url => new URL(url))
      let responsePath = responseURL ? responseURL.pathname + responseURL.search : null
      if(req.getResponseHeader(LINK_HEADER) !== "live-link"){
        return callback(400)
      } else if(responseURL === null || responsePath != requestPath){
        return callback(302)
      } else if(req.status !== 200){
        return callback(req.status)
      } else {
        callback(200, req.responseText)
      }
    }
    req.send()
  },

  updateCurrentState(callback){ if(!this.canPushState()){ return }
    history.replaceState(callback(history.state || {}), "", window.location.href)
  },

  pushState(kind, meta, to){
    if(this.canPushState()){
      if(to !== window.location.href){
        if(meta.type == "redirect" && meta.scroll) {
          // If we're redirecting store the current scrollY for the current history state.
          let currentState = history.state || {}
          currentState.scroll = meta.scroll
          history.replaceState(currentState, "", window.location.href)
        }

        delete meta.scroll // Only store the scroll in the redirect case.
        history[kind + "State"](meta, "", to || null) // IE will coerce undefined to string
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

  getHashTargetEl(maybeHash) {
    let hash = maybeHash.toString().substring(1)
    if(hash === ""){ return }
    return document.getElementById(hash) || document.querySelector(`a[name="${hash}"]`)
  }
}

export let DOM = {
  byId(id){ return document.getElementById(id) || logError(`no id found for ${id}`) },

  removeClass(el, className){
    el.classList.remove(className)
    if(el.classList.length === 0){ el.removeAttribute("class") }
  },

  all(node, query, callback){
    let array = Array.from(node.querySelectorAll(query))
    return callback ? array.forEach(callback) : array
  },

  childNodeLength(html){
    let template = document.createElement("template")
    template.innerHTML = html
    return template.content.childElementCount
  },

  isUploadInput(el){ return el.type === "file" && el.getAttribute(PHX_UPLOAD_REF) !== null },

  findUploadInputs(node){ return this.all(node, `input[type="file"][${PHX_UPLOAD_REF}]`) },

  findComponentNodeList(node, cid){
    return this.filterWithinSameLiveView(this.all(node, `[${PHX_COMPONENT}="${cid}"]`), node)
  },

  isPhxDestroyed(node){
    return node.id && DOM.private(node, "destroyed") ? true : false
  },

  markPhxChildDestroyed(el){
    el.setAttribute(PHX_SESSION, "")
    this.putPrivate(el, "destroyed", true)
  },

  findPhxChildrenInFragment(html, parentId){
    let template = document.createElement("template")
    template.innerHTML = html
    return this.findPhxChildren(template.content, parentId)
  },

  isIgnored(el, phxUpdate){
    return (el.getAttribute(phxUpdate) || el.getAttribute("data-phx-update")) === "ignore"
  },

  isPhxUpdate(el, phxUpdate, updateTypes){
    return el.getAttribute && updateTypes.indexOf(el.getAttribute(phxUpdate)) >= 0
  },

  findPhxChildren(el, parentId){
    return this.all(el, `${PHX_VIEW_SELECTOR}[${PHX_PARENT_ID}="${parentId}"]`)
  },

  findParentCIDs(node, cids){
    let initial = new Set(cids)
    return cids.reduce((acc, cid) => {
      let selector = `[${PHX_COMPONENT}="${cid}"] [${PHX_COMPONENT}]`

      this.filterWithinSameLiveView(this.all(node, selector), node)
        .map(el => parseInt(el.getAttribute(PHX_COMPONENT)))
        .forEach(childCID => acc.delete(childCID))

      return acc
    }, initial)
  },

  filterWithinSameLiveView(nodes, parent) {
    if(parent.querySelector(PHX_VIEW_SELECTOR)) {
      return nodes.filter(el => this.withinSameLiveView(el, parent))
    } else {
      return nodes
    }
  },

  withinSameLiveView(node, parent){
    while(node = node.parentNode){
      if(node.isSameNode(parent)){ return true }
      if(node.getAttribute(PHX_VIEW)){ return false }
    }
  },

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

  putTitle(str){
    let titleEl = document.querySelector("title")
    let {prefix, suffix} = titleEl.dataset
    document.title = `${prefix || ""}${str}${suffix || ""}`
  },

  debounce(el, event, phxDebounce, defaultDebounce, phxThrottle, defaultThrottle, callback){
    let debounce = el.getAttribute(phxDebounce)
    let throttle = el.getAttribute(phxThrottle)
    if(debounce === ""){ debounce = defaultDebounce }
    if(throttle === ""){ throttle = defaultThrottle }
    let value = debounce || throttle
    switch(value){
      case null: return callback()

      case "blur":
        if(this.once(el, "debounce-blur")){
          el.addEventListener("blur", () => callback())
        }
        return

      default:
        let timeout = parseInt(value)
        let trigger = () => throttle ? this.deletePrivate(el, THROTTLED) : callback()
        let currentCycle = this.incCycle(el, DEBOUNCE_TRIGGER, trigger)
        if(isNaN(timeout)){ return logError(`invalid throttle/debounce value: ${value}`) }
        if(throttle){
          let newKeyDown = false
          if(event.type === "keydown"){
            let prevKey = this.private(el, DEBOUNCE_PREV_KEY)
            this.putPrivate(el, DEBOUNCE_PREV_KEY, event.key)
            newKeyDown = prevKey !== event.key
          }

          if(!newKeyDown && this.private(el, THROTTLED)){
            return false
          } else {
            callback()
            this.putPrivate(el, THROTTLED, true)
            setTimeout(() => this.triggerCycle(el, DEBOUNCE_TRIGGER), timeout)
          }
        } else {
          setTimeout(() => this.triggerCycle(el, DEBOUNCE_TRIGGER, currentCycle), timeout)
        }

        if(el.form && this.once(el.form, "bind-debounce")){
          el.form.addEventListener("submit", (e) => {
            Array.from((new FormData(el.form)).entries(), ([name, val]) => {
              let input = el.form.querySelector(`[name="${name}"]`)
              this.incCycle(input, DEBOUNCE_TRIGGER)
              this.deletePrivate(input, THROTTLED)
            })
          })
        }
        if(this.once(el, "bind-debounce")){
          el.addEventListener("blur", (e) => this.triggerCycle(el, DEBOUNCE_TRIGGER))
        }
    }
  },

  triggerCycle(el, key, currentCycle){
    let [cycle, trigger] = this.private(el, key)
    if(!currentCycle){ currentCycle = cycle }
    if(currentCycle === cycle){
      this.incCycle(el, key)
      trigger()
    }
  },

  once(el, key){
    if(this.private(el, key) === true){ return false }
    this.putPrivate(el, key, true)
    return true
  },

  incCycle(el, key, trigger = function(){}){
    let [currentCycle, oldTrigger] = this.private(el, key) || [0, trigger]
    currentCycle++
    this.putPrivate(el, key, [currentCycle, trigger])
    return currentCycle
  },

  discardError(container, el, phxFeedbackFor){
    let field = el.getAttribute && el.getAttribute(phxFeedbackFor)
    // TODO: Remove id lookup after we update Phoenix to use input_name instead of input_id
    let input = field && container.querySelector(`[id="${field}"], [name="${field}"]`)
    if(!input){ return }

    if(!(this.private(input, PHX_HAS_FOCUSED) || this.private(input.form, PHX_HAS_SUBMITTED))){
      el.classList.add(PHX_NO_FEEDBACK_CLASS)
    }
  },

  showError(inputEl, phxFeedbackFor){
    if(inputEl.id || inputEl.name){
      this.all(inputEl.form, `[${phxFeedbackFor}="${inputEl.id}"], [${phxFeedbackFor}="${inputEl.name}"]`, (el) => {
        this.removeClass(el, PHX_NO_FEEDBACK_CLASS)
      })
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
    if(typeof(html) === "undefined"){
      return node.cloneNode(true)
    } else {
      let cloned = node.cloneNode(false)
      cloned.innerHTML = html
      return cloned
    }
  },

  mergeAttrs(target, source, opts = {}){
    let exclude = opts.exclude || []
    let isIgnored = opts.isIgnored
    let sourceAttrs = source.attributes
    for (let i = sourceAttrs.length - 1; i >= 0; i--){
      let name = sourceAttrs[i].name
      if(exclude.indexOf(name) < 0){ target.setAttribute(name, source.getAttribute(name)) }
    }

    let targetAttrs = target.attributes
    for (let i = targetAttrs.length - 1; i >= 0; i--){
      let name = targetAttrs[i].name
      if(isIgnored){
        if(name.startsWith("data-") && !source.hasAttribute(name)){ target.removeAttribute(name) }
      } else {
        if(!source.hasAttribute(name)){ target.removeAttribute(name) }
      }
    }
  },

  mergeFocusedInput(target, source){
    // skip selects because FF will reset highlighted index for any setAttribute
    if(!(target instanceof HTMLSelectElement)){ DOM.mergeAttrs(target, source, {except: ["value"]}) }
    if(source.readOnly){
      target.setAttribute("readonly", true)
    } else {
      target.removeAttribute("readonly")
    }
  },

  hasSelectionRange(el) {
    return el.setSelectionRange && (el.type === "text" || el.type === "textarea")
  },

  restoreFocus(focused, selectionStart, selectionEnd){
    if(!DOM.isTextualInput(focused)){ return }
    let wasFocused = focused.matches(":focus")
    if(focused.readOnly){ focused.blur() }
    if(!wasFocused){ focused.focus() }
    if(this.hasSelectionRange(focused)){
      focused.setSelectionRange(selectionStart, selectionEnd)
    }
  },

  isFormInput(el){ return /^(?:input|select|textarea)$/i.test(el.tagName) && el.type !== "button"},

  syncAttrsToProps(el){
    if(el instanceof HTMLInputElement && CHECKABLE_INPUTS.indexOf(el.type.toLocaleLowerCase()) >= 0){
      el.checked = el.getAttribute("checked") !== null
    }
  },

  isTextualInput(el){ return FOCUSABLE_INPUTS.indexOf(el.type) >= 0 },

  isNowTriggerFormExternal(el, phxTriggerExternal){
    return el.getAttribute && el.getAttribute(phxTriggerExternal) !== null
  },

  syncPendingRef(fromEl, toEl, disableWith){
    let ref = fromEl.getAttribute(PHX_REF)
    if(ref === null){ return true }

    if(DOM.isFormInput(fromEl) || fromEl.getAttribute(disableWith) !== null){
      if(DOM.isUploadInput(fromEl)){ DOM.mergeAttrs(fromEl, toEl, {isIgnored: true}) }
      DOM.putPrivate(fromEl, PHX_REF, toEl)
      return false
    } else {
      PHX_EVENT_CLASSES.forEach(className => {
        fromEl.classList.contains(className) && toEl.classList.add(className)
      })
      toEl.setAttribute(PHX_REF, ref)
      return true
    }
  },

  cleanChildNodes(container, phxUpdate){
    if (DOM.isPhxUpdate(container, phxUpdate, ["append", "prepend"])) {
      let toRemove = []
      container.childNodes.forEach(childNode => {
        if(!childNode.id){
          // Skip warning if it's an empty text node (e.g. a new-line)
          let isEmptyTextNode = childNode.nodeType === Node.TEXT_NODE && childNode.nodeValue.trim() === ""
          if(!isEmptyTextNode){
            logError(`only HTML element tags with an id are allowed inside containers with phx-update.\n\n` +
                    `removing illegal node: "${(childNode.outerHTML || childNode.nodeValue).trim()}"\n\n`)
          }
          toRemove.push(childNode)
        }
      })
      toRemove.forEach(childNode => childNode.remove())
    }
  }
}

class DOMPostMorphRestorer {
  constructor(containerBefore, containerAfter, updateType) {
    let idsBefore = new Set()
    let idsAfter = new Set([...containerAfter.children].map(child => child.id))

    let elementsToModify = []

    Array.from(containerBefore.children).forEach(child => {
      if (child.id) { // all of our children should be elements with ids
        idsBefore.add(child.id)
        if (idsAfter.has(child.id)) {
          let previousElementId = child.previousElementSibling && child.previousElementSibling.id
          elementsToModify.push({elementId: child.id, previousElementId: previousElementId})
        }
      }
    })

    this.containerId = containerAfter.id
    this.updateType = updateType
    this.elementsToModify = elementsToModify
    this.elementIdsToAdd = [...idsAfter].filter(id => !idsBefore.has(id))
  }

  // We do the following to optimize append/prepend operations:
  //   1) Track ids of modified elements & of new elements
  //   2) All the modified elements are put back in the correct position in the DOM tree
  //      by storing the id of their previous sibling
  //   3) New elements are going to be put in the right place by morphdom during append.
  //      For prepend, we move them to the first position in the container
  perform() {
    let container = DOM.byId(this.containerId)
    this.elementsToModify.forEach(elementToModify => {
      if (elementToModify.previousElementId) {
        maybe(document.getElementById(elementToModify.previousElementId), previousElem => {
          maybe(document.getElementById(elementToModify.elementId), elem => {
            let isInRightPlace = elem.previousElementSibling && elem.previousElementSibling.id == previousElem.id
            if (!isInRightPlace) {
              previousElem.insertAdjacentElement("afterend", elem)
            }
          })
        })
      } else {
        // This is the first element in the container
        maybe(document.getElementById(elementToModify.elementId), elem => {
          let isInRightPlace = elem.previousElementSibling == null
          if (!isInRightPlace) {
            container.insertAdjacentElement("afterbegin", elem)
          }
        })
      }
    })

    if(this.updateType == "prepend"){
      this.elementIdsToAdd.reverse().forEach(elemId => {
        maybe(document.getElementById(elemId), elem => container.insertAdjacentElement("afterbegin", elem))
      })
    }
  }
}

class DOMPatch {
  static patchEl(fromEl, toEl, activeElement){
    morphdom(fromEl, toEl, {
      childrenOnly: false,
      onBeforeElUpdated: (fromEl, toEl) => {
        if(activeElement && activeElement.isSameNode(fromEl) && DOM.isFormInput(fromEl)){
          DOM.mergeFocusedInput(fromEl, toEl)
          return false
        }
      }
    })
  }

  constructor(view, container, id, html, targetCID){
    this.view = view
    this.liveSocket = view.liveSocket
    this.container = container
    this.id = id
    this.rootID = view.root.id
    this.html = html
    this.targetCID = targetCID
    this.cidPatch = typeof(this.targetCID) === "number"
    this.callbacks = {
      beforeadded: [], beforeupdated: [], beforephxChildAdded: [],
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

  markPrunableContentForRemoval(){
    DOM.all(this.container, `[phx-update=append] > *, [phx-update=prepend] > *`, el => {
      el.setAttribute(PHX_REMOVE, "")
    })
  }

  perform(){
    let {view, liveSocket, container, html} = this
    let targetContainer = this.isCIDPatch() ? this.targetCIDContainer(html) : container
    if(this.isCIDPatch() && !targetContainer){ return }

    let focused = liveSocket.getActiveElement()
    let {selectionStart, selectionEnd} = focused && DOM.hasSelectionRange(focused) ? focused : {}
    let phxUpdate = liveSocket.binding(PHX_UPDATE)
    let phxFeedbackFor = liveSocket.binding(PHX_FEEDBACK_FOR)
    let disableWith = liveSocket.binding(PHX_DISABLE_WITH)
    let phxTriggerExternal = liveSocket.binding(PHX_TRIGGER_ACTION)
    let added = []
    let updates = []
    let appendPrependUpdates = []
    let externalFormTriggered = null

    let diffHTML = liveSocket.time("premorph container prep", () => {
      return this.buildDiffHTML(container, html, phxUpdate, targetContainer)
    })

    this.trackBefore("added", container)
    this.trackBefore("updated", container, container)

    liveSocket.time("morphdom", () => {
      morphdom(targetContainer, diffHTML, {
        childrenOnly: targetContainer.getAttribute(PHX_COMPONENT) === null,
        getNodeKey: (node) => {
          return DOM.isPhxDestroyed(node) ? null : node.id
        },
        onBeforeNodeAdded: (el) => {
          //input handling
          DOM.discardError(targetContainer, el, phxFeedbackFor)
          this.trackBefore("added", el)
          return el
        },
        onNodeAdded: (el) => {
          if(DOM.isNowTriggerFormExternal(el, phxTriggerExternal)){
            externalFormTriggered = el
          }
          // nested view handling
          if(DOM.isPhxChild(el) && view.ownsElement(el)){
            this.trackAfter("phxChildAdded", el)
          }
          added.push(el)
        },
        onNodeDiscarded: (el) => {
          // nested view handling
          if(DOM.isPhxChild(el)){ liveSocket.destroyViewByEl(el) }
          this.trackAfter("discarded", el)
        },
        onBeforeNodeDiscarded: (el) => {
          if(el.getAttribute && el.getAttribute(PHX_REMOVE) !== null){ return true }
          if(el.parentNode !== null && DOM.isPhxUpdate(el.parentNode, phxUpdate, ["append", "prepend"]) && el.id){ return false }
          if(this.skipCIDSibling(el)){ return false }
          return true
        },
        onElUpdated: (el) => {
          if(DOM.isNowTriggerFormExternal(el, phxTriggerExternal)){
            externalFormTriggered = el
          }
          updates.push(el)
        },
        onBeforeElUpdated: (fromEl, toEl) => {
          DOM.cleanChildNodes(toEl, phxUpdate)
          if(this.skipCIDSibling(toEl)){ return false }
          if(DOM.isIgnored(fromEl, phxUpdate)){
            this.trackBefore("updated", fromEl, toEl)
            DOM.mergeAttrs(fromEl, toEl, {isIgnored: true})
            updates.push(fromEl)
            return false
          }
          if(fromEl.type === "number" && (fromEl.validity && fromEl.validity.badInput)){ return false }
          if(!DOM.syncPendingRef(fromEl, toEl, disableWith)){
            if(DOM.isUploadInput(fromEl)){
              this.trackBefore("updated", fromEl, toEl)
              updates.push(fromEl)
            }
            return false
          }

          // nested view handling
          if(DOM.isPhxChild(toEl)){
            let prevSession = fromEl.getAttribute(PHX_SESSION)
            DOM.mergeAttrs(fromEl, toEl, {exclude: [PHX_STATIC]})
            if(prevSession !== ""){ fromEl.setAttribute(PHX_SESSION, prevSession) }
            fromEl.setAttribute(PHX_ROOT_ID, this.rootID)
            return false
          }

          // input handling
          DOM.copyPrivates(toEl, fromEl)
          DOM.discardError(targetContainer, toEl, phxFeedbackFor)

          let isFocusedFormEl = focused && fromEl.isSameNode(focused) && DOM.isFormInput(fromEl)
          if(isFocusedFormEl && !this.forceFocusedSelectUpdate(fromEl, toEl)){
            this.trackBefore("updated", fromEl, toEl)
            DOM.mergeFocusedInput(fromEl, toEl)
            DOM.syncAttrsToProps(fromEl)
            updates.push(fromEl)
            return false
          } else {
            if(DOM.isPhxUpdate(toEl, phxUpdate, ["append", "prepend"])){
              appendPrependUpdates.push(new DOMPostMorphRestorer(fromEl, toEl, toEl.getAttribute(phxUpdate)))
            }
            DOM.syncAttrsToProps(toEl)
            this.trackBefore("updated", fromEl, toEl)
            return true
          }
        }
      })
    })

    if(liveSocket.isDebugEnabled()){ detectDuplicateIds() }

    if(appendPrependUpdates.length > 0){
      liveSocket.time("post-morph append/prepend restoration", () => {
        appendPrependUpdates.forEach(update => update.perform())
      })
    }

    liveSocket.silenceEvents(() => DOM.restoreFocus(focused, selectionStart, selectionEnd))
    DOM.dispatchEvent(document, "phx:update")
    added.forEach(el => this.trackAfter("added", el))
    updates.forEach(el => this.trackAfter("updated", el))

    if(externalFormTriggered){
      liveSocket.disconnect()
      externalFormTriggered.submit()
    }
    return true
  }

  forceFocusedSelectUpdate(fromEl, toEl){
    let isSelect = ["select", "select-one", "select-multiple"].find((t) => t === fromEl.type)
    return fromEl.multiple === true || (isSelect && fromEl.innerHTML != toEl.innerHTML)
  }

  isCIDPatch(){ return this.cidPatch }

  skipCIDSibling(el){
    return el.nodeType === Node.ELEMENT_NODE && el.getAttribute(PHX_SKIP) !== null
  }

  targetCIDContainer(html){ if(!this.isCIDPatch()){ return }
    let [first, ...rest] = DOM.findComponentNodeList(this.container, this.targetCID)
    if(rest.length === 0 && DOM.childNodeLength(html) === 1){
      return first
    } else {
      return first && first.parentNode
    }
  }

  // builds HTML for morphdom patch
  // - for full patches of LiveView or a component with a single
  //   root node, simply returns the HTML
  // - for patches of a component with multiple root nodes, the
  //   parent node becomes the target container and non-component
  //   siblings are marked as skip.
  buildDiffHTML(container, html, phxUpdate, targetContainer){
    let isCIDPatch = this.isCIDPatch()
    let isCIDWithSingleRoot = isCIDPatch && targetContainer.getAttribute(PHX_COMPONENT) === this.targetCID.toString()
    if(!isCIDPatch || isCIDWithSingleRoot){
      return html
    } else {
      // component patch with multiple CID roots
      let diffContainer = null
      let template = document.createElement("template")
      diffContainer = DOM.cloneNode(targetContainer)
      let [firstComponent, ...rest] = DOM.findComponentNodeList(diffContainer, this.targetCID)
      template.innerHTML = html
      rest.forEach(el => el.remove())
      Array.from(diffContainer.childNodes).forEach(child => {
        // we can only skip trackable nodes with an ID
        if(child.id && child.nodeType === Node.ELEMENT_NODE && child.getAttribute(PHX_COMPONENT) !== this.targetCID.toString()){
          child.setAttribute(PHX_SKIP, "")
          child.innerHTML = ""
        }
      })
      Array.from(template.content.childNodes).forEach(el => diffContainer.insertBefore(el, firstComponent))
      firstComponent.remove()
      return diffContainer.outerHTML
    }
  }
}

export class View {
  constructor(el, liveSocket, parentView, href, flash){
    this.liveSocket = liveSocket
    this.flash = flash
    this.parent = parentView
    this.root = parentView ? parentView.root : this
    this.el = el
    this.id = this.el.id
    this.view = this.el.getAttribute(PHX_VIEW)
    this.ref = 0
    this.childJoins = 0
    this.loaderTimer = null
    this.pendingDiffs = []
    this.pruningCIDs = []
    this.href = href
    this.joinCount = this.parent ? this.parent.joinCount - 1 : 0
    this.joinPending = true
    this.destroyed = false
    this.joinCallback = function(){}
    this.stopCallback = function(){}
    this.pendingJoinOps = this.parent ? null : []
    this.viewHooks = {}
    this.uploaders = {}
    this.formSubmits = []
    this.children = this.parent ? null : {}
    this.root.children[this.id] = {}
    this.channel = this.liveSocket.channel(`lv:${this.id}`, () => {
      return {
        url: this.href,
        params: this.connectParams(),
        session: this.getSession(),
        static: this.getStatic(),
        flash: this.flash
      }
    })
    this.showLoader(this.liveSocket.loaderTimeout)
    this.bindChannel()
  }

  isMain(){ return this.liveSocket.main === this }

  connectParams(){
    let params = this.liveSocket.params(this.view)
    let manifest =
      DOM.all(document, `[${this.binding(PHX_TRACK_STATIC)}]`)
      .map(node => node.src || node.href).filter(url => typeof(url) === "string")

    if(manifest.length > 0){ params["_track_static"] = manifest }
    params["_mounts"] = this.joinCount

    return params
  }

  name(){ return this.view }

  isConnected(){ return this.channel.canPush() }

  getSession(){ return this.el.getAttribute(PHX_SESSION) }

  getStatic(){
    let val = this.el.getAttribute(PHX_STATIC)
    return val === "" ? null : val
  }

  destroy(callback = function(){}){
    this.destroyAllChildren()
    this.destroyed = true
    delete this.root.children[this.id]
    if(this.parent){ delete this.root.children[this.parent.id][this.id] }
    clearTimeout(this.loaderTimer)
    let onFinished = () => {
      callback()
      for(let id in this.viewHooks){
        this.destroyHook(this.viewHooks[id])
      }
    }

    DOM.markPhxChildDestroyed(this.el)

    this.log("destroyed", () => ["the child has been removed from the parent"])
    this.channel.leave()
      .receive("ok", onFinished)
      .receive("error", onFinished)
      .receive("timeout", onFinished)
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
      for(let id in this.viewHooks){ this.viewHooks[id].__disconnected() }
      this.setContainerClasses(PHX_DISCONNECTED_CLASS)
    }
  }

  hideLoader(){
    clearTimeout(this.loaderTimer)
    this.setContainerClasses(PHX_CONNECTED_CLASS)
  }

  triggerReconnected(){
    for(let id in this.viewHooks){ this.viewHooks[id].__reconnected() }
  }

  log(kind, msgCallback){
    this.liveSocket.log(this, kind, msgCallback)
  }

  withinTargets(phxTarget, callback){
    if(/^(0|[1-9]\d*)$/.test(phxTarget)){
      let targets = DOM.findComponentNodeList(this.el, phxTarget)
      if(targets.length === 0){
        logError(`no component found matching phx-target of ${phxTarget}`)
      } else {
        callback(this, targets[0])
      }
    } else {
      let targets = Array.from(document.querySelectorAll(phxTarget))
      if(targets.length === 0){ logError(`nothing found matching the phx-target selector "${phxTarget}"`) }
      targets.forEach(target => this.liveSocket.owner(target, view => callback(view, target)))
    }
  }

  applyDiff(type, rawDiff, callback){
    this.log(type, () => ["", clone(rawDiff)])
    let {diff, reply, events, title} = Rendered.extract(rawDiff)
    if(title){ DOM.putTitle(title) }

    callback({diff, reply, events})
    return reply
  }

  onJoin(resp){
    let {rendered} = resp
    this.childJoins = 0
    this.joinPending = true
    this.flash = null

    Browser.dropLocal(this.name(), CONSECUTIVE_RELOADS)
    this.applyDiff("mount", rendered, ({diff, events}) => {
      this.rendered = new Rendered(this.id, diff)
      let html = this.renderContainer(null, "join")
      this.dropPendingRefs()
      let forms = this.formsForRecovery(html)
      this.joinCount++

      if(forms.length > 0){
        forms.forEach((form, i) => {
          this.pushFormRecovery(form, resp => {
            if(i === forms.length - 1){
              this.onJoinComplete(resp, html, events)
            }
          })
        })
      } else {
        this.onJoinComplete(resp, html, events)
      }
    })
  }

  dropPendingRefs(){ DOM.all(this.el, `[${PHX_REF}]`, el => el.removeAttribute(PHX_REF)) }

  onJoinComplete({live_patch}, html, events){
    // In order to provide a better experience, we want to join
    // all LiveViews first and only then apply their patches.
    if(this.joinCount > 1 || (this.parent && !this.parent.isJoinPending())){
      return this.applyJoinPatch(live_patch, html, events)
    }

    // One downside of this approach is that we need to find phxChildren
    // in the html fragment, instead of directly on the DOM. The fragment
    // also does not include PHX_STATIC, so we need to copy it over from
    // the DOM.
    let newChildren = DOM.findPhxChildrenInFragment(html, this.id).filter(toEl => {
      let fromEl = toEl.id && this.el.querySelector(`#${toEl.id}`)
      let phxStatic = fromEl && fromEl.getAttribute(PHX_STATIC)
      if(phxStatic){ toEl.setAttribute(PHX_STATIC, phxStatic) }
      return this.joinChild(toEl)
    })

    if(newChildren.length === 0){
      if(this.parent){
        this.root.pendingJoinOps.push([this, () => this.applyJoinPatch(live_patch, html, events)])
        this.parent.ackJoin(this)
      } else {
        this.onAllChildJoinsComplete()
        this.applyJoinPatch(live_patch, html, events)
      }
    } else {
      this.root.pendingJoinOps.push([this, () => this.applyJoinPatch(live_patch, html, events)])
    }
  }

  attachTrueDocEl(){
    this.el = DOM.byId(this.id)
    this.el.setAttribute(PHX_ROOT_ID, this.root.id)
  }

  dispatchEvents(events){
    events.forEach(([event, payload]) => {
      window.dispatchEvent(new CustomEvent(`phx:hook:${event}`, {detail: payload}))
    })
  }

  applyJoinPatch(live_patch, html, events){
    this.attachTrueDocEl()
    let patch = new DOMPatch(this, this.el, this.id, html, null)
    patch.markPrunableContentForRemoval()
    this.performPatch(patch, false)
    this.joinNewChildren()
    DOM.all(this.el, `[${this.binding(PHX_HOOK)}], [data-phx-${PHX_HOOK}]`, hookEl => {
      let hook = this.addHook(hookEl)
      if(hook){ hook.__mounted() }
    })

    this.joinPending = false
    this.dispatchEvents(events)
    this.applyPendingUpdates()

    if(live_patch){
      let {kind, to} = live_patch
      this.liveSocket.historyPatch(to, kind)
    }
    this.hideLoader()
    if(this.joinCount > 1){ this.triggerReconnected() }
    this.stopCallback()
  }

  triggerBeforeUpdateHook(fromEl, toEl){
    this.liveSocket.triggerDOM("onBeforeElUpdated", [fromEl, toEl])
    let hook = this.getHook(fromEl)
    let isIgnored = hook && DOM.isIgnored(fromEl, this.binding(PHX_UPDATE))
    if(hook && !fromEl.isEqualNode(toEl) && !(isIgnored && isEqualObj(fromEl.dataset, toEl.dataset))){
      hook.__beforeUpdate()
      return hook
    }
  }

  performPatch(patch, pruneCids){
    let destroyedCIDs = []
    let phxChildrenAdded = false
    let updatedHookIds = new Set()

    patch.after("added", el => {
      this.liveSocket.triggerDOM("onNodeAdded", [el])

      let newHook = this.addHook(el)
      if(newHook){ newHook.__mounted() }
    })

    patch.after("phxChildAdded", el => phxChildrenAdded = true)

    patch.before("updated", (fromEl, toEl) => {
      let hook = this.triggerBeforeUpdateHook(fromEl, toEl)
      if(hook){ updatedHookIds.add(fromEl.id) }
    })

    patch.after("updated", el => {
      if(updatedHookIds.has(el.id)){ this.getHook(el).__updated() }
    })

    patch.after("discarded", (el) => {
      let cid = this.componentID(el)
      if(typeof(cid) === "number" && destroyedCIDs.indexOf(cid) === -1){ destroyedCIDs.push(cid) }
      let hook = this.getHook(el)
      hook && this.destroyHook(hook)
    })

    patch.perform()

    // We should not pruneCids on joins. Otherwise, in case of
    // rejoins, we may notify cids that no longer belong to the
    // current LiveView to be removed.
    if(pruneCids) {
      this.maybePushComponentsDestroyed(destroyedCIDs)
    }

    return phxChildrenAdded
  }

  joinNewChildren(){
    DOM.findPhxChildren(this.el, this.id).forEach(el => this.joinChild(el))
  }

  getChildById(id){ return this.root.children[this.id][id] }

  getDescendentByEl(el){
    if(el.id === this.id){
      return this
    } else {
      return this.children[el.getAttribute(PHX_PARENT_ID)][el.id]
    }
  }

  destroyDescendent(id){
    for(let parentId in this.root.children){
      for(let childId in this.root.children[parentId]){
        if(childId === id){ return this.root.children[parentId][childId].destroy() }
      }
    }
  }

  joinChild(el){
    let child = this.getChildById(el.id)
    if(!child){
      let view = new View(el, this.liveSocket, this)
      this.root.children[this.id][view.id] = view
      view.join()
      this.childJoins++
      return true
    }
  }

  isJoinPending(){ return this.joinPending }

  ackJoin(child){
    this.childJoins--

    if(this.childJoins === 0){
      if(this.parent){
        this.parent.ackJoin(this)
      } else {
        this.onAllChildJoinsComplete()
      }
    }
  }

  onAllChildJoinsComplete(){
    this.joinCallback()
    this.pendingJoinOps.forEach(([view, op]) => {
      if(!view.isDestroyed()){ op() }
    })
    this.pendingJoinOps = []
  }

  update(diff, events){
    if(this.isJoinPending() || this.liveSocket.hasPendingLink()){
      return this.pendingDiffs.push({diff, events})
    }

    this.rendered.mergeDiff(diff)
    let phxChildrenAdded = false

    // When the diff only contains component diffs, then walk components
    // and patch only the parent component containers found in the diff.
    // Otherwise, patch entire LV container.
    if(this.rendered.isComponentOnlyDiff(diff)){
      this.liveSocket.time("component patch complete", () => {
        let parentCids = DOM.findParentCIDs(this.el, this.rendered.componentCIDs(diff))
        parentCids.forEach(parentCID => {
          if(this.componentPatch(this.rendered.getComponent(diff, parentCID), parentCID)){ phxChildrenAdded = true }
        })
      })
    } else if(!isEmpty(diff)){
      this.liveSocket.time("full patch complete", () => {
        let html = this.renderContainer(diff, "update")
        let patch = new DOMPatch(this, this.el, this.id, html, null)
        phxChildrenAdded = this.performPatch(patch, true)
      })
    }

    this.dispatchEvents(events)
    if(phxChildrenAdded){ this.joinNewChildren() }
  }

  renderContainer(diff, kind){
    return this.liveSocket.time(`toString diff (${kind})`, () => {
      let tag = this.el.tagName
      // Don't skip any component in the diff nor any marked as pruned
      // (as they may have been added back)
      let cids = diff ? this.rendered.componentCIDs(diff).concat(this.pruningCIDs) : null
      let html = this.rendered.toString(cids)
      return `<${tag}>${html}</${tag}>`
    })
  }

  componentPatch(diff, cid){
    if(isEmpty(diff)) return false
    let html = this.rendered.componentToString(cid)
    let patch = new DOMPatch(this, this.el, this.id, html, cid)
    let childrenAdded = this.performPatch(patch, true)
    return childrenAdded
  }

  getHook(el){ return this.viewHooks[ViewHook.elementID(el)] }

  addHook(el){ if(ViewHook.elementID(el) || !el.getAttribute){ return }
    let hookName = el.getAttribute(`data-phx-${PHX_HOOK}`) || el.getAttribute(this.binding(PHX_HOOK))
    if(hookName && !this.ownsElement(el)){ return }
    let callbacks = this.liveSocket.getHookCallbacks(hookName)

    if(callbacks){
      if(!el.id){ logError(`no DOM ID for hook "${hookName}". Hooks require a unique ID on each element.`, el)}
      let hook = new ViewHook(this, el, callbacks)
      this.viewHooks[ViewHook.elementID(hook.el)] = hook
      return hook
    } else if(hookName !== null){
      logError(`unknown hook found for "${hookName}"`, el)
    }
  }

  destroyHook(hook){
    hook.__destroyed()
    hook.__cleanup__()
    delete this.viewHooks[ViewHook.elementID(hook.el)]
  }

  applyPendingUpdates(){
    this.pendingDiffs.forEach(({diff, events}) => this.update(diff, events))
    this.pendingDiffs = []
  }

  onChannel(event, cb){
    this.liveSocket.onChannel(this.channel, event, resp => {
      if(this.isJoinPending()){
        this.root.pendingJoinOps.push([this, () => cb(resp)])
      } else {
        cb(resp)
      }
    })
  }

  bindChannel(){
    // The diff event should be handled by the regular update operations.
    // All other operations are queued to be applied only after join.
    this.liveSocket.onChannel(this.channel, "diff", (rawDiff) => {
      this.applyDiff("update", rawDiff, ({diff, events}) => this.update(diff, events))
    })
    this.onChannel("redirect", ({to, flash}) => this.onRedirect({to, flash}))
    this.onChannel("live_patch", (redir) => this.onLivePatch(redir))
    this.onChannel("live_redirect", (redir) => this.onLiveRedirect(redir))
    this.channel.onError(reason => this.onError(reason))
    this.channel.onClose(reason => this.onClose(reason))
  }

  destroyAllChildren(){
    for(let id in this.root.children[this.id]){
      this.getChildById(id).destroy()
    }
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

  onRedirect({to, flash}){ this.liveSocket.redirect(to, flash) }

  isDestroyed(){ return this.destroyed }

  join(callback){
    if(!this.parent){
      this.stopCallback = this.liveSocket.withPageLoading({to: this.href, kind: "initial"})
    }
    this.joinCallback = () => callback && callback(this, this.joinCount)
    this.liveSocket.wrapPush(this, {timeout: false}, () => {
      return this.channel.join()
        .receive("ok", data => this.onJoin(data))
        .receive("error", resp => this.onJoinError(resp))
        .receive("timeout", () => this.onJoinError({reason: "timeout"}))
    })
  }

  onJoinError(resp){
    if(resp.redirect || resp.live_redirect){
      this.joinPending = false
      this.channel.leave()
    }
    if(resp.redirect){ return this.onRedirect(resp.redirect) }
    if(resp.live_redirect){ return this.onLiveRedirect(resp.live_redirect) }
    this.log("error", () => ["unable to join", resp])
    return this.liveSocket.reloadWithJitter(this)
  }

  onClose(reason){
    if(this.isDestroyed()){ return }
    if(this.isJoinPending() || (this.liveSocket.hasPendingLink() && reason !== "leave")){
      return this.liveSocket.reloadWithJitter(this)
    }
    this.destroyAllChildren()
    this.liveSocket.dropActiveElement(this)
    // document.activeElement can be null in Internet Explorer 11
    if(document.activeElement){ document.activeElement.blur() }
    if(this.liveSocket.isUnloaded()){
      this.showLoader(BEFORE_UNLOAD_LOADER_TIMEOUT)
    }
  }

  onError(reason){
    this.onClose(reason)
    this.log("error", () => ["view crashed", reason])
    if(!this.liveSocket.isUnloaded()){ this.displayError() }
  }

  displayError(){
    if(this.isMain()){ DOM.dispatchEvent(window, "phx:page-loading-start", {to: this.href, kind: "error"}) }
    this.showLoader()
    this.setContainerClasses(PHX_DISCONNECTED_CLASS, PHX_ERROR_CLASS)
  }

  pushWithReply(refGenerator, event, payload, onReply = function(){}){
    let [ref, [el]] = refGenerator ? refGenerator() : [null, []]
    let onLoadingDone = function(){}
    if(el && (el.getAttribute(this.binding(PHX_PAGE_LOADING)) !== null)){
      onLoadingDone = this.liveSocket.withPageLoading({kind: "element", target: el})
    }

    if(typeof(payload.cid) !== "number"){ delete payload.cid }
    return(
      this.liveSocket.wrapPush(this, {timeout: true}, () => {
        return this.channel.push(event, payload, PUSH_TIMEOUT).receive("ok", resp => {
          let hookReply = null
          if(ref !== null){ this.undoRefs(ref) }
          if(resp.diff){
            hookReply = this.applyDiff("update", resp.diff, ({diff, events}) => {
              this.update(diff, events)
            })
          }
          if(resp.redirect){ this.onRedirect(resp.redirect) }
          if(resp.live_patch){ this.onLivePatch(resp.live_patch) }
          if(resp.live_redirect){ this.onLiveRedirect(resp.live_redirect) }
          onLoadingDone()
          onReply(resp, hookReply)
        })
      })
    )
  }

  undoRefs(ref){
    DOM.all(this.el, `[${PHX_REF}="${ref}"]`, el => {
      // remove refs
      el.removeAttribute(PHX_REF)
      // restore inputs
      if(el.getAttribute(PHX_READONLY) !== null){
        el.readOnly = false
        el.removeAttribute(PHX_READONLY)
      }
      if(el.getAttribute(PHX_DISABLED) !== null){
        el.disabled = false
        el.removeAttribute(PHX_DISABLED)
      }
      // remove classes
      PHX_EVENT_CLASSES.forEach(className => DOM.removeClass(el, className))
      // restore disables
      let disableRestore = el.getAttribute(PHX_DISABLE_WITH_RESTORE)
      if(disableRestore !== null){
        el.innerText = disableRestore
        el.removeAttribute(PHX_DISABLE_WITH_RESTORE)
      }
      let toEl = DOM.private(el, PHX_REF)
      if(toEl){
        let hook = this.triggerBeforeUpdateHook(el, toEl)
        DOMPatch.patchEl(el, toEl, this.liveSocket.getActiveElement())
        if(hook){ hook.__updated() }
        DOM.deletePrivate(el, PHX_REF)
      }
    })
  }

  putRef(elements, event){
    let newRef = this.ref++
    let disableWith = this.binding(PHX_DISABLE_WITH)

    elements.forEach(el => {
      el.classList.add(`phx-${event}-loading`)
      el.setAttribute(PHX_REF, newRef)
      let disableText = el.getAttribute(disableWith)
      if(disableText !== null){
        if(!el.getAttribute(PHX_DISABLE_WITH_RESTORE)){
          el.setAttribute(PHX_DISABLE_WITH_RESTORE, el.innerText)
        }
        el.innerText = disableText
      }
    })
    return [newRef, elements]
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

  pushHookEvent(targetCtx, event, payload, onReply){
    if(!this.isConnected()){
      this.log("hook", () => [`unable to push hook event. LiveView not connected`, event, payload])
      return false
    }
    let [ref, els] = this.putRef([], "hook")
    this.pushWithReply(() => [ref, els], "event", {
      type: "hook",
      event: event,
      value: payload,
      cid: this.closestComponentID(targetCtx)
    }, (resp, reply) => onReply(reply, ref))

    return ref
  }

  extractMeta(el, meta){
    let prefix = this.binding("value-")
    for (let i = 0; i < el.attributes.length; i++){
      let name = el.attributes[i].name
      if(name.startsWith(prefix)){ meta[name.replace(prefix, "")] = el.getAttribute(name) }
    }
    if(el.value !== undefined){
      meta.value = el.value

      if (el.tagName === "INPUT" && CHECKABLE_INPUTS.indexOf(el.type) >= 0 && !el.checked) {
        delete meta.value
      }
    }
    return meta
  }

  pushEvent(type, el, targetCtx, phxEvent, meta){
    this.pushWithReply(() => this.putRef([el], type), "event", {
      type: type,
      event: phxEvent,
      value: this.extractMeta(el, meta),
      cid: this.targetComponentID(el, targetCtx)
    })
  }

  pushKey(keyElement, targetCtx, kind, phxEvent, meta){
    this.pushWithReply(() => this.putRef([keyElement], kind), "event", {
      type: kind,
      event: phxEvent,
      value: this.extractMeta(keyElement, meta),
      cid: this.targetComponentID(keyElement, targetCtx)
    })
  }

  pushFileProgress(fileEl, entryRef, progress, onReply = function(){}){
    this.liveSocket.withinOwners(fileEl.form, (view, targetCtx) => {
      view.pushWithReply(null, "progress", {
        event: fileEl.getAttribute(view.binding(PHX_PROGRESS)),
        ref: fileEl.getAttribute(PHX_UPLOAD_REF),
        entry_ref: entryRef,
        progress: progress,
        cid: view.targetComponentID(fileEl.form, targetCtx)
      }, onReply)
    })
  }

  pushInput(inputEl, targetCtx, phxEvent, eventTarget, callback){
    let uploads
    let cid = this.targetComponentID(inputEl.form, targetCtx)
    let refGenerator = () => this.putRef([inputEl, inputEl.form], "change")
    let formData = serializeForm(inputEl.form, {_target: eventTarget.name})
    if(inputEl.files && inputEl.files.length > 0){
      LiveUploader.trackFiles(inputEl, Array.from(inputEl.files))
    }
    uploads = LiveUploader.serializeUploads(inputEl)
    let event = {
      type: "form",
      event: phxEvent,
      value: formData,
      uploads: uploads,
      cid: cid
    }
    this.pushWithReply(refGenerator, "event", event, resp => {
      DOM.showError(inputEl, this.liveSocket.binding(PHX_FEEDBACK_FOR))
      if(DOM.isUploadInput(inputEl) && inputEl.getAttribute("data-phx-auto-upload") !== null){
        if(LiveUploader.filesAwaitingPreflight(inputEl).length > 0) {
          let [ref, els] = refGenerator()
          this.uploadFiles(inputEl.form, targetCtx, ref, cid, (uploads) => {
            callback && callback(resp)
            this.triggerAwaitingSubmit(inputEl.form)
          })
        }
      } else {
        callback && callback(resp)
      }
    })
  }

  triggerAwaitingSubmit(formEl){
    let awaitingSubmit = this.getScheduledSubmit(formEl)
    if(awaitingSubmit){
      let [el, ref, callback] = awaitingSubmit
      this.cancelSubmit(formEl)
      callback()
    }
  }

  getScheduledSubmit(formEl){
    return this.formSubmits.find(([el, callback]) => el.isSameNode(formEl))
  }

  scheduleSubmit(formEl, ref, callback){
    if(this.getScheduledSubmit(formEl)){ return true }
    this.formSubmits.push([formEl, ref, callback])
  }

  cancelSubmit(formEl){
    this.formSubmits = this.formSubmits.filter(([el, ref, callback]) => {
      if(el.isSameNode(formEl)){
        this.undoRefs(ref)
        return false
      } else {
        return true
      }
    })
  }

  pushFormSubmit(formEl, targetCtx, phxEvent, onReply){
    let filterIgnored = el => {
      let userIgnored = closestPhxBinding(el, `${this.binding(PHX_UPDATE)}=ignore`, el.form)
      return !(userIgnored || closestPhxBinding(el, `data-phx-update=ignore`, el.form))
    }
    let filterDisables = el => {
      return el.hasAttribute(this.binding(PHX_DISABLE_WITH))
    }
    let filterButton = el => el.tagName == "BUTTON"

    let filterInput = el => ["INPUT", "TEXTAREA", "SELECT"].includes(el.tagName)

    let refGenerator = () => {
      let formElements = Array.from(formEl.elements)
      let disables = formElements.filter(filterDisables)
      let buttons = formElements.filter(filterButton).filter(filterIgnored)
      let inputs = formElements.filter(filterInput).filter(filterIgnored)

      buttons.forEach(button => {
        button.setAttribute(PHX_DISABLED, button.disabled)
        button.disabled = true
      })
      inputs.forEach(input => {
        input.setAttribute(PHX_READONLY, input.readOnly)
        input.readOnly = true
        if(input.files){
          input.setAttribute(PHX_DISABLED, input.disabled)
          input.disabled = true
        }
      })
      formEl.setAttribute(this.binding(PHX_PAGE_LOADING), "")
      return this.putRef([formEl].concat(disables).concat(buttons).concat(inputs), "submit")
    }

    let cid = this.targetComponentID(formEl, targetCtx)
    if(LiveUploader.hasUploadsInProgress(formEl)){
      let [ref, els] = refGenerator()
      return this.scheduleSubmit(formEl, ref, () => this.pushFormSubmit(formEl, targetCtx, phxEvent, onReply))
    } else if(LiveUploader.inputsAwaitingPreflight(formEl).length > 0) {
      let [ref, els] = refGenerator()
      let proxyRefGen = () => [ref, els]
      this.uploadFiles(formEl, targetCtx, ref, cid, (uploads) => {
        let formData = serializeForm(formEl, {})
        this.pushWithReply(proxyRefGen, "event", {
          type: "form",
          event: phxEvent,
          value: formData,
          cid: cid
        }, onReply)
      })
    } else {
      let formData = serializeForm(formEl)
      this.pushWithReply(refGenerator, "event", {
        type: "form",
        event: phxEvent,
        value: formData,
        cid: cid
      }, onReply)
    }
  }

  uploadFiles(formEl, targetCtx, ref, cid, onComplete){
    let joinCountAtUpload = this.joinCount
    let inputEls = LiveUploader.activeFileInputs(formEl)

    // get each file input
    inputEls.forEach(inputEl => {
      let uploader = new LiveUploader(inputEl, this, onComplete)
      this.uploaders[inputEl] = uploader
      let entries = uploader.entries().map(entry => entry.toPreflightPayload())

      let payload = {
        ref: inputEl.getAttribute(PHX_UPLOAD_REF),
        entries: entries,
        cid: this.targetComponentID(inputEl.form, targetCtx)
      }

      this.log("upload", () => [`sending preflight request`, payload])

      this.pushWithReply(null, "allow_upload", payload, resp => {
        this.log("upload", () => [`got preflight response`, resp])
        if(resp.error){
          this.undoRefs(ref)
          let [entry_ref, reason] = resp.error
          this.log("upload", () => [`error for entry ${entry_ref}`, reason])
        } else {
          let onError = (callback) => {
            this.channel.onError(() => {
              if(this.joinCount === joinCountAtUpload){ callback() }
            })
          }
          uploader.initAdapterUpload(resp, onError, this.liveSocket)
        }
      })
    })
  }

  pushFormRecovery(form, callback){
    this.liveSocket.withinOwners(form, (view, targetCtx) => {
      let input = form.elements[0]
      let phxEvent = form.getAttribute(this.binding(PHX_AUTO_RECOVER)) || form.getAttribute(this.binding("change"))
      view.pushInput(input, targetCtx, phxEvent, input, callback)
    })
  }

  pushLinkPatch(href, targetEl, callback){
    let linkRef = this.liveSocket.setPendingLink(href)
    let refGen = targetEl ? () => this.putRef([targetEl], "click") : null

    this.pushWithReply(refGen, "link", {url: href}, resp => {
      if(resp.link_redirect){
        this.liveSocket.replaceMain(href, null, callback, linkRef)
      } else if(this.liveSocket.commitPendingLink(linkRef)){
        this.href = href
        this.applyPendingUpdates()
        callback && callback()
      }
    }).receive("timeout", () => this.liveSocket.redirect(window.location.href))
  }

  formsForRecovery(html){
    if(this.joinCount === 0){ return [] }

    let phxChange = this.binding("change")
    let template = document.createElement("template")
    template.innerHTML = html

    return(
      DOM.all(this.el, `form[${phxChange}]`)
         .filter(form => this.ownsElement(form))
         .filter(form => form.elements.length > 0)
         .filter(form => form.getAttribute(this.binding(PHX_AUTO_RECOVER)) !== "ignore")
         .filter(form => template.content.querySelector(`form[${phxChange}="${form.getAttribute(phxChange)}"]`))
    )
  }

  maybePushComponentsDestroyed(destroyedCIDs){
    let willDestroyCIDs = destroyedCIDs.filter(cid => {
      return DOM.findComponentNodeList(this.el, cid).length === 0
    })
    if(willDestroyCIDs.length > 0){
      this.pruningCIDs.push(...willDestroyCIDs)

      this.pushWithReply(null, "cids_will_destroy", {cids: willDestroyCIDs}, () => {
        // The cids are either back on the page or they will be fully removed,
        // so we can remove them from the pruningCIDs.
        this.pruningCIDs = this.pruningCIDs.filter(cid => willDestroyCIDs.indexOf(cid) !== -1)

        // See if any of the cids we wanted to destroy were added back,
        // if they were added back, we don't actually destroy them.
        let completelyDestroyCIDs = willDestroyCIDs.filter(cid => {
          return DOM.findComponentNodeList(this.el, cid).length === 0
        })

        if(completelyDestroyCIDs.length > 0){
          this.pushWithReply(null, "cids_destroyed", {cids: completelyDestroyCIDs}, (resp) => {
            this.rendered.pruneCIDs(resp.cids)
          })
        }
      })
    }
  }

  ownsElement(el){
    return el.getAttribute(PHX_PARENT_ID) === this.id ||
           maybe(el.closest(PHX_VIEW_SELECTOR), node => node.id) === this.id
  }

  submitForm(form, targetCtx, phxEvent){
    DOM.putPrivate(form, PHX_HAS_SUBMITTED, true)
    this.liveSocket.blurActiveElement(this)
    this.pushFormSubmit(form, targetCtx, phxEvent, () => {
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
    this.__listeners = new Set()
    this.__isDisconnected = false
    this.el = el
    this.viewName = view.name()
    this.el.phxHookId = this.constructor.makeID()
    for(let key in this.__callbacks){ this[key] = this.__callbacks[key] }
  }

  __mounted(){ this.mounted && this.mounted() }
  __updated(){ this.updated && this.updated() }
  __beforeUpdate(){ this.beforeUpdate && this.beforeUpdate() }
  __destroyed(){ this.destroyed && this.destroyed() }
  __reconnected(){
    if(this.__isDisconnected){
      this.__isDisconnected = false
      this.reconnected && this.reconnected()
    }
  }
  __disconnected(){
    this.__isDisconnected = true
    this.disconnected && this.disconnected()
  }

  pushEvent(event, payload = {}, onReply = function(){}){
    return this.__view.pushHookEvent(null, event, payload, onReply)
  }

  pushEventTo(phxTarget, event, payload = {}, onReply = function(){}){
    return this.__view.withinTargets(phxTarget, (view, targetCtx) => {
      return view.pushHookEvent(targetCtx, event, payload, onReply)
    })
  }

  handleEvent(event, callback){
    let callbackRef = (customEvent, bypass) => bypass ? event : callback(customEvent.detail)
    window.addEventListener(`phx:hook:${event}`, callbackRef)
    this.__listeners.add(callbackRef)
    return callbackRef
  }

  removeHandleEvent(callbackRef){
    let event = callbackRef(null, true)
    window.removeEventListener(`phx:hook:${event}`, callbackRef)
    this.__listeners.delete(callbackRef)
  }

  __cleanup__(){
    this.__listeners.forEach(callbackRef => this.removeHandleEvent(callbackRef))
  }
}

export default LiveSocket
