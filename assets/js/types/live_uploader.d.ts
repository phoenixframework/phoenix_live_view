export default class LiveUploader {
    static genFileRef(file: any): any;
    static getEntryDataURL(inputEl: any, ref: any): string;
    static hasUploadsInProgress(formEl: any): boolean;
    static serializeUploads(inputEl: any): {};
    static clearFiles(inputEl: any): void;
    static untrackFile(inputEl: any, file: any): void;
    /**
     * @param {HTMLInputElement} inputEl
     * @param {Array<File|Blob>} files
     * @param {DataTransfer} [dataTransfer]
     */
    static trackFiles(inputEl: HTMLInputElement, files: Array<File | Blob>, dataTransfer?: DataTransfer): void;
    static activeFileInputs(formEl: any): HTMLInputElement[];
    static activeFiles(input: any): any;
    static inputsAwaitingPreflight(formEl: any): HTMLInputElement[];
    static filesAwaitingPreflight(input: any): any;
    static markPreflightInProgress(entries: any): void;
    constructor(inputEl: any, view: any, onComplete: any);
    autoUpload: any;
    view: any;
    onComplete: any;
    _entries: UploadEntry[];
    numEntriesInProgress: number;
    isAutoUpload(): any;
    entries(): UploadEntry[];
    initAdapterUpload(resp: any, onError: any, liveSocket: any): void;
}
import UploadEntry from "./upload_entry";
