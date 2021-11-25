# JavaScript interoperability

To enable LiveView client/server interaction, we instantiate a LiveSocket. For example:

    import {Socket} from "phoenix"
    import {LiveSocket} from "phoenix_live_view"

    let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
    let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})
    liveSocket.connect()

All options are passed directly to the `Phoenix.Socket` constructor,
except for the following LiveView specific options:

  * `bindingPrefix` - the prefix to use for phoenix bindings. Defaults `"phx-"`
  * `params` - the `connect_params` to pass to the view's mount callback. May be
    a literal object or closure returning an object. When a closure is provided,
    the function receives the view's element.
  * `hooks` – a reference to a user-defined hooks namespace, containing client
    callbacks for server/client interop. See the [Client hooks](#client-hooks-via-phx-hook)
    section below for details.
  * `uploaders` – a reference to a user-defined uploaders namespace, containing
    client callbacks for client-side direct-to-cloud uploads. See the
    [External Uploads guide](uploads-external.md) for details.

## Debugging Client Events

To aid debugging on the client when troubleshooting issues, the `enableDebug()`
and `disableDebug()` functions are exposed on the `LiveSocket` JavaScript instance.
Calling `enableDebug()` turns on debug logging which includes LiveView life-cycle and
payload events as they come and go from client to server. In practice, you can expose
your instance on `window` for quick access in the browser's web console, for example:

    // app.js
    let liveSocket = new LiveSocket(...)
    liveSocket.connect()
    window.liveSocket = liveSocket

    // in the browser's web console
    >> liveSocket.enableDebug()

The debug state uses the browser's built-in `sessionStorage`, so it will remain in effect
for as long as your browser session lasts.

## Simulating Latency

Proper handling of latency is critical for good UX. LiveView's CSS loading states allow
the client to provide user feedback while awaiting a server response. In development,
near zero latency on localhost does not allow latency to be easily represented or tested,
so LiveView includes a latency simulator with the JavaScript client to ensure your
application provides a pleasant experience. Like the `enableDebug()` function above,
the `LiveSocket` instance includes `enableLatencySim(milliseconds)` and `disableLatencySim()`
functions which apply throughout the current browser session. The `enableLatencySim` function
accepts an integer in milliseconds for the round-trip-time to the server. For example:

    // app.js
    let liveSocket = new LiveSocket(...)
    liveSocket.connect()
    window.liveSocket = liveSocket

    // in the browser's web console
    >> liveSocket.enableLatencySim(1000)
    [Log] latency simulator enabled for the duration of this browser session.
          Call disableLatencySim() to disable

## Loading state and errors

By default, the following classes are applied to the LiveView's parent
container:

  - `"phx-connected"` - applied when the view has connected to the server
  - `"phx-loading"` - applied when the view is not connected to the server
  - `"phx-error"` - applied when an error occurs on the server. Note, this
    class will be applied in conjunction with `"phx-loading"` if connection
    to the server is lost.

All `phx-` event bindings apply their own css classes when pushed. For example
the following markup:

    <button phx-click="clicked" phx-window-keydown="key">...</button>

On click, would receive the `phx-click-loading` class, and on keydown would receive
the `phx-keydown-loading` class. The css loading classes are maintained until an
acknowledgement is received on the client for the pushed event.

In the case of forms, when a `phx-change` is sent to the server, the input element
which emitted the change receives the `phx-change-loading` class, along with the
parent form tag. The following events receive css loading classes:

  - `phx-click` - `phx-click-loading`
  - `phx-change` - `phx-change-loading`
  - `phx-submit` - `phx-submit-loading`
  - `phx-focus` - `phx-focus-loading`
  - `phx-blur` - `phx-blur-loading`
  - `phx-window-keydown` - `phx-keydown-loading`
  - `phx-window-keyup` - `phx-keyup-loading`

For live page navigation via `live_redirect` and `live_patch`, as well as form
submits via `phx-submit`, the JavaScript events `"phx:page-loading-start"` and
`"phx:page-loading-stop"` are dispatched on window. Additionally, any `phx-`
event may dispatch page loading events by annotating the DOM element with
`phx-page-loading`. This is useful for showing main page loading status, for example:

    // app.js
    import topbar from "topbar"
    window.addEventListener("phx:page-loading-start", info => topbar.show())
    window.addEventListener("phx:page-loading-stop", info => topbar.hide())

Within the callback, `info.detail` will be an object that contains a `kind`
key, with a value that depends on the triggering event:

  - `"redirect"` - the event was triggered by a redirect
  - `"patch"` - the event was triggered by a patch
  - `"initial"` - the event was triggered by initial page load
  - `"element"` - the event was triggered by a `phx-` bound element, such as `phx-click`

For all kinds of page loading events, all but `"element"` will receive an additional `to`
key in the info metadata pointing to the href associated with the page load.

In the case of an `"element"` page loading event, the info will contain a
`"target"` key containing the DOM element which triggered the page loading
state.

## Client hooks via `phx-hook`

To handle custom client-side JavaScript when an element is added, updated,
or removed by the server, a hook object may be provided via `phx-hook`.
`phx-hook` must point to an object with the following life-cycle callbacks:

  * `mounted` - the element has been added to the DOM and its server
    LiveView has finished mounting
  * `beforeUpdate` - the element is about to be updated in the DOM.
    *Note*: any call here must be synchronous as the operation cannot
    be deferred or cancelled.
  * `updated` - the element has been updated in the DOM by the server
  * `destroyed` - the element has been removed from the page, either
    by a parent update, or by the parent being removed entirely
  * `disconnected` - the element's parent LiveView has disconnected from the server
  * `reconnected` - the element's parent LiveView has reconnected to the server

The above life-cycle callbacks have in-scope access to the following attributes:

  * `el` - attribute referencing the bound DOM node
  * `pushEvent(event, payload, (reply, ref) => ...)` - method to push an event from the client to the LiveView server
  * `pushEventTo(selectorOrTarget, event, payload, (reply, ref) => ...)` - method to push targeted events from the client
    to LiveViews and LiveComponents. It sends the event to the LiveComponent or LiveView the `selectorOrTarget` is
    defined in, where it's value can be either a query selector or an actual DOM element. If the query selector returns
    more than one element it will send the event to all of them, even if all the elements are in the same LiveComponent
    or LiveView.
  * `handleEvent(event, (payload) => ...)` - method to handle an event pushed from the server
  * `upload(name, files)` - method to inject a list of file-like objects into an uploader.
  * `uploadTo(selectorOrTarget, name, files)` - method to inject a list of file-like objects into an uploader.
    The hook will send the files to the uploader with `name` defined by [`allow_upload/3`](`Phoenix.LiveView.allow_upload/3`)
    on the server-side. Dispatching new uploads triggers an input change event which will be sent to the
    LiveComponent or LiveView the `selectorOrTarget` is defined in, where it's value can be either a query selector or an
    actual DOM element. If the query selector returns more than one live file input, an error will be logged.

For example, the markup for a controlled input for phone-number formatting could be written
like this:

    <input type="text" name="user[phone_number]" id="user-phone-number" phx-hook="PhoneNumber" />

Then a hook callback object could be defined and passed to the socket:

    let Hooks = {}
    Hooks.PhoneNumber = {
      mounted() {
        this.el.addEventListener("input", e => {
          let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
          if(match) {
            this.el.value = `${match[1]}-${match[2]}-${match[3]}`
          }
        })
      }
    }

    let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks, ...})
    ...

