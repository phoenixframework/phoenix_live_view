/*
 * This is the documentation for the LiveView JavaScript client.
 * It is a more low-level API documentation for advanced users.
 * For a higher-level overview, [see the page on JavaScript interoperability](https://phoenix-live-view.hexdocs.pm/js-interop.html) instead.
 *
 * The main documentation can be found at `https://phoenix-live-view.hexdocs.pm`.
 *
 * @packageDocumentation
 */

import LiveSocket, { type LiveSocketOptions, isUsedInput } from "./live_socket";
import DOM from "./dom";
import { ViewHook } from "./view_hook";
import View from "./view";
import { logError } from "./diagnostics";

import type { EncodedJS } from "./js_commands";
import type { Hook, HooksOptions, HookInterface } from "./view_hook";
import LiveUploader from "./live_uploader";

export type { LiveSocketOptions, HookInterface, HooksOptions, EncodedJS };

/** Creates a hook instance for the given element and callbacks.
 *
 * @param el - The element to associate with the hook.
 * @param callbacks - The list of hook callbacks, such as mounted,
 *   updated, destroyed, etc.
 *
 * *Note*: `createHook` must be called from the `connectedCallback` lifecycle
 * which is triggered after the element has been added to the DOM. If you try
 * to call `createHook` from the constructor, an error will be logged.
 *
 * Furthermore, you can only start using the hook's APIs after the `mounted`
 * callback of the hook has been called. If you try to call them earlier,
 * an error will be logged.
 *
 * @example
 *
 * class MyComponent extends HTMLElement {
 *   connectedCallback(){
 *     let onLiveViewMounted = () => this.hook.pushEvent(...))
 *     this.hook = createHook(this, {mounted: onLiveViewMounted})
 *   }
 * }
 *
 * @returns Returns the Hook instance for the custom element.
 *
 * @category JavaScript Hooks
 */
function createHook(el: HTMLElement, callbacks: Hook): ViewHook {
  let existingHook = DOM.getCustomElHook(el);
  if (existingHook) {
    return existingHook;
  }

  if (!el.hasAttribute("id")) {
    logError(
      "hook.missing-id",
      "Elements passed to createHook need to have a unique id attribute",
      { el },
    );
  }

  let hook = new ViewHook(View.closestView(el), el, callbacks);
  DOM.putCustomElHook(el, hook);
  return hook;
}

/** Returns an object URL for the file matching the given upload ref,
 * or `null` if no matching file is found.
 *
 * @param input - The file input element associated with the upload.
 * @param uploadRef - The upload ref identifying the file entry.
 *
 * @example
 *
 * import { getFileURLForUpload } from "phoenix_live_view"
 *
 * let url = getFileURLForUpload(inputEl, uploadRef)
 * if (url) { imgEl.src = url }
 */
function getFileURLForUpload(
  input: HTMLElement,
  uploadRef: string,
): string | null {
  return LiveUploader.getEntryDataURL(input, uploadRef);
}

export {
  LiveSocket,
  isUsedInput,
  createHook,
  ViewHook,
  Hook,
  getFileURLForUpload,
};
