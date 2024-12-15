defmodule Phoenix.LiveView do
  @moduledoc ~S'''
  A LiveView is a process that receives events, updates
  its state, and renders updates to a page as diffs.

  To get started, see [the Welcome guide](welcome.md).
  This module provides advanced documentation and features
  about using LiveView.

  ## Life-cycle

  A LiveView begins as a regular HTTP request and HTML response,
  and then upgrades to a stateful view on client connect,
  guaranteeing a regular HTML page even if JavaScript is disabled.
  Any time a stateful view changes or updates its socket assigns, it is
  automatically re-rendered and the updates are pushed to the client.

  Socket assigns are stateful values kept on the server side in
  `Phoenix.LiveView.Socket`. This is different from the common stateless
  HTTP pattern of sending the connection state to the client in the form
  of a token or cookie and rebuilding the state on the server to service
  every request.

  You begin by rendering a LiveView typically from your router.
  When LiveView is first rendered, the `c:mount/3` callback is invoked
  with the current params, the current session and the LiveView socket.
  As in a regular request, `params` contains public data that can be
  modified by the user. The `session` always contains private data set
  by the application itself. The `c:mount/3` callback wires up socket
  assigns necessary for rendering the view. After mounting, `c:handle_params/3`
  is invoked so uri and query params are handled. Finally, `c:render/1`
  is invoked and the HTML is sent as a regular HTML response to the
  client.

  After rendering the static page, LiveView connects from the client
  to the server where stateful views are spawned to push rendered updates
  to the browser, and receive client events via `phx-` bindings. Just like
  the first rendering, `c:mount/3`, is invoked  with params, session,
  and socket state. However in the connected client case, a LiveView process
  is spawned on the server, runs `c:handle_params/3` again and then pushes
  the result of `c:render/1` to the client and continues on for the duration
  of the connection. If at any point during the stateful life-cycle a crash
  is encountered, or the client connection drops, the client gracefully
  reconnects to the server, calling `c:mount/3` and `c:handle_params/3` again.

  LiveView also allows attaching hooks to specific life-cycle stages with
  `attach_hook/4`.

  ## Template collocation

  There are two possible ways of rendering content in a LiveView. The first
  one is by explicitly defining a render function, which receives `assigns`
  and returns a `HEEx` template defined with [the `~H` sigil](`Phoenix.Component.sigil_H/2`).

      defmodule MyAppWeb.DemoLive do
        # In a typical Phoenix app, the following line would usually be `use MyAppWeb, :live_view`
        use Phoenix.LiveView

        def render(assigns) do
          ~H"""
          Hello world!
          """
        end
      end

  For larger templates, you can place them in a file in the same directory
  and same name as the LiveView. For example, if the file above is placed
  at `lib/my_app_web/live/demo_live.ex`, you can also remove the
  `render/1` function altogether and put the template code at
  `lib/my_app_web/live/demo_live.html.heex`.

  ## Async Operations

  Performing asynchronous work is common in LiveViews and LiveComponents.
  It allows the user to get a working UI quickly while the system fetches some
  data in the background or talks to an external service, without blocking the
  render or event handling. For async work, you also typically need to handle
  the different states of the async operation, such as loading, error, and the
  successful result. You also want to catch any errors or exits and translate it
  to a meaningful update in the UI rather than crashing the user experience.

  ### Async assigns

  The `assign_async/3` function takes the socket, a key or list of keys which will be assigned
  asynchronously, and a function. This function will be wrapped in a `task` by
  `assign_async`, making it easy for you to return the result. This function must
  return an `{:ok, assigns}` or `{:error, reason}` tuple, where `assigns` is a map
  of the keys passed to `assign_async`.
  If the function returns anything else, an error is raised.

  The task is only started when the socket is connected.

  For example, let's say we want to async fetch a user's organization from the database,
  as well as their profile and rank:

      def mount(%{"slug" => slug}, _, socket) do
        {:ok,
         socket
         |> assign(:foo, "bar")
         |> assign_async(:org, fn -> {:ok, %{org: fetch_org!(slug)}} end)
         |> assign_async([:profile, :rank], fn -> {:ok, %{profile: ..., rank: ...}} end)}
      end

  > ### Warning {: .warning}
  >
  > When using async operations it is important to not pass the socket into the function
  > as it will copy the whole socket struct to the Task process, which can be very expensive.
  >
  > Instead of:
  >
  > ```elixir
  > assign_async(:org, fn -> {:ok, %{org: fetch_org(socket.assigns.slug)}} end)
  > ```
  >
  > We should do:
  >
  > ```elixir
  > slug = socket.assigns.slug
  > assign_async(:org, fn -> {:ok, %{org: fetch_org(slug)}} end)
  > ```
  >
  > See: https://hexdocs.pm/elixir/process-anti-patterns.html#sending-unnecessary-data

  The state of the async operation is stored in the socket assigns within an
  `Phoenix.LiveView.AsyncResult`. It carries the loading and failed states, as
  well as the result. For example, if we wanted to show the loading states in
  the UI for the `:org`, our template could conditionally render the states:

  ```heex
  <div :if={@org.loading}>Loading organization...</div>
  <div :if={org = @org.ok? && @org.result}>{org.name} loaded!</div>
  ```

  The `Phoenix.Component.async_result/1` function component can also be used to
  declaratively render the different states using slots:

  ```heex
  <.async_result :let={org} assign={@org}>
    <:loading>Loading organization...</:loading>
    <:failed :let={_failure}>there was an error loading the organization</:failed>
    {org.name}
  </.async_result>
  ```

  ### Arbitrary async operations

  Sometimes you need lower level control of asynchronous operations, while
  still receiving process isolation and error handling. For this, you can use
  `start_async/3` and the `Phoenix.LiveView.AsyncResult` module directly:

      def mount(%{"id" => id}, _, socket) do
        {:ok,
         socket
         |> assign(:org, AsyncResult.loading())
         |> start_async(:my_task, fn -> fetch_org!(id) end)}
      end

      def handle_async(:my_task, {:ok, fetched_org}, socket) do
        %{org: org} = socket.assigns
        {:noreply, assign(socket, :org, AsyncResult.ok(org, fetched_org))}
      end

      def handle_async(:my_task, {:exit, reason}, socket) do
        %{org: org} = socket.assigns
        {:noreply, assign(socket, :org, AsyncResult.failed(org, {:exit, reason}))}
      end

  `start_async/3` is used to fetch the organization asynchronously. The
  `c:handle_async/3` callback is called when the task completes or exits,
  with the results wrapped in either `{:ok, result}` or `{:exit, reason}`.
  The `AsyncResult` module provides functions to update the state of the
  async operation, but you can also assign any value directly to the socket
  if you want to handle the state yourself.

  ## Endpoint configuration

  LiveView accepts the following configuration in your endpoint under
  the `:live_view` key:

    * `:signing_salt` (required) - the salt used to sign data sent
      to the client

    * `:hibernate_after` (optional) - the idle time in milliseconds allowed in
    the LiveView before compressing its own memory and state.
    Defaults to 15000ms (15 seconds)

  '''

  alias Phoenix.LiveView.{Socket, LiveStream, Async}

  @type unsigned_params :: map

  @doc """
  The LiveView entry-point.

  For each LiveView in the root of a template, `c:mount/3` is invoked twice:
  once to do the initial page load and again to establish the live socket.

  It expects three arguments:

    * `params` - a map of string keys which contain public information that
      can be set by the user. The map contains the query params as well as any
      router path parameter. If the LiveView was not mounted at the router,
      this argument is the atom `:not_mounted_at_router`
    * `session` - the connection session
    * `socket` - the LiveView socket

  It must return either `{:ok, socket}` or `{:ok, socket, options}`, where
  `options` is one of:

    * `:temporary_assigns` - a keyword list of assigns that are temporary
      and must be reset to their value after every render. Note that once
      the value is reset, it won't be re-rendered again until it is explicitly
      assigned

    * `:layout` - the optional layout to be used by the LiveView. Setting
      this option will override any layout previously set via
      `Phoenix.LiveView.Router.live_session/2` or on `use Phoenix.LiveView`

  """
  @callback mount(
              params :: unsigned_params() | :not_mounted_at_router,
              session :: map,
              socket :: Socket.t()
            ) ::
              {:ok, Socket.t()} | {:ok, Socket.t(), keyword()}

  @doc """
  Renders a template.

  This callback is invoked whenever LiveView detects
  new content must be rendered and sent to the client.

  If you define this function, it must return a template
  defined via the `Phoenix.Component.sigil_H/2`.

  If you don't define this function, LiveView will attempt
  to render a template in the same directory as your LiveView.
  For example, if you have a LiveView named `MyApp.MyCustomView`
  inside `lib/my_app/live_views/my_custom_view.ex`, Phoenix
  will look for a template at `lib/my_app/live_views/my_custom_view.html.heex`.
  """
  @callback render(assigns :: Socket.assigns()) :: Phoenix.LiveView.Rendered.t()

  @doc """
  Invoked when the LiveView is terminating.

  In case of errors, this callback is only invoked if the LiveView
  is trapping exits. See `c:GenServer.terminate/2` for more info.
  """
  @callback terminate(reason, socket :: Socket.t()) :: term
            when reason: :normal | :shutdown | {:shutdown, :left | :closed | term}

  @doc """
  Invoked after mount and whenever there is a live patch event.

  It receives the current `params`, including parameters from
  the router, the current `uri` from the client and the `socket`.
  It is invoked after mount or whenever there is a live navigation
  event caused by `push_patch/2` or `<.link patch={...}>`.

  It must always return `{:noreply, socket}`, where `:noreply`
  means no additional information is sent to the client.

  > #### Note {: .warning}
  >
  > `handle_params` is only allowed on LiveViews mounted at the router,
  > as it takes the current url of the page as the second parameter.
  """
  @callback handle_params(unsigned_params(), uri :: String.t(), socket :: Socket.t()) ::
              {:noreply, Socket.t()}

  @doc """
  Invoked to handle events sent by the client.

  It receives the `event` name, the event payload as a map,
  and the socket.

  It must return `{:noreply, socket}`, where `:noreply` means
  no additional information is sent to the client, or
  `{:reply, map(), socket}`, where the given `map()` is encoded
  and sent as a reply to the client.
  """
  @callback handle_event(event :: binary, unsigned_params(), socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:reply, map, Socket.t()}

  @doc """
  Invoked to handle calls from other Elixir processes.

  See `GenServer.call/3` and `c:GenServer.handle_call/3`
  for more information.
  """
  @callback handle_call(msg :: term, {pid, reference}, socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:reply, term, Socket.t()}

  @doc """
  Invoked to handle casts from other Elixir processes.

  See `GenServer.cast/2` and `c:GenServer.handle_cast/2`
  for more information. It must always return `{:noreply, socket}`,
  where `:noreply` means no additional information is sent
  to the process which cast the message.
  """
  @callback handle_cast(msg :: term, socket :: Socket.t()) ::
              {:noreply, Socket.t()}

  @doc """
  Invoked to handle messages from other Elixir processes.

  See `Kernel.send/2` and `c:GenServer.handle_info/2`
  for more information. It must always return `{:noreply, socket}`,
  where `:noreply` means no additional information is sent
  to the process which sent the message.
  """
  @callback handle_info(msg :: term, socket :: Socket.t()) ::
              {:noreply, Socket.t()}

  @doc """
  Invoked when the result of an `start_async/3` operation is available.

  For a deeper understanding of using this callback,
  refer to the ["Arbitrary async operations"](#module-arbitrary-async-operations) section.
  """
  @callback handle_async(
              name :: term,
              async_fun_result :: {:ok, term} | {:exit, term},
              socket :: Socket.t()
            ) ::
              {:noreply, Socket.t()}

  @optional_callbacks mount: 3,
                      render: 1,
                      terminate: 2,
                      handle_params: 3,
                      handle_event: 3,
                      handle_call: 3,
                      handle_info: 2,
                      handle_cast: 2,
                      handle_async: 3

  @doc """
  Uses LiveView in the current module to mark it a LiveView.

      use Phoenix.LiveView,
        container: {:tr, class: "colorized"},
        layout: {MyAppWeb.Layouts, :app},
        log: :info

  ## Options

    * `:container` - an optional tuple for the HTML tag and DOM attributes to
      be used for the LiveView container. For example: `{:li, style: "color: blue;"}`.
      See `Phoenix.Component.live_render/3` for more information and examples.

    * `:global_prefixes` - the global prefixes to use for components. See
      `Global Attributes` in `Phoenix.Component` for more information.

    * `:layout` - configures the layout the LiveView will be rendered in.
      This layout can be overridden by on `c:mount/3` or via the `:layout`
      option in `Phoenix.LiveView.Router.live_session/2`

    * `:log` - configures the log level for the LiveView, either `false`
      or a log level

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
      @behaviour Phoenix.LiveView
      @before_compile Phoenix.LiveView.Renderer

      @phoenix_live_opts opts
      Module.register_attribute(__MODULE__, :phoenix_live_mount, accumulate: true)
      @before_compile Phoenix.LiveView

      # Phoenix.Component must come last so its @before_compile runs last
      use Phoenix.Component, Keyword.take(opts, [:global_prefixes])
    end
  end

  defmacro __before_compile__(env) do
    opts = Module.get_attribute(env.module, :phoenix_live_opts)

    on_mount =
      env.module
      |> Module.get_attribute(:phoenix_live_mount)
      |> Enum.reverse()

    live = Phoenix.LiveView.__live__([on_mount: on_mount] ++ opts)

    quote do
      @doc false
      def __live__ do
        unquote(Macro.escape(live))
      end
    end
  end

  @doc """
  Defines metadata for a LiveView.

  This must be returned from the `__live__` callback.

  It accepts:

    * `:container` - an optional tuple for the HTML tag and DOM attributes to
      be used for the LiveView container. For example: `{:li, style: "color: blue;"}`.

    * `:layout` - configures the layout the LiveView will be rendered in.
      This layout can be overridden by on `c:mount/3` or via the `:layout`
      option in `Phoenix.LiveView.Router.live_session/2`

    * `:log` - configures the log level for the LiveView, either `false`
      or a log level

    * `:on_mount` - a list of tuples with module names and argument to be invoked
      as `on_mount` hooks

  """
  def __live__(opts \\ []) do
    on_mount = opts[:on_mount] || []

    layout =
      Phoenix.LiveView.Utils.normalize_layout(Keyword.get(opts, :layout, false))

    log =
      case Keyword.fetch(opts, :log) do
        {:ok, false} -> false
        {:ok, log} when is_atom(log) -> log
        :error -> :debug
        _ -> raise ArgumentError, ":log expects an atom or false, got: #{inspect(opts[:log])}"
      end

    container = opts[:container] || {:div, []}

    %{
      container: container,
      kind: :view,
      layout: layout,
      lifecycle: Phoenix.LiveView.Lifecycle.build(on_mount),
      log: log
    }
  end

  @doc """
  Declares a module callback to be invoked on the LiveView's mount.

  The function within the given module, which must be named `on_mount`,
  will be invoked before both disconnected and connected mounts. The hook
  has the option to either halt or continue the mounting process as usual.
  If you wish to redirect the LiveView, you **must** halt, otherwise an error
  will be raised.

  Tip: if you need to define multiple `on_mount` callbacks, avoid defining
  multiple modules. Instead, pass a tuple and use pattern matching to handle
  different cases:

      def on_mount(:admin, _params, _session, socket) do
        {:cont, socket}
      end

      def on_mount(:user, _params, _session, socket) do
        {:cont, socket}
      end

  And then invoke it as:

      on_mount {MyAppWeb.SomeHook, :admin}
      on_mount {MyAppWeb.SomeHook, :user}

  Registering `on_mount` hooks can be useful to perform authentication
  as well as add custom behaviour to other callbacks via `attach_hook/4`.

  The `on_mount` callback can return a keyword list of options as a third
  element in the return tuple. These options are identical to what can
  optionally be returned in `c:mount/3`.

  ## Examples

  The following is an example of attaching a hook via
  `Phoenix.LiveView.Router.live_session/3`:

      # lib/my_app_web/live/init_assigns.ex
      defmodule MyAppWeb.InitAssigns do
        @moduledoc "\""
        Ensures common `assigns` are applied to all LiveViews attaching this hook.
        "\""
        import Phoenix.LiveView
        import Phoenix.Component

        def on_mount(:default, _params, _session, socket) do
          {:cont, assign(socket, :page_title, "DemoWeb")}
        end

        def on_mount(:user, params, session, socket) do
          # code
        end

        def on_mount(:admin, _params, _session, socket) do
          {:cont, socket, layout: {DemoWeb.Layouts, :admin}}
        end
      end

      # lib/my_app_web/router.ex
      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        # pipelines, plugs, etc.

        live_session :default, on_mount: MyAppWeb.InitAssigns do
          scope "/", MyAppWeb do
            pipe_through :browser
            live "/", PageLive, :index
          end
        end

        live_session :authenticated, on_mount: {MyAppWeb.InitAssigns, :user} do
          scope "/", MyAppWeb do
            pipe_through [:browser, :require_user]
            live "/profile", UserLive.Profile, :index
          end
        end

        live_session :admins, on_mount: {MyAppWeb.InitAssigns, :admin} do
          scope "/admin", MyAppWeb.Admin do
            pipe_through [:browser, :require_user, :require_admin]
            live "/", AdminLive.Index, :index
          end
        end
      end

  """
  defmacro on_mount(mod_or_mod_arg) do
    caller = %{__CALLER__ | function: {:on_mount, 1}}

    # While we could pass `mod_or_mod_arg` as a whole to
    # expand_literals, we want to also be able to expand only
    # the first element, even if the second element is not a literal.
    mod_or_mod_arg =
      case mod_or_mod_arg do
        {mod, arg} ->
          {Macro.expand_literals(mod, caller), Macro.expand_literals(arg, caller)}

        mod_or_mod_arg ->
          Macro.expand_literals(mod_or_mod_arg, caller)
      end

    quote do
      Module.put_attribute(
        __MODULE__,
        :phoenix_live_mount,
        Phoenix.LiveView.Lifecycle.validate_on_mount!(__MODULE__, unquote(mod_or_mod_arg))
      )
    end
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
  def connected?(%Socket{transport_pid: transport_pid}), do: transport_pid != nil

  @doc """
  Configures which function to use to render a LiveView/LiveComponent.

  By default, LiveView invokes the `render/1` function in the same module
  the LiveView/LiveComponent is defined, passing `assigns` as its sole
  argument. This function allows you to set a different rendering function.

  One possible use case for this function is to set a different template
  on disconnected render. When the user first accesses a LiveView, we will
  perform a disconnected render to send to the browser. This is useful for
  several reasons, such as reducing the time to first paint and for search
  engine indexing.

  However, when LiveView is gated behind an authentication page, it may be
  useful to render a placeholder on disconnected render and perform the
  full render once the WebSocket connects. This can be achieved with
  `render_with/2` and is particularly useful on complex pages (such as
  dashboards and reports).

  To do so, you must simply invoke `render_with(socket, &some_function_component/1)`,
  configuring your socket with a new rendering function.
  """
  def render_with(%Socket{} = socket, component) when is_function(component, 1) do
    put_in(socket.private[:render_with], component)
  end

  @doc """
  Puts a new private key and value in the socket.

  Privates are *not change tracked*. This storage is meant to be used by
  users and libraries to hold state that doesn't require
  change tracking. The keys should be prefixed with the app/library name.

  ## Examples

  Key values can be placed in private:

      put_private(socket, :myapp_meta, %{foo: "bar"})

  And then retrieved:

      socket.private[:myapp_meta]
  """
  @reserved_privates ~w(
    connect_params
    connect_info
    assign_new
    live_async
    live_layout
    live_temp
    lifecycle
    render_with
    root_view
  )a
  def put_private(%Socket{} = socket, key, value) when key not in @reserved_privates do
    %{socket | private: Map.put(socket.private, key, value)}
  end

  def put_private(%Socket{}, bad_key, _value) do
    raise ArgumentError, "cannot set reserved private key #{inspect(bad_key)}"
  end

  @doc """
  Adds a flash message to the socket to be displayed.

  *Note*: While you can use `put_flash/3` inside a `Phoenix.LiveComponent`,
  components have their own `@flash` assigns. The `@flash` assign
  in a component is only copied to its parent LiveView if the component
  calls `push_navigate/2` or `push_patch/2`.

  *Note*: You must also place the `Phoenix.LiveView.Router.fetch_live_flash/2`
  plug in your browser's pipeline in place of `fetch_flash` for LiveView flash
  messages be supported, for example:

      import Phoenix.LiveView.Router

      pipeline :browser do
        ...
        plug :fetch_live_flash
      end

  In a typical LiveView application, the message will be rendered by the CoreComponents’ flash/1 component.
  It is up to this function to determine what kind of messages it supports.
  By default, the `:info` and `:error` kinds are handled.

  ## Examples

      iex> put_flash(socket, :info, "It worked!")
      iex> put_flash(socket, :error, "You can't access that page")
  """

  defdelegate put_flash(socket, kind, msg), to: Phoenix.LiveView.Utils

  @doc """
  Clears the flash.

  ## Examples

      iex> clear_flash(socket)

  Clearing the flash can also be triggered on the client and natively handled by LiveView using the `lv:clear-flash` event.

  For example:

  ```heex
  <p class="alert" phx-click="lv:clear-flash">
    {Phoenix.Flash.get(@flash, :info)}
  </p>
  ```
  """
  defdelegate clear_flash(socket), to: Phoenix.LiveView.Utils

  @doc """
  Clears a key from the flash.

  ## Examples

      iex> clear_flash(socket, :info)

  Clearing the flash can also be triggered on the client and natively handled by LiveView using the `lv:clear-flash` event.

  For example:

  ```heex
  <p class="alert" phx-click="lv:clear-flash" phx-value-key="info">
    {Phoenix.Flash.get(@flash, :info)}
  </p>
  ```
  """
  defdelegate clear_flash(socket, key), to: Phoenix.LiveView.Utils

  @doc """
  Pushes an event to the client.

  Events can be handled in two ways:

    1. They can be handled on `window` via `addEventListener`.
       A "phx:" prefix will be added to the event name.

    2. They can be handled inside a hook via `handleEvent`.

  Events are dispatched to all active hooks on the client who are
  handling the given `event`. If you need to scope events, then
  this must be done by namespacing them.

  Events pushed during `push_navigate` are currently discarded,
  as the LiveView is immediately dismounted.

  ## Hook example

  If you push a "scores" event from your LiveView:

      {:noreply, push_event(socket, "scores", %{points: 100, user: "josé"})}

  A hook declared via `phx-hook` can handle it via `handleEvent`:

  ```javascript
  this.handleEvent("scores", data => ...)
  ```

  ## `window` example

  All events are also dispatched on the `window`. This means you can handle
  them by adding listeners. For example, if you want to remove an element
  from the page, you can do this:

      {:noreply, push_event(socket, "remove-el", %{id: "foo-bar"})}

  And now in your app.js you can register and handle it:

  ```javascript
  window.addEventListener(
    "phx:remove-el",
    e => document.getElementById(e.detail.id).remove()
  )
  ```

  """
  defdelegate push_event(socket, event, payload), to: Phoenix.LiveView.Utils

  @doc ~S"""
  Allows an upload for the provided name.

  ## Options

    * `:accept` - Required. A list of unique file extensions (such as ".jpeg") or
      mime type (such as "image/jpeg" or "image/*"). You may also pass the atom
      `:any` instead of a list to support to allow any kind of file.
      For example, `[".jpeg"]`, `:any`, etc.

    * `:max_entries` - The maximum number of selected files to allow per
      file input. Defaults to 1.

    * `:max_file_size` - The maximum file size in bytes to allow to be uploaded.
      Defaults 8MB. For example, `12_000_000`.

    * `:chunk_size` - The chunk size in bytes to send when uploading.
      Defaults `64_000`.

    * `:chunk_timeout` - The time in milliseconds to wait before closing the
      upload channel when a new chunk has not been received. Defaults to `10_000`.

    * `:external` - A 2-arity function for generating metadata for external
      client uploaders. This function must return either `{:ok, meta, socket}`
      or `{:error, meta, socket}` where meta is a map. See the Uploads section
      for example usage.

    * `:progress` - An optional 3-arity function for receiving progress events.

    * `:auto_upload` - Instructs the client to upload the file automatically
      on file selection instead of waiting for form submits. Defaults to `false`.

    * `:writer` - A module implementing the `Phoenix.LiveView.UploadWriter`
      behaviour to use for writing the uploaded chunks. Defaults to writing to a
      temporary file for consumption. See the `Phoenix.LiveView.UploadWriter` docs
      for custom usage.

  Raises when a previously allowed upload under the same name is still active.

  ## Examples

      allow_upload(socket, :avatar, accept: ~w(.jpg .jpeg), max_entries: 2)
      allow_upload(socket, :avatar, accept: :any)

  For consuming files automatically as they are uploaded, you can pair `auto_upload: true` with
  a custom progress function to consume the entries as they are completed. For example:

      allow_upload(socket, :avatar, accept: :any, progress: &handle_progress/3, auto_upload: true)

      defp handle_progress(:avatar, entry, socket) do
        if entry.done? do
          uploaded_file =
            consume_uploaded_entry(socket, entry, fn %{} = meta ->
              {:ok, ...}
            end)

          {:noreply, put_flash(socket, :info, "file #{uploaded_file.name} uploaded")}
        else
          {:noreply, socket}
        end
      end
  """
  defdelegate allow_upload(socket, name, options), to: Phoenix.LiveView.Upload

  @doc """
  Revokes a previously allowed upload from `allow_upload/3`.

  ## Examples

      disallow_upload(socket, :avatar)
  """
  defdelegate disallow_upload(socket, name), to: Phoenix.LiveView.Upload

  @doc """
  Cancels an upload for the given entry.

  ## Examples

  ```heex
  <%= for entry <- @uploads.avatar.entries do %>
    ...
    <button phx-click="cancel-upload" phx-value-ref={entry.ref}>cancel</button>
  <% end %>
  ```

      def handle_event("cancel-upload", %{"ref" => ref}, socket) do
        {:noreply, cancel_upload(socket, :avatar, ref)}
      end
  """
  defdelegate cancel_upload(socket, name, entry_ref), to: Phoenix.LiveView.Upload

  @doc """
  Returns the completed and in progress entries for the upload.

  ## Examples

      case uploaded_entries(socket, :photos) do
        {[_ | _] = completed, []} ->
          # all entries are completed

        {[], [_ | _] = in_progress} ->
          # all entries are still in progress
      end
  """
  defdelegate uploaded_entries(socket, name), to: Phoenix.LiveView.Upload

  @doc ~S"""
  Consumes the uploaded entries.

  Raises when there are still entries in progress.
  Typically called when submitting a form to handle the
  uploaded entries alongside the form data. For form submissions,
  it is guaranteed that all entries have completed before the submit event
  is invoked. Once entries are consumed, they are removed from the upload.

  The function passed to consume may return a tagged tuple of the form
  `{:ok, my_result}` to collect results about the consumed entries, or
  `{:postpone, my_result}` to collect results, but postpone the file
  consumption to be performed later.

  A list of all `my_result` values produced by the passed function is
  returned, regardless of whether they were consumed or postponed.

  ## Examples

      def handle_event("save", _params, socket) do
        uploaded_files =
          consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
            dest = Path.join("priv/static/uploads", Path.basename(path))
            File.cp!(path, dest)
            {:ok, ~p"/uploads/#{Path.basename(dest)}"}
          end)
        {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_files))}
      end
  """
  defdelegate consume_uploaded_entries(socket, name, func), to: Phoenix.LiveView.Upload

  @doc ~S"""
  Consumes an individual uploaded entry.

  Raises when the entry is still in progress.
  Typically called when submitting a form to handle the
  uploaded entries alongside the form data. Once entries are consumed,
  they are removed from the upload.

  This is a lower-level feature than `consume_uploaded_entries/3` and useful
  for scenarios where you want to consume entries as they are individually completed.

  Like `consume_uploaded_entries/3`, the function passed to consume may return
  a tagged tuple of the form `{:ok, my_result}` to collect results about the
  consumed entries, or `{:postpone, my_result}` to collect results,
  but postpone the file consumption to be performed later.

  ## Examples

      def handle_event("save", _params, socket) do
        case uploaded_entries(socket, :avatar) do
          {[_|_] = entries, []} ->
            uploaded_files = for entry <- entries do
              consume_uploaded_entry(socket, entry, fn %{path: path} ->
                dest = Path.join("priv/static/uploads", Path.basename(path))
                File.cp!(path, dest)
                {:ok, ~p"/uploads/#{Path.basename(dest)}"}
              end)
            end
            {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_files))}

          _ ->
            {:noreply, socket}
        end
      end
  """
  defdelegate consume_uploaded_entry(socket, entry, func), to: Phoenix.LiveView.Upload

  @doc """
  Annotates the socket for redirect to a destination path.

  *Note*: LiveView redirects rely on instructing client
  to perform a `window.location` update on the provided
  redirect location. The whole page will be reloaded and
  all state will be discarded.

  ## Options

    * `:to` - the path to redirect to. It must always be a local path
    * `:status` - the HTTP status code to use for the redirect. Defaults to 302.
    * `:external` - an external path to redirect to. Either a string
      or `{scheme, url}` to redirect to a custom scheme

  ## Examples

      {:noreply, redirect(socket, to: "/")}
      {:noreply, redirect(socket, to: "/", status: 301)}
      {:noreply, redirect(socket, external: "https://example.com")}

  """
  def redirect(socket, opts \\ []) do
    status = Keyword.get(opts, :status, 302)

    cond do
      Keyword.has_key?(opts, :to) ->
        do_internal_redirect(socket, Keyword.fetch!(opts, :to), status)

      Keyword.has_key?(opts, :external) ->
        do_external_redirect(socket, Keyword.fetch!(opts, :external), status)

      true ->
        raise ArgumentError, "expected :to or :external option in redirect/2"
    end
  end

  defp do_internal_redirect(%Socket{} = socket, url, redirect_status) do
    validate_local_url!(url, "redirect/2")

    put_redirect(socket, {:redirect, %{to: url, status: redirect_status}})
  end

  defp do_external_redirect(%Socket{} = socket, url, redirect_status) do
    case url do
      {scheme, rest} ->
        put_redirect(
          socket,
          {:redirect, %{external: "#{scheme}:#{rest}", status: redirect_status}}
        )

      url when is_binary(url) ->
        external_url = Phoenix.LiveView.Utils.valid_string_destination!(url, "redirect/2")

        put_redirect(
          socket,
          {:redirect, %{external: external_url, status: redirect_status}}
        )

      other ->
        raise ArgumentError,
              "expected :external option in redirect/2 to be valid URL, got: #{inspect(other)}"
    end
  end

  @doc """
  Annotates the socket for navigation within the current LiveView.

  When navigating to the current LiveView, `c:handle_params/3` is
  immediately invoked to handle the change of params and URL state.
  Then the new state is pushed to the client, without reloading the
  whole page while also maintaining the current scroll position.
  For live navigation to another LiveView in the same `live_session`,
  use `push_navigate/2`. Otherwise, use `redirect/2`.

  ## Options

    * `:to` - the required path to link to. It must always be a local path
    * `:replace` - the flag to replace the current history or push a new state.
      Defaults `false`.

  ## Examples

      {:noreply, push_patch(socket, to: "/")}
      {:noreply, push_patch(socket, to: "/", replace: true)}

  """
  def push_patch(%Socket{} = socket, opts) do
    opts = push_opts!(opts, "push_patch/2")
    put_redirect(socket, {:live, :patch, opts})
  end

  @doc """
  Annotates the socket for navigation to another LiveView in the same `live_session`.

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

      {:noreply, push_navigate(socket, to: "/")}
      {:noreply, push_navigate(socket, to: "/", replace: true)}

  """
  def push_navigate(%Socket{} = socket, opts) do
    opts = push_opts!(opts, "push_navigate/2")
    put_redirect(socket, {:live, :redirect, opts})
  end

  @doc false
  @deprecated "Use push_navigate/2 instead"
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
    %{socket | redirected: command}
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

    * `"_csrf_token"` - the CSRF Token which must be explicitly set by the user
      when connecting
    * `"_mounts"` - the number of times the current LiveView is mounted.
      It is 0 on first mount, then increases on each reconnect. It resets
      when navigating away from the current LiveView or on errors
    * `"_track_static"` - set automatically with a list of all href/src from
      tags with the `phx-track-static` annotation in them. If there are no
      such tags, nothing is sent
    * `"_live_referer"` - sent by the client as the referer URL when a
      live navigation has occurred from `push_navigate` or client link navigate.

  ## Examples

      def mount(_params, _session, socket) do
        {:ok, assign(socket, width: get_connect_params(socket)["width"] || @width)}
      end
  """
  def get_connect_params(%Socket{private: private} = socket) do
    if connect_params = private[:connect_params] do
      if connected?(socket), do: connect_params, else: nil
    else
      raise_root_and_mount_only!(socket, "connect_params")
    end
  end

  @doc """
  Accesses a given connect info key from the socket.

  The following keys are supported: `:peer_data`, `:trace_context_headers`,
  `:x_headers`, `:uri`, and `:user_agent`.

  The connect information is available only during mount. During disconnected
  render, all keys are available. On connected render, only the keys explicitly
  declared in your socket are available. See `Phoenix.Endpoint.socket/3` for
  a complete description of the keys.

  ## Examples

  The first step is to declare the `connect_info` you want to receive.
  Typically, it includes at least the session, but you must include all
  other keys you want to access on connected mount, such as `:peer_data`:

      socket "/live", Phoenix.LiveView.Socket,
        websocket: [connect_info: [:peer_data, session: @session_options]]

  Those values can now be accessed on the connected mount as
  `get_connect_info/2`:

      def mount(_params, _session, socket) do
        peer_data = get_connect_info(socket, :peer_data)
        {:ok, assign(socket, ip: peer_data.address)}
      end

  If the key is not available, usually because it was not specified
  in `connect_info`, it returns nil.
  """
  def get_connect_info(%Socket{private: private} = socket, key) when is_atom(key) do
    if connect_info = private[:connect_info] do
      case connect_info do
        %Plug.Conn{} -> conn_connect_info(connect_info, key)
        %{} -> connect_info[key]
      end
    else
      raise_root_and_mount_only!(socket, "connect_info")
    end
  end

  defp conn_connect_info(conn, :peer_data) do
    Plug.Conn.get_peer_data(conn)
  end

  defp conn_connect_info(conn, :x_headers) do
    for {header, _} = pair <- conn.req_headers,
        String.starts_with?(header, "x-"),
        do: pair
  end

  defp conn_connect_info(conn, :trace_context_headers) do
    for {header, _} = pair <- conn.req_headers,
        header in ["traceparent", "tracestate"],
        do: pair
  end

  defp conn_connect_info(conn, :uri) do
    %URI{
      scheme: to_string(conn.scheme),
      query: conn.query_string,
      port: conn.port,
      host: conn.host,
      path: conn.request_path
    }
  end

  defp conn_connect_info(conn, :user_agent) do
    with {_, value} <- List.keyfind(conn.req_headers, "user-agent", 0) do
      value
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

  ```heex
  <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
  <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}></script>
  ```

  Now, whenever LiveView connects to the server, it will send a copy `src`
  or `href` attributes of all tracked statics and compare those values with
  the latest entries computed by `mix phx.digest` in the server.

  The tracked statics on the client will match the ones on the server the
  huge majority of times. However, if there is a new deployment, those values
  may differ. You can use this function to detect those cases and show a
  banner to the user, asking them to reload the page. To do so, first set the
  assign on mount:

      def mount(params, session, socket) do
        {:ok, assign(socket, static_changed?: static_changed?(socket))}
      end

  And then in your views:

  ```heex
  <div :if={@static_changed?} id="reload-static">
    The app has been updated. Click here to <a href="#" onclick="window.location.reload()">reload</a>.
  </div>
  ```

  If you prefer, you can also send a JavaScript script that immediately
  reloads the page.

  **Note:** only set `phx-track-static` on your own assets. For example, do
  not set it in external JavaScript files:

  ```heex
  <script defer phx-track-static type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/3.4.1/jquery.min.js"></script>
  ```

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
      raise_root_and_mount_only!(socket, "static_changed?")
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

  defp raise_root_and_mount_only!(socket, fun) do
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

  @doc ~S'''
  Asynchronously updates a `Phoenix.LiveComponent` with new assigns.

  The `pid` argument is optional and it defaults to the current process,
  which means the update instruction will be sent to a component running
  on the same LiveView. If the current process is not a LiveView or you
  want to send updates to a live component running on another LiveView,
  you should explicitly pass the LiveView's pid instead.

  The second argument can be either the value of the `@myself` or the module of
  the live component. If you pass the module, then the `:id` that identifies
  the component must be passed as part of the assigns.

  When the component receives the update,
  [`update_many/1`](`c:Phoenix.LiveComponent.update_many/1`) will be invoked if
  it is defined, otherwise [`update/2`](`c:Phoenix.LiveComponent.update/2`) is
  invoked with the new assigns.  If
  [`update/2`](`c:Phoenix.LiveComponent.update/2`) is not defined all assigns
  are simply merged into the socket. The assigns received as the first argument
  of the [`update/2`](`c:Phoenix.LiveComponent.update/2`) callback will only
  include the _new_ assigns passed from this function.  Pre-existing assigns may
  be found in `socket.assigns`.

  While a component may always be updated from the parent by updating some
  parent assigns which will re-render the child, thus invoking
  [`update/2`](`c:Phoenix.LiveComponent.update/2`) on the child component,
  `send_update/3` is useful for updating a component that entirely manages its
  own state, as well as messaging between components mounted in the same
  LiveView.

  ## Examples

      def handle_event("cancel-order", _, socket) do
        ...
        send_update(Cart, id: "cart", status: "cancelled")
        {:noreply, socket}
      end

      def handle_event("cancel-order-asynchronously", _, socket) do
        ...
        pid = self()

        Task.Supervisor.start_child(MyTaskSup, fn ->
          # Do something asynchronously
          send_update(pid, Cart, id: "cart", status: "cancelled")
        end)

        {:noreply, socket}
      end

      def render(assigns) do
        ~H"""
        <.some_component on_complete={&send_update(@myself, completed: &1)} />
        """
      end
  '''
  def send_update(pid \\ self(), module_or_cid, assigns)

  def send_update(pid, module, assigns) when is_atom(module) and is_pid(pid) do
    assigns = Enum.into(assigns, %{})

    id =
      assigns[:id] ||
        raise ArgumentError, "missing required :id in send_update. Got: #{inspect(assigns)}"

    Phoenix.LiveView.Channel.send_update(pid, {module, id}, assigns)
  end

  def send_update(pid, %Phoenix.LiveComponent.CID{} = cid, assigns) when is_pid(pid) do
    assigns = Enum.into(assigns, %{})

    Phoenix.LiveView.Channel.send_update(pid, cid, assigns)
  end

  @doc """
  Similar to `send_update/3` but the update will be delayed according to the given `time_in_milliseconds`.

  It returns a reference which can be cancelled with `Process.cancel_timer/1`.

  ## Examples

      def handle_event("cancel-order", _, socket) do
        ...
        send_update_after(Cart, [id: "cart", status: "cancelled"], 3000)
        {:noreply, socket}
      end

      def handle_event("cancel-order-asynchronously", _, socket) do
        ...
        pid = self()

        Task.start(fn ->
          # Do something asynchronously
          send_update_after(pid, Cart, [id: "cart", status: "cancelled"], 3000)
        end)

        {:noreply, socket}
      end
  """
  def send_update_after(pid \\ self(), module_or_cid, assigns, time_in_milliseconds)

  def send_update_after(pid, %Phoenix.LiveComponent.CID{} = cid, assigns, time_in_milliseconds)
      when is_integer(time_in_milliseconds) and is_pid(pid) do
    assigns = Enum.into(assigns, %{})

    Phoenix.LiveView.Channel.send_update_after(pid, cid, assigns, time_in_milliseconds)
  end

  def send_update_after(pid, module, assigns, time_in_milliseconds)
      when is_atom(module) and is_integer(time_in_milliseconds) and is_pid(pid) do
    assigns = Enum.into(assigns, %{})

    id =
      assigns[:id] ||
        raise ArgumentError, "missing required :id in send_update_after. Got: #{inspect(assigns)}"

    Phoenix.LiveView.Channel.send_update_after(pid, {module, id}, assigns, time_in_milliseconds)
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

  @doc """
  Attaches the given `fun` by `name` for the lifecycle `stage` into `socket`.

  > Note: This function is for server-side lifecycle callbacks.
  > For client-side hooks, see the
  > [JS Interop guide](js-interop.html#client-hooks-via-phx-hook).

  Hooks provide a mechanism to tap into key stages of the LiveView
  lifecycle in order to bind/update assigns, intercept events,
  patches, and regular messages when necessary, and to inject
  common functionality. Use `attach_hook/4` on any of the following
  lifecycle stages: `:handle_params`, `:handle_event`, `:handle_info`, `:handle_async`, and
  `:after_render`. To attach a hook to the `:mount` stage, use `on_mount/1`.

  > Note: only `:after_render` and `:handle_event` hooks are currently supported in
  > LiveComponents.

  ## Return Values

  Lifecycle hooks take place immediately before a given lifecycle
  callback is invoked on the LiveView. With the exception of `:after_render`,
  a hook may return `{:halt, socket}` to halt the reduction, otherwise
  it must return `{:cont, socket}` so the operation may continue until
  all hooks have been invoked for the current stage.

  For `:after_render` hooks, the `socket` itself must be returned.
  Any updates to the socket assigns *will not* trigger a new render
  or diff calculation to the client.

  ## Halting the lifecycle

  Note that halting from a hook _will halt the entire lifecycle stage_.
  This means that when a hook returns `{:halt, socket}` then the
  LiveView callback will **not** be invoked. This has some
  implications.

  ### Implications for plugin authors

  When defining a plugin that matches on specific callbacks, you **must**
  define a catch-all clause, as your hook will be invoked even for events
  you may not be interested in.

  ### Implications for end-users

  Allowing a hook to halt the invocation of the callback means that you can
  attach hooks to intercept specific events before detaching themselves,
  while allowing other events to continue normally.

  ## Replying to events

  Hooks attached to the `:handle_event` stage are able to reply to client events
  by returning `{:halt, reply, socket}`. This is useful especially for [JavaScript
  interoperability](js-interop.html#client-hooks-via-phx-hook) because a client hook
  can push an event and receive a reply.

  ## Examples

  Attaching and detaching a hook:

      def mount(_params, _session, socket) do
        socket =
          attach_hook(socket, :my_hook, :handle_event, fn
            "very-special-event", _params, socket ->
              # Handle the very special event and then detach the hook
              {:halt, detach_hook(socket, :my_hook, :handle_event)}

            _event, _params, socket ->
              {:cont, socket}
          end)

        {:ok, socket}
      end

  Replying to a client event:

  ```javascript
  /**
   * @type {Object.<string, import("phoenix_live_view").ViewHook>}
   */
  let Hooks = {}
  Hooks.ClientHook = {
    mounted() {
      this.pushEvent("ClientHook:mounted", {hello: "world"}, (reply) => {
        console.log("received reply:", reply)
      })
    }
  }
  let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks, ...})
  ```

      def render(assigns) do
        ~H"\""
        <div id="my-client-hook" phx-hook="ClientHook"></div>
        "\""
      end

      def mount(_params, _session, socket) do
        socket =
          attach_hook(socket, :reply_on_client_hook_mounted, :handle_event, fn
            "ClientHook:mounted", params, socket ->
              {:halt, params, socket}

            _, _, socket ->
              {:cont, socket}
          end)

        {:ok, socket}
      end
  """
  defdelegate attach_hook(socket, name, stage, fun), to: Phoenix.LiveView.Lifecycle

  @doc """
  Detaches a hook with the given `name` from the lifecycle `stage`.

  > Note: This function is for server-side lifecycle callbacks.
  > For client-side hooks, see the
  > [JS Interop guide](js-interop.html#client-hooks-via-phx-hook).

  If no hook is found, this function is a no-op.

  ## Examples

      def handle_event(_, socket) do
        {:noreply, detach_hook(socket, :hook_that_was_attached, :handle_event)}
      end
  """
  defdelegate detach_hook(socket, name, stage), to: Phoenix.LiveView.Lifecycle

  @doc ~S"""
  Assigns a new stream to the socket or inserts items into an existing stream.
  Returns an updated `socket`.

  Streams are a mechanism for managing large collections on the client without
  keeping the resources on the server.

    * `name` - A string or atom name of the key to place under the
      `@streams` assign.
    * `items` - An enumerable of items to insert.

  The following options are supported:

    * `:at` - The index to insert or update the items in the
      collection on the client. By default `-1` is used, which appends the items
      to the parent DOM container. A value of `0` prepends the items.

      Note that this operation is equal to inserting the items one by one, each at
      the given index. Therefore, when inserting multiple items at an index other than `-1`,
      the UI will display the items in reverse order:

          stream(socket, :songs, [song1, song2, song3], at: 0)

      In this case the UI will prepend `song1`, then `song2` and then `song3`, so it will show
      `song3`, `song2`, `song1` and then any previously inserted items.

      To insert in the order of the list, use `Enum.reverse/1`:

          stream(socket, :songs, Enum.reverse([song1, song2, song3]), at: 0)

    * `:reset` - A boolean to reset the stream on the client or not. Defaults
      to `false`.

    * `:limit` - An optional positive or negative number of results to limit
      on the UI on the client. As new items are streamed, the UI will remove existing
      items to maintain the limit. For example, to limit the stream to the last 10 items
      in the UI while appending new items, pass a negative value:

          stream(socket, :songs, songs, at: -1, limit: -10)

      Likewise, to limit the stream to the first 10 items, while prepending new items,
      pass a positive value:

          stream(socket, :songs, songs, at: 0, limit: 10)

  Once a stream is defined, a new `@streams` assign is available containing
  the name of the defined streams. For example, in the above definition, the
  stream may be referenced as `@streams.songs` in your template. Stream items
  are temporary and freed from socket state immediately after the `render/1`
  function is invoked (or a template is rendered from disk).

  By default, calling `stream/4` on an existing stream will bulk insert the new items
  on the client while leaving the existing items in place. Streams may also be reset
  when calling `stream/4`, which we discuss below.

  ## Resetting a stream

  To empty a stream container on the client, you can pass `:reset` with an empty list:

      stream(socket, :songs, [], reset: true)

  Or you can replace the entire stream on the client with a new collection:

      stream(socket, :songs, new_songs, reset: true)

  ## Limiting a stream

  It is often useful to limit the number of items in the UI while allowing the
  server to stream new items in a fire-and-forget fashion. This prevents
  the server from overwhelming the client with new results while also opening up
  powerful features like virtualized infinite scrolling. See a complete
  bidirectional infinite scrolling example with stream limits in the
  [scroll events guide](bindings.md#scroll-events-and-infinite-stream-pagination)

  When a stream exceeds the limit on the client, the existing items will be pruned
  based on the number of items in the stream container and the limit direction. A
  positive limit will prune items from the end of the container, while a negative
  limit will prune items from the beginning of the container.

  Note that the limit is not enforced on the first `c:mount/3` render (when no websocket
  connection was established yet), as it means more data than necessary has been
  loaded. In such cases, you should only load and pass the desired amount of items
  to the stream.

  When inserting single items using `stream_insert/4`, the limit needs to be passed
  as an option for it to be enforced on the client:

      stream_insert(socket, :songs, song, limit: -10)

  ## Required DOM attributes

  For stream items to be trackable on the client, the following requirements
  must be met:

    1. The parent DOM container must include a `phx-update="stream"` attribute,
       along with a unique DOM id.
    2. Each stream item must include its DOM id on the item's element.

  > #### Note {: .warning}
  >
  > Failing to place `phx-update="stream"` on the **immediate parent** for
  > **each stream** will result in broken behavior.
  >
  > Also, do not alter the generated DOM ids, e.g., by prefixing them. Doing so will
  > result in broken behavior.

  When consuming a stream in a template, the DOM id and item is passed as a tuple,
  allowing convenient inclusion of the DOM id for each item. For example:

  ```heex
  <table>
    <tbody id="songs" phx-update="stream">
      <tr
        :for={{dom_id, song} <- @streams.songs}
        id={dom_id}
      >
        <td>{song.title}</td>
        <td>{song.duration}</td>
      </tr>
    </tbody>
  </table>
  ```

  We consume the stream in a for comprehension by referencing the
  `@streams.songs` assign. We used the computed DOM id to populate
  the `<tr>` id, then we render the table row as usual.

  Now `stream_insert/3` and `stream_delete/3` may be issued and new rows will
  be inserted or deleted from the client.

  ## Handling the empty case

  When rendering a list of items, it is common to show a message for the empty case.
  But when using streams, we cannot rely on `Enum.empty?/1` or similar approaches to
  check if the list is empty. Instead we can use the CSS `:only-child` selector
  and show the message client side:

  ```heex
  <table>
    <tbody id="songs" phx-update="stream">
      <tr id="songs-empty" class="only:block hidden">
        <td colspan="2">No songs found</td>
      </tr>
      <tr
        :for={{dom_id, song} <- @streams.songs}
        id={dom_id}
      >
        <td>{song.title}</td>
        <td>{song.duration}</td>
      </tr>
    </tbody>
  </table>
  ```

  ## Non-stream items in stream containers

  In the section on handling the empty case, we showed how to render a message when
  the stream is empty by rendering a non-stream item inside the stream container.

  Note that for non-stream items inside a `phx-update="stream"` container, the following
  needs to be considered:

    1. Items can be added and updated, but not removed, even if the stream is reset.

  This means that if you try to conditionally render a non-stream item inside a stream container,
  it won't be removed if it was rendered once.

    2. Items are affected by the `:at` option.

  For example, when you render a non-stream item at the beginning of the stream container and then
  prepend items (with `at: 0`) to the stream, the non-stream item will be pushed down.

  """
  @spec stream(
          socket :: Socket.t(),
          name :: atom | String.t(),
          items :: Enumerable.t(),
          opts :: Keyword.t()
        ) ::
          Socket.t()
  def stream(%Socket{} = socket, name, items, opts \\ []) do
    socket
    |> ensure_streams()
    |> assign_stream(name, items, opts)
  end

  @doc ~S"""
  Configures a stream.

  The following options are supported:

    * `:dom_id` - An optional function to generate each stream item's DOM id.
      The function accepts each stream item and converts the item to a string id.
      By default, the `:id` field of a map or struct will be used if the item has
      such a field, and will be prefixed by the `name` hyphenated with the id.
      For example, the following examples are equivalent:

          stream(socket, :songs, songs)

          socket
          |> stream_configure(:songs, dom_id: &("songs-#{&1.id}"))
          |> stream(:songs, songs)

  A stream must be configured before items are inserted, and once configured,
  a stream may not be re-configured. To ensure a stream is only configured a
  single time in a LiveComponent, use the `mount/1` callback. For example:

      def mount(socket) do
        {:ok, stream_configure(socket, :songs, dom_id: &("songs-#{&1.id}"))}
      end

      def update(assigns, socket) do
        {:ok, stream(socket, :songs, ...)}
      end

  Returns an updated `socket`.
  """
  @spec stream_configure(socket :: Socket.t(), name :: atom | String.t(), opts :: Keyword.t()) ::
          Socket.t()
  def stream_configure(%Socket{} = socket, name, opts) when is_list(opts) do
    new_socket = ensure_streams(socket)

    case new_socket.assigns.streams do
      %{^name => %LiveStream{}} ->
        raise ArgumentError, "cannot configure stream :#{name} after it has been streamed"

      %{__configured__: %{^name => _opts}} ->
        raise ArgumentError, "cannot re-configure stream :#{name} after it has been configured"

      %{} ->
        Phoenix.Component.update(new_socket, :streams, fn streams ->
          Map.update!(streams, :__configured__, fn conf -> Map.put(conf, name, opts) end)
        end)
    end
  end

  defp ensure_streams(%Socket{} = socket) do
    Phoenix.LiveView.Utils.assign_new(socket, :streams, fn ->
      %{__ref__: 0, __changed__: MapSet.new(), __configured__: %{}}
    end)
  end

  @doc """
  Inserts a new item or updates an existing item in the stream.

  Returns an updated `socket`.

  See `stream/4` for inserting multiple items at once.

  The following options are supported:

    * `:at` - The index to insert or update the item in the collection on the client.
      By default, the item is appended to the parent DOM container. This is the same as
      passing a value of `-1`.
      If the item already exists in the parent DOM container then it will be
      updated in place.

    * `:limit` - A limit of items to maintain in the UI. A limit passed to `stream/4` does
      not affect subsequent calls to `stream_insert/4`, therefore the limit must be passed
      here as well in order to be enforced. See `stream/4` for more information on
      limiting streams.

    * `:update_only` - A boolean to only update the item in the stream. If the item does not
      exist on the client, it will not be inserted. Defaults to `false`.

  ## Examples

  Imagine you define a stream on mount with a single item:

      stream(socket, :songs, [%Song{id: 1, title: "Song 1"}])

  Then, in a callback such as `handle_info` or `handle_event`, you
  can append a new song:

      stream_insert(socket, :songs, %Song{id: 2, title: "Song 2"})

  Or prepend a new song with `at: 0`:

      stream_insert(socket, :songs, %Song{id: 2, title: "Song 2"}, at: 0)

  Or update an existing song (in this case the `:at` option has no effect):

      stream_insert(socket, :songs, %Song{id: 1, title: "Song 1 updated"}, at: 0)

  Or append a new song while limiting the stream to the last 10 items:

      stream_insert(socket, :songs, %Song{id: 2, title: "Song 2"}, limit: -10)

  ## Updating Items

  As shown, an existing item on the client can be updated by issuing a `stream_insert`
  for the existing item. When the client updates an existing item, the item will remain
  in the same location as it was previously, and will not be moved to the end of the
  parent children. To both update an existing item and move it to another position,
  issue a `stream_delete`, followed by a `stream_insert`. For example:

      song = get_song!(id)

      socket
      |> stream_delete(:songs, song)
      |> stream_insert(:songs, song, at: -1)

  See `stream_delete/3` for more information on deleting items.
  """
  @spec stream_insert(
          socket :: Socket.t(),
          name :: atom | String.t(),
          item :: any,
          opts :: Keyword.t()
        ) ::
          Socket.t()
  def stream_insert(%Socket{} = socket, name, item, opts \\ []) do
    at = Keyword.get(opts, :at, -1)
    limit = Keyword.get(opts, :limit)
    update_only = Keyword.get(opts, :update_only, false)

    update_stream(socket, name, &LiveStream.insert_item(&1, item, at, limit, update_only))
  end

  @doc """
  Deletes an item from the stream.

  The item's DOM is computed from the `:dom_id` provided in the `stream/3` definition.
  Delete information for this DOM id is sent to the client and the item's element
  is removed from the DOM, following the same behavior of element removal, such as
  invoking `phx-remove` commands and executing client hook `destroyed()` callbacks.

  ## Examples

      def handle_event("delete", %{"id" => id}, socket) do
        song = get_song!(id)
        {:noreply, stream_delete(socket, :songs, song)}
      end

  See `stream_delete_by_dom_id/3` to remove an item without requiring the
  original data structure.

  Returns an updated `socket`.
  """
  @spec stream_delete(socket :: Socket.t(), name :: atom | String.t(), item :: any) :: Socket.t()
  def stream_delete(%Socket{} = socket, name, item) do
    update_stream(socket, name, &LiveStream.delete_item(&1, item))
  end

  @doc ~S'''
  Deletes an item from the stream given its computed DOM id.

  Returns an updated `socket`.

  Behaves just like `stream_delete/3`, but accept the precomputed DOM id,
  which allows deleting from a stream without fetching or building the original
  stream data structure.

  ## Examples

      def render(assigns) do
        ~H"""
        <table>
          <tbody id="songs" phx-update="stream">
            <tr
              :for={{dom_id, song} <- @streams.songs}
              id={dom_id}
            >
              <td>{song.title}</td>
              <td><button phx-click={JS.push("delete", value: %{id: dom_id})}>delete</button></td>
            </tr>
          </tbody>
        </table>
        """
      end

      def handle_event("delete", %{"id" => dom_id}, socket) do
        {:noreply, stream_delete_by_dom_id(socket, :songs, dom_id)}
      end
  '''
  @spec stream_delete_by_dom_id(socket :: Socket.t(), name :: atom | String.t(), id :: String.t()) ::
          Socket.t()
  def stream_delete_by_dom_id(%Socket{} = socket, name, id) do
    update_stream(socket, name, &LiveStream.delete_item_by_dom_id(&1, id))
  end

  defp assign_stream(%Socket{} = socket, name, items, opts) do
    streams = socket.assigns.streams

    case streams do
      %{^name => %LiveStream{}} ->
        new_socket =
          if opts[:reset] do
            update_stream(socket, name, &LiveStream.reset(&1))
          else
            socket
          end

        Enum.reduce(items, new_socket, fn item, acc -> stream_insert(acc, name, item, opts) end)

      %{} ->
        config = get_in(streams, [:__configured__, name]) || []
        opts = Keyword.merge(opts, config)

        ref =
          if cid = socket.assigns[:myself] do
            "#{cid}-#{streams.__ref__}"
          else
            to_string(streams.__ref__)
          end

        stream = LiveStream.new(name, ref, items, opts)

        socket
        |> Phoenix.Component.update(:streams, fn streams ->
          %{streams | __ref__: streams.__ref__ + 1}
          |> Map.put(name, stream)
          |> Map.update!(:__changed__, &MapSet.put(&1, name))
        end)
        |> attach_hook(name, :after_render, fn hook_socket ->
          if name in hook_socket.assigns.streams.__changed__ do
            Phoenix.Component.update(hook_socket, :streams, fn streams ->
              streams
              |> Map.update!(:__changed__, &MapSet.delete(&1, name))
              |> Map.update!(name, &LiveStream.prune(&1))
            end)
          else
            hook_socket
          end
        end)
    end
  end

  defp update_stream(%Socket{} = socket, name, func) do
    Phoenix.Component.update(socket, :streams, fn streams ->
      stream =
        case Map.fetch(streams, name) do
          {:ok, stream} -> stream
          :error -> raise ArgumentError, "no stream with name #{inspect(name)} previously defined"
        end

      streams
      |> Map.put(name, func.(stream))
      |> Map.update!(:__changed__, &MapSet.put(&1, name))
    end)
  end

  @doc """
  Assigns keys asynchronously.

  Wraps your function in a task linked to the caller, errors are wrapped.
  Each key passed to `assign_async/3` will be assigned to
  an `%AsyncResult{}` struct holding the status of the operation
  and the result when the function completes.

  The task is only started when the socket is connected.

  ## Options

    * `:supervisor` - allows you to specify a `Task.Supervisor` to supervise the task.
    * `:reset` - remove previous results during async operation when true. Possible values are
      `true`, `false`, or a list of keys to reset. Defaults to `false`.

  ## Examples

      def mount(%{"slug" => slug}, _, socket) do
        {:ok,
         socket
         |> assign(:foo, "bar")
         |> assign_async(:org, fn -> {:ok, %{org: fetch_org!(slug)}} end)
         |> assign_async([:profile, :rank], fn -> {:ok, %{profile: ..., rank: ...}} end)}
      end

  See the moduledoc for more information.

  ## `assign_async/3` and `send_update/3`

  Since the code inside `assign_async/3` runs in a separate process,
  `send_update(Component, data)` does not work inside `assign_async/3`,
  since `send_update/2` assumes it is running inside the LiveView process.
  The solution is to explicitly send the update to the LiveView:

      parent = self()
      assign_async(socket, :org, fn ->
        # ...
        send_update(parent, Component, data)
      end)

  ## Testing async operations

  When testing LiveViews and LiveComponents with async assigns, use
  `Phoenix.LiveViewTest.render_async/2` to ensure the test waits until the async operations
  are complete before proceeding with assertions or before ending the test. For example:

      {:ok, view, _html} = live(conn, "/my_live_view")
      html = render_async(view)
      assert html =~ "My assertion"

  Not calling `render_async/2` to ensure all async assigns have finished might result in errors in
  cases where your process has side effects:

      [error] MyXQL.Connection (#PID<0.308.0>) disconnected: ** (DBConnection.ConnectionError) client #PID<0.794.0>
  """
  defmacro assign_async(socket, key_or_keys, func, opts \\ []) do
    Async.assign_async(socket, key_or_keys, func, opts, __CALLER__)
  end

  @doc """
  Wraps your function in an asynchronous task and invokes a callback `name` to
  handle the result.

  The task is linked to the caller and errors/exits are wrapped.
  The result of the task is sent to the `c:handle_async/3` callback
  of the caller LiveView or LiveComponent.

  If there is an in-flight task with the same `name`, the later `start_async` wins and the previous task’s result is ignored.
  If you wish to replace an existing task, you can use `cancel_async/3` before `start_async/3`.
  You are not restricted to just atoms for `name`, it can be any term such as a tuple.

  The task is only started when the socket is connected.

  ## Options

    * `:supervisor` - allows you to specify a `Task.Supervisor` to supervise the task.

  ## Examples

      def mount(%{"id" => id}, _, socket) do
        {:ok,
         socket
         |> assign(:org, AsyncResult.loading())
         |> start_async(:my_task, fn -> fetch_org!(id) end)}
      end

      def handle_async(:my_task, {:ok, fetched_org}, socket) do
        %{org: org} = socket.assigns
        {:noreply, assign(socket, :org, AsyncResult.ok(org, fetched_org))}
      end

      def handle_async(:my_task, {:exit, reason}, socket) do
        %{org: org} = socket.assigns
        {:noreply, assign(socket, :org, AsyncResult.failed(org, {:exit, reason}))}
      end

  See the moduledoc for more information.
  """
  defmacro start_async(socket, name, func, opts \\ []) do
    Async.start_async(socket, name, func, opts, __CALLER__)
  end

  @doc """
  Cancels an async operation if one exists.

  Accepts either the `%AsyncResult{}` when using `assign_async/3` or
  the key passed to `start_async/3`.

  The underlying process will be killed with the provided reason, or
  with `{:shutdown, :cancel}` if no reason is passed. For `assign_async/3`
  operations, the `:failed` field will be set to `{:exit, reason}`.
  For `start_async/3`, the `c:handle_async/3` callback will receive
  `{:exit, reason}` as the result.

  Returns the `%Phoenix.LiveView.Socket{}`.

  ## Examples

      cancel_async(socket, :preview)
      cancel_async(socket, :preview, :my_reason)
      cancel_async(socket, socket.assigns.preview)
  """
  def cancel_async(socket, async_or_keys, reason \\ {:shutdown, :cancel}) do
    Async.cancel_async(socket, async_or_keys, reason)
  end
end
