/*
================================================================================
Phoenix LiveView JavaScript Client
================================================================================

See the hexdocs at `https://hexdocs.pm/phoenix_live_view` for documentation.

*/

import LiveSocket, {isUsedInput} from "./live_socket"
import JS from "./js"

let createHook = (el, callbacks = {}) => {
  return new Promise((resolve) => {
    window.dispatchEvent(new CustomEvent("phx:_create_hook", {
      detail: {el, callbacks, reply: (hook) => resolve(hook)}
    }))
  })
}

export {
  LiveSocket,
  JS,
  isUsedInput,
  createHook
}
