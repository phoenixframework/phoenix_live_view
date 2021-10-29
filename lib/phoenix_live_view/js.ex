defmodule Phoenix.LiveView.JS do
  @moduledoc ~S'''
  Provides commands for executing JavaScript utility operations on the client.

  JS commands support a variety of utility operations for common client-side
  needs, such as adding or removing css classes, showing or hiding content, and transitioning
  in and out with animations. While these operations can be accomplished via
  client-side hooks, JS commands are DOM patch aware, so operations applied
  by the JS APIs will stick to elements across patches from the server.

  In addition to purely client-side utilities, the JS command incluces a
  rich `push` API, for extending the default `phx-` binding pushes with
  options to customize targets, loading states, and additional payload values.

  ## Enhanced Push Events

  The `push/3` command allows you to extend the built-in pushed event handling
  when a `phx-` event is pushed to the server. For example, you may wish to
  target a specific component, specify additional payload values to include
  with the event, apply loading states to external elements, etc. For example,
  given this basic `phx-click` event:

      <div phx-click="inc">+</div>

  Imagine you need to target your current component, and apply a loading state
  to the parent container while the client awaits the server acknowledgement:

      alias Phoenix.LiveView.JS

      <div phx-click={JS.push("inc", loading: ".thermo", target: @myself)}>+</div>

  Push commands also compose with all other utilities. For example, to add
  a class when pushing:

      <div phx-click={
        JS.push("inc", loading: ".thermo", target: @myself)
        |> JS.add_class(".warmer", to: ".thermo")
      }>+</div>

  ## Client Utility Commands

  The following utilities are included:

    * `add_class` - Add classes to elements, with optional transitions
    * `remove_class` - Remove classes from elements, with optional transitions
    * `show` - Show elements, with optional transitions
    * `hide` - Hide elements, with optional transitions
    * `toggle` - Shows or hides elements based on visiblity, with optional transitions
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
  '''
  alias Phoenix.LiveView.JS

  defstruct ops: []

  @default_transition_time 200

  defimpl Phoenix.HTML.Safe, for: Phoenix.LiveView.JS do
    def to_iodata(%Phoenix.LiveView.JS{} = cmd) do
      Phoenix.HTML.Engine.html_escape(Phoenix.json_library().encode!(cmd.ops))
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

  def push(event, opts) when is_binary(event) and is_list(opts) do
    push(%JS{}, event, opts)
  end

  def push(%JS{} = cmd, event) when is_binary(event) do
    push(cmd, event, [])
  end

  def push(%JS{} = cmd, event, opts) when is_binary(event) and is_list(opts) do
    opts =
      opts
      |> validate_keys(:push, [:target, :loading, :page_loading, :value])
      |> put_target()
      |> put_value()

    put_op(cmd, "push", Enum.into(opts, %{event: event}))
  end

  @doc """
  Dispatches an event to the DOM.

    * `event` - The string event name to dispatch.

  ## Options

    * `:to` - The optional DOM selector to dispatch the event to.
      Defaults to the interacted element.
    * `:detail` - The optional detail map to dispatch along
      with the client event. The details will be available in the
      `event.detail` attribute for event listeners.

  ## Examples

      window.addEventListener("click", e => console.log("clicked!", e.detail))

      <button phx-click={JS.dispatch("click", to: ".nav")}>Click me!</button>
  """
  def dispatch(cmd \\ %JS{}, event, opts) do
    opts = validate_keys(opts, :dispatch, [:to, :detail])
    args = %{event: event, to: opts[:to]}

    args =
      case Keyword.fetch(opts, :detail) do
        {:ok, detail} -> Map.put(args, :detail, detail)
        :error -> args
      end

    put_op(cmd, "dispatch", args)
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

  ## Examples

      <div id="item">My Item</div>

      <button phx-click={JS.toggle(to: "#item")}>
        toggle item!
      </button>

      <button phx-click={JS.show(to: "#item", in: "fade-in-scale", out: "fade-out-scale")}>
        toggle fancy!
      </button>
  """
  def toggle(opts \\ [])
  def toggle(%JS{} = cmd), do: toggle(cmd, [])
  def toggle(opts) when is_list(opts), do: toggle(%JS{}, opts)

  def toggle(cmd, opts) when is_list(opts) do
    opts = validate_keys(opts, :toggle, [:to, :in, :out, :display, :time])
    in_classes = transition_class_names(opts[:in])
    out_classes = transition_class_names(opts[:out])
    time = opts[:time] || @default_transition_time

    put_op(cmd, "toggle", %{
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
  def show(%JS{} = cmd), do: show(cmd, [])
  def show(opts) when is_list(opts), do: show(%JS{}, opts)

  def show(cmd, opts) when is_list(opts) do
    opts = validate_keys(opts, :show, [:to, :transition, :display, :time])
    transition = transition_class_names(opts[:transition])
    time = opts[:time] || @default_transition_time

    put_op(cmd, "show", %{
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
  def hide(%JS{} = cmd), do: hide(cmd, [])
  def hide(opts) when is_list(opts), do: hide(%JS{}, opts)

  def hide(cmd, opts) when is_list(opts) do
    opts = validate_keys(opts, :hide, [:to, :transition, :time])
    transition = transition_class_names(opts[:transition])
    time = opts[:time] || @default_transition_time

    put_op(cmd, "hide", %{
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

  def add_class(%JS{} = js, names) when is_binary(names) do
    add_class(js, names, [])
  end

  def add_class(names, opts) when is_binary(names) and is_list(opts) do
    add_class(%JS{}, names, opts)
  end

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

  def remove_class(%JS{} = js, names) when is_binary(names) do
    remove_class(js, names, [])
  end

  def remove_class(names, opts) when is_binary(names) and is_list(opts) do
    remove_class(%JS{}, names, opts)
  end

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

    * `:to` - The optional DOM selector to remove classes from.
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

  def transition(transition, opts) when (is_binary(transition) or is_tuple(transition)) and is_list(opts) do
    transition(%JS{}, transition, opts)
  end

  def transition(%JS{} = cmd, transition) when is_binary(transition) or is_tuple(transition) do
    transition(cmd, transition, [])
  end

  def transition(%JS{} = cmd, transition, opts) when (is_binary(transition) or is_tuple(transition)) and is_list(opts) do
    opts = validate_keys(opts, :transition, [:to, :time])
    time = opts[:time] || @default_transition_time

    put_op(cmd, "transition", %{
      time: time,
      to: opts[:to],
      transition: transition_class_names(transition)
    })
  end

  defp put_op(%JS{ops: ops} = cmd, kind, %{} = args) do
    %JS{cmd | ops: ops ++ [[kind, args]]}
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
