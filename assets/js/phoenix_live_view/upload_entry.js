import {
  PHX_ACTIVE_ENTRY_REFS,
  PHX_LIVE_FILE_UPDATED,
  PHX_PREFLIGHTED_REFS
} from "./constants"

import {
  channelUploader,
  logError
} from "./utils"

import LiveUploader from "./live_uploader"

export default class UploadEntry {
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

  static isPreflightInProgress(file){
    return file._preflightInProgress === true
  }

  static markPreflightInProgress(file){
    file._preflightInProgress = true
  }

  constructor(fileEl, file, view, autoUpload){
    this.ref = LiveUploader.genFileRef(file)
    this.fileEl = fileEl
    this.file = file
    this.view = view
    this.meta = null
    this._isCancelled = false
    this._isDone = false
    this._progress = 0
    this._lastProgressSent = -1
    this._onDone = function(){ }
    this._onElUpdated = this.onElUpdated.bind(this)
    this.fileEl.addEventListener(PHX_LIVE_FILE_UPDATED, this._onElUpdated)
    this.autoUpload = autoUpload
  }

  metadata(){ return this.meta }

  progress(progress){
    this._progress = Math.floor(progress)
    if(this._progress > this._lastProgressSent){
      if(this._progress >= 100){
        this._progress = 100
        this._lastProgressSent = 100
        this._isDone = true
        this.view.pushFileProgress(this.fileEl, this.ref, 100, () => {
          LiveUploader.untrackFile(this.fileEl, this.file)
          this._onDone()
        })
      } else {
        this._lastProgressSent = this._progress
        this.view.pushFileProgress(this.fileEl, this.ref, this._progress)
      }
    }
  }

  isCancelled(){ return this._isCancelled }

  cancel(){
    this.file._preflightInProgress = false
    this._isCancelled = true
    this._isDone = true
    this._onDone()
  }

  isDone(){ return this._isDone }

  error(reason = "failed"){
    this.fileEl.removeEventListener(PHX_LIVE_FILE_UPDATED, this._onElUpdated)
    this.view.pushFileProgress(this.fileEl, this.ref, {error: reason})
    if(!this.isAutoUpload()){ LiveUploader.clearFiles(this.fileEl) }
  }

  isAutoUpload(){ return this.autoUpload }

  //private

  onDone(callback){
    this._onDone = () => {
      this.fileEl.removeEventListener(PHX_LIVE_FILE_UPDATED, this._onElUpdated)
      callback()
    }
  }

  onElUpdated(){
    let activeRefs = this.fileEl.getAttribute(PHX_ACTIVE_ENTRY_REFS).split(",")
    if(activeRefs.indexOf(this.ref) === -1){
      LiveUploader.untrackFile(this.fileEl, this.file)
      this.cancel()
    }
  }

  toPreflightPayload(){
    return {
      last_modified: this.file.lastModified,
      name: this.file.name,
      relative_path: this.file.webkitRelativePath,
      size: this.file.size,
      type: this.file.type,
      ref: this.ref,
      meta: typeof(this.file.meta) === "function" ? this.file.meta() : undefined
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
    if(!this.meta){ logError(`no preflight upload response returned with ref ${this.ref}`, {input: this.fileEl, response: resp}) }
  }
}
