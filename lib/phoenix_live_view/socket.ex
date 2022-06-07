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
  form your own `MyAppWeb.UserSocket` module.

  Next, declare your `channel` definitions and optional `connect/3`, and
  `id/1` callbacks to handle your channel specific needs, then mount
  your own socket in your endpoint:

      socket "/live", MyAppWeb.UserSocket,
        websocket: [connect_info: [session: @session_options]]
  """
  use Phoenix.Socket

  require Logger

  @derive {Inspect,
           only: [
             :id,
             :endpoint,
             :router,
             :view,
             :parent_pid,
             :root_pid,
             :assigns,
             :transport_pid
           ]}

  defstruct id: nil,
            endpoint: nil,
            view: nil,
            parent_pid: nil,
            root_pid: nil,
            router: nil,
            assigns: %{__changed__: %{}},
            private: %{__changed__: %{}},
            fingerprints: Phoenix.LiveView.Diff.new_fingerprints(),
            redirected: nil,
            host_uri: nil,
            transport_pid: nil

  @typedoc "Struct returned when `assigns` is not in the socket."
  @opaque assigns_not_in_socket :: Phoenix.LiveView.Socket.AssignsNotInSocket.t()

  @typedoc "The data in a LiveView as stored in the socket."
  @type assigns :: map | assigns_not_in_socket()

  @type fingerprints :: {nil, map} | {binary, map}

  @type t :: %__MODULE__{
          id: binary(),
          endpoint: module(),
          view: module(),
          parent_pid: nil | pid(),
          root_pid: pid(),
          router: module(),
          assigns: assigns,
          private: map(),
          fingerprints: fingerprints,
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

  defmacro __using__(_opts) do
    quote do
      use Phoenix.Socket

      channel "lvu:*", Phoenix.LiveView.UploadChannel
      channel "lv:*", Phoenix.LiveView.Channel

      @phoenix_connect false
      @phoenix_id false

      @before_compile unquote(__MODULE__)
      @on_definition unquote(__MODULE__)
    end
  end

  def __on_definition__(env, :def, :connect, [_, _, _], _guards, _body) do
    Module.put_attribute(env.module, :phoenix_connect, true)
  end

  def __on_definition__(env, :def, :id, [_], _guards, _body) do
    Module.put_attribute(env.module, :phoenix_id, true)
  end

  def __on_definition__(_env, _kind, _name, _args, _guards, _body), do: :ok

  defmacro __before_compile__(_env) do
    quote do
      if @phoenix_connect do
        defoverridable connect: 3

        def connect(params, %Phoenix.Socket{} = socket, connect_info) do
          case super(params, socket, connect_info) do
            {:ok, %Phoenix.Socket{} = new_socket} ->
              Phoenix.LiveView.Socket.connect(params, new_socket, connect_info)

            other ->
              other
          end
        end
      else
        defdelegate connect(params, socket, info), to: unquote(__MODULE__)
      end

      unless @phoenix_id do
        defdelegate id(socket), to: unquote(__MODULE__)
      end
    end
  end
end
