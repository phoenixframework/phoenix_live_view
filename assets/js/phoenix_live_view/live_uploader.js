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
    callback(URL.createObjectURL(file))
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
    let files = this.activeFiles(inputEl)
    let fileData = {}
    files.forEach(file => {
      let entry = {path: inputEl.name}
      let uploadRef = inputEl.getAttribute(PHX_UPLOAD_REF)
      fileData[uploadRef] = fileData[uploadRef] || []
      entry.ref = this.genFileRef(file)
      entry.name = file.name || entry.ref
      entry.type = file.type
      entry.size = file.size
      fileData[uploadRef].push(entry)
    })
    return fileData
  }

  static clearFiles(inputEl){
    inputEl.value = null
    inputEl.removeAttribute(PHX_UPLOAD_REF)
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
