# Bindings

Phoenix supports DOM element bindings for client-server interaction. For
example, to react to a click on a button, you would render the element:

    <button phx-click="inc_temperature">+</button>

Then on the server, all LiveView bindings are handled with the `handle_event`
callback, for example:

    def handle_event("inc_temperature", _value, socket) do
      {:ok, new_temp} = Thermostat.inc_temperature(socket.assigns.id)
      {:noreply, assign(socket, :temperature, new_temp)}
    end

| Binding                | Attributes |
|------------------------|------------|
| [Params](#click-events) | `phx-value-*` |
| [Click Events](#click-events) | `phx-click`, `phx-capture-click` |
| [Focus/Blur Events](#focus-and-blur-events) | `phx-blur`, `phx-focus`, `phx-window-blur`, `phx-window-focus` |
| [Key Events](#key-events) | `phx-keydown`, `phx-keyup`, `phx-window-keydown`, `phx-window-keyup`, `phx-key` |
| [Form Events](form-bindings.md) | `phx-change`, `phx-submit`, `phx-feedback-for`, `phx-disable-with`, `phx-trigger-action`, `phx-auto-recover` |
| [Rate Limiting](#rate-limiting-events-with-debounce-and-throttle) | `phx-debounce`, `phx-throttle` |
| [DOM Patching](dom-patching.md) | `phx-update` |
| [JS Interop](js-interop.md#client-hooks) | `phx-hook` |

## Click Events

The `phx-click` binding is used to send click events to the server.
When any client event, such as a `phx-click` click is pushed, the value
sent to the server will be chosen with the following priority:

  * Any number of optional `phx-value-` prefixed attributes, such as:

        <div phx-click="inc" phx-value-myvar1="val1" phx-value-myvar2="val2">

    will send the following map of params to the server:

        def handle_event("inc", %{"myvar1" => "val1", "myvar2" => "val2"}, socket) do

    If the `phx-value-` prefix is used, the server payload will also contain a `"value"`
    if the element's value attribute exists.

  * When receiving a map on the server, the payload will also include user defined metadata
    of the client event, or an empty map if none is set. For example, the following `LiveSocket`
    client option would send the coordinates and `altKey` information for all clicks:

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


The `phx-capture-click` event is just like `phx-click`, but instead of the click event
being dispatched to the closest `phx-click` element as it bubbles up through the DOM, the event
is dispatched as it propagates from the top of the DOM tree down to the target element. This is
useful when wanting to bind click events without receiving bubbled events from child UI elements.
Since capturing happens before bubbling, this can also be important for preparing or preventing
behaviour that will be applied during the bubbling phase.

## Focus and Blur Events

Focus and blur events may be bound to DOM elements that emit
such events, using the `phx-blur`, and `phx-focus` bindings, for example:

    <input name="email" phx-focus="myfocus" phx-blur="myblur"/>

To detect when the page itself has received focus or blur,
`phx-window-focus` and `phx-window-blur` may be specified. These window
level events may also be necessary if the element in consideration
(most often a `div` with no tabindex) cannot receive focus. Like other
bindings, `phx-value-*` can be provided on the bound element, and those
values will be sent as part of the payload. For example:

    <div class="container"
        phx-window-focus="page-active"
        phx-window-blur="page-inactive"
        phx-value-page="123">
      ...
    </div>

The following window-level bindings are supported:

  * `phx-window-focus`
  * `phx-window-blur`
  * `phx-window-keydown`
  * `phx-window-keyup`

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

To determine which key has been pressed you should use `key` value. The
available options can be found on
[MDN](https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/key/Key_Values)
or via the [Key Event Viewer](https://w3c.github.io/uievents/tools/key-event-viewer.html).

By default, the bound element will be the event listener, but a
window-level binding may be provided via `phx-window-keydown` or `phx-window-keyup`,
for example:

    def render(assigns) do
      ~L"""
      <div id="thermostat" phx-window-keyup="update_temp">
        Current temperature: <%= @temperature %>
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

    def handle_event("update_temp", _key, socket) do
      {:noreply, socket}
    end

## Rate limiting events with Debounce and Throttle

All events can be rate-limited on the client by using the
`phx-debounce` and `phx-throttle` bindings, with the following behavior:

  * `phx-debounce` - Accepts either an integer timeout value (in milliseconds),
    or `"blur"`. When an integer is provided, emitting the event is delayed by
    the specified milliseconds. When `"blur"` is provided, emitting the event is
    delayed until the field is blurred by the user. Debouncing is typically used for
    input elements.

  * `phx-throttle` - Accepts an integer timeout value to throttle the event in milliseconds.
    Unlike debounce, throttle will immediately emit the event, then rate limit it at once
    per provided timeout. Throttling is typically used to rate limit clicks, mouse and
    keyboard actions.

For example, to avoid validating an email until the field is blurred, while validating
the username at most every 2 seconds after a user changes the field:

    <form phx-change="validate" phx-submit="save">
      <input type="text" name="user[email]" phx-debounce="blur"/>
      <input type="text" name="user[username]" phx-debounce="2000"/>
    </form>

And to rate limit a volume up click to once every second:

    <button phx-click="volume_up" phx-throttle="1000">+</button>

Likewise, you may throttle held-down keydown:

    <div phx-window-keydown="keydown" phx-throttle="500">
      ...
    </div>

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

## LiveView Specific Events

The `lv:` event prefix supports LiveView specific features that are handled
by LiveView without calling the user's `handle_event/3` callbacks. Today,
the following events are supported:

  - `lv:clear-flash` – clears the flash when sent to the server. If a
    `phx-value-key` is provided, the specific key will be removed from the flash.

For example:

    <p class="alert" phx-click="lv:clear-flash" phx-value-key="info">
      <%= live_flash(@flash, :info) %>
    </p>
