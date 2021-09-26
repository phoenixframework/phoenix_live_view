import {
  logError
} from "./utils"

export default class EntryUploader {
  constructor(entry, chunkSize, liveSocket){
    this.liveSocket = liveSocket
    this.entry = entry
    this.offset = 0
    this.chunkSize = chunkSize
    this.chunkTimer = null
    this._started = false
    this._onDone = undefined
  }

  error(reason){
    this._started = false
    clearTimeout(this.chunkTimer)
    this.uploadChannel.leave()
    this.entry.error(reason)
    this.onDone()
  }

  upload(onDone){
    this._onDone = onDone
    this.uploadChannel = this.liveSocket.channel(`lvu:${this.entry.ref}`, {token: this.entry.metadata()})
    this._started = true
    this.uploadChannel.onError(reason => this.error(reason))
    this.uploadChannel.join()
      .receive("ok", _data => this.readNextChunk())
      .receive("error", reason => this.error(reason))
  }

  isDone(){ return this.offset >= this.entry.file.size }
  onDone() { typeof this._onDone === "function" && this._onDone() }
  hasStarted() { return this._started }

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
          this.chunkTimer = setTimeout(() => this.readNextChunk(), this.liveSocket.getLatencySim() || 0)
        } else {
          this.onDone()
        }
      })
  }
}
