/**
 * Module Type Dependencies:
 * @typedef {import('./view.js').default} View
 * @typedef {import('./live_socket.js').default} LiveSocket
 */

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
import DOM from "./dom"

export default class UploadEntry {
  /**
   * Is the file for this input still being uploaded? 
   * @param {HTMLInputElement} fileEl 
   * @param {File} file 
   * @returns {boolean}
   */
  static isActive(fileEl, file){
    let isNew = file._phxRef === undefined
    let activeRefs = fileEl.getAttribute(PHX_ACTIVE_ENTRY_REFS).split(",")
    let isActive = activeRefs.indexOf(LiveUploader.genFileRef(file)) >= 0
    return file.size > 0 && (isNew || isActive)
  }

  /**
   * Is the file for this input active and in preflight?
   * @param {HTMLInputElement} fileEl 
   * @param {File} file 
   * @returns {boolean}
   */
  static isPreflighted(fileEl, file){
    let preflightedRefs = fileEl.getAttribute(PHX_PREFLIGHTED_REFS).split(",")
    let isPreflighted = preflightedRefs.indexOf(LiveUploader.genFileRef(file)) >= 0
    return isPreflighted && this.isActive(fileEl, file)
  }

  /**
   * Constructor
   * @param {HTMLInputElement} fileEl 
   * @param {File} file 
   * @param {View} view 
   */
  constructor(fileEl, file, view){
    /** @readonly */
    this.ref = LiveUploader.genFileRef(file)

    this.fileEl = fileEl
    this.file = file
    this.view = view
    this.meta = null
    
    /** @private */
    this._isCancelled = false
    /** @private */
    this._isDone = false
    /** @private */
    this._progress = 0
    /** @private */
    this._lastProgressSent = -1
    /** @private */
    this._onDone = function (){ }
    /** @private */
    this._onElUpdated = this.onElUpdated.bind(this)

    this.fileEl.addEventListener(PHX_LIVE_FILE_UPDATED, this._onElUpdated)
  }

  /**
   * Get metadata for this upload entry
   * @returns {{uploader: LiveUploader}|null}
   */
  metadata(){ return this.meta }

  /**
   * Push file progress to the view
   * @param {number} progress 
   */
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

  /**
   * Cancel the upload for this entry
   */
  cancel(){
    this._isCancelled = true
    this._isDone = true
    this._onDone()
  }

  /**
   * @returns {boolean}
   */
  isDone(){ return this._isDone }

  /**
   * Mark upload as an error and update view file progress
   * @param {string} [reason] 
   */
  error(reason = "failed"){
    this.fileEl.removeEventListener(PHX_LIVE_FILE_UPDATED, this._onElUpdated)
    this.view.pushFileProgress(this.fileEl, this.ref, {error: reason})
    if(!DOM.isAutoUpload(this.fileEl)){ LiveUploader.clearFiles(this.fileEl) }
  }

  /**
   * Set a callback for when upload is done
   * @private
   * @param {() => void} callback 
   */
  onDone(callback){
    this._onDone = () => {
      this.fileEl.removeEventListener(PHX_LIVE_FILE_UPDATED, this._onElUpdated)
      callback()
    }
  }

  /**
   * @private
   */
  onElUpdated(){
    let activeRefs = this.fileEl.getAttribute(PHX_ACTIVE_ENTRY_REFS).split(",")
    if(activeRefs.indexOf(this.ref) === -1){ this.cancel() }
  }

  /**
   * Generate the preflight payload data
   * @private
   * @returns
   */
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

  /**
   * Lookup the uploader for this specific entry
   * @private
   * @param {{[key: string]: function}} uploaders
   * @returns {{name: string, callback: function}}
   */
  uploader(uploaders){
    if(this.meta.uploader){
      let callback = uploaders[this.meta.uploader] || logError(`no uploader configured for ${this.meta.uploader}`)
      return {name: this.meta.uploader, callback: callback}
    } else {
      return {name: "channel", callback: channelUploader}
    }
  }

  /**
   * Update metadata from response
   * @private
   * @param {{entries: {[key: string]: object}}} resp 
   */
  zipPostFlight(resp){
    this.meta = resp.entries[this.ref]
    if(!this.meta){ logError(`no preflight upload response returned with ref ${this.ref}`, {input: this.fileEl, response: resp}) }
  }
}
