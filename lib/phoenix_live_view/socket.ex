defmodule Phoenix.LiveView.Socket.AssignsNotInSocket do
  @moduledoc """
  Struct for socket.assigns while rendering.

  The socket assigns are available directly inside the template
  as LiveEEx `assigns`, such as `@foo` and `@bar`. Any assign access
  should be done using the assigns in the template where proper change
  tracking takes place.
  """
  defstruct []
  @type t :: %__MODULE__{}
end

defmodule Phoenix.LiveView.Socket do
  @moduledoc """
  The LiveView socket for Phoenix Endpoints.
  """
  use Phoenix.Socket
  require Logger

  if Version.match?(System.version(), ">= 1.8.0") do
    @derive {Inspect,
             only: [:id, :endpoint, :router, :view, :parent_pid, :root_pid, :assigns, :changed]}
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
            private: %{},
            fingerprints: Phoenix.LiveView.Diff.new_fingerprints(),
            redirected: nil,
            connected?: false

  @type t :: %__MODULE__{}
  @type unsigned_params :: map
  @type assigns :: map | Phoenix.LiveView.Socket.AssignsNotInSocket.t()

  channel "lv:*", Phoenix.LiveView.Channel

  @doc """
  Connects the Phoenix.Socket for a LiveView client.
  """
  @impl Phoenix.Socket
  def connect(_params, %Phoenix.Socket{} = socket, connect_info) do
    {:ok, put_in(socket.private[:connect_info], connect_info)}
  end

  @doc """
  Identifies the Phoenix.Socket for a LiveView client.
  """
  @impl Phoenix.Socket
  def id(socket), do: socket.private.connect_info[:session]["live_socket_id"]
end
