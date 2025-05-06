defmodule Phoenix.LiveView.JS do
  @moduledoc ~S'''
  Provides commands for executing JavaScript utility operations on the client.

  JS commands support a variety of utility operations for common client-side
  needs, such as adding or removing CSS classes, setting or removing tag attributes,
  showing or hiding content, and transitioning in and out with animations.
  While these operations can be accomplished via client-side hooks,
  JS commands are DOM-patch aware, so operations applied
  by the JS APIs will stick to elements across patches from the server.

  In addition to purely client-side utilities, the JS commands include a
  rich `push` API, for extending the default `phx-` binding pushes with
  options to customize targets, loading states, and additional payload values.

  ## Client Utility Commands

  The following utilities are included:

    * `add_class` - Add classes to elements, with optional transitions
    * `remove_class` - Remove classes from elements, with optional transitions
    * `toggle_class` - Sets or removes classes from elements, with optional transitions
    * `set_attribute` - Set an attribute on elements
    * `remove_attribute` - Remove an attribute from elements
    * `toggle_attribute` - Sets or removes element attribute based on attribute presence.
    * `show` - Show elements, with optional transitions
    * `hide` - Hide elements, with optional transitions
    * `toggle` - Shows or hides elements based on visibility, with optional transitions
    * `transition` - Apply a temporary transition to elements for animations
    * `dispatch` - Dispatch a DOM event to elements

  For example, the following modal component can be shown or hidden on the
  client without a trip to the server:

      alias Phoenix.LiveView.JS

      def hide_modal(js \\ %JS{}) do
        js
        |> JS.hide(transition: "fade-out", to: "#modal")
        |> JS.hide(transition: "fade-out-scale", to: "#modal-content")
      end

      def modal(assigns) do
        ~H"""
        <div id="modal" class="phx-modal" phx-remove={hide_modal()}>
          <div
            id="modal-content"
            class="phx-modal-content"
            phx-click-away={hide_modal()}
            phx-window-keydown={hide_modal()}
            phx-key="escape"
          >
            <button class="phx-modal-close" phx-click={hide_modal()}>✖</button>
            <p>{@text}</p>
          </div>
        </div>
        """
      end

  ## Enhanced push events

  The `push/1` command allows you to extend the built-in pushed event handling
  when a `phx-` event is pushed to the server. For example, you may wish to
  target a specific component, specify additional payload values to include
  with the event, apply loading states to external elements, etc. For example,
  given this basic `phx-click` event:

  ```heex
  <button phx-click="inc">+</button>
  ```

  Imagine you need to target your current component, and apply a loading state
  to the parent container while the client awaits the server acknowledgement:

      alias Phoenix.LiveView.JS

      ~H"""
      <button phx-click={JS.push("inc", loading: ".thermo", target: @myself)}>+</button>
      """

  Push commands also compose with all other utilities. For example,
  to add a class when pushing:

  ```heex
  <button phx-click={
    JS.push("inc", loading: ".thermo", target: @myself)
    |> JS.add_class("warmer", to: ".thermo")
  }>+</button>
  ```

  Any `phx-value-*` attributes will also be included in the payload, their
  values will be overwritten by values given directly to `push/1`. Any
  `phx-target` attribute will also be used, and overwritten.

  ```heex
  <button
    phx-click={JS.push("inc", value: %{limit: 40})}
    phx-value-room="bedroom"
    phx-value-limit="this value will be 40"
    phx-target={@myself}
  >+</button>
  ```

  ## DOM Selectors

  The client utility commands in this module all take an optional DOM selector
  using the `:to` option.

  This can be a string for a regular DOM selector such as:

  ```elixir
  JS.add_class("warmer", to: ".thermo")
  JS.hide(to: "#modal")
  JS.show(to: "body a:nth-child(2)")
  ```

  It is also possible to provide scopes to the DOM selector. The following scopes
  are available:

   * `{:inner, "selector"}` To target an element within the interacted element.
   * `{:closest, "selector"}` To target the closest element from the interacted
   element upwards.

   For example, if building a dropdown component, the button could use the `:inner`
   scope:

   ```heex
   <div phx-click={JS.show(to: {:inner, ".menu"})}>
     <div>Open me</div>
     <div class="menu hidden" phx-click-away={JS.hide()}>
       I'm in the dropdown menu
     </div>
   </div>
   ```

  ## Custom JS events with `JS.dispatch/1` and `window.addEventListener`

  `dispatch/1` can be used to dispatch custom JavaScript events to
  elements. For example, you can use `JS.dispatch("click", to: "#foo")`,
  to dispatch a click event to an element.

  This also means you can augment your elements with custom events,
  by using JavaScript's `window.addEventListener` and invoking them
  with `dispatch/1`. For example, imagine you want to provide
  a copy-to-clipboard functionality in your application. You can
  add a custom event for it:

  ```javascript
  window.addEventListener("my_app:clipcopy", (event) => {
    if ("clipboard" in navigator) {
      const text = event.target.textContent;
      navigator.clipboard.writeText(text);
    } else {
      alert("Sorry, your browser does not support clipboard copy.");
    }
  });
  ```

  Now you can have a button like this:

  ```heex
  <button phx-click={JS.dispatch("my_app:clipcopy", to: "#element-with-text-to-copy")}>
    Copy content
  </button>
  ```

  The combination of `dispatch/1` with `window.addEventListener` is
  a powerful mechanism to increase the amount of actions you can trigger
  client-side from your LiveView code.

  You can also use `window.addEventListener` to listen to events pushed
  from the server. You can learn more in our [JS interoperability guide](js-interop.md).
  '''
  alias Phoenix.LiveView.JS

  defstruct ops: []

  @opaque internal :: []
  @type t :: %__MODULE__{ops: internal}

  @default_transition_time 200

  defimpl Phoenix.HTML.Safe, for: Phoenix.LiveView.JS do
    def to_iodata(%Phoenix.LiveView.JS{} = js) do
      Phoenix.HTML.Engine.html_escape(Phoenix.json_library().encode!(js.ops))
    end
  end

  @doc """
  Pushes an event to the server.

    * `event` - The string event name to push.

  ## Options

    * `:target` - A selector or component ID to push to. This value will
      overwrite any `phx-target` attribute present on the element.
    * `:loading` - A selector to apply the phx loading classes to,
      such as `phx-click-loading` in case the event was triggered by
      `phx-click`. The element will be locked from server updates
      until the push is acknowledged by the server.
    * `:page_loading` - Boolean to trigger the phx:page-loading-start and
      phx:page-loading-stop events for this push. Defaults to `false`.
    * `:value` - A map of values to send to the server. These values will be
      merged over any `phx-value-*` attributes that are present on the element.
      All keys will be treated as strings when merging. When used on a form event
      like `phx-change` or `phx-submit`, the precedence is
      `JS.push value > phx-value-* > input value`.

  ## Examples

  ```heex
  <button phx-click={JS.push("clicked")}>click me!</button>
  <button phx-click={JS.push("clicked", value: %{id: @id})}>click me!</button>
  <button phx-click={JS.push("clicked", page_loading: true)}>click me!</button>
  ```
  """
  def push(event) when is_binary(event) do
    push(%JS{}, event, [])
  end

  @doc "See `push/1`."
  def push(event, opts) when is_binary(event) and is_list(opts) do
    push(%JS{}, event, opts)
  end

  def push(%JS{} = js, event) when is_binary(event) do
    push(js, event, [])
  end

  @doc "See `push/1`."
  def push(%JS{} = js, event, opts) when is_binary(event) and is_list(opts) do
    opts =
      opts
      |> validate_keys(:push, [:target, :loading, :page_loading, :value])
      |> put_target()
      |> put_value()

    put_op(js, "push", Keyword.put(opts, :event, event))
  end

  @doc """
  Dispatches an event to the DOM.

    * `event` - The string event name to dispatch.

  *Note*: All events dispatched are of a type
  [CustomEvent](https://developer.mozilla.org/en-US/docs/Web/API/CustomEvent),
  with the exception of `"click"`. For a `"click"`, a
  [MouseEvent](https://developer.mozilla.org/en-US/docs/Web/API/MouseEvent)
  is dispatched to properly simulate a UI click.

  For emitted `CustomEvent`'s, the event detail will contain a `dispatcher`,
  which references the DOM node that dispatched the JS event to the target
  element.

  ## Options

    * `:to` - An optional DOM selector to dispatch the event to.
      Defaults to the interacted element. See the `DOM selectors`
      section for details.
    * `:detail` - An optional detail map to dispatch along
      with the client event. The details will be available in the
      `event.detail` attribute for event listeners.
    * `:bubbles` – A boolean flag to bubble the event or not. Defaults to `true`.
    * `:blocking` - A boolean flag to block the UI until the event handler calls `event.detail.done()`.
      The done function is injected by LiveView and *must* be called eventually to unblock the UI.
      This is useful to integrate with third party JavaScript based animation libraries.

  ## Examples

  ```javascript
  window.addEventListener("click", e => console.log("clicked!", e.detail))
  ```

  ```heex
  <button phx-click={JS.dispatch("click", to: ".nav")}>Click me!</button>
  ```
  """
  def dispatch(js \\ %JS{}, event)
  def dispatch(%JS{} = js, event), do: dispatch(js, event, [])
  def dispatch(event, opts), do: dispatch(%JS{}, event, opts)

  @doc "See `dispatch/2`."
  def dispatch(%JS{} = js, event, opts) do
    opts = validate_keys(opts, :dispatch, [:to, :detail, :bubbles, :blocking])
    args = [event: event, to: opts[:to]]

    args =
      case Keyword.fetch(opts, :bubbles) do
        {:ok, val} when is_boolean(val) ->
          Keyword.put(args, :bubbles, val)

        {:ok, other} ->
          raise ArgumentError, "expected :bubbles to be a boolean, got: #{inspect(other)}"

        :error ->
          args
      end

    if opts[:blocking] do
      case opts[:detail] do
        map when is_map(map) and (is_map_key(map, "done") or is_map_key(map, :done)) ->
          raise ArgumentError, """
          the detail map passed to JS.dispatch must not contain a `done` key
          when `blocking: true` is used!

          Got: #{inspect(map)}
          """

        _ ->
          :ok
      end
    end

    args =
      case {event, Keyword.fetch(opts, :detail)} do
        {"click", {:ok, _detail}} ->
          raise ArgumentError, """
          click events cannot be dispatched with details.

          The browser rewrites `MouseEvent` details to an integer. If you would like to
          handle a click event with custom details, dispatch your own proxy event, read the
          details, then trigger the click, for example:

              JS.dispatch("myapp:click", detail: %{...})
              window.addEventListener("myapp:click", e => {
                console.log("details", e.detail)
                e.target.click() // forward click event
              })
          """

        {_, {:ok, detail}} ->
          Keyword.put(args, :detail, detail)

        {_, :error} ->
          args
      end

    args =
      case Keyword.get(opts, :blocking) do
        true ->
          Keyword.put(args, :blocking, opts[:blocking])

        _ ->
          args
      end

    put_op(js, "dispatch", args)
  end

  @doc """
  Toggles element visibility.

  ## Options

    * `:to` - An optional DOM selector to toggle.
      Defaults to the interacted element. See the `DOM selectors`
      section for details.
    * `:in` - A string of classes to apply when toggling in, or
      a 3-tuple containing the transition class, the class to apply
      to start the transition, and the ending transition class, such as:
      `{"ease-out duration-300", "opacity-0", "opacity-100"}`
    * `:out` - A string of classes to apply when toggling out, or
      a 3-tuple containing the transition class, the class to apply
      to start the transition, and the ending transition class, such as:
      `{"ease-out duration-300", "opacity-100", "opacity-0"}`
    * `:time` - The time in milliseconds to apply the transition `:in` and `:out` classes.
      Defaults to #{@default_transition_time}.
    * `:display` - An optional display value to set when toggling in. Defaults
      to `"block"`.
    * `:blocking` - A boolean flag to block the UI during the transition. Defaults `true`.

  When the toggle is complete on the client, a `phx:show-start` or `phx:hide-start`, and
  `phx:show-end` or `phx:hide-end` event will be dispatched to the toggled elements.

  ## Examples

  ```heex
  <div id="item">My Item</div>

  <button phx-click={JS.toggle(to: "#item")}>
    toggle item!
  </button>

  <button phx-click={JS.toggle(to: "#item", in: "fade-in-scale", out: "fade-out-scale")}>
    toggle fancy!
  </button>
  ```
  """
  def toggle(opts \\ [])
  def toggle(%JS{} = js), do: toggle(js, [])
  def toggle(opts) when is_list(opts), do: toggle(%JS{}, opts)

  @doc "See `toggle/1`."
  def toggle(js, opts) when is_list(opts) do
    opts = validate_keys(opts, :toggle, [:to, :in, :out, :display, :time, :blocking])
    in_classes = transition_class_names(opts[:in])
    out_classes = transition_class_names(opts[:out])
    time = opts[:time]

    put_op(js, "toggle",
      to: opts[:to],
      display: opts[:display],
      ins: in_classes,
      outs: out_classes,
      time: time,
      blocking: opts[:blocking]
    )
  end

  @doc """
  Shows elements.

  *Note*: Only targets elements that are hidden, meaning they have a height and/or width equal to zero.

  ## Options

    * `:to` - An optional DOM selector to show.
      Defaults to the interacted element. See the `DOM selectors`
      section for details.
    * `:transition` - A string of classes to apply before showing or
      a 3-tuple containing the transition class, the class to apply
      to start the transition, and the ending transition class, such as:
      `{"ease-out duration-300", "opacity-0", "opacity-100"}`
    * `:time` - The time in milliseconds to apply the transition from `:transition`.
      Defaults to #{@default_transition_time}.
    * `:blocking` - A boolean flag to block the UI during the transition. Defaults `true`.
    * `:display` - An optional display value to set when showing. Defaults to `"block"`.

  During the process, the following events will be dispatched to the shown elements:

    * When the action is triggered on the client, `phx:show-start` is dispatched.
    * After the time specified by `:time`, `phx:show-end` is dispatched.

  ## Examples

  ```heex
  <div id="item">My Item</div>

  <button phx-click={JS.show(to: "#item")}>
    show!
  </button>

  <button phx-click={JS.show(to: "#item", transition: "fade-in-scale")}>
    show fancy!
  </button>
  ```
  """
  def show(opts \\ [])
  def show(%JS{} = js), do: show(js, [])
  def show(opts) when is_list(opts), do: show(%JS{}, opts)

  @doc "See `show/1`."
  def show(js, opts) when is_list(opts) do
    opts = validate_keys(opts, :show, [:to, :transition, :display, :time, :blocking])
    transition = transition_class_names(opts[:transition])
    time = opts[:time]

    put_op(js, "show",
      to: opts[:to],
      display: opts[:display],
      transition: transition,
      time: time,
      blocking: opts[:blocking]
    )
  end

  @doc """
  Hides elements.

  *Note*: Only targets elements that are visible, meaning they have a height and/or width greater than zero.

  ## Options

    * `:to` - An optional DOM selector to hide.
      Defaults to the interacted element. See the `DOM selectors`
      section for details.
    * `:transition` - A string of classes to apply before hiding or
      a 3-tuple containing the transition class, the class to apply
      to start the transition, and the ending transition class, such as:
      `{"ease-out duration-300", "opacity-100", "opacity-0"}`
    * `:time` - The time in milliseconds to apply the transition from `:transition`.
      Defaults to #{@default_transition_time}.
    * `:blocking` - A boolean flag to block the UI during the transition. Defaults `true`.

  During the process, the following events will be dispatched to the hidden elements:

    * When the action is triggered on the client, `phx:hide-start` is dispatched.
    * After the time specified by `:time`, `phx:hide-end` is dispatched.

  ## Examples

  ```heex
  <div id="item">My Item</div>

  <button phx-click={JS.hide(to: "#item")}>
    hide!
  </button>

  <button phx-click={JS.hide(to: "#item", transition: "fade-out-scale")}>
    hide fancy!
  </button>
  ```
  """
  def hide(opts \\ [])
  def hide(%JS{} = js), do: hide(js, [])
  def hide(opts) when is_list(opts), do: hide(%JS{}, opts)

  @doc "See `hide/1`."
  def hide(js, opts) when is_list(opts) do
    opts = validate_keys(opts, :hide, [:to, :transition, :time, :blocking])
    transition = transition_class_names(opts[:transition])
    time = opts[:time]

    put_op(js, "hide",
      to: opts[:to],
      transition: transition,
      time: time,
      blocking: opts[:blocking]
    )
  end

  @doc """
  Adds classes to elements.

    * `names` - A string with one or more class names to add.

  ## Options

    * `:to` - An optional DOM selector to add classes to.
      Defaults to the interacted element. See the `DOM selectors`
      section for details.
    * `:transition` - A string of classes to apply before adding classes or
      a 3-tuple containing the transition class, the class to apply
      to start the transition, and the ending transition class, such as:
      `{"ease-out duration-300", "opacity-0", "opacity-100"}`
    * `:time` - The time in milliseconds to apply the transition from `:transition`.
      Defaults to #{@default_transition_time}.
    * `:blocking` - A boolean flag to block the UI during the transition. Defaults `true`.

  ## Examples

  ```heex
  <div id="item">My Item</div>
  <button phx-click={JS.add_class("highlight underline", to: "#item")}>
    highlight!
  </button>
  ```
  """
  def add_class(names) when is_binary(names), do: add_class(%JS{}, names, [])

  @doc "See `add_class/1`."
  def add_class(%JS{} = js, names) when is_binary(names) do
    add_class(js, names, [])
  end

  def add_class(names, opts) when is_binary(names) and is_list(opts) do
    add_class(%JS{}, names, opts)
  end

  @doc "See `add_class/1`."
  def add_class(%JS{} = js, names, opts) when is_binary(names) and is_list(opts) do
    opts = validate_keys(opts, :add_class, [:to, :transition, :time, :blocking])
    time = opts[:time]

    put_op(js, "add_class",
      to: opts[:to],
      names: class_names(names),
      transition: transition_class_names(opts[:transition]),
      time: time,
      blocking: opts[:blocking]
    )
  end

  @doc """
  Adds or removes element classes based on presence.

    * `names` - A string with one or more class names to toggle.

  ## Options

    * `:to` - An optional DOM selector to target.
      Defaults to the interacted element. See the `DOM selectors`
      section for details.
    * `:transition` - A string of classes to apply before adding classes or
      a 3-tuple containing the transition class, the class to apply
      to start the transition, and the ending transition class, such as:
      `{"ease-out duration-300", "opacity-0", "opacity-100"}`
    * `:time` - The time in milliseconds to apply the transition from `:transition`.
      Defaults to #{@default_transition_time}.
    * `:blocking` - A boolean flag to block the UI during the transition. Defaults `true`.

  ## Examples

  ```heex
  <div id="item">My Item</div>
  <button phx-click={JS.toggle_class("active", to: "#item")}>
    toggle active!
  </button>
  ```
  """
  def toggle_class(names) when is_binary(names), do: toggle_class(%JS{}, names, [])

  def toggle_class(%JS{} = js, names) when is_binary(names) do
    toggle_class(js, names, [])
  end

  def toggle_class(names, opts) when is_binary(names) and is_list(opts) do
    toggle_class(%JS{}, names, opts)
  end

  def toggle_class(%JS{} = js, names, opts) when is_binary(names) and is_list(opts) do
    opts = validate_keys(opts, :toggle_class, [:to, :transition, :time, :blocking])
    time = opts[:time]

    put_op(js, "toggle_class",
      to: opts[:to],
      names: class_names(names),
      transition: transition_class_names(opts[:transition]),
      time: time,
      blocking: opts[:blocking]
    )
  end

  @doc """
  Removes classes from elements.

    * `names` - A string with one or more class names to remove.

  ## Options

    * `:to` - An optional DOM selector to remove classes from.
      Defaults to the interacted element. See the `DOM selectors`
      section for details.
    * `:transition` - A string of classes to apply before removing classes or
      a 3-tuple containing the transition class, the class to apply
      to start the transition, and the ending transition class, such as:
      `{"ease-out duration-300", "opacity-0", "opacity-100"}`
    * `:time` - The time in milliseconds to apply the transition from `:transition`.
      Defaults to #{@default_transition_time}.
    * `:blocking` - A boolean flag to block the UI during the transition. Defaults `true`.

  ## Examples

  ```heex
  <div id="item">My Item</div>
  <button phx-click={JS.remove_class("highlight underline", to: "#item")}>
    remove highlight!
  </button>
  ```
  """
  def remove_class(names) when is_binary(names), do: remove_class(%JS{}, names, [])

  @doc "See `remove_class/1`."
  def remove_class(%JS{} = js, names) when is_binary(names) do
    remove_class(js, names, [])
  end

  def remove_class(names, opts) when is_binary(names) and is_list(opts) do
    remove_class(%JS{}, names, opts)
  end

  @doc "See `remove_class/1`."
  def remove_class(%JS{} = js, names, opts) when is_binary(names) and is_list(opts) do
    opts = validate_keys(opts, :remove_class, [:to, :transition, :time, :blocking])
    time = opts[:time]

    put_op(js, "remove_class",
      to: opts[:to],
      names: class_names(names),
      transition: transition_class_names(opts[:transition]),
      time: time,
      blocking: opts[:blocking]
    )
  end

  @doc """
  Transitions elements.

    * `transition` - A string of classes to apply during the transition or
      a 3-tuple containing the transition class, the class to apply
      to start the transition, and the ending transition class, such as:
      `{"ease-out duration-300", "opacity-0", "opacity-100"}`

  Transitions are useful for temporarily adding an animation class
  to elements, such as for highlighting content changes.

  ## Options

    * `:to` - An optional DOM selector to apply transitions to.
      Defaults to the interacted element. See the `DOM selectors`
      section for details.
    * `:time` - The time in milliseconds to apply the transition from `:transition`.
      Defaults to #{@default_transition_time}.
    * `:blocking` - A boolean flag to block the UI during the transition. Defaults `true`.

  ## Examples

  ```heex
  <div id="item">My Item</div>
  <button phx-click={JS.transition("shake", to: "#item")}>Shake!</button>

  <div phx-mounted={JS.transition({"ease-out duration-300", "opacity-0", "opacity-100"}, time: 300)}>
      duration-300 milliseconds matches time: 300 milliseconds
  </div>
  ```
  """
  def transition(transition) when is_binary(transition) or is_tuple(transition) do
    transition(%JS{}, transition, [])
  end

  @doc "See `transition/1`."
  def transition(transition, opts)
      when (is_binary(transition) or is_tuple(transition)) and is_list(opts) do
    transition(%JS{}, transition, opts)
  end

  def transition(%JS{} = js, transition) when is_binary(transition) or is_tuple(transition) do
    transition(js, transition, [])
  end

  @doc "See `transition/1`."
  def transition(%JS{} = js, transition, opts)
      when (is_binary(transition) or is_tuple(transition)) and is_list(opts) do
    opts = validate_keys(opts, :transition, [:to, :time, :blocking])
    time = opts[:time]

    put_op(js, "transition",
      time: time,
      to: opts[:to],
      transition: transition_class_names(transition),
      blocking: opts[:blocking]
    )
  end

  @doc """
  Sets an attribute on elements.

  Accepts a tuple containing the string attribute name/value pair.

  ## Options

    * `:to` - An optional DOM selector to add attributes to.
      Defaults to the interacted element. See the `DOM selectors`
      section for details.

  ## Examples

  ```heex
  <button phx-click={JS.set_attribute({"aria-expanded", "true"}, to: "#dropdown")}>
    show
  </button>
  ```
  """
  def set_attribute({attr, val}), do: set_attribute(%JS{}, {attr, val}, [])

  @doc "See `set_attribute/1`."
  def set_attribute({attr, val}, opts) when is_list(opts),
    do: set_attribute(%JS{}, {attr, val}, opts)

  def set_attribute(%JS{} = js, {attr, val}), do: set_attribute(js, {attr, val}, [])

  @doc "See `set_attribute/1`."
  def set_attribute(%JS{} = js, {attr, val}, opts) when is_list(opts) do
    opts = validate_keys(opts, :set_attribute, [:to])
    put_op(js, "set_attr", to: opts[:to], attr: [attr, val])
  end

  @doc """
  Removes an attribute from elements.

    * `attr` - The string attribute name to remove.

  ## Options

    * `:to` - An optional DOM selector to remove attributes from.
      Defaults to the interacted element. See the `DOM selectors`
      section for details.

  ## Examples

  ```heex
  <button phx-click={JS.remove_attribute("aria-expanded", to: "#dropdown")}>
    hide
  </button>
  ```
  """
  def remove_attribute(attr), do: remove_attribute(%JS{}, attr, [])

  @doc "See `remove_attribute/1`."
  def remove_attribute(attr, opts) when is_list(opts),
    do: remove_attribute(%JS{}, attr, opts)

  def remove_attribute(%JS{} = js, attr), do: remove_attribute(js, attr, [])

  @doc "See `remove_attribute/1`."
  def remove_attribute(%JS{} = js, attr, opts) when is_list(opts) do
    opts = validate_keys(opts, :remove_attribute, [:to])
    put_op(js, "remove_attr", to: opts[:to], attr: attr)
  end

  @doc """
  Sets or removes element attribute based on attribute presence.

  Accepts a two or three-element tuple:

  * `{attr, val}` - Sets the attribute to the given value or removes it
  * `{attr, val1, val2}` - Toggles the attribute between `val1` and `val2`

  ## Options

    * `:to` - An optional DOM selector to set or remove attributes from.
      Defaults to the interacted element. See the `DOM selectors`
      section for details.

  ## Examples

  ```heex
  <button phx-click={JS.toggle_attribute({"aria-expanded", "true", "false"}, to: "#dropdown")}>
    toggle
  </button>

  <button phx-click={JS.toggle_attribute({"open", "true"}, to: "#dialog")}>
    toggle
  </button>
  ```

  """
  def toggle_attribute({attr, val}), do: toggle_attribute(%JS{}, {attr, val}, [])
  def toggle_attribute({attr, val1, val2}), do: toggle_attribute(%JS{}, {attr, val1, val2}, [])

  @doc "See `toggle_attribute/1`."
  def toggle_attribute({attr, val}, opts) when is_list(opts),
    do: toggle_attribute(%JS{}, {attr, val}, opts)

  def toggle_attribute({attr, val1, val2}, opts) when is_list(opts),
    do: toggle_attribute(%JS{}, {attr, val1, val2}, opts)

  def toggle_attribute(%JS{} = js, {attr, val}), do: toggle_attribute(js, {attr, val}, [])

  def toggle_attribute(%JS{} = js, {attr, val1, val2}),
    do: toggle_attribute(js, {attr, val1, val2}, [])

  @doc "See `toggle_attribute/1`."
  def toggle_attribute(%JS{} = js, {attr, val}, opts) when is_list(opts) do
    opts = validate_keys(opts, :toggle_attribute, [:to])
    put_op(js, "toggle_attr", to: opts[:to], attr: [attr, val])
  end

  def toggle_attribute(%JS{} = js, {attr, val1, val2}, opts) when is_list(opts) do
    opts = validate_keys(opts, :toggle_attribute, [:to])
    put_op(js, "toggle_attr", to: opts[:to], attr: [attr, val1, val2])
  end

  @doc """
  Sends focus to a selector.

  ## Options

    * `:to` - An optional DOM selector to send focus to.
      Defaults to the interacted element. See the `DOM selectors`
      section for details.

  ## Examples

      JS.focus(to: "main")
  """
  def focus(opts \\ [])
  def focus(%JS{} = js), do: focus(js, [])
  def focus(opts) when is_list(opts), do: focus(%JS{}, opts)

  @doc "See `focus/1`."
  def focus(%JS{} = js, opts) when is_list(opts) do
    opts = validate_keys(opts, :focus, [:to])
    put_op(js, "focus", to: opts[:to])
  end

  @doc """
  Sends focus to the first focusable child in selector.

  ## Options

    * `:to` - An optional DOM selector to focus.
      Defaults to the interacted element. See the `DOM selectors`
      section for details.

  ## Examples

      JS.focus_first(to: "#modal")
  """
  def focus_first(opts \\ [])
  def focus_first(%JS{} = js), do: focus_first(js, [])
  def focus_first(opts) when is_list(opts), do: focus_first(%JS{}, opts)

  @doc "See `focus_first/1`."
  def focus_first(%JS{} = js, opts) when is_list(opts) do
    opts = validate_keys(opts, :focus_first, [:to])
    put_op(js, "focus_first", to: opts[:to])
  end

  @doc """
  Pushes focus from the source element to be later popped.

  ## Options

    * `:to` - An optional DOM selector to push focus to.
      Defaults to the interacted element. See the `DOM selectors`
      section for details.

  ## Examples

      JS.push_focus()
      JS.push_focus(to: "#my-button")
  """
  def push_focus(opts \\ [])
  def push_focus(%JS{} = js), do: push_focus(js, [])
  def push_focus(opts) when is_list(opts), do: push_focus(%JS{}, opts)

  @doc "See `push_focus/1`."
  def push_focus(%JS{} = js, opts) when is_list(opts) do
    opts = validate_keys(opts, :push_focus, [:to])
    put_op(js, "push_focus", to: opts[:to])
  end

  @doc """
  Focuses the last pushed element.

  ## Examples

      JS.pop_focus()
  """
  def pop_focus(%JS{} = js \\ %JS{}) do
    put_op(js, "pop_focus", [])
  end

  @doc """
  Sends a navigation event to the server and updates the browser's pushState history.

  ## Options

    * `:replace` - Whether to replace the browser's pushState history. Defaults to `false`.

  ## Examples

      JS.navigate("/my-path")
  """
  def navigate(href) when is_binary(href) do
    navigate(%JS{}, href, [])
  end

  @doc "See `navigate/1`."
  def navigate(href, opts) when is_binary(href) and is_list(opts) do
    navigate(%JS{}, href, opts)
  end

  def navigate(%JS{} = js, href) when is_binary(href) do
    navigate(js, href, [])
  end

  @doc "See `navigate/1`."
  def navigate(%JS{} = js, href, opts) when is_binary(href) and is_list(opts) do
    opts = validate_keys(opts, :navigate, [:replace])
    put_op(js, "navigate", href: href, replace: !!opts[:replace])
  end

  @doc """
  Sends a patch event to the server and updates the browser's pushState history.

  ## Options

    * `:replace` - Whether to replace the browser's pushState history. Defaults to `false`.

  ## Examples

      JS.patch("/my-path")
  """
  def patch(href) when is_binary(href) do
    patch(%JS{}, href, [])
  end

  @doc "See `patch/1`."
  def patch(href, opts) when is_binary(href) and is_list(opts) do
    patch(%JS{}, href, opts)
  end

  def patch(%JS{} = js, href) when is_binary(href) do
    patch(js, href, [])
  end

  @doc "See `patch/1`."
  def patch(%JS{} = js, href, opts) when is_binary(href) and is_list(opts) do
    opts = validate_keys(opts, :patch, [:replace])
    put_op(js, "patch", href: href, replace: !!opts[:replace])
  end

  @doc """
  Executes JS commands located in an element's attribute.

    * `attr` - The string attribute where the JS command is specified

  ## Options

    * `:to` - An optional DOM selector to fetch the attribute from.
      Defaults to the interacted element. See the `DOM selectors`
      section for details.

  ## Examples

  ```heex
  <div id="modal" phx-remove={JS.hide("#modal")}>...</div>
  <button phx-click={JS.exec("phx-remove", to: "#modal")}>close</button>
  ```
  """
  def exec(attr) when is_binary(attr) do
    exec(%JS{}, attr, [])
  end

  @doc "See `exec/1`."
  def exec(attr, opts) when is_binary(attr) and is_list(opts) do
    exec(%JS{}, attr, opts)
  end

  def exec(%JS{} = js, attr) when is_binary(attr) do
    exec(js, attr, [])
  end

  @doc "See `exec/1`."
  def exec(%JS{} = js, attr, opts) when is_binary(attr) and is_list(opts) do
    opts = validate_keys(opts, :exec, [:to])
    put_op(js, "exec", attr: attr, to: opts[:to])
  end

  @doc """
  Combines two JS commands, appending the second to the first.
  """
  def concat(%JS{ops: first}, %JS{ops: second}), do: %JS{ops: first ++ second}

  defp put_op(%JS{ops: ops} = js, kind, args) do
    args = drop_nil_values(args)
    struct!(js, ops: ops ++ [[kind, args]])
  end

  defp drop_nil_values(args) when is_list(args) do
    Enum.reject(args, fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp class_names(nil), do: []

  defp class_names(names) do
    String.split(names, " ", trim: true)
  end

  defp transition_class_names(nil), do: nil

  defp transition_class_names(transition) when is_binary(transition),
    do: [class_names(transition), [], []]

  defp transition_class_names({transition, tstart, tend})
       when is_binary(tstart) and is_binary(transition) and is_binary(tend) do
    [class_names(transition), class_names(tstart), class_names(tend)]
  end

  defp validate_keys(opts, kind, allowed_keys) do
    Enum.map(opts, fn
      {:to, {scope, _selector}} when scope not in [:closest, :inner, :document] ->
        raise ArgumentError, """
        invalid scope for :to option in #{kind}.
        Valid scopes are :closest, :inner, :document. Got: #{inspect(scope)}
        """

      {:to, {:document, selector}} ->
        {:to, selector}

      {:to, {scope, selector}} ->
        {:to, %{scope => selector}}

      {:to, selector} when is_binary(selector) ->
        {:to, selector}

      {key, val} ->
        if key not in allowed_keys do
          raise ArgumentError, """
          invalid option for #{kind}
          Expected keys to be one of #{inspect(allowed_keys)}, got: #{inspect(key)}
          """
        end

        {key, val}
    end)
  end

  defp put_value(opts) do
    case Keyword.fetch(opts, :value) do
      {:ok, val} when is_map(val) -> Keyword.put(opts, :value, val)
      {:ok, val} -> raise ArgumentError, "push :value expected to be a map, got: #{inspect(val)}"
      :error -> opts
    end
  end

  defp put_target(opts) do
    case Keyword.fetch(opts, :target) do
      {:ok, %Phoenix.LiveComponent.CID{cid: cid}} -> Keyword.put(opts, :target, cid)
      {:ok, selector} -> Keyword.put(opts, :target, selector)
      :error -> opts
    end
  end
end
