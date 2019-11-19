defmodule Phoenix.LiveView.Socket do
  @moduledoc """
  The LiveView socket for Phoenix Endpoints.
  """
  use Phoenix.Socket
  require Logger

  if Version.match?(System.version(), ">= 1.8.0") do
    @derive {Inspect, only: [:id, :endpoint, :view, :parent_pid, :root_id, :assigns, :changed]}
  end

  defstruct id: nil,
            endpoint: nil,
            view: nil,
            parent_pid: nil,
            root_pid: nil,
            assigns: %{},
            changed: %{},
            private: %{},
            fingerprints: Phoenix.LiveView.Diff.new_fingerprints(),
            redirected: nil,
            connected?: false

  @type t :: %__MODULE__{}
  @type unsigned_params :: map
  @type assigns :: map

  channel "lv:*", Phoenix.LiveView.Channel

  @doc """
  Connects the Phoenix.Socket for a LiveView client.
  """
  @impl Phoenix.Socket
  def connect(_params, %Phoenix.Socket{} = socket, connect_info) do
    case connect_info do
      %{session: session} when is_map(session) ->
        {:ok, put_in(socket.private[:session], session)}

      _ ->
        Logger.error("""
        LiveView was not configured to use session. Do so with:

        1) Find `plug Plug.Session, ...` in your endpoint.ex and move the options `...` to a module attribute:

            @session_options [
              ...
            ]

        2) Change the `plug Plug.Session` to use said attribute:

            plug Plug.Session, @session_options

        3) And pass said options to your LiveView socket:

            socket "/live", Phoenix.LiveView.Socket,
              websocket: [connect_info: [session: @session_options]]

        4) You should define the CSRF meta tag inside the in <head> in your layout:

            <%= csrf_meta_tag() %>

        5) Then in your app.js:

            let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
            let liveSocket = new LiveSocket("/live", {params: {_csrf_token: csrfToken}});
        """)

        :error
    end
  end

  @doc """
  Identifies the Phoenix.Socket for a LiveView client.
  """
  @impl Phoenix.Socket
  def id(socket), do: socket.private[:session]["live_socket_id"]
end
