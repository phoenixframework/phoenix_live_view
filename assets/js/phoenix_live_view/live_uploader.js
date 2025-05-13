import {
  PHX_DONE_REFS,
  PHX_PREFLIGHTED_REFS,
  PHX_UPLOAD_REF,
} from "./constants";

import {} from "./utils";

import DOM from "./dom";
import UploadEntry from "./upload_entry";

let liveUploaderFileRef = 0;

export default class LiveUploader {
  static genFileRef(file) {
    const ref = file._phxRef;
    if (ref !== undefined) {
      return ref;
    } else {
      file._phxRef = (liveUploaderFileRef++).toString();
      return file._phxRef;
    }
  }

  static getEntryDataURL(inputEl, ref, callback) {
    const file = this.activeFiles(inputEl).find(
      (file) => this.genFileRef(file) === ref,
    );
    callback(URL.createObjectURL(file));
  }

  static hasUploadsInProgress(formEl) {
    let active = 0;
    DOM.findUploadInputs(formEl).forEach((input) => {
      if (
        input.getAttribute(PHX_PREFLIGHTED_REFS) !==
        input.getAttribute(PHX_DONE_REFS)
      ) {
        active++;
      }
    });
    return active > 0;
  }

  static serializeUploads(inputEl) {
    const files = this.activeFiles(inputEl);
    const fileData = {};
    files.forEach((file) => {
      const entry = { path: inputEl.name };
      const uploadRef = inputEl.getAttribute(PHX_UPLOAD_REF);
      fileData[uploadRef] = fileData[uploadRef] || [];
      entry.ref = this.genFileRef(file);
      entry.last_modified = file.lastModified;
      entry.name = file.name || entry.ref;
      entry.relative_path = file.webkitRelativePath;
      entry.type = file.type;
      entry.size = file.size;
      if (typeof file.meta === "function") {
        entry.meta = file.meta();
      }
      fileData[uploadRef].push(entry);
    });
    return fileData;
  }

  static clearFiles(inputEl) {
    inputEl.value = null;
    inputEl.removeAttribute(PHX_UPLOAD_REF);
    DOM.putPrivate(inputEl, "files", []);
  }

  static untrackFile(inputEl, file) {
    DOM.putPrivate(
      inputEl,
      "files",
      DOM.private(inputEl, "files").filter((f) => !Object.is(f, file)),
    );
  }

  /**
   * @param {HTMLInputElement} inputEl
   * @param {Array<File|Blob>} files
   * @param {DataTransfer} [dataTransfer]
   */
  static trackFiles(inputEl, files, dataTransfer) {
    if (inputEl.getAttribute("multiple") !== null) {
      const newFiles = files.filter(
        (file) => !this.activeFiles(inputEl).find((f) => Object.is(f, file)),
      );
      DOM.updatePrivate(inputEl, "files", [], (existing) =>
        existing.concat(newFiles),
      );
      inputEl.value = null;
    } else {
      // Reset inputEl files to align output with programmatic changes (i.e. drag and drop)
      if (dataTransfer && dataTransfer.files.length > 0) {
        inputEl.files = dataTransfer.files;
      }
      DOM.putPrivate(inputEl, "files", files);
    }
  }

  static activeFileInputs(formEl) {
    const fileInputs = DOM.findUploadInputs(formEl);
    return Array.from(fileInputs).filter(
      (el) => el.files && this.activeFiles(el).length > 0,
    );
  }

  static activeFiles(input) {
    return (DOM.private(input, "files") || []).filter((f) =>
      UploadEntry.isActive(input, f),
    );
  }

  static inputsAwaitingPreflight(formEl) {
    const fileInputs = DOM.findUploadInputs(formEl);
    return Array.from(fileInputs).filter(
      (input) => this.filesAwaitingPreflight(input).length > 0,
    );
  }

  static filesAwaitingPreflight(input) {
    return this.activeFiles(input).filter(
      (f) =>
        !UploadEntry.isPreflighted(input, f) &&
        !UploadEntry.isPreflightInProgress(f),
    );
  }

  static markPreflightInProgress(entries) {
    entries.forEach((entry) => UploadEntry.markPreflightInProgress(entry.file));
  }

  constructor(inputEl, view, onComplete) {
    this.autoUpload = DOM.isAutoUpload(inputEl);
    this.view = view;
    this.onComplete = onComplete;
    this._entries = Array.from(
      LiveUploader.filesAwaitingPreflight(inputEl) || [],
    ).map((file) => new UploadEntry(inputEl, file, view, this.autoUpload));

    // prevent sending duplicate preflight requests
    LiveUploader.markPreflightInProgress(this._entries);

    this.numEntriesInProgress = this._entries.length;
  }

  isAutoUpload() {
    return this.autoUpload;
  }

  entries() {
    return this._entries;
  }

  initAdapterUpload(resp, onError, liveSocket) {
    this._entries = this._entries.map((entry) => {
      if (entry.isCancelled()) {
        this.numEntriesInProgress--;
        if (this.numEntriesInProgress === 0) {
          this.onComplete();
        }
      } else {
        entry.zipPostFlight(resp);
        entry.onDone(() => {
          this.numEntriesInProgress--;
          if (this.numEntriesInProgress === 0) {
            this.onComplete();
          }
        });
      }
      return entry;
    });

    const groupedEntries = this._entries.reduce((acc, entry) => {
      if (!entry.meta) {
        return acc;
      }
      const { name, callback } = entry.uploader(liveSocket.uploaders);
      acc[name] = acc[name] || { callback: callback, entries: [] };
      acc[name].entries.push(entry);
      return acc;
    }, {});

    for (const name in groupedEntries) {
      const { callback, entries } = groupedEntries[name];
      callback(entries, onError, resp, liveSocket);
    }
  }
}
