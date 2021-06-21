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
    this.uploadChannel = liveSocket.channel(`lvu:${entry.ref}`, {token: entry.metadata()})
  }

  error(reason){
    clearTimeout(this.chunkTimer)
    this.uploadChannel.leave()
    this.entry.error(reason)
  }

  upload(){
    this.uploadChannel.onError(reason => this.error(reason))
    this.uploadChannel.join()
      .receive("ok", _data => this.readNextChunk())
      .receive("error", reason => this.error(reason))
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
          this.chunkTimer = setTimeout(() => this.readNextChunk(), this.liveSocket.getLatencySim() || 0)
        }
      })
  }
}
