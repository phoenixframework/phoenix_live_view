defmodule Phoenix.LiveView.Socket.AssignsNotInSocket do
  @moduledoc false

  defimpl Inspect do
    def inspect(_, _) do
      "#Phoenix.LiveView.Socket.AssignsNotInSocket<>"
    end
  end

  defstruct [:__assigns__]
  @type t :: %__MODULE__{}
end

defmodule Phoenix.LiveView.Socket do
  @moduledoc """
  The LiveView socket for Phoenix Endpoints.

  This is typically mounted directly in your endpoint.

      socket "/live", Phoenix.LiveView.Socket,
        websocket: [connect_info: [session: @session_options]]

  To share an underlying transport connection between regular
  Phoenix channels and LiveView processes, `use Phoenix.LiveView.Socket`
  from your own `MyAppWeb.UserSocket` module.

  Next, declare your `channel` definitions and optional `connect/3`, and
  `id/1` callbacks to handle your channel specific needs, then mount
  your own socket in your endpoint:

      socket "/live", MyAppWeb.UserSocket,
        websocket: [connect_info: [session: @session_options]]

  If you require session options to be set at runtime, you can use
  an MFA tuple. The function it designates must return a keyword list.

      socket "/live", MyAppWeb.UserSocket,
        websocket: [connect_info: [session: {__MODULE__, :runtime_opts, []}]]

      # ...

      def runtime_opts() do
        Keyword.put(@session_options, :domain, host())
      end

  ## Socket options

  Options given to `use Phoenix.LiveView.Socket` are forwarded to
  `use Phoenix.Socket`. See the "Using options" section of `Phoenix.Socket`
  for the supported options. For example, each file upload entry joins its
  own channel when using the default uploader, so allowing many concurrent
  uploads may require raising `:max_channels_per_transport`:

      defmodule MyAppWeb.UserSocket do
        use Phoenix.LiveView.Socket, max_channels_per_transport: 200
      end

  ## Resumable sockets

  Since Phoenix 1.9, a client can resume its socket over a new connection
  after the previous one failed. The LiveViews keep running on the server,
  so they don't mount again, and the client receives the updates it missed.
  Long polling always works this way. For WebSockets, enable the `:resumable`
  option on the server:

      socket "/live", Phoenix.LiveView.Socket,
        websocket: [resumable: true, connect_info: [session: @session_options]],
        longpoll: [connect_info: [session: @session_options]]

  and on the client:

      let liveSocket = new LiveSocket("/live", Socket, {
        resumable: true,
        longPollFallbackMs: 2500,
        params: {_csrf_token: csrfToken}
      })

  With `longPollFallbackMs`, a client that cannot resume its socket over
  a WebSocket in time continues it with long polling. See the `:resumable`
  option of `Phoenix.Endpoint.socket/3` for how long the server keeps
  the socket.

  While the client cannot resume its socket, LiveView shows the same state
  as for a lost connection: the LiveView containers get the `phx-loading`,
  `phx-error` and `phx-client-error` classes, `phx-disconnected` commands run,
  and the `disconnected` callbacks of hooks are invoked. After the resume,
  `phx-connected` commands run and the `reconnected` callbacks of hooks
  are invoked.

  ### Checking the session on resume

  Resuming does not invoke `connect/3`. Instead, `Phoenix.LiveView.Socket`
  checks the session of the new connection in `c:Phoenix.Socket.resume/3`.
  The client resumes only if the session of the new connection has the same
  `"live_socket_id"` as the session of the first connection, or if neither
  has one. Otherwise, the socket stops. This happens, for example, when:

    * the user logged out or the session expired, so the `"live_socket_id"`
      is missing or different

    * the user logged in, for example in another tab, so the session has a
      `"live_socket_id"` it did not have before

  The client then connects again, which invokes `connect/3` and sets the
  socket id. Its LiveViews mount again, which runs your `on_mount` hooks.

  The check only compares the `"live_socket_id"`, as other session keys, such
  as the flash, change while the user stays logged in. It requires the session
  in the `:connect_info` of both transports, as shown above. Projects generated
  with `mix phx.new` already configure it. When the session is not configured,
  every resume is accepted.

  After a resume, LiveViews that mount on the socket see the `connect_info`
  of the new connection, for example in `Phoenix.LiveView.get_connect_info/2`.
  LiveViews that were already mounted keep their state.

  Sockets defined with `use Phoenix.LiveView.Socket` run the same check. They
  can define `resume/3` for additional checks, which runs only when the session
  check passed. Its socket already contains the new `connect_info`.
  Return `:error` to stop the socket, for example when the user token
  in the session is no longer valid:

      defmodule MyAppWeb.UserSocket do
        use Phoenix.LiveView.Socket

        @impl true
        def resume(_params, socket, connect_info) do
          if MyApp.Accounts.get_user_by_session_token(connect_info.session["user_token"]) do
            {:ok, socket}
          else
            :error
          end
        end
      end

  ## Adoptable LiveViews

  > #### Experimental {: .warning}
  >
  > Adoptable LiveViews are experimental and might change in future releases.
  > They require a Phoenix version with `Phoenix.Socket.start_detached/3`.

  Adoptable LiveViews mount once during the HTTP request. The request starts a
  detached socket session, mounts the LiveView in connected mode, and uses its
  HTML to render the page. When the client connects, it attaches to the session
  and receives any updates sent since the initial render.

  By default, LiveViews mount once for the HTTP response and again when the
  client connects.

  Enable it per LiveView:

      use Phoenix.LiveView, adoptable: true

  It requires a resumable socket, see "Resumable sockets" above, and the path of
  that socket in the `:adopt` configuration of the endpoint:

      config :my_app, MyAppWeb.Endpoint,
        live_view: [signing_salt: "...", adopt: [socket: "/live"]]

  The `:adopt` configuration accepts:

    * `:socket` - the path of the socket the client connects to. Required.

    * `:max_pending` - the maximum number of sessions waiting for client attachment
      on a node. At the limit, new requests render without adoption. Defaults to
      `10_000`. `nil` disables the limit.

    * `:window_ms` - the base timeout for client attachment, in milliseconds.
      The server uses `1.5 × :window_ms` as the session timeout. Defaults to the
      `:window_ms` of the socket.

    * `:enabled` - `true`, `false`, or an MFA tuple that receives the conn,
      followed by the arguments of the tuple, and returns a boolean.
      Defaults to `true`. Use a function to skip adoption for some requests,
      for example for crawlers that never connect.

  The client adopts the LiveView when its `LiveSocket` connects to the same path,
  and uses a resumable transport for it, even without the `resumable` option.
  When it cannot attach, for example because the session expired, it connects
  as usual and the LiveView mounts again.

  Adoption changes the mount in these ways:

    * `connected?/1` returns `true` during the HTTP request, and
      `get_connect_params/1` returns `nil`, as the client did not connect yet.
      See "Data from the client" below

    * `assign_new/3` uses the assigns of the conn, as in a disconnected mount

    * the LiveView runs in a separate process. The HTTP request propagates
      exceptions, exits, and throws from `mount/3` and `handle_params/3`.
      Redirects and patches during mount produce HTTP redirects.

    * child LiveViews rendered with `live_render/3` render empty containers
      in the HTTP response and mount when the client connects

  ### Data from the client

  Adoptable LiveViews have no connect params, as they mount before the client
  connects. Store data that the first render needs, such as the preferred
  language or time zone, in the session instead. The dead render then shows
  the same as the connected one.

  For data that only the client knows, push an event once the LiveView joined,
  with a hook on an element of the layout that your LiveViews render:

  ```heex
  <div id="client-info" phx-hook="ClientInfo" class="hidden"></div>
  ```

  ```javascript
  const ClientInfo = {
    mounted() {
      this.pushEvent("client-info", {
        time_zone: Intl.DateTimeFormat().resolvedOptions().timeZone
      })
    }
  }
  ```

  The hook runs after every join, adopted or not, so the LiveView handles the
  event the same way in both cases, for example in an `on_mount` hook:

      def on_mount(:default, _params, _session, socket) do
        {:cont,
         attach_hook(socket, :client_info, :handle_event, fn
           "client-info", %{"time_zone" => time_zone}, socket ->
             {:halt, assign(socket, :time_zone, time_zone)}

           _event, _params, socket ->
             {:cont, socket}
         end)}
      end

  This also defers work until the client connects: a LiveView that starts
  expensive work in this event instead of `mount/3` does not run it for
  clients that never connect, such as crawlers.

  Tests that use `Phoenix.LiveViewTest` render adoptable LiveViews as before, in the
  test process, so they keep sharing resources such as the database sandbox.

  All adoptable LiveViews rendered during one HTTP request share a socket session.
  This includes LiveViews rendered by templates with `Phoenix.Component.live_render/3`.

  LiveView stores the session in the process dictionary. For LiveViews that a
  controller template renders with `Phoenix.Component.live_render/3`, the web
  server must use a separate process for each request or clear the process
  dictionary between requests. Cowboy and Bandit meet this requirement.

  If page rendering fails after a LiveView mounts, the socket session stops after
  the attachment timeout expires.
  """
  use Phoenix.Socket

  @derive {Inspect,
           only: [
             :id,
             :endpoint,
             :router,
             :view,
             :parent_pid,
             :root_pid,
             :assigns,
             :transport_pid,
             :sticky?
           ]}

  defstruct id: nil,
            endpoint: nil,
            view: nil,
            parent_pid: nil,
            root_pid: nil,
            router: nil,
            assigns: %{__changed__: %{}},
            private: %{live_temp: %{}},
            redirected: nil,
            host_uri: nil,
            transport_pid: nil,
            sticky?: false

  @typedoc "Struct returned when `assigns` is not in the socket."
  @opaque assigns_not_in_socket :: Phoenix.LiveView.Socket.AssignsNotInSocket.t()

  @typedoc "The data in a LiveView as stored in the socket."
  @type assigns :: map | assigns_not_in_socket()

  @type t :: %__MODULE__{
          id: binary(),
          endpoint: module(),
          view: module(),
          parent_pid: nil | pid(),
          root_pid: pid(),
          router: module(),
          assigns: assigns,
          private: map(),
          redirected: nil | tuple(),
          host_uri: URI.t() | :not_mounted_at_router,
          transport_pid: pid() | nil
        }

  channel "lvu:*", Phoenix.LiveView.UploadChannel
  channel "lv:*", Phoenix.LiveView.Channel

  @impl Phoenix.Socket
  def connect(_params, %Phoenix.Socket{} = socket, connect_info) do
    {:ok, put_in(socket.private[:connect_info], connect_info)}
  end

  @impl Phoenix.Socket
  def id(socket), do: socket.private.connect_info[:session]["live_socket_id"]

  # We compare the live_socket_id of the sessions instead of the socket id,
  # as sockets that use this module can define their own id/1.
  # TODO: Use @impl Phoenix.Socket when we require Phoenix 1.9
  @impl {:resume, 3} in Phoenix.Socket.behaviour_info(:callbacks)
  @doc false
  def resume(_params, %Phoenix.Socket{} = socket, connect_info) do
    # A session that gained a live_socket_id must connect again, so the socket
    # gets the id and LiveViews mounted afterwards receive its "disconnect".
    if live_socket_id(socket.private[:connect_info]) == live_socket_id(connect_info) do
      {:ok, put_in(socket.private[:connect_info], connect_info)}
    else
      :error
    end
  end

  defp live_socket_id(%{session: %{"live_socket_id" => id}}), do: id
  defp live_socket_id(_connect_info), do: nil

  defmacro __using__(opts) do
    quote do
      use Phoenix.Socket, unquote(opts)

      channel "lvu:*", Phoenix.LiveView.UploadChannel
      channel "lv:*", Phoenix.LiveView.Channel

      def connect(params, socket, info), do: {:ok, socket}
      def resume(params, socket, info), do: {:ok, socket}
      defdelegate id(socket), to: unquote(__MODULE__)

      defoverridable connect: 3, resume: 3, id: 1

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      defoverridable connect: 3, resume: 3, id: 1

      def connect(params, %Phoenix.Socket{} = socket, connect_info) do
        with {:ok, %Phoenix.Socket{} = new_socket} <- super(params, socket, connect_info) do
          Phoenix.LiveView.Socket.connect(params, new_socket, connect_info)
        end
      end

      # The session check runs first, so a resume/3 of the socket only
      # sees connections of the same session, with their connect_info.
      def resume(params, %Phoenix.Socket{} = socket, connect_info) do
        with {:ok, %Phoenix.Socket{} = new_socket} <-
               Phoenix.LiveView.Socket.resume(params, socket, connect_info) do
          super(params, new_socket, connect_info)
        end
      end
    end
  end
end
