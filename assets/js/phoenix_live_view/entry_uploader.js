import { logError } from "./utils";

export default class EntryUploader {
  constructor(entry, config, liveSocket) {
    const { chunk_size, chunk_timeout } = config;
    this.liveSocket = liveSocket;
    this.entry = entry;
    this.offset = 0;
    this.chunkSize = chunk_size;
    this.chunkTimeout = chunk_timeout;
    this.chunkTimer = null;
    this.errored = false;
    this.uploadChannel = liveSocket.channel(`lvu:${entry.ref}`, {
      token: entry.metadata(),
    });
  }

  error(reason) {
    if (this.errored) {
      return;
    }
    this.uploadChannel.leave();
    this.errored = true;
    clearTimeout(this.chunkTimer);
    this.entry.error(reason);
  }

  upload() {
    this.uploadChannel.onError((reason) => this.error(reason));
    this.uploadChannel
      .join()
      .receive("ok", (_data) => this.readNextChunk())
      .receive("error", (reason) => this.error(reason));
  }

  isDone() {
    return this.offset >= this.entry.file.size;
  }

  readNextChunk() {
    const reader = new window.FileReader();
    const blob = this.entry.file.slice(
      this.offset,
      this.chunkSize + this.offset,
    );
    reader.onload = (e) => {
      if (e.target.error === null) {
        this.offset += /** @type {ArrayBuffer} */ (e.target.result).byteLength;
        this.pushChunk(/** @type {ArrayBuffer} */ (e.target.result));
      } else {
        return logError("Read error: " + e.target.error);
      }
    };
    reader.readAsArrayBuffer(blob);
  }

  pushChunk(chunk) {
    if (!this.uploadChannel.isJoined()) {
      return;
    }
    this.uploadChannel
      .push("chunk", chunk, this.chunkTimeout)
      .receive("ok", () => {
        this.entry.progress((this.offset / this.entry.file.size) * 100);
        if (!this.isDone()) {
          this.chunkTimer = setTimeout(
            () => this.readNextChunk(),
            this.liveSocket.getLatencySim() || 0,
          );
        }
      })
      .receive("error", ({ reason }) => this.error(reason));
  }
}
