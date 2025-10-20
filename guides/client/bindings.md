# Bindings

Phoenix supports DOM element bindings for client-server interaction. For
example, to react to a click on a button, you would render the element:

```heex
<button phx-click="inc_temperature">+</button>
```

Then on the server, all LiveView bindings are handled with the `handle_event`
callback, for example:

    def handle_event("inc_temperature", _value, socket) do
      {:ok, new_temp} = Thermostat.inc_temperature(socket.assigns.id)
      {:noreply, assign(socket, :temperature, new_temp)}
    end

| Binding                | Attributes |
|------------------------|------------|
| [Params](#click-events) | `phx-value-*` |
| [Click Events](#click-events) | `phx-click`, `phx-click-away` |
| [Form Events](form-bindings.md) | `phx-change`, `phx-submit`, `phx-disable-with`, `phx-trigger-action`, `phx-auto-recover` |
| [Focus Events](#focus-and-blur-events) | `phx-blur`, `phx-focus`, `phx-window-blur`, `phx-window-focus` |
| [Key Events](#key-events) | `phx-keydown`, `phx-keyup`, `phx-window-keydown`, `phx-window-keyup`, `phx-key` |
| [Scroll Events](#scroll-events-and-infinite-pagination) | `phx-viewport-top`, `phx-viewport-bottom` |
| [DOM Patching](#dom-patching) | `phx-update`, `phx-mounted`, `phx-remove` |
| [JS Interop](js-interop.md#client-hooks-via-phx-hook) | `phx-hook` |
| [Lifecycle Events](#lifecycle-events) | `phx-connected`, `phx-disconnected` |
| [Rate Limiting](#rate-limiting-events-with-debounce-and-throttle) | `phx-debounce`, `phx-throttle` |
| [Static tracking](`Phoenix.LiveView.static_changed?/1`) | `phx-track-static` |

If you need to trigger commands actions via JavaScript, see [JavaScript interoperability](js-interop.md#js-commands).

## Click Events

The `phx-click` binding is used to send click events to the server.
When any client event, such as a `phx-click` click is pushed, the value
sent to the server will be chosen with the following priority:

  * The `:value` specified in `Phoenix.LiveView.JS.push/3`, such as:

    ```heex
    <div phx-click={JS.push("inc", value: %{myvar1: @val1})}>
    ```

  * Any number of optional `phx-value-` prefixed attributes, such as:

    ```heex
    <div phx-click="inc" phx-value-myvar1="val1" phx-value-myvar2="val2">
    ```

    will send the following map of params to the server:

        def handle_event("inc", %{"myvar1" => "val1", "myvar2" => "val2"}, socket) do

    If the `phx-value-` prefix is used, the server payload will also contain a `"value"`
    if the element's value attribute exists.

  * The payload will also include any additional user defined metadata of the client event.
    For example, the following `LiveSocket` client option would send the coordinates and
    `altKey` information for all clicks:

    ```javascript
    let liveSocket = new LiveSocket("/live", Socket, {
      params: {_csrf_token: csrfToken},
      metadata: {
        click: (e, el) => {
          return {
            altKey: e.altKey,
            clientX: e.clientX,
            clientY: e.clientY
          }
        }
      }
    })
    ```

The `phx-click-away` event is fired when a click event happens outside of the element.
This is useful for hiding toggled containers like drop-downs.

## Focus and Blur Events

Focus and blur events may be bound to DOM elements that emit
such events, using the `phx-blur`, and `phx-focus` bindings, for example:

```heex
<input name="email" phx-focus="myfocus" phx-blur="myblur"/>
```

To detect when the page itself has received focus or blur,
`phx-window-focus` and `phx-window-blur` may be specified. These window
level events may also be necessary if the element in consideration
(most often a `div` with no tabindex) cannot receive focus. Like other
bindings, `phx-value-*` can be provided on the bound element, and those
values will be sent as part of the payload. For example:

```heex
<div class="container"
    phx-window-focus="page-active"
    phx-window-blur="page-inactive"
    phx-value-page="123">
  ...
</div>
```

## Key Events

The `onkeydown`, and `onkeyup` events are supported via the `phx-keydown`,
and `phx-keyup` bindings. Each binding supports a `phx-key` attribute, which triggers
the event for the specific key press. If no `phx-key` is provided, the event is triggered
for any key press. When pushed, the value sent to the server will contain the `"key"`
that was pressed, plus any user-defined metadata. For example, pressing the
Escape key looks like this:

    %{"key" => "Escape"}

To capture additional user-defined metadata, the `metadata` option for keydown events
may be provided to the `LiveSocket` constructor. For example:

```javascript
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  metadata: {
    keydown: (e, el) => {
      return {
        key: e.key,
        metaKey: e.metaKey,
        repeat: e.repeat
      }
    }
  }
})
```

To determine which key has been pressed you should use `key` value. The
available options can be found on
[MDN](https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/key/Key_Values)
or via the [Key Event Viewer](https://w3c.github.io/uievents/tools/key-event-viewer.html).

*Note*: `phx-keyup` and `phx-keydown` are not supported on inputs.
Instead use form bindings, such as `phx-change`, `phx-submit`, etc.

*Note*: it is possible for certain browser features like autofill to trigger key events
with no `"key"` field present in the value map sent to the server. For this reason, we
recommend always having a fallback catch-all event handler for LiveView key bindings.
By default, the bound element will be the event listener, but a
window-level binding may be provided via `phx-window-keydown` or `phx-window-keyup`,
for example:

    def render(assigns) do
      ~H"""
      <div id="thermostat" phx-window-keyup="update_temp">
        Current temperature: {@temperature}
      </div>
      """
    end

    def handle_event("update_temp", %{"key" => "ArrowUp"}, socket) do
      {:ok, new_temp} = Thermostat.inc_temperature(socket.assigns.id)
      {:noreply, assign(socket, :temperature, new_temp)}
    end

    def handle_event("update_temp", %{"key" => "ArrowDown"}, socket) do
      {:ok, new_temp} = Thermostat.dec_temperature(socket.assigns.id)
      {:noreply, assign(socket, :temperature, new_temp)}
    end

    def handle_event("update_temp", _, socket) do
      {:noreply, socket}
    end

## Rate limiting events with Debounce and Throttle

All events can be rate-limited on the client by using the
`phx-debounce` and `phx-throttle` bindings, with the exception of the `phx-blur`
binding, which is fired immediately.

Rate limited and debounced events have the following behavior:

  * `phx-debounce` - Accepts either an integer timeout value (in milliseconds),
    or `"blur"`. When an integer is provided, emitting the event is delayed by
    the specified milliseconds. When `"blur"` is provided, emitting the event is
    delayed until the field is blurred by the user. When the value is omitted
    a default of 300ms is used. Debouncing is typically used for input elements.

  * `phx-throttle` - Accepts an integer timeout value to throttle the event in milliseconds.
    Unlike debounce, throttle will immediately emit the event, then rate limit it at once
    per provided timeout. When the value is omitted a default of 300ms is used.
    Throttling is typically used to rate limit clicks, mouse and keyboard actions.

For example, to avoid validating an email until the field is blurred, while validating
the username at most every 2 seconds after a user changes the field:

```heex
<form id="my-form" phx-change="validate" phx-submit="save">
  <input type="text" name="user[email]" phx-debounce="blur"/>
  <input type="text" name="user[username]" phx-debounce="2000"/>
</form>
```

And to rate limit a volume up click to once every second:

```heex
<button phx-click="volume_up" phx-throttle="1000">+</button>
```

Likewise, you may throttle held-down keydown:

```heex
<div phx-window-keydown="keydown" phx-throttle="500">
  ...
</div>
```

Unless held-down keys are required, a better approach is generally to use
`phx-keyup` bindings which only trigger on key up, thereby being self-limiting.
However, `phx-keydown` is useful for games and other use cases where a constant
press on a key is desired. In such cases, throttle should always be used.

### Debounce and Throttle special behavior

The following specialized behavior is performed for forms and keydown bindings:

  * When a `phx-submit`, or a `phx-change` for a different input is triggered,
    any current debounce or throttle timers are reset for existing inputs.

  * A `phx-keydown` binding is only throttled for key repeats. Unique keypresses
    back-to-back will dispatch the pressed key events.

## JS commands

LiveView bindings support a JavaScript command interface via the `Phoenix.LiveView.JS` module, which allows you to specify utility operations that execute on the client when firing `phx-` binding events, such as `phx-click`, `phx-change`, etc. Commands compose together to allow you to push events, add classes to elements, transition elements in and out, and more.
See the `Phoenix.LiveView.JS` documentation for full usage.

For a small example of what's possible, imagine you want to show and hide a modal on the page without needing to make the round trip to the server to render the content:

```heex
<div id="modal" class="modal">
  My Modal
</div>

<button phx-click={JS.show(to: "#modal", transition: "fade-in")}>
  show modal
</button>

<button phx-click={JS.hide(to: "#modal", transition: "fade-out")}>
  hide modal
</button>

<button phx-click={JS.toggle(to: "#modal", in: "fade-in", out: "fade-out")}>
  toggle modal
</button>
```

Or if your UI library relies on classes to perform the showing or hiding:

```heex
<div id="modal" class="modal">
  My Modal
</div>

<button phx-click={JS.add_class("show", to: "#modal", transition: "fade-in")}>
  show modal
</button>

<button phx-click={JS.remove_class("show", to: "#modal", transition: "fade-out")}>
  hide modal
</button>
```

Commands compose together. For example, you can push an event to the server and
immediately hide the modal on the client:

```heex
<div id="modal" class="modal">
  My Modal
</div>

<button phx-click={JS.push("modal-closed") |> JS.remove_class("show", to: "#modal", transition: "fade-out")}>
  hide modal
</button>
```

It is also useful to extract commands into their own functions:

```elixir
alias Phoenix.LiveView.JS

def hide_modal(js \\ %JS{}, selector) do
  js
  |> JS.push("modal-closed")
  |> JS.remove_class("show", to: selector, transition: "fade-out")
end
```

```heex
<button phx-click={hide_modal("#modal")}>hide modal</button>
```

The `Phoenix.LiveView.JS.push/3` command is particularly powerful in allowing you to customize the event being pushed to the server. For example, imagine you start with a familiar `phx-click` which pushes a message to the server when clicked:

```heex
<button phx-click="clicked">click</button>
```

Now imagine you want to customize what happens when the `"clicked"` event is pushed, such as which component should be targeted, which element should receive CSS loading state classes, etc. This can be accomplished with options on the JS push command. For example:

```heex
<button phx-click={JS.push("clicked", target: @myself, loading: ".container")}>click</button>
```

See `Phoenix.LiveView.JS.push/3` for all supported options.

## DOM patching

A container can be marked with `phx-update` to configure how the DOM
is updated. The following values are supported:

  * `replace` - the default operation. Replaces the element with the contents

  * `stream` - supports stream operations. Streams are used to manage large
    collections in the UI without having to store the collection on the server

  * `ignore` - ignores updates to the DOM regardless of new content changes.
    This is useful for client-side interop with existing libraries that do
    their own DOM operations

When using `phx-update`, a unique DOM ID must always be set in the
container. If using "stream", a DOM ID must also be set
for each child. When inserting stream elements containing an
ID already present in the container, LiveView will replace the existing
element with the new content. See `Phoenix.LiveView.stream/3` for more
information.

The "ignore" behaviour is frequently used when you need to integrate
with another JS library. Updates from the server to the element's content
and attributes are ignored, *except for data attributes*. Changes, additions,
and removals from the server to data attributes are merged with the ignored
element which can be used to pass data to the JS handler.

To react to elements being mounted to the DOM, the `phx-mounted` binding
can be used. For example, to animate an element on mount:

```heex
<div phx-mounted={JS.transition("animate-ping", time: 500)}>
```

If `phx-mounted` is used on the initial page render, it will run at the earliest
opportunity. For elements outside of a LiveView, this is as soon as `liveSocket.connect()`
is executed. For elements inside of a LiveView, this is only after the initial socket
connection is established and the LiveView is mounted.

To react to elements being removed from the DOM, the `phx-remove` binding
may be specified, which can contain a `Phoenix.LiveView.JS` command to execute.
The `phx-remove` command is only executed for the removed parent element.
It does not cascade to children.

To react to elements being updated in the DOM, you'll need to use a
[hook](js-interop.md#client-hooks-via-phx-hook), which gives you full access
to the element life-cycle.

## Lifecycle events

LiveView supports the `phx-connected` and `phx-disconnected` bindings to react
to connection lifecycle events with JS commands. For example, to show an element
when the LiveView has lost its connection and hide it when the connection
recovers:

```heex
<div id="status" class="hidden" phx-disconnected={JS.show()} phx-connected={JS.hide()}>
  Attempting to reconnect...
</div>
```

`phx-connected` and `phx-disconnected` are only executed when operating
inside a LiveView container. For static templates, they will have no effect.

## LiveView events prefix

The `lv:` event prefix supports LiveView specific features that are handled
by LiveView without calling the user's `handle_event/3` callbacks. Today,
the following events are supported:

  - `lv:clear-flash` – clears the flash when sent to the server. If a
    `phx-value-key` is provided, the specific key will be removed from the flash.

For example:

```heex
<p class="alert" phx-click="lv:clear-flash" phx-value-key="info">
  {Phoenix.Flash.get(@flash, :info)}
</p>
```

## Scroll events and infinite pagination

The `phx-viewport-top` and `phx-viewport-bottom` bindings allow you to detect when a container's
first child reaches the top of the viewport, or the last child reaches the bottom of the viewport.
This is useful for infinite scrolling where you want to send paging events for the next results set or previous results set as the user is scrolling up and down and reaches the top or bottom of the viewport.

Generally, applications will add padding above and below a container when performing infinite scrolling to allow smooth scrolling as results are loaded. Combined with `Phoenix.LiveView.stream/3`, the `phx-viewport-top` and `phx-viewport-bottom` allow for infinite virtualized list that only keeps a small set of actual elements in the DOM. For example:

```elixir
def mount(_, _, socket) do
  {:ok,
    socket
    |> assign(page: 1, per_page: 20)
    |> paginate_posts(1)}
end

defp paginate_posts(socket, new_page) when new_page >= 1 do
  %{per_page: per_page, page: cur_page} = socket.assigns
  posts = Blog.list_posts(offset: (new_page - 1) * per_page, limit: per_page)

  {posts, at, limit} =
    if new_page >= cur_page do
      {posts, -1, per_page * 3 * -1}
    else
      {Enum.reverse(posts), 0, per_page * 3}
    end

  case posts do
    [] ->
      assign(socket, end_of_timeline?: at == -1)

    [_ | _] = posts ->
      socket
      |> assign(end_of_timeline?: false)
      |> assign(:page, new_page)
      |> stream(:posts, posts, at: at, limit: limit)
  end
end
```

Our `paginate_posts` function fetches a page of posts, and determines if the user is paging to a previous page or next page. Based on the direction of paging, the stream is either prepended to, or appended to with `at` of `0` or `-1` respectively. We also set the `limit` of the stream to three times the `per_page` to allow enough posts in the UI to appear as an infinite list, but small enough to maintain UI performance. We also set an `@end_of_timeline?` assign to track whether the user is at the end of results or not. Finally, we update the `@page` assign and posts stream. We can then wire up our container to support the viewport events:

```heex
<ul
  id="posts"
  phx-update="stream"
  phx-viewport-top={@page > 1 && JS.push("prev-page", page_loading: true)}
  phx-viewport-bottom={!@end_of_timeline? && JS.push("next-page", page_loading: true)}
  class={[
    if(@end_of_timeline?, do: "pb-10", else: "pb-[calc(200vh)]"),
    if(@page == 1, do: "pt-10", else: "pt-[calc(200vh)]")
  ]}
>
  <li :for={{id, post} <- @streams.posts} id={id}>
    <.post_card post={post} />
  </li>
</ul>
<div :if={@end_of_timeline?} class="mt-5 text-[50px] text-center">
  🎉 You made it to the beginning of time 🎉
</div>
```

There's not much here, but that's the point! This little snippet of UI is driving a fully virtualized list with bidirectional infinite scrolling. We use the `phx-viewport-top` binding to send the `"prev-page"` event to the LiveView, but only if the user is beyond the first page. It doesn't make sense to load negative page results, so we remove the binding entirely in those cases. Next, we wire up `phx-viewport-bottom` to send the `"next-page"` event, but only if we've yet to reach the end of the timeline. Finally, we conditionally apply some CSS classes which sets a large top and bottom padding to twice the viewport height based on the current pagination for smooth scrolling.

To complete our solution, we only need to handle the `"prev-page"` and `"next-page"` events in the LiveView:

```elixir
def handle_event("next-page", _, socket) do
  {:noreply, paginate_posts(socket, socket.assigns.page + 1)}
end

def handle_event("prev-page", %{"_overran" => true}, socket) do
  {:noreply, paginate_posts(socket, 1)}
end

def handle_event("prev-page", _, socket) do
  if socket.assigns.page > 1 do
    {:noreply, paginate_posts(socket, socket.assigns.page - 1)}
  else
    {:noreply, socket}
  end
end
```

This code simply calls the `paginate_posts` function we defined as our first step, using the current or next page to drive the results. Notice that we match on a special `"_overran" => true` parameter in our `"prev-page"` event. The viewport events send this parameter when the user has "overran" the viewport top or bottom. Imagine the case where the user is scrolling back up through many pages of results, but grabs the scrollbar and returns immediately to the top of the page. This means our `<ul id="posts">` container was overrun by the top of the viewport, and we need to reset the the UI to page the first page.

When testing, you can use `Phoenix.LiveViewTest.render_hook/3` to test the viewport events:

```elixir
view
|> element("#posts")
|> render_hook("next-page")
```
