/*
================================================================================
Phoenix LiveView Javascript Client 
================================================================================

## Usage

Instantiate a single LiveSocket instances to enable LiveView
client/server interaction, for example:

    import LiveSocket from "live_view"

    let liveSocket = new LiveSocket("/live")
    liveSocket.connect()

A LiveSocket can also be created from an existing socket:

    import { Socket } from "phoenix"
    import LiveSocket from "live_view"

    let socket = new Socket("/live")
    let liveSocket = new LiveSocket(socket)
    liveSocket.connect()

All options are passed directly to the `Phoenix.Socket` constructor,
except for the following LiveView specific options:

  * `bindingPrefix` - the prefix to use for phoenix bindings. Defaults `"phx-"`

## Events

### Click Events

When pushed, the value sent to the server will be chosen with the
following priority:

  - An optional `"phx-value"` binding on the clicked element
  - The clicked element's `value` property
  - An empty string

### Key Events

The onkeypress, onkeydown, and onkeyup events are supported via
the `phx-keypress`, `phx-keydown`, and `phx-keyup` bindings. By
default, the bound element will be the event listener, but an
optional `phx-target` may be provided which may be `"document"`,
`"window"`, or the DOM id of a target element.

When pushed, the value sent to the server will be the event's keyCode.

## Forms and input handling

The JavaScript client is always the source of truth for current
input values. For any given input with focus, LiveView will never
overwrite the input's current value, even if it deviates from
the server's rendered updates. This works well for updates where
major side effects are not expected, such as form validation errors,
or additive UX around the user's input values as they fill out a form.
For these usecases, the `phx-change` input does not concern itself
with disabling input editing while an event to the server is inflight.

The `phx-submit` event is used for form submissions where major side-effects
typically happen, such as rendering new containers, calling an external
service, or redirecting to a new page. For these use-cases, the form inputs
are set to `readonly` on submit, and any submit button is disabled until
the client gets an acknowledgement that the server has processed the
`phx-submit` event. Following an acknowledgement, any updates are patched
to the DOM as normal, and the last input with focus is restored if the
user has not otherwised focused on a new input during submission.

To handle latent form submissions, any HTML tag can be annotated with
`phx-disable-with`, which swaps the element's `innerText` with the provided
value during form submission. For example, the following code would change
the "Save" button to "Saving...", and restore it to "Save" on acknowledgement:

    <button type="submit" phx-disable-with="Saving...">Save</button>


## Loading state and Errors

By default, the following classes are applied to the Live View's parent
container:

  - `"phx-connected"` - applied when the view has connected to the server
  - `"phx-disconnected"` - applied when the view is not connected to the server
  - `"phx-error"` - applied when an error occurs on the server. Note, this
    class will be applied in conjunction with `"phx-disconnected"` connection
    to the server is lost.

In addition to applied classes, an empty `"phx-loader"` exists adjacent
to every LiveView, and its display status is toggled automatically based on
connection and error class changes. This behavior may be disabled by overriding
`.phx-loader` in your css to `display: none!important`.
*/

import { Socket } from 'phoenix'
import { BINDING_PREFIX, PHX_VIEW_SELECTOR, PHX_PARENT_ID } from './constants'
import { View } from './View'

// todo document LiveSocket specific options like viewLogger
export class LiveSocket {
  constructor(urlOrSocket, opts = {}) {
    this.unloaded = false
    window.addEventListener('beforeunload', e => {
      this.unloaded = true
    })
    this.socket = this.buildSocket(urlOrSocket, opts)
    this.socket.onOpen(() => (this.unloaded = false))
    this.bindingPrefix = opts.bindingPrefix || BINDING_PREFIX
    this.opts = opts
    this.views = {}
    this.viewLogger = opts.viewLogger
    this.activeElement = null
    this.prevActive = null
  }

  buildSocket(urlOrSocket, opts) {
    if (typeof urlOrSocket !== 'string') {
      return urlOrSocket
    }

    if (!opts.reconnectAfterMs) {
      opts.reconnectAfterMs = tries => {
        if (this.unloaded) {
          return [50, 100, 250][tries - 1] || 500
        } else {
          return [1000, 2000, 5000, 10000][tries - 1] || 10000
        }
      }
    }
    return new Socket(urlOrSocket, opts)
  }

  log(view, kind, msgCallback) {
    if (this.viewLogger) {
      let [msg, obj] = msgCallback()
      this.viewLogger(view, kind, msg, obj)
    }
  }

  connect() {
    if (
      ['complete', 'loaded', 'interactive'].indexOf(document.readyState) >= 0
    ) {
      this.joinRootViews()
    } else {
      document.addEventListener('DOMContentLoaded', () => {
        this.joinRootViews()
      })
    }
    return this.socket.connect()
  }

  disconnect() {
    return this.socket.disconnect()
  }

  channel(topic, params) {
    return this.socket.channel(topic, params || {})
  }

  joinRootViews() {
    document
      .querySelectorAll(`${PHX_VIEW_SELECTOR}:not([${PHX_PARENT_ID}])`)
      .forEach(rootEl => {
        this.joinView(rootEl)
      })
  }

  joinView(el, parentView) {
    let view = new View(el, this, parentView)
    this.views[view.id] = view
    view.join()
  }

  getViewById(id) {
    return this.views[id]
  }

  onViewError(view) {
    this.dropActiveElement(view)
  }

  destroyViewById(id) {
    let view = this.views[id]
    if (view) {
      delete this.views[view.id]
      view.destroy()
    }
  }

  getBindingPrefix() {
    return this.bindingPrefix
  }

  setActiveElement(target) {
    if (this.activeElement === target) {
      return
    }
    this.activeElement = target
    let cancel = () => {
      if (target === this.activeElement) {
        this.activeElement = null
      }
      target.removeEventListener('mouseup', this)
      target.removeEventListener('touchend', this)
    }
    target.addEventListener('mouseup', cancel)
    target.addEventListener('touchend', cancel)
  }

  getActiveElement() {
    if (document.activeElement === document.body) {
      return this.activeElement || document.activeElement
    } else {
      return document.activeElement
    }
  }

  dropActiveElement(view) {
    if (this.prevActive && view.ownsElement(this.prevActive)) {
      this.prevActive = null
    }
  }

  restorePreviouslyActiveFocus() {
    if (this.prevActive && this.prevActive !== document.body) {
      this.prevActive.focus()
    }
  }

  blurActiveElement() {
    this.prevActive = this.getActiveElement()
    if (this.prevActive !== document.body) {
      this.prevActive.blur()
    }
  }
}

export default LiveSocket
