# JavaScript interoperability

To enable LiveView client/server interaction, we instantiate a LiveSocket. For example:

```javascript
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})
liveSocket.connect()
```

All options are passed directly to the `Phoenix.Socket` constructor,
except for the following LiveView specific options:

  * `bindingPrefix` - the prefix to use for phoenix bindings. Defaults `"phx-"`
  * `params` - the `connect_params` to pass to the view's mount callback. May be
    a literal object or closure returning an object. When a closure is provided,
    the function receives the view's element.
  * `hooks` - a reference to a user-defined hooks namespace, containing client
    callbacks for server/client interop. See the [Client hooks](#client-hooks-via-phx-hook)
    section below for details.
  * `uploaders` - a reference to a user-defined uploaders namespace, containing
    client callbacks for client-side direct-to-cloud uploads. See the
    [External uploads guide](external-uploads.md) for details.
  * `metadata` - additional user-defined metadata that is sent along events to the server.
    See the [Key events](bindings.html#key-events) section in the bindings guide
    for an example.

## Debugging client events

To aid debugging on the client when troubleshooting issues, the `enableDebug()`
and `disableDebug()` functions are exposed on the `LiveSocket` JavaScript instance.
Calling `enableDebug()` turns on debug logging which includes LiveView life-cycle and
payload events as they come and go from client to server. In practice, you can expose
your instance on `window` for quick access in the browser's web console, for example:

```javascript
// app.js
let liveSocket = new LiveSocket(...)
liveSocket.connect()
window.liveSocket = liveSocket

// in the browser's web console
>> liveSocket.enableDebug()
```

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
accepts an integer in milliseconds for the one-way latency to and from the server. For example:

```javascript
// app.js
let liveSocket = new LiveSocket(...)
liveSocket.connect()
window.liveSocket = liveSocket

// in the browser's web console
>> liveSocket.enableLatencySim(1000)
[Log] latency simulator enabled for the duration of this browser session.
      Call disableLatencySim() to disable
```

## Handling server-pushed events

When the server uses `Phoenix.LiveView.push_event/3`, the event name
will be dispatched in the browser with the `phx:` prefix. For example,
imagine the following template where you want to highlight an existing
element from the server to draw the user's attention:

```heex
<div id={"item-#{item.id}"} class="item">
  {item.title}
</div>
```

Next, the server can issue a highlight using the standard `push_event`:

```elixir
def handle_info({:item_updated, item}, socket) do
  {:noreply, push_event(socket, "highlight", %{id: "item-#{item.id}"})}
end
```

Finally, a window event listener can listen for the event and conditionally
execute the highlight command if the element matches:

```javascript
let liveSocket = new LiveSocket(...)
window.addEventListener("phx:highlight", (e) => {
  let el = document.getElementById(e.detail.id)
  if(el) {
    // logic for highlighting
  }
})
```

If you desire, you can also integrate this functionality with Phoenix'
JS commands, executing JS commands for the given element whenever highlight
is triggered. First, update the element to embed the JS command into a data
attribute:

```heex
<div id={"item-#{item.id}"} class="item" data-highlight={JS.transition("highlight")}>
  {item.title}
</div>
```

Now, in the event listener, use `LiveSocket.execJS` to trigger all JS
commands in the new attribute:

```javascript
let liveSocket = new LiveSocket(...)
window.addEventListener("phx:highlight", (e) => {
  document.querySelectorAll(`[data-highlight]`).forEach(el => {
    if(el.id == e.detail.id){
      liveSocket.execJS(el, el.getAttribute("data-highlight"))
    }
  })
})
```

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

*Note:* When using hooks outside the context of a LiveView, `mounted` is the only
callback invoked, and only those elements on the page at DOM ready will be tracked.
For dynamic tracking of the DOM as elements are added, removed, and updated, a LiveView
should be used.

The above life-cycle callbacks have in-scope access to the following attributes:

  * `el` - attribute referencing the bound DOM node
  * `liveSocket` - the reference to the underlying `LiveSocket` instance
  * `pushEvent(event, payload, (reply, ref) => ...)` - method to push an event from the client to the LiveView server
  * `pushEventTo(selectorOrTarget, event, payload, (reply, ref) => ...)` - method to push targeted events from the client
    to LiveViews and LiveComponents. It sends the event to the LiveComponent or LiveView the `selectorOrTarget` is
    defined in, where its value can be either a query selector or an actual DOM element. If the query selector returns
    more than one element it will send the event to all of them, even if all the elements are in the same LiveComponent
    or LiveView. `pushEventTo` supports passing the node element e.g. `this.el` instead of selector e.g. `"#" + this.el.id`
    as the first parameter for target.
  * `handleEvent(event, (payload) => ...)` - method to handle an event pushed from the server
  * `upload(name, files)` - method to inject a list of file-like objects into an uploader.
  * `uploadTo(selectorOrTarget, name, files)` - method to inject a list of file-like objects into an uploader.
    The hook will send the files to the uploader with `name` defined by [`allow_upload/3`](`Phoenix.LiveView.allow_upload/3`)
    on the server-side. Dispatching new uploads triggers an input change event which will be sent to the
    LiveComponent or LiveView the `selectorOrTarget` is defined in, where its value can be either a query selector or an
    actual DOM element. If the query selector returns more than one live file input, an error will be logged.

For example, the markup for a controlled input for phone-number formatting could be written
like this:

```heex
<input type="text" name="user[phone_number]" id="user-phone-number" phx-hook="PhoneNumber" />
```

Then a hook callback object could be defined and passed to the socket:

```javascript
/**
 * @type {Object.<string, import("phoenix_live_view").ViewHook>}
 */
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
```

*Note*: when using `phx-hook`, a unique DOM ID must always be set.

> #### Warning {: .warning}
>
> Hooks cannot be added dynamically on an element. For example:
> ```heex
>  <div id="my-hook" phx-hook={if @hook_enabled, do: "MyHook"} />
>  ```
>
> In this case, if `@hook_enabled` starts as `true`, then the hook will work as
> intended. However, if the value starts as `false` and changes from `false` to `true`,
> the hook will never be initialized, and therefore `mounted` will never be called.
>
> To achieve the desired effect, the hook should always be set, and an attribute on
> the DOM element can be checked in the `updated` callback to toggle the state of
> the hook.
>
>  ```heex
> <div id="my-hook" phx-hook="MyHook" data-hook-enabled={to_string(@hook_enabled)} />
> ```
> ```javascript
> hooks.MyHook = {
>   updated: {
>     if (this.el.getAttribute("data-hook-enabled") !== "false")) {
>       this.el.innerHTML = "MyHook is enabled";
>     }
>   }
> }
> ```

For integration with client-side libraries which require a broader access to full
DOM management, the `LiveSocket` constructor accepts a `dom` option with an
`onBeforeElUpdated` callback. The `fromEl` and `toEl` DOM nodes are passed to the
function just before the DOM patch operations occurs in LiveView. This allows external
libraries to (re)initialize DOM elements or copy attributes as necessary as LiveView
performs its own patch operations. The update operation cannot be cancelled or deferred,
and the return value is ignored.

For example, the following option could be used to guarantee that some attributes set on the client-side are kept intact:

```javascript
...
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
  dom: {
    onBeforeElUpdated(from, to) {
      for (const attr of from.attributes) {
        if (attr.name.startsWith("data-js-")) {
          to.setAttribute(attr.name, attr.value);
        }
      }
    }
  }
}
```

In the example above, all attributes starting with `data-js-` won't be replaced when the DOM is patched by LiveView.

### Client-server communication

A hook can push events to the LiveView by using the `pushEvent` function and receive a
reply from the server via a `{:reply, map, socket}` return value. The reply payload will be
passed to the optional `pushEvent` response callback.

Communication with the hook from the server can be done by reading data attributes on the
hook element or by using `Phoenix.LiveView.push_event/3` on the server and `handleEvent` on the client.

For example, to implement infinite scrolling, one can pass the current page using data attributes:

```heex
<div id="infinite-scroll" phx-hook="InfiniteScroll" data-page={@page}>
```

And then in the client:

```javascript
/**
 * @type {import("phoenix_live_view").ViewHook}
 */
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
```

However, the data attribute approach is not a good approach if you need to frequently push data to the client. To push out-of-band events to the client, for example to render charting points, one could do:

```heex
<div id="chart" phx-hook="Chart">
```

And then on the client:

```javascript
/**
 * @type {import("phoenix_live_view").ViewHook}
 */
Hooks.Chart = {
  mounted(){
    this.handleEvent("points", ({points}) => MyChartLib.addPoints(points))
  }
}
```

And then you can push events as:

    {:noreply, push_event(socket, "points", %{points: new_points})}

Events pushed from the server via `push_event` are global and will be dispatched
to all active hooks on the client who are handling that event. If you need to scope events
(for example when pushing from a live component that has siblings on the current live view),
then this must be done by namespacing them:

    def update(%{id: id, points: points} = assigns, socket) do
      socket =
        socket
        |> assign(assigns)
        |> push_event("points-#{id}", points)

      {:ok, socket}
    end

And then on the client:

```javascript
Hooks.Chart = {
  mounted(){
    this.handleEvent(`points-${this.el.id}`, (points) => MyChartLib.addPoints(points));
  }
}
```

*Note*: In case a LiveView pushes events and renders content, `handleEvent` callbacks are invoked after the page is updated. Therefore, if the LiveView redirects at the same time it pushes events, callbacks won't be invoked on the old page's elements. Callbacks would be invoked on the redirected page's newly mounted hook elements.
