export default class EntryUploader {
    constructor(entry: any, config: any, liveSocket: any);
    liveSocket: any;
    entry: any;
    offset: number;
    chunkSize: any;
    chunkTimeout: any;
    chunkTimer: number;
    errored: boolean;
    uploadChannel: any;
    error(reason: any): void;
    upload(): void;
    isDone(): boolean;
    readNextChunk(): void;
    pushChunk(chunk: any): void;
}
