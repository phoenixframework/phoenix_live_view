/*
================================================================================
Phoenix LiveView JavaScript Client
================================================================================

See the hexdocs at `https://hexdocs.pm/phoenix_live_view` for documentation.

*/

import LiveSocket, {isUsedInput} from "./live_socket"
import DOM from "./dom"
import ViewHook from "./view_hook"
import View from "./view"

/** Creates a ViewHook instance for the given element and callbacks.
 *
 * @param {HTMLElement} el - The element to associate with the hook.
 * @param {Object} [callbacks] - The list of hook callbacks, such as mounted,
 *   updated, destroyed, etc.
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
 * *Note*: `createHook` must be called from the `connectedCallback` lifecycle
 * which is triggered after the element has been added to the DOM. If you try
 * to call `createHook` from the constructor, an error will be logged.
 *
 * @returns {ViewHook} Returns the ViewHook instance for the custom element.
 */
let createHook = (el, callbacks = {}) => {
  let existingHook = DOM.getCustomElHook(el)
  if(existingHook){ return existingHook }

  let hook = new ViewHook(View.closestView(el), el, callbacks)
  DOM.putCustomElHook(el, hook)
  return hook
}

export {
  LiveSocket,
  isUsedInput,
  createHook
}