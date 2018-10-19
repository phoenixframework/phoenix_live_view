defmodule Phoenix.LiveView.Flash do
  @moduledoc """
  Fetches Phoenix live view flash messages from cookie token.

  ## Examples


      plug Phoenix.LiveView.Flash

  """

  @behaviour Plug

  @cookie_key "__phoenix_flash__"
  @salt "phoenix liveview flash"

  @impl Plug
  def init(opts), do: opts

  @doc """
  Fetches the live flash from a token passed via client cookies.
  """
  @impl Plug
  def call(conn, _opts) do
    case cookie_flash(conn) do
      {conn, nil} -> Phoenix.Controller.fetch_flash(conn, [])
      {conn, flash} ->
        conn
        |> Plug.Conn.put_session("phoenix_flash", flash)
        |> Phoenix.Controller.fetch_flash([])
    end
  end
  defp cookie_flash(%Plug.Conn{cookies: %{@cookie_key => token}} = conn) do
    flash =
      case Phoenix.Token.verify(conn, @salt, token, max_age: 60_000) do
        {:ok, json_flash} -> Phoenix.json_library().decode!(json_flash)
        {:error, _reason} -> nil
      end

    {Plug.Conn.delete_resp_cookie(conn, @cookie_key), flash}
  end
  defp cookie_flash(%Plug.Conn{} = conn), do: {conn, nil}

  @doc """
  Signs the live view flash into a token.
  """
  def sign_token(endpoint_mod, %{} = flash) do
    Phoenix.Token.sign(endpoint_mod, @salt, Phoenix.json_library().encode!(flash))
  end
end
