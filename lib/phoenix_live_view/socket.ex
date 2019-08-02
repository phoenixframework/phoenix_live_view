defmodule Phoenix.LiveView.Socket do
  @moduledoc """
  The LiveView socket for Phoenix Endpoints.
  """
  use Phoenix.Socket

  defstruct id: nil,
            endpoint: nil,
            view: nil,
            router: nil,
            parent_pid: nil,
            assigns: %{},
            changed: %{},
            temporary: %{},
            fingerprints: {nil, %{}},
            private: %{},
            mounted: false,
            redirected: nil,
            connected?: false

  channel "lv:*", Phoenix.LiveView.Channel

  @doc """
  Connects the Phoenix.Socket for a LiveView client.
  """
  @impl Phoenix.Socket
  def connect(_params, %Phoenix.Socket{} = socket, connect_info) do
    case connect_info do
      %{session: nil} ->
        # TODO: tell them to pass the CSRF token
        {:error, :session_is_nil}

      %{session: session} ->
        token = Map.get(session, "_csrf_token")
        {:ok, put_in(socket.private[:csrf_token], token)}

      _ ->
        # TODO: tell them to pass the CSRF token
        {:error, :no_session_info}
    end
  end

  @doc """
  Identifies the Phoenix.Socket for a LiveView client.
  """
  @impl Phoenix.Socket
  def id(_socket), do: nil
end
