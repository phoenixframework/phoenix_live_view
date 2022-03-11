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
    * `set_attribute` - Set an attribute on elements
    * `remove_attribute` - Remove an attribute from elements
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
            <p><%= @text %></p>
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

      <div phx-click="inc">+</div>

  Imagine you need to target your current component, and apply a loading state
  to the parent container while the client awaits the server acknowledgement:

      alias Phoenix.LiveView.JS

      <div phx-click={JS.push("inc", loading: ".thermo", target: @myself)}>+</div>

  Push commands also compose with all other utilities. For example,
  to add a class when pushing:

      <div phx-click={
        JS.push("inc", loading: ".thermo", target: @myself)
        |> JS.add_class(".warmer", to: ".thermo")
      }>+</div>

  ## Custom JS events with `JS.dispatch/1` and `window.addEventListener`

  `dispatch/1` can be used to dispatch custom JavaScript events to
  elements. For example, you can use `JS.dispatch("click", to: "#foo")`,
  to dispatch a click event to an element.

  This also means you can augment your elements with custom events,
  by using JavaScript's `window.addEventListener` and invoking them
  with `dispatch/1`. For example, imagine you want to provide
  a copy-to-clipboard functionality in your application. You can
  add a custom event for it:

      window.addEventListener("my_app:clipcopy", (event) => {
        if ("clipboard" in navigator) {
          const text = event.target.textContent;
          navigator.clipboard.writeText(text);
        } else {
          alert("Sorry, your browser does not support clipboard copy.");
        }
      });

  Now you can have a button like this:

      <button phx-click={JS.dispatch("my_app:clipcopy", to: "#element-with-text-to-copy")}>
        Copy content
      </button>

  The combination of `dispatch/1` with `window.addEventListener` is
  a powerful mechanism to increase the amount of actions you can trigger
  client-side from your LiveView code.
  '''
  alias Phoenix.LiveView.JS

  defstruct ops: []

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

    * `:target` - The selector or component ID to push to
    * `:loading` - The selector to apply the phx loading classes to
    * `:page_loading` - Boolean to trigger the phx:page-loading-start and
      phx:page-loading-stop events for this push. Defaults to `false`
    * `:value` - The map of values to send to the server

  ## Examples

      <button phx-click={JS.push("clicked")}>click me!</button>
      <button phx-click={JS.push("clicked", value: %{id: @id})}>click me!</button>
      <button phx-click={JS.push("clicked", page_loading: true)}>click me!</button>
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

    put_op(js, "push", Enum.into(opts, %{event: event}))
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

    * `:to` - The optional DOM selector to dispatch the event to.
      Defaults to the interacted element.
    * `:detail` - The optional detail map to dispatch along
      with the client event. The details will be available in the
      `event.detail` attribute for event listeners.
    * `:bubbles` – The boolean flag to bubble the event or not. Default `true`.

  ## Examples

      window.addEventListener("click", e => console.log("clicked!", e.detail))

      <button phx-click={JS.dispatch("click", to: ".nav")}>Click me!</button>
  """
  def dispatch(js \\ %JS{}, event)
  def dispatch(%JS{} = js, event), do: dispatch(js, event, [])
  def dispatch(event, opts), do: dispatch(%JS{}, event, opts)

  @doc "See `dispatch/2`."
  def dispatch(%JS{} = js, event, opts) do
    opts = validate_keys(opts, :dispatch, [:to, :detail, :bubbles])
    args = %{event: event, to: opts[:to]}

    args =
      case Keyword.fetch(opts, :bubbles) do
        {:ok, val} when is_boolean(val) ->
          Map.put(args, :bubbles, val)

        {:ok, other} ->
          raise ArgumentError, "expected :bubbles to be a boolean, got: #{inspect(other)}"

        :error ->
          args
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
          Map.put(args, :detail, detail)

        {_, :error} ->
          args
      end

    put_op(js, "dispatch", args)
  end

  @doc """
  Toggles elements.

  ## Options

    * `:to` - The optional DOM selector to toggle.
      Defaults to the interacted element.
    * `:in` - The string of classes to apply when toggling in, or
      a 3-tuple containing the transition class, the class to apply
      to start the transition, and the ending transition class, such as:
      `{"ease-out duration-300", "opacity-0", "opacity-100"}`
    * `:out` - The string of classes to apply when toggling out, or
      a 3-tuple containing the transition class, the class to apply
      to start the transition, and the ending transition class, such as:
      `{"ease-out duration-300", "opacity-100", "opacity-0"}`
    * `:time` - The time to apply the transition `:in` and `:out` classes.
      Defaults #{@default_transition_time}
    * `:display` - The optional display value to set when toggling in. Defaults `"block"`.

  When the toggle is complete on the client, a `phx:show-start` or `phx:hide-start`, and
  `phx:show-end` or `phx:hide-end` event will be dispatched to the toggled elements.

  ## Examples

      <div id="item">My Item</div>

      <button phx-click={JS.toggle(to: "#item")}>
        toggle item!
      </button>

      <button phx-click={JS.toggle(to: "#item", in: "fade-in-scale", out: "fade-out-scale")}>
        toggle fancy!
      </button>
  """
  def toggle(opts \\ [])
  def toggle(%JS{} = js), do: toggle(js, [])
  def toggle(opts) when is_list(opts), do: toggle(%JS{}, opts)

  @doc "See `toggle/1`."
  def toggle(js, opts) when is_list(opts) do
    opts = validate_keys(opts, :toggle, [:to, :in, :out, :display, :time])
    in_classes = transition_class_names(opts[:in])
    out_classes = transition_class_names(opts[:out])
    time = opts[:time] || @default_transition_time

    put_op(js, "toggle", %{
      to: opts[:to],
      display: opts[:display],
      ins: in_classes,
      outs: out_classes,
      time: time
    })
  end

  @doc """
  Shows elements.

  ## Options

    * `:to` - The optional DOM selector to show.
      Defaults to the interacted element.
    * `:transition` - The string of classes to apply before showing or
      a 3-tuple containing the transition class, the class to apply
      to start the transition, and the ending transition class, such as:
      `{"ease-out duration-300", "opacity-0", "opacity-100"}`
    * `:time` - The time to apply the transition from `:transition`.
      Defaults #{@default_transition_time}
    * `:display` - The optional display value to set when showing. Defaults `"block"`.

  When the show is complete on the client, a `phx:show-start` and `phx:show-end` event
  will be dispatched to the shown elements.

  ## Examples

      <div id="item">My Item</div>

      <button phx-click={JS.show(to: "#item")}>
        show!
      </button>

      <button phx-click={JS.show(to: "#item", transition: "fade-in-scale")}>
        show fancy!
      </button>
  """
  def show(opts \\ [])
  def show(%JS{} = js), do: show(js, [])
  def show(opts) when is_list(opts), do: show(%JS{}, opts)

  @doc "See `show/1`."
  def show(js, opts) when is_list(opts) do
    opts = validate_keys(opts, :show, [:to, :transition, :display, :time])
    transition = transition_class_names(opts[:transition])
    time = opts[:time] || @default_transition_time

    put_op(js, "show", %{
      to: opts[:to],
      display: opts[:display],
      transition: transition,
      time: time
    })
  end

  @doc """
  Hides elements.

  ## Options

    * `:to` - The optional DOM selector to hide.
      Defaults to the interacted element.
    * `:transition` - The string of classes to apply before hiding or
      a 3-tuple containing the transition class, the class to apply
      to start the transition, and the ending transition class, such as:
      `{"ease-out duration-300", "opacity-0", "opacity-100"}`
    * `:time` - The time to apply the transition from `:transition`.
      Defaults #{@default_transition_time}

  When the show is complete on the client, a `phx:hide-start` and `phx:hide-end`
  event will be dispatched to the hidden elements.

  ## Examples

      <div id="item">My Item</div>

      <button phx-click={JS.hide(to: "#item")}>
        hide!
      </button>

      <button phx-click={JS.hide(to: "#item", transition: "fade-out-scale")}>
        hide fancy!
      </button>
  """
  def hide(opts \\ [])
  def hide(%JS{} = js), do: hide(js, [])
  def hide(opts) when is_list(opts), do: hide(%JS{}, opts)

  @doc "See `hide/1`."
  def hide(js, opts) when is_list(opts) do
    opts = validate_keys(opts, :hide, [:to, :transition, :time])
    transition = transition_class_names(opts[:transition])
    time = opts[:time] || @default_transition_time

    put_op(js, "hide", %{
      to: opts[:to],
      transition: transition,
      time: time
    })
  end

  @doc """
  Adds classes to elements.

    * `names` - The string of classes to add.

  ## Options

    * `:to` - The optional DOM selector to add classes to.
      Defaults to the interacted element.
    * `:transition` - The string of classes to apply before adding classes or
      a 3-tuple containing the transition class, the class to apply
      to start the transition, and the ending transition class, such as:
      `{"ease-out duration-300", "opacity-0", "opacity-100"}`
    * `:time` - The time to apply the transition from `:transition`.
      Defaults #{@default_transition_time}

  ## Examples

      <div id="item">My Item</div>
      <button phx-click={JS.add_class("highlight underline", to: "#item")}>
        highlight!
      </button>
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
    opts = validate_keys(opts, :add_class, [:to, :transition, :time])
    time = opts[:time] || @default_transition_time

    put_op(js, "add_class", %{
      to: opts[:to],
      names: class_names(names),
      transition: transition_class_names(opts[:transition]),
      time: time
    })
  end

  @doc """
  Removes classes from elements.

    * `names` - The string of classes to remove.

  ## Options

    * `:to` - The optional DOM selector to remove classes from.
      Defaults to the interacted element.
    * `:transition` - The string of classes to apply before removing classes or
      a 3-tuple containing the transition class, the class to apply
      to start the transition, and the ending transition class, such as:
      `{"ease-out duration-300", "opacity-0", "opacity-100"}`
    * `:time` - The time to apply the transition from `:transition`.
      Defaults #{@default_transition_time}

  ## Examples

      <div id="item">My Item</div>
      <button phx-click={JS.remove_class("highlight underline", to: "#item")}>
        remove highlight!
      </button>
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
    opts = validate_keys(opts, :remove_class, [:to, :transition, :time])
    time = opts[:time] || @default_transition_time

    put_op(js, "remove_class", %{
      to: opts[:to],
      names: class_names(names),
      transition: transition_class_names(opts[:transition]),
      time: time
    })
  end

  @doc """
  Transitions elements.

    * `transition` - The string of classes to apply before removing classes or
      a 3-tuple containing the transition class, the class to apply
      to start the transition, and the ending transition class, such as:
      `{"ease-out duration-300", "opacity-0", "opacity-100"}`

  Transitions are useful for temporarily adding an animation class
  to element(s), such as for highlighting content changes.

  ## Options

    * `:to` - The optional DOM selector to apply transitions to.
      Defaults to the interacted element.
    * `:time` - The time to apply the transition from `:transition`.
      Defaults #{@default_transition_time}

  ## Examples

      <div id="item">My Item</div>
      <button phx-click={JS.transition("shake", to: "#item")}>Shake!</button>
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
    opts = validate_keys(opts, :transition, [:to, :time])
    time = opts[:time] || @default_transition_time

    put_op(js, "transition", %{
      time: time,
      to: opts[:to],
      transition: transition_class_names(transition)
    })
  end

  @doc """
  Sets an attribute on elements.

  Accepts a tuple containing the string attribute name/value pair.

  ## Options

    * `:to` - The optional DOM selector to add attributes to.
      Defaults to the interacted element.

  ## Examples

      <button phx-click={JS.set_attribute({"aria-expanded", "true"}, to: "#dropdown")}>
        show
      </button>
  """
  def set_attribute({attr, val}), do: set_attribute(%JS{}, {attr, val}, [])

  @doc "See `set_attribute/1`."
  def set_attribute({attr, val}, opts) when is_list(opts),
    do: set_attribute(%JS{}, {attr, val}, opts)

  def set_attribute(%JS{} = js, {attr, val}), do: set_attribute(js, {attr, val}, [])

  @doc "See `set_attribute/1`."
  def set_attribute(%JS{} = js, {attr, val}, opts) when is_list(opts) do
    opts = validate_keys(opts, :set_attribute, [:to])
    put_op(js, "set_attr", %{to: opts[:to], attr: [attr, val]})
  end

  @doc """
  Removes an attribute from elements.

    * `attr` - The string attribute name to remove.

  ## Options

    * `:to` - The optional DOM selector to remove attributes from.
      Defaults to the interacted element.

  ## Examples

      <button phx-click={JS.remove_attribute("aria-expanded", to: "#dropdown")}>
        hide
      </button>
  """
  def remove_attribute(attr), do: remove_attribute(%JS{}, attr, [])

  @doc "See `remove_attribute/1`."
  def remove_attribute(attr, opts) when is_list(opts),
    do: remove_attribute(%JS{}, attr, opts)

  def remove_attribute(%JS{} = js, attr), do: remove_attribute(js, attr, [])

  @doc "See `remove_attribute/1`."
  def remove_attribute(%JS{} = js, attr, opts) when is_list(opts) do
    opts = validate_keys(opts, :remove_attribute, [:to])
    put_op(js, "remove_attr", %{to: opts[:to], attr: attr})
  end

  defp put_op(%JS{ops: ops} = js, kind, %{} = args) do
    %JS{js | ops: ops ++ [[kind, args]]}
  end

  defp class_names(nil), do: []

  defp class_names(names) do
    String.split(names, " ")
  end

  defp transition_class_names(nil), do: [[], [], []]

  defp transition_class_names(transition) when is_binary(transition),
    do: [class_names(transition), [], []]

  defp transition_class_names({transition, tstart, tend})
       when is_binary(tstart) and is_binary(transition) and is_binary(tend) do
    [class_names(transition), class_names(tstart), class_names(tend)]
  end

  defp validate_keys(opts, kind, allowed_keys) do
    for key <- Keyword.keys(opts) do
      if key not in allowed_keys do
        raise ArgumentError, """
        invalid option for #{kind}
        Expected keys to be one of #{inspect(allowed_keys)}, got: #{inspect(key)}
        """
      end
    end

    opts
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
