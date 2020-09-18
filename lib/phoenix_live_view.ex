defmodule Phoenix.LiveView do
  @moduledoc ~S'''
  LiveView provides rich, real-time user experiences with
  server-rendered HTML.

  The LiveView programming model is declarative: instead of
  saying "once event X happens, change Y on the page",
  events in LiveView are regular messages which may cause
  changes to its state. Once the state changes, LiveView will
  re-render the relevant parts of its HTML template and push it
  to the browser, which updates itself in the most efficient
  manner. This means developers write LiveView templates as
  any other server-rendered HTML and LiveView does the hard
  work of tracking changes and sending the relevant diffs to
  the browser.

  At the end of the day, a LiveView is nothing more than a
  process that receives events as messages and updates its
  state. The state itself is nothing more than functional
  and immutable Elixir data structures. The events are either
  internal application messages (usually emitted by `Phoenix.PubSub`)
  or sent by the client/browser.

  LiveView is first rendered statically as part of regular
  HTTP requests, which provides quick times for "First Meaningful
  Paint", in addition to helping search and indexing engines.
  Then a persistent connection is established between client and
  server. This allows LiveView applications to react faster to user
  events as there is less work to be done and less data to be sent
  compared to stateless requests that have to authenticate, decode, load,
  and encode data on every request. The flipside is that LiveView
  uses more memory on the server compared to stateless requests.

  ## Use cases

  There are many use cases where LiveView is an excellent
  fit right now:

    * Handling of user interaction and inputs, buttons, and
      forms - such as input validation, dynamic forms,
      autocomplete, etc;

    * Events and updates pushed by server - such as
      notifications, dashboards, etc;

    * Page and data navigation - such as navigating between
      pages, pagination, etc can be built with LiveView
      using the excellent live navigation feature set.
      This reduces the amount of data sent over the wire,
      gives developers full control over the LiveView
      life-cycle, while controlling how the browser
      tracks those changes in state;

  There are also use cases which are a bad fit for LiveView:

    * Animations - animations, menus, and general events
      that do not need the server in the first place are a
      bad fit for LiveView, as they can be achieved purely
      with CSS and/or CSS transitions;

  ## Life-cycle

  A LiveView begins as a regular HTTP request and HTML response,
  and then upgrades to a stateful view on client connect,
  guaranteeing a regular HTML page even if JavaScript is disabled.
  Any time a stateful view changes or updates its socket assigns, it is
  automatically re-rendered and the updates are pushed to the client.

  You begin by rendering a LiveView typically from your router.
  When LiveView is first rendered, the `c:mount/3` callback is invoked
  with the current params, the current session and the LiveView socket.
  As in a regular request, `params` contains public data that can be
  modified by the user. The `session` always contains private data set
  by the application itself. The `c:mount/3` callback wires up socket
  assigns necessary for rendering the view. After mounting, `c:render/1`
  is invoked and the HTML is sent as a regular HTML response to the
  client.

  After rendering the static page, LiveView connects from the client
  to the server where stateful views are spawned to push rendered updates
  to the browser, and receive client events via `phx-` bindings. Just like
  the first rendering, `c:mount/3` is invoked  with params, session,
  and socket state, where mount assigns values for rendering. However
  in the connected client case, a LiveView process is spawned on
  the server, pushes the result of `c:render/1` to the client and
  continues on for the duration of the connection. If at any point
  during the stateful life-cycle a crash is encountered, or the client
  connection drops, the client gracefully reconnects to the server,
  calling `c:mount/3` once again.

  ## Example

  Before writing your first example, make sure that Phoenix LiveView
  is properly installed. If you are just getting started, this can
  be easily done by running `mix phx.new my_app --live`. The `phx.new`
  command with the `--live` flag will create a new project with
  LiveView installed and configured. Otherwise, please follow the steps
  in the [installation guide](installation.md) before continuing.

  A LiveView is a simple module that requires two callbacks: `c:mount/3`
  and `c:render/1`:

      defmodule MyAppWeb.ThermostatLive do
        # If you generated an app with mix phx.new --live,
        # the line below would be: use MyAppWeb, :live_view
        use Phoenix.LiveView

        def render(assigns) do
          ~L"""
          Current temperature: <%= @temperature %>
          """
        end

        def mount(_params, %{"current_user_id" => user_id}, socket) do
          temperature = Thermostat.get_user_reading(user_id)
          {:ok, assign(socket, :temperature, temperature)}
        end
      end

  The `c:render/1` callback receives the `socket.assigns` and is responsible
  for returning rendered content. You can use `Phoenix.LiveView.Helpers.sigil_L/2`
  to inline LiveView templates.

  Next, decide where you want to use your LiveView.

  You can serve the LiveView directly from your router (recommended):

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        import Phoenix.LiveView.Router

        scope "/", MyAppWeb do
          live "/thermostat", ThermostatLive
        end
      end

  *Note:* the above assumes there is `plug :put_root_layout` call
  in your router that configures the LiveView layout. This call is
  automatically included by `mix phx.new --live` and described in
  the installation guide. If you don't want to configure a root layout,
  you must pass `layout: {MyAppWeb.LayoutView, "app.html"}` as an
  option to the `live` macro above.

  Alternatively, you can `live_render` from any template:

      <h1>Temperature Control</h1>
      <%= live_render(@conn, MyAppWeb.ThermostatLive) %>

  Or you can `live_render` your view from any controller:

      defmodule MyAppWeb.ThermostatController do
        ...
        import Phoenix.LiveView.Controller

        def show(conn, %{"id" => id}) do
          live_render(conn, MyAppWeb.ThermostatLive)
        end
      end

  When a LiveView is rendered, all of the data currently stored in the
  connection session (see `Plug.Conn.get_session/1`) will be given to
  the LiveView.

  It is also possible to pass additional session information to the LiveView
  through a session parameter:

      # In the router
      live "/thermostat", ThermostatLive, session: %{"extra_token" => "foo"}

      # In a view
      <%= live_render(@conn, MyAppWeb.ThermostatLive, session: %{"extra_token" => "foo"}) %>

  Notice the `:session` uses string keys as a reminder that session data
  is serialized and sent to the client. So you should always keep the data
  in the session to a minimum. For example, instead of storing a User struct,
  you should store the "user_id" and load the User when the LiveView mounts.

  Once the LiveView is rendered, a regular HTML response is sent. In your
  app.js file, you should find the following:

      import {Socket} from "phoenix"
      import LiveSocket from "phoenix_live_view"

      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
      let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})
      liveSocket.connect()

  After the client connects, `c:mount/3` will be invoked inside a spawned
  LiveView process. At this point, you can use `connected?/1` to
  conditionally perform stateful work, such as subscribing to pubsub topics,
  sending messages, etc. For example, you can periodically update a LiveView
  with a timer:

      defmodule DemoWeb.ThermostatLive do
        use Phoenix.LiveView
        ...

        def mount(_params, %{"current_user_id" => user_id}, socket) do
          if connected?(socket), do: Process.send_after(self(), :update, 30000)

          case Thermostat.get_user_reading(user_id) do
            {:ok, temperature} ->
              {:ok, assign(socket, temperature: temperature, user_id: user_id)}

            {:error, _reason} ->
              {:ok, redirect(socket, to: "/error")}
          end
        end

        def handle_info(:update, socket) do
          Process.send_after(self(), :update, 30000)
          {:ok, temperature} = Thermostat.get_reading(socket.assigns.user_id)
          {:noreply, assign(socket, :temperature, temperature)}
        end
      end

  We used `connected?(socket)` on mount to send our view a message every 30s if
  the socket is in a connected state. We receive the `:update` message in the
  `handle_info/2` callback, just like in an Elixir `GenServer`, and update our
  socket assigns. Whenever a socket's assigns change, `c:render/1` is automatically
  invoked, and the updates are sent to the client.

  ## Colocating templates

  In the examples above, we have placed the template directly inside the
  LiveView:

      defmodule MyAppWeb.ThermostatLive do
        use Phoenix.LiveView

        def render(assigns) do
          ~L"""
          Current temperature: <%= @temperature %>
          """
        end

  For larger templates, you can place them in a file in the same directory
  and same name as the LiveView. For example, if the file above is placed
  at `lib/my_app_web/live/thermostat_live.ex`, you can also remove the
  `c:render/1` definition above and instead put the template code at
  `lib/my_app_web/live/thermostat_live.html.leex`.

  Alternatively, you can keep the `c:render/1` callback but delegate to an
  existing `Phoenix.View` module in your application. For example:

      defmodule MyAppWeb.ThermostatLive do
        use Phoenix.LiveView

        def render(assigns) do
          Phoenix.View.render(MyAppWeb.PageView, "page.html", assigns)
        end
      end

  In all cases, each assign in the template will be accessible as `@assign`.
  You can learn more about [assigns and LiveEEx templates in their own guide](assigns-eex.md).

  ## Bindings

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
  | [Params](bindings.md#click-events) | `phx-value-*` |
  | [Click Events](bindings.md#click-events) | `phx-click`, `phx-capture-click` |
  | [Focus/Blur Events](bindings.md#focus-and-blur-events) | `phx-blur`, `phx-focus`, `phx-window-blur`, `phx-window-focus` |
  | [Key Events](bindings.md#key-events) | `phx-keydown`, `phx-keyup`, `phx-window-keydown`, `phx-window-keyup` |
  | [Form Events](form-bindings.md) | `phx-change`, `phx-submit`, `phx-feedback-for`, `phx-disable-with`, `phx-trigger-action`, `phx-auto-recover` |
  | [Rate Limiting](bindings.md#rate-limiting-events-with-debounce-and-throttle) | `phx-debounce`, `phx-throttle` |
  | [DOM Patching](dom-patching.md) | `phx-update` |
  | [JS Interop](js-interop.md#client-hooks) | `phx-hook` |

  ## Compartmentalizing markup and events with `render`, `live_render`, and `live_component`

  We can render another template directly from a LiveView template by simply
  calling `render`:

      render SomeView, "child_template.html", assigns

  Where `SomeView` is a regular `Phoenix.View`, typically defined in
  `lib/my_app_web/views/some_view.ex` and "child_template.html" is defined
  at `lib/my_app_web/templates/some_view/child_template.html.leex`. As long
  as the template has the `.leex` extension and all assigns are passed,
  LiveView change tracking will also work across templates.

  When rendering a child template, any of the `phx-*` events in the child
  template will be sent to the LiveView. In other words, similar to regular
  Phoenix templates, a regular `render` call does not start another LiveView.
  This means `render` is useful for sharing markup between views.

  If you want to start a separate LiveView from within a LiveView, then you
  can call `live_render/3` instead of `render/3`. This child LiveView runs
  in a separate process than the parent, with its own `mount` and `handle_event`
  callbacks. If a child LiveView crashes, it won't affect the parent. If the
  parent crashes, all children are terminated.

  When rendering a child LiveView, the `:id` option is required to uniquely
  identify the child. A child LiveView will only ever be rendered and mounted
  a single time, provided its ID remains unchanged. Updates to a child session
  will be merged on the client, but not passed back up until either a crash and
  re-mount or a connection drop and recovery. To force a child to re-mount with
  new session data, a new ID must be provided.

  Given that a LiveView runs on its own process, it is an excellent tool for creating
  completely isolated UI elements, but it is a slightly expensive abstraction if
  all you want is to compartmentalize markup and events. For example, if you are
  showing a table with all users in the system, and you want to compartmentalize
  this logic, rendering a separate `LiveView` for each user, then using a process
  per user would likely be too expensive. For these cases, LiveView provides
  `Phoenix.LiveComponent`, which are rendered using `live_component/3`:

      <%= live_component(@socket, UserComponent, id: user.id, user: user) %>

  Components have their own `mount` and `handle_event` callbacks, as well as their
  own state with change tracking support. Components are also lightweight as they
  "run" in the same process as the parent `LiveView`. However, this means an error
  in a component would cause the whole view to fail to render. See `Phoenix.LiveComponent`
  for a complete rundown on components.

  To sum it up:

    * `render` - compartmentalizes markup
    * `live_component` - compartmentalizes state, markup, and events
    * `live_render` - compartmentalizes state, markup, events, and error isolation

  ## Endpoint configuration

  LiveView accepts the following configuration in your endpoint under
  the `:live_view` key:

    * `:signing_salt` (required) - the salt used to sign data sent
      to the client

    * `:hibernate_after` (optional) - the idle time in milliseconds allowed in
    the LiveView before compressing its own memory and state.
    Defaults to 15000ms (15 seconds)

  ## Guides

  LiveView has many guides to help you on your journey.

  ## Server-side

  These guides focus on server-side functionality:

    * [Assigns and LiveEEx](assigns-eex.md)
    * [Error and exception handling](error-handling.md)
    * [Live Layouts](live-layouts.md)
    * [Live Navigation](live-navigation.md)
    * [Security considerations of the LiveView model](security-model.md)
    * [Telemetry](telemetry.md)
    * [Using Gettext for internationalization](using-gettext.md)

  ## Client-side

  These guides focus on LiveView bindings and client-side integration:

    * [Bindings](bindings.md)
    * [Form bindings](form-bindings.md)
    * [DOM patching and temporary assigns](dom-patching.md)
    * [JavaScript interoperability](js-interop.md)

  '''

  alias Phoenix.LiveView.Socket

  @type unsigned_params :: map

  @doc """
  The LiveView entry-point.

  For each LiveView in the root of a template, `c:mount/3` is invoked twice:
  once to do the initial page load and again to establish the live socket.

  It expects three parameters:

    * `params` - a map of string keys which contain public information that
      can be set by the user. The map contains the query params as well as any
      router path parameter. If the LiveView was not mounted at the router,
      this argument is the atom `:not_mounted_at_router`
    * `session` - the connection session
    * `socket` - the LiveView socket

  It must return either `{:ok, socket}` or `{:ok, socket, options}`, where
  `options` is one of:

    * `:temporary_assigns` - a keyword list of assigns that are temporary
      and must be reset to their value after every render

    * `:layout` - the optional layout to be used by the LiveView

  """
  @callback mount(
              unsigned_params() | :not_mounted_at_router,
              session :: map,
              socket :: Socket.t()
            ) ::
              {:ok, Socket.t()} | {:ok, Socket.t(), keyword()}

  @callback render(assigns :: Socket.assigns()) :: Phoenix.LiveView.Rendered.t()

  @callback terminate(reason, socket :: Socket.t()) :: term
            when reason: :normal | :shutdown | {:shutdown, :left | :closed | term}

  @callback handle_params(unsigned_params(), uri :: String.t(), socket :: Socket.t()) ::
              {:noreply, Socket.t()}

  @callback handle_event(event :: binary, unsigned_params(), socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:reply, map, Socket.t()}

  @callback handle_call(msg :: term, {pid, reference}, socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:reply, term, Socket.t()}

  @callback handle_info(msg :: term, socket :: Socket.t()) ::
              {:noreply, Socket.t()}

  @optional_callbacks mount: 3,
                      terminate: 2,
                      handle_params: 3,
                      handle_event: 3,
                      handle_call: 3,
                      handle_info: 2

  @doc """
  Uses LiveView in the current module to mark it a LiveView.

      use Phoenix.LiveView,
        namespace: MyAppWeb,
        container: {:tr, class: "colorized"},
        layout: {MyAppWeb.LayoutView, "live.html"}

  ## Options

    * `:namespace` - configures the namespace the `LiveView` is in
    * `:container` - configures the container the `LiveView` will be wrapped in
    * `:layout` - configures the layout the `LiveView` will be rendered in

  """
  defmacro __using__(opts) do
    # Expand layout if possible to avoid compile-time dependencies
    opts =
      with true <- Keyword.keyword?(opts),
           {layout, template} <- Keyword.get(opts, :layout) do
        layout = Macro.expand(layout, %{__CALLER__ | function: {:__live__, 0}})
        Keyword.replace!(opts, :layout, {layout, template})
      else
        _ -> opts
      end

    quote bind_quoted: [opts: opts] do
      import Phoenix.LiveView
      import Phoenix.LiveView.Helpers
      @behaviour Phoenix.LiveView

      require Phoenix.LiveView.Renderer
      @before_compile Phoenix.LiveView.Renderer

      @doc false
      def __live__, do: unquote(Macro.escape(Phoenix.LiveView.__live__(__MODULE__, opts)))
    end
  end

  @doc false
  def __live__(module, opts) do
    container = opts[:container] || {:div, []}
    namespace = opts[:namespace] || module |> Module.split() |> Enum.take(1) |> Module.concat()
    name = module |> Atom.to_string() |> String.replace_prefix("#{namespace}.", "")

    layout =
      case opts[:layout] do
        {mod, template} when is_atom(mod) and is_binary(template) ->
          {mod, template}

        nil ->
          nil

        other ->
          raise ArgumentError,
                ":layout expects a tuple of the form {MyLayoutView, \"my_template.html\"}, " <>
                  "got: #{inspect(other)}"
      end

    %{container: container, name: name, kind: :view, module: module, layout: layout}
  end

  @doc """
  Returns true if the socket is connected.

  Useful for checking the connectivity status when mounting the view.
  For example, on initial page render, the view is mounted statically,
  rendered, and the HTML is sent to the client. Once the client
  connects to the server, a LiveView is then spawned and mounted
  statefully within a process. Use `connected?/1` to conditionally
  perform stateful work, such as subscribing to pubsub topics,
  sending messages, etc.

  ## Examples

      defmodule DemoWeb.ClockLive do
        use Phoenix.LiveView
        ...
        def mount(_params, _session, socket) do
          if connected?(socket), do: :timer.send_interval(1000, self(), :tick)

          {:ok, assign(socket, date: :calendar.local_time())}
        end

        def handle_info(:tick, socket) do
          {:noreply, assign(socket, date: :calendar.local_time())}
        end
      end
  """
  def connected?(%Socket{connected?: connected?}), do: connected?

  @doc """
  Assigns a value into the socket only if it does not exist.

  Useful for lazily assigning values and referencing parent assigns.

  ## Referencing parent assigns

  When a LiveView is mounted in a disconnected state, the `Plug.Conn` assigns
  will be available for reference via `assign_new/3`, allowing assigns to
  be shared for the initial HTTP request. The `Plug.Conn` assigns will not be
  available during the connected mount. Likewise, nested LiveView children have
  access to their parent's assigns on mount using `assign_new`, which allows
  assigns to be shared down the nested LiveView tree.

  ## Examples

      # controller
      conn
      |> assign(:current_user, user)
      |> LiveView.Controller.live_render(MyLive, session: %{"user_id" => user.id})

      # LiveView mount
      def mount(_params, %{"user_id" => user_id}, socket) do
        {:ok, assign_new(socket, :current_user, fn -> Accounts.get_user!(user_id) end)}
      end

  """
  def assign_new(%Socket{} = socket, key, func) when is_function(func, 0) do
    validate_assign_key!(key)

    case socket do
      %{assigns: %{^key => _}} ->
        socket

      %{private: %{assign_new: {assigns, keys}}} ->
        # It is important to store the keys even if they are not in assigns
        # because maybe the controller doesn't have it but the view does.
        socket = put_in(socket.private.assign_new, {assigns, [key | keys]})
        Phoenix.LiveView.Utils.force_assign(socket, key, Map.get_lazy(assigns, key, func))

      %{} ->
        Phoenix.LiveView.Utils.force_assign(socket, key, func.())
    end
  end

  @doc """
  Adds key value pairs to socket assigns.

  A single key value pair may be passed, or a keyword list or a map
  of assigns may be provided to be merged into existing socket assigns.

  ## Examples

      iex> assign(socket, :name, "Elixir")
      iex> assign(socket, name: "Elixir", logo: "💧")
      iex> assign(socket, %{name: "Elixir"})
  """
  def assign(%Socket{} = socket, key, value) do
    validate_assign_key!(key)
    Phoenix.LiveView.Utils.assign(socket, key, value)
  end

  @doc """
  See `assign/3`.
  """
  def assign(%Socket{} = socket, attrs) when is_map(attrs) or is_list(attrs) do
    Enum.reduce(attrs, socket, fn {key, value}, acc ->
      validate_assign_key!(key)
      Phoenix.LiveView.Utils.assign(acc, key, value)
    end)
  end

  defp validate_assign_key!(:flash) do
    raise ArgumentError,
          ":flash is a reserved assign by LiveView and it cannot be set directly. " <>
            "Use the appropriate flash functions instead."
  end

  defp validate_assign_key!(_key), do: :ok

  @doc """
  Updates an existing key in the socket assigns.

  The update function receives the current key's value and
  returns the updated value. Raises if the key does not exist.

  ## Examples

      iex> update(socket, :count, fn count -> count + 1 end)
      iex> update(socket, :count, &(&1 + 1))
  """
  def update(%Socket{assigns: assigns} = socket, key, func) do
    case Map.fetch(assigns, key) do
      {:ok, val} -> assign(socket, [{key, func.(val)}])
      :error -> raise KeyError, key: key, term: assigns
    end
  end

  @doc """
  Adds a flash message to the socket to be displayed.

  *Note*: While you can use `put_flash/3` inside a `Phoenix.LiveComponent`,
  components have their own `@flash` assigns. The `@flash` assign
  in a component is only copied to its parent LiveView if the component
  calls `push_redirect/2` or `push_patch/2`.

  *Note*: You must also place the `Phoenix.LiveView.Router.fetch_live_flash/2`
  plug in your browser's pipeline in place of `fetch_flash` to be supported,
  for example:

      import Phoenix.LiveView.Router

      pipeline :browser do
        ...
        plug :fetch_live_flash
      end

  ## Examples

      iex> put_flash(socket, :info, "It worked!")
      iex> put_flash(socket, :error, "You can't access that page")
  """
  defdelegate put_flash(socket, kind, msg), to: Phoenix.LiveView.Utils

  @doc """
  Clears the flash.

  ## Examples

      iex> clear_flash(socket)
  """
  defdelegate clear_flash(socket), to: Phoenix.LiveView.Utils

  @doc """
  Clears a key from the flash.

  ## Examples

      iex> clear_flash(socket, :info)
  """
  defdelegate clear_flash(socket, key), to: Phoenix.LiveView.Utils

  @doc """
  Pushes an event to the client to be consumed by hooks.

  *Note*: events will be dispatched to all active hooks on the client who are
  handling the given `event`. Scoped events can be achieved by namespacing
  your event names.

  ## Examples

      {:noreply, push_event(socket, "scores", %{points: 100, user: "josé"})}
  """
  defdelegate push_event(socket, event, payload), to: Phoenix.LiveView.Utils

  @doc """
  Annotates the socket for redirect to a destination path.

  *Note*: LiveView redirects rely on instructing client
  to perform a `window.location` update on the provided
  redirect location. The whole page will be reloaded and
  all state will be discarded.

  ## Options

    * `:to` - the path to redirect to. It must always be a local path
    * `:external` - an external path to redirect to
  """
  def redirect(%Socket{} = socket, to: url) do
    validate_local_url!(url, "redirect/2")
    put_redirect(socket, {:redirect, %{to: url}})
  end

  def redirect(%Socket{} = socket, external: url) do
    put_redirect(socket, {:redirect, %{external: url}})
  end

  def redirect(%Socket{}, _) do
    raise ArgumentError, "expected :to or :external option in redirect/2"
  end

  @doc """
  Annotates the socket for navigation within the current LiveView.

  When navigating to the current LiveView, `c:handle_params/3` is
  immediately invoked to handle the change of params and URL state.
  Then the new state is pushed to the client, without reloading the
  whole page while also maintaining the current scroll position.
  For live redirects to another LiveView, use `push_redirect/2`.

  ## Options

    * `:to` - the required path to link to. It must always be a local path
    * `:replace` - the flag to replace the current history or push a new state.
      Defaults `false`.

  ## Examples

      {:noreply, push_patch(socket, to: "/")}
      {:noreply, push_patch(socket, to: "/", replace: true)}

  """
  def push_patch(%Socket{} = socket, opts) do
    %{to: to} = opts = push_opts!(opts, "push_patch/2")

    case Phoenix.LiveView.Utils.live_link_info!(socket, socket.root_view, to) do
      {:internal, params, action, _parsed_uri} ->
        put_redirect(socket, {:live, {params, action}, opts})

      {:external, _uri} ->
        raise ArgumentError,
              "cannot push_patch/2 to #{inspect(to)} because the given path " <>
                "does not point to the current root view #{inspect(socket.root_view)}"
    end
  end

  @doc """
  Annotates the socket for navigation to another LiveView.

  The current LiveView will be shutdown and a new one will be mounted
  in its place, without reloading the whole page. This can
  also be used to remount the same LiveView, in case you want to start
  fresh. If you want to navigate to the same LiveView without remounting
  it, use `push_patch/2` instead.

  ## Options

    * `:to` - the required path to link to. It must always be a local path
    * `:replace` - the flag to replace the current history or push a new state.
      Defaults `false`.

  ## Examples

      {:noreply, push_redirect(socket, to: "/")}
      {:noreply, push_redirect(socket, to: "/", replace: true)}

  """
  def push_redirect(%Socket{} = socket, opts) do
    opts = push_opts!(opts, "push_redirect/2")
    put_redirect(socket, {:live, :redirect, opts})
  end

  defp push_opts!(opts, context) do
    to = Keyword.fetch!(opts, :to)
    validate_local_url!(to, context)
    kind = if opts[:replace], do: :replace, else: :push
    %{to: to, kind: kind}
  end

  defp put_redirect(%Socket{redirected: nil} = socket, command) do
    %Socket{socket | redirected: command}
  end

  defp put_redirect(%Socket{redirected: to} = _socket, _command) do
    raise ArgumentError, "socket already prepared to redirect with #{inspect(to)}"
  end

  @invalid_local_url_chars ["\\"]

  defp validate_local_url!("//" <> _ = to, where) do
    raise_invalid_local_url!(to, where)
  end

  defp validate_local_url!("/" <> _ = to, where) do
    if String.contains?(to, @invalid_local_url_chars) do
      raise ArgumentError, "unsafe characters detected for #{where} in URL #{inspect(to)}"
    else
      to
    end
  end

  defp validate_local_url!(to, where) do
    raise_invalid_local_url!(to, where)
  end

  defp raise_invalid_local_url!(to, where) do
    raise ArgumentError, "the :to option in #{where} expects a path but was #{inspect(to)}"
  end

  @doc """
  Accesses the connect params sent by the client for use on connected mount.

  Connect params are only sent when the client connects to the server and
  only remain available during mount. `nil` is returned when called in a
  disconnected state and a `RuntimeError` is raised if called after mount.

  ## Reserved params

  The following params have special meaning in LiveView:

    * "_csrf_token" - the CSRF Token which must be explicitly set by the user
      when connecting
    * "_mounts" - the number of times the current LiveView is mounted.
      It is 0 on first mount, then increases on each reconnect. It resets
      when navigating away from the current LiveView or on errors
    * "_track_static" - set automatically with a list of all href/src from
      tags with the "phx-track-static" annotation in them. If there are no
      such tags, nothing is sent

  ## Examples

      def mount(_params, _session, socket) do
        {:ok, assign(socket, width: get_connect_params(socket)["width"] || @width)}
      end
  """
  def get_connect_params(%Socket{private: private} = socket) do
    if connect_params = private[:connect_params] do
      if connected?(socket), do: connect_params, else: nil
    else
      raise_connect_only!(socket, "connect_params")
    end
  end

  @doc """
  Accesses the connect info from the socket to use on connected mount.

  Connect info are only sent when the client connects to the server and
  only remain available during mount. `nil` is returned when called in a
  disconnected state and a `RuntimeError` is raised if called after mount.

  ## Examples

  First, when invoking the LiveView socket, you need to declare the
  `connect_info` you want to receive. Typically, it includes at least
  the session but it may include other keys, such as `:peer_data`.
  See `Phoenix.Endpoint.socket/3`:

      socket "/live", Phoenix.LiveView.Socket,
        websocket: [connect_info: [:peer_data, session: @session_options]]

  Those values can now be accessed on the connected mount as
  `get_connect_info/1`:

      def mount(_params, _session, socket) do
        if info = get_connect_info(socket) do
          {:ok, assign(socket, ip: info.peer_data.address)}
        else
          {:ok, assign(socket, ip: nil)}
        end
      end
  """
  def get_connect_info(%Socket{private: private} = socket) do
    if connect_info = private[:connect_info] do
      if connected?(socket), do: connect_info, else: nil
    else
      raise_connect_only!(socket, "connect_info")
    end
  end

  @doc """
  Returns true if the socket is connected and the tracked static assets have changed.

  This function is useful to detect if the client is running on an outdated
  version of the marked static files. It works by comparing the static paths
  sent by the client with the one on the server.

  **Note:** this functionality requires Phoenix v1.5.2 or later.

  To use this functionality, the first step is to annotate which static files
  you want to be tracked by LiveView, with the `phx-track-static`. For example:

      <link phx-track-static rel="stylesheet" href="<%= Routes.static_path(@conn, "/css/app.css") %>"/>
      <script defer phx-track-static type="text/javascript" src="<%= Routes.static_path(@conn, "/js/app.js") %>"></script>

  Now, whenever LiveView connects to the server, it will send a copy `src`
  or `href` attributes of all tracked statics and compare those values with
  the latest entries computed by `mix phx.digest` in the server.

  The tracked statics on the client will match the ones on the server the
  huge majority of times. However, if there is a new deployment, those values
  may differ. You can use this function to detect those cases and show a
  banner to the user, asking them to reload the page. To do so, first set the
  assign on mount:

      def mount(params, session, socket) do
        {:ok, assign(socket, static_change: static_changed?(socket))}
      end

  And then in your views:

      <%= if @static_changed? do %>
        <div id="reload-static">
          The app has been updated. Click here to <a href="#" onclick="window.location.reload()">reload</a>.
        </div>
      <% end %>

  If you prefer, you can also send a JavaScript script that immediately
  reloads the page.

  **Note:** only set `phx-track-static` on your own assets. For example, do
  not set it in external JavaScript files:

      <script defer phx-track-static type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/3.4.1/jquery.min.js"></script>

  Because you don't actually serve the file above, LiveView will interpret
  the static above as missing, and this function will return true.
  """
  def static_changed?(%Socket{private: private, endpoint: endpoint} = socket) do
    if connect_params = private[:connect_params] do
      connected?(socket) and
        static_changed?(
          connect_params["_track_static"],
          endpoint.config(:cache_static_manifest_latest)
        )
    else
      raise_connect_only!(socket, "static_changed?")
    end
  end

  defp static_changed?([_ | _] = statics, %{} = latest) do
    latest = Map.to_list(latest)

    not Enum.all?(statics, fn static ->
      [static | _] = :binary.split(static, "?")

      Enum.any?(latest, fn {non_digested, digested} ->
        String.ends_with?(static, non_digested) or String.ends_with?(static, digested)
      end)
    end)
  end

  defp static_changed?(_, _), do: false

  defp raise_connect_only!(socket, fun) do
    if child?(socket) do
      raise RuntimeError, """
      attempted to read #{fun} from a nested child LiveView #{inspect(socket.view)}.

      Only the root LiveView has access to #{fun}.
      """
    else
      raise RuntimeError, """
      attempted to read #{fun} outside of #{inspect(socket.view)}.mount/3.

      #{fun} only exists while mounting. If you require access to this information
      after mount, store the state in socket assigns.
      """
    end
  end

  @doc """
  Asynchronously updates a `Phoenix.LiveComponent` with new assigns.

  The component that is updated must be stateful (the `:id` in the assigns must
  match the `:id` associated with the component) and the component must be
  mounted within the current LiveView.

  When the component receives the update, the optional
  [`preload/1`](`c:Phoenix.LiveComponent.preload/1`) callback is invoked, then
  the updated values are merged with the component's assigns and
  [`update/2`](`c:Phoenix.LiveComponent.update/2`) is called for the updated
  component(s).

  While a component may always be updated from the parent by updating some
  parent assigns which will re-render the child, thus invoking
  [`update/2`](`c:Phoenix.LiveComponent.update/2`) on the child component,
  `send_update/2` is useful for updating a component that entirely manages its
  own state, as well as messaging between components mounted in the same
  LiveView.

  **Note:** `send_update/2` cannot update a LiveComponent that is mounted in a
  different LiveView. To update a component in a different LiveView you must
  send a message to the LiveView process that the LiveComponent is mounted
  within (often via `Phoenix.PubSub`).

  ## Examples

      def handle_event("cancel-order", _, socket) do
        ...
        send_update(Cart, id: "cart", status: "cancelled")
        {:noreply, socket}
      end
  """
  def send_update(module, assigns) when is_atom(module) do
    assigns = Enum.into(assigns, %{})

    id =
      assigns[:id] ||
        raise ArgumentError, "missing required :id in send_update. Got: #{inspect(assigns)}"

    Phoenix.LiveView.Channel.send_update(module, id, assigns)
  end

  @doc """
  Similar to `send_update/2` but the update will be delayed according to the given `time_in_milliseconds`.

  ## Examples

      def handle_event("cancel-order", _, socket) do
        ...
        send_update_after(Cart, [id: "cart", status: "cancelled"], 3000)
        {:noreply, socket}
      end
  """
  def send_update_after(module, assigns, time_in_milliseconds)
      when is_atom(module) and is_integer(time_in_milliseconds) do
    assigns = Enum.into(assigns, %{})

    id =
      assigns[:id] ||
        raise ArgumentError, "missing required :id in send_update_after. Got: #{inspect(assigns)}"

    Phoenix.LiveView.Channel.send_update_after(module, id, assigns, time_in_milliseconds)
  end

  @doc """
  Returns the transport pid of the socket.

  Raises `ArgumentError` if the socket is not connected.

  ## Examples

      iex> transport_pid(socket)
      #PID<0.107.0>
  """
  def transport_pid(%Socket{}) do
    case Process.get(:"$callers") do
      [transport_pid | _] -> transport_pid
      _ -> raise ArgumentError, "transport_pid/1 may only be called when the socket is connected."
    end
  end

  defp child?(%Socket{parent_pid: pid}), do: is_pid(pid)
end
