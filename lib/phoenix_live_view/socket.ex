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
    case connect_info do
      %{session: session} when is_map(session) ->
        {:ok, put_in(socket.private[:session], session)}

      %{session: _} ->
        Logger.debug("""
        LiveView session was misconfigured or the user token is outdated.

        1) Ensure your session configuration in your endpoint is in a module attribute:

            @session_options [
              ...
            ]

        2) Change the `plug Plug.Session` to use said attribute:

            plug Plug.Session, @session_options

        3) Also pass the `@session_options` to your LiveView socket:

            socket "/live", Phoenix.LiveView.Socket,
              websocket: [connect_info: [session: @session_options]]

        4) Define the CSRF meta tag inside the `<head>` tag in your layout:

            <%= csrf_meta_tag() %>

        5) Pass it forward in your app.js:

            let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
            let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}});
        """)

        :error

      %{} ->
        {:ok, put_in(socket.private[:session], %{})}
    end
  end

  @doc """
  Identifies the Phoenix.Socket for a LiveView client.
  """
  @impl Phoenix.Socket
  def id(socket), do: socket.private[:session]["live_socket_id"]
end
