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
    this.errored = false
    this.uploadChannel = liveSocket.channel(`lvu:${entry.ref}`, {token: entry.metadata()})
  }

  error(reason){
    if(this.errored){ return }
    this.uploadChannel.leave()
    this.errored = true
    this.entry.error(reason)
  }

  upload(){
    this.uploadChannel.onError(reason => this.error(reason))

    return new Promise((resolve, reject) => {
      this.uploadChannel.join()
        .receive("ok", _data => resolve())
        .receive("error", reason => reject(reason))
    })
      .then(() => this.readNextChunk())
      .catch(reason => this.error(reason))
  }

  isDone(){ return this.offset >= this.entry.file.size }

  // private

  readNextChunk(){
    let blob = this.entry.file.slice(this.offset, this.chunkSize + this.offset)
    this.offset += blob.size
    return this.pushChunk(blob)
  }

  pushChunk(chunk){
    if(!this.uploadChannel.isJoined()){ return }

    return new Promise((resolve, reject) => {
      this.uploadChannel.push("chunk", chunk)
        .receive("ok", () => {
          this.entry.progress((this.offset / this.entry.file.size) * 100)
          if(!this.isDone()){
            resolve(this.simulateLatency())
          }
        })
        .receive("error", ({reason}) => reject(reason))
    })
  }

  simulateLatency(){
    let callback = () => this.readNextChunk()
    let latency = this.liveSocket.getLatencySim() || 0
    let resolver = Promise.resolve()
    if(latency !== 0){
      resolver = new Promise(resolve => setTimeout(() => resolve(), latency))
    }
    return resolver.then(callback)
  }
}
