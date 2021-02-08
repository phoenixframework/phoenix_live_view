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

      socket "/live", Phoenix.LiveView.Socket

  """
  use Phoenix.Socket

  require Logger

  if Version.match?(System.version(), ">= 1.8.0") do
    @derive {Inspect,
             only: [
               :assigns,
               :changed,
               :endpoint,
               :id,
               :parent_pid,
               :remote_ip,
               :root_pid,
               :router,
               :user_agent,
               :view,
               :x_headers
             ]}
  end

  defstruct id: nil,
            endpoint: nil,
            view: nil,
            root_view: nil,
            parent_pid: nil,
            root_pid: nil,
            router: nil,
            assigns: %{},
            changed: %{},
            private: %{changed: %{}},
            fingerprints: Phoenix.LiveView.Diff.new_fingerprints(),
            redirected: nil,
            host_uri: nil,
            remote_ip: nil,
            user_agent: nil,
            x_headers: [],
            connected?: false

  @type assigns :: map | Phoenix.LiveView.Socket.AssignsNotInSocket.t()
  @type fingerprints :: {nil, map} | {binary, map}

  @type t :: %__MODULE__{
          id: binary(),
          endpoint: module(),
          view: module(),
          root_view: module(),
          parent_pid: nil | pid(),
          root_pid: pid(),
          router: module(),
          assigns: assigns,
          changed: map(),
          private: map(),
          fingerprints: fingerprints,
          redirected: nil | tuple(),
          host_uri: URI.t(),
          remote_ip: tuple(),
          user_agent: String.t(),
          x_headers: keyword(),
          connected?: boolean()
        }

  channel "lvu:*", Phoenix.LiveView.UploadChannel
  channel "lv:*", Phoenix.LiveView.Channel

  @impl Phoenix.Socket
  def connect(_params, %Phoenix.Socket{} = socket, connect_info) do
    {:ok, put_in(socket.private[:connect_info], connect_info)}
  end

  @impl Phoenix.Socket
  def id(socket), do: socket.private.connect_info[:session]["live_socket_id"]
end
