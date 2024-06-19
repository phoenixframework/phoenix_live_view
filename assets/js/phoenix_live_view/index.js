/*
================================================================================
Phoenix LiveView JavaScript Client
================================================================================

See the hexdocs at `https://hexdocs.pm/phoenix_live_view` for documentation.

*/

import LiveSocket, {isUsedInput} from "./live_socket"
import JS from "./js"
import DOM from "./dom"
import ViewHook from "./view_hook"
import View from "./view"
import {PHX_VIEW_SELECTOR} from "./constants"

/** Creates a ViewHook instance for the given element and callbacks.
 *
 * @param {HTMLElement} el - The element to associate with the hook.
 * @param {Object} [callbacks] - The list of hook callbacks, such as mounted,
 *   updated, destroyed, etc.
 *
 * @example
 *
 * class MyComponent extends HTMLElement {
 *   constructor(){
 *    super()
 *    createHook(this, {}).then(hook => {
 *      hook.pushEvent(...)
 *    })
 *   }
 * }
 *
 * @returns {Promise} Returns a promise that resolves with the ViewHook instance.
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
  JS,
  isUsedInput,
  createHook
}
