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