*Note*: when using `phx-hook`, a unique DOM ID must always be set.

For integration with client-side libraries which require a broader access to full
DOM management, the `LiveSocket` constructor accepts a `dom` option with an
`onBeforeElUpdated` callback. The `fromEl` and `toEl` DOM nodes are passed to the
function just before the DOM patch operations occurs in LiveView. This allows external
libraries to (re)initialize DOM elements or copy attributes as necessary as LiveView
performs its own patch operations. The update operation cannot be cancelled or deferred,
and the return value is ignored. For example, the following option could be used to add
[Alpine.js](https://github.com/alpinejs/alpine) support to your project:

    let liveSocket = new LiveSocket("/live", Socket, {
      ...,
      dom: {
        onBeforeElUpdated(from, to){
          if(from._x_dataStack){ window.Alpine.clone(from, to) }
        }
      },
    })

### Client-server communication

A hook can push events to the LiveView by using the `pushEvent` function and receive a
reply from the server via a `{:reply, map, socket}` return value. The reply payload will be
passed to the optional `pushEvent` response callback.

Communication with the hook from the server can be done by reading data attributes on the
hook element or by using `Phoenix.LiveView.push_event/3` on the server and `handleEvent` on the client.

For example, to implement infinite scrolling, one can pass the current page using data attributes:

    <div id="infinite-scroll" phx-hook="InfiniteScroll" data-page="<%= @page %>">

And then in the client:

    Hooks.InfiniteScroll = {
      page() { return this.el.dataset.page },
      mounted(){
        this.pending = this.page()
        window.addEventListener("scroll", e => {
          if(this.pending == this.page() && scrollAt() > 90){
            this.pending = this.page() + 1
            this.pushEvent("load-more", {})
          }
        })
      },
      updated(){ this.pending = this.page() }
    }

However, the data attribute approach is not a good approach if you need to frequently push data to the client. To push out-of-band events to the client, for example to render charting points, one could do:

    <div id="chart" phx-hook="Chart">
    {:noreply, push_event(socket, "points", %{points: new_points})}

And then on the client:

    Hooks.Chart = {
      mounted(){
        this.handleEvent("points", ({points}) => MyChartLib.addPoints(points))
      }
    }

*Note*: remember events pushed from the server via `push_event` are global and will be dispatched
to all active hooks on the client who are handling that event.

*Note*: In case a LiveView pushes events and renders content, `handleEvent` callbacks are invoked after the page is updated. Therefore, if the LiveView redirects at the same time it pushes events, callbacks won't be invoked on the old page's elements. Callbacks would be invoked on the redirected page's newly mounted hook elements.

## Triggering `phx-` form events with JavaScript

Often it is desirable to trigger an event on a DOM element without explicit
user interaction on the element. For example, a custom form element such as a
date picker or custom select input which utilizes a hidden input element to
store the selected state.

In these cases, the event functions on the DOM API can be used, for example
to trigger a `phx-change` event:

```javascript
document.getElementById("my-select").dispatchEvent(
  new Event("input", {bubbles: true})
)
```

When using a client hook, `this.el` can be used to determine the element as
outlined in the "Client hooks" documentation.

It is also possible to trigger a `phx-submit` using a "submit" event:

```javascript
document.getElementById("my-form").dispatchEvent(
  new Event("submit", {bubbles: true})
)
```

## Executing JS Commands for custom attributes

The `Phoenix.LiveView.JS` commands execute when `phx-` bindings are triggered, such as `phx-click`, or `phx-change` bindings. Custom scripts may also execute a command by using the `execJS` function of the `LiveSocket` instance. For example, imagine the following template where you want to highlight an existing element from the server to draw the user's attention:

```heex
<div id={"item-#{item.id}"} class="item" data-handle-highlight={JS.transition("highlight")}>
  <%= item.title %>
</div>
```

Next, the server can issue a highlight using the standard `push_event`:

```elixir
def handle_info({:item_updated, item}, socket) do
  {:ok, push_event(socket, "highlight", %{id: item.id})}
end
```

Finally, a window event listener can listen for the event and conditionally
execute the highlight command if the element matches:

```javascript
let liveSocket = new LiveSocket(...)
window.addEventListener(`phx:highlight`, (e) => {
  document.querySelectorAll(`[data-handle-highlight]`).forEach(el => {
    if(el.id == e.detail.id){
      liveSocket.execJS(el, el.getAttribute("data-handle-highlight"))
    }
  })
})
```
