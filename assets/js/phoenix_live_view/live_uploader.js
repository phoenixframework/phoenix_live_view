/**
 * Module Type Dependencies:
 * @typedef {import('./view.js').default} View
 * @typedef {import('./live_socket.js').default} LiveSocket
 */
import {
  PHX_DONE_REFS,
  PHX_PREFLIGHTED_REFS,
  PHX_UPLOAD_REF
} from "./constants"

import {
} from "./utils"

import DOM from "./dom"
import UploadEntry from "./upload_entry"

let liveUploaderFileRef = 0

export default class LiveUploader {
  /**
   * Generate a unique reference for this file
   * @param {File} file 
   * @returns {string} the file ref
   */
  static genFileRef(file){
    let ref = file._phxRef
    if(ref !== undefined){
      return ref
    } else {
      file._phxRef = (liveUploaderFileRef++).toString()
      return file._phxRef
    }
  }

  /**
   * Create URL and pass to the callback
   * @param {HTMLInputElement} inputEl 
   * @param {string} ref 
   * @param {function} callback 
   */
  static getEntryDataURL(inputEl, ref, callback){
    let file = this.activeFiles(inputEl).find(file => this.genFileRef(file) === ref)
    callback(URL.createObjectURL(file))
  }

  /**
   * Are any file uploads still in-flight for the given form?
   * @param {HTMLFormElement} formEl 
   * @returns {boolean}
   */
  static hasUploadsInProgress(formEl){
    let active = 0
    DOM.findUploadInputs(formEl).forEach(input => {
      if(input.getAttribute(PHX_PREFLIGHTED_REFS) !== input.getAttribute(PHX_DONE_REFS)){
        active++
      }
    })
    return active > 0
  }

  /**
   * Create entry data for all active file uploads in input element, mapped to
   * the input's upload ref
   * @param {HTMLInputElement} inputEl 
   * @returns {object} map of file refs to array of entries
   */
  static serializeUploads(inputEl){
    let files = this.activeFiles(inputEl)
    let fileData = {}
    files.forEach(file => {
      let entry = {path: inputEl.name}
      let uploadRef = inputEl.getAttribute(PHX_UPLOAD_REF)
      fileData[uploadRef] = fileData[uploadRef] || []
      entry.ref = this.genFileRef(file)
      entry.last_modified = file.lastModified
      entry.name = file.name || entry.ref
      entry.relative_path = file.webkitRelativePath
      entry.type = file.type
      entry.size = file.size
      if(typeof(file.meta) === "function"){ entry.meta = file.meta() }
      fileData[uploadRef].push(entry)
    })
    return fileData
  }

  /**
   * Clear upload refs on given file upload input
   * @param {HTMLInputElement} inputEl 
   */
  static clearFiles(inputEl){
    inputEl.value = null
    inputEl.removeAttribute(PHX_UPLOAD_REF)
    DOM.putPrivate(inputEl, "files", [])
  }

  /**
   * Untrack file upload for input
   * @param {HTMLInputElement} inputEl 
   * @param {File} file 
   */
  static untrackFile(inputEl, file){
    DOM.putPrivate(inputEl, "files", DOM.private(inputEl, "files").filter(f => !Object.is(f, file)))
  }

  /**
   * Track file uploads for the given input
   * @param {HTMLInputElement} inputEl 
   * @param {File[]} files 
   * @param {object=} dataTransfer 
   */
  static trackFiles(inputEl, files, dataTransfer){
    if(inputEl.getAttribute("multiple") !== null){
      let newFiles = files.filter(file => !this.activeFiles(inputEl).find(f => Object.is(f, file)))
      DOM.putPrivate(inputEl, "files", this.activeFiles(inputEl).concat(newFiles))
      inputEl.value = null
    } else {
      // Reset inputEl files to align output with programmatic changes (i.e. drag and drop)
      if(dataTransfer && dataTransfer.files.length > 0){ inputEl.files = dataTransfer.files }
      DOM.putPrivate(inputEl, "files", files)
    }
  }

  /**
   * Select a list of all file inputs with active uploads
   * @param {HTMLFormElement} formEl 
   * @returns {HTMLInputElement[]}
   */
  static activeFileInputs(formEl){
    let fileInputs = DOM.findUploadInputs(formEl)
    return Array.from(fileInputs).filter(el => el.files && this.activeFiles(el).length > 0)
  }

  /**
   * Select a list of all files from this input being actively uploaded
   * @param {HTMLInputElement} input 
   * @returns {File[]}
   */
  static activeFiles(input){
    return (DOM.private(input, "files") || []).filter(f => UploadEntry.isActive(input, f))
  }

  /**
   * Select a list of all file inputs with files still awaiting preflight
   * @param {HTMLFormElement} formEl 
   * @returns {HTMLInputElement[]}
   */
  static inputsAwaitingPreflight(formEl){
    let fileInputs = DOM.findUploadInputs(formEl)
    return Array.from(fileInputs).filter(input => this.filesAwaitingPreflight(input).length > 0)
  }

  /**
   * Select a list of all files from this input still awaiting preflight 
   * @param {HTMLInputElement} input 
   * @returns {File[]}
   */
  static filesAwaitingPreflight(input){
    return this.activeFiles(input).filter(f => !UploadEntry.isPreflighted(input, f))
  }

  /**
   * Constructor
   * @param {HTMLInputElement} inputEl 
   * @param {View} view 
   * @param {function} onComplete 
   */
  constructor(inputEl, view, onComplete){
    this.view = view
    this.onComplete = onComplete
    this._entries =
      Array.from(LiveUploader.filesAwaitingPreflight(inputEl) || [])
        .map(file => new UploadEntry(inputEl, file, view))

    this.numEntriesInProgress = this._entries.length
  }

  /**
   * Get upload entries list
   * @returns {UploadEntry[]}
   */
  entries(){ return this._entries }

  /**
   * Initialize the upload process
   * @param {any} resp 
   * @param {function} onError 
   * @param {LiveSocket} liveSocket 
   */
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
      if(!entry.meta){ return acc }
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
