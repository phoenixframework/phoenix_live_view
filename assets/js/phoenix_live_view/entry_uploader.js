/**
 * Module Type Dependencies:
 * @typedef {import('./live_socket.js').default} LiveSocket
 * @typedef {import('./upload_entry').default} UploadEntry
 */
import {
  logError
} from "./utils"

export default class EntryUploader {
  /**
   * Constructor
   * @param {UploadEntry} entry 
   * @param {number} chunkSize 
   * @param {LiveSocket} liveSocket 
   */
  constructor(entry, chunkSize, liveSocket){
    this.liveSocket = liveSocket
    this.entry = entry
    this.offset = 0
    this.chunkSize = chunkSize
    this.chunkTimer = null
    this.errored = false
    this.uploadChannel = liveSocket.channel(`lvu:${entry.ref}`, {token: entry.metadata()})
  }

  /**
   * Mark this entry upload as an error
   * @private
   * @param {string} [reason] 
   */
  error(reason){
    if(this.errored){ return }
    this.errored = true
    clearTimeout(this.chunkTimer)
    this.entry.error(reason)
  }

  /**
   * Perform upload over channel
   * @public
   */
  upload(){
    this.uploadChannel.onError(reason => this.error(reason))
    this.uploadChannel.join()
      .receive("ok", _data => this.readNextChunk())
      .receive("error", reason => this.error(reason))
  }

  /**
   * Have all file chunks finished uploading?
   * @public
   * @returns {boolean}
   */
  isDone(){ return this.offset >= this.entry.file.size }

  /**
   * Read and upload next file chunk
   * @private
   */
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

  /**
   * Perform file chunk upload over channel
   * @private
   * @param {string | ArrayBuffer | null} chunk 
   */
  pushChunk(chunk){
    if(!this.uploadChannel.isJoined()){ return }
    this.uploadChannel.push("chunk", chunk)
      .receive("ok", () => {
        this.entry.progress((this.offset / this.entry.file.size) * 100)
        if(!this.isDone()){
          this.chunkTimer = setTimeout(() => this.readNextChunk(), this.liveSocket.getLatencySim() || 0)
        }
      })
      .receive("error", ({reason}) => this.error(reason))
  }
}
