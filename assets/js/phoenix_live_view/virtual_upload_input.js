import {
  PHX_ACTIVE_ENTRY_REFS,
  PHX_DONE_REFS,
  PHX_PREFLIGHTED_REFS,
  PHX_UPLOAD_REF,
} from "./constants";

/**
 * A minimal stand-in for a file input element, used for programmatic
 * (inputless) uploads pushed via the hook `uploadBytes` API.
 *
 * It implements exactly the surface `LiveUploader` and `UploadEntry` touch
 * on a real input: attribute storage, inert event listeners, and a `form`
 * that resolves ownership to the upload's view root. The config ref is
 * unknown until the name-addressed preflight replies, at which point it is
 * adopted so progress pushes carry it like a DOM-anchored upload.
 *
 * This class is a deliberate seam: its surface is the implicit interface the
 * upload pipeline expects from an input element. If that dependency is ever
 * extracted into an explicit upload-target abstraction, this becomes one of
 * its two implementations (the DOM input being the other).
 */
let virtualEntrySeq = 0;

export default class VirtualUploadInput {
  static nextEntryName() {
    return (virtualEntrySeq++).toString(36);
  }

  constructor(view, name, files) {
    this.view = view;
    this.name = name;
    this.files = files;
    this.form = view.el;
    this._attrs = {
      "data-phx-auto-upload": "",
      [PHX_ACTIVE_ENTRY_REFS]: "",
      [PHX_PREFLIGHTED_REFS]: "",
      [PHX_DONE_REFS]: "",
    };
  }

  getAttribute(name) {
    return name in this._attrs ? this._attrs[name] : null;
  }

  hasAttribute(name) {
    return name in this._attrs;
  }

  setAttribute(name, value) {
    this._attrs[name] = value;
  }

  removeAttribute(name) {
    delete this._attrs[name];
  }

  adoptUploadRef(ref) {
    this.setAttribute(PHX_UPLOAD_REF, ref);
  }

  addEventListener() {}
  removeEventListener() {}
  dispatchEvent() {}
}
