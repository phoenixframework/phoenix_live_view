defmodule Phoenix.LiveView.Flash do
  @moduledoc """
  Fetches Phoenix LiveView flash messages from cookie token.

  ## Examples

      plug Phoenix.LiveView.Flash

  The signing salt for the token is pulled from
  your endpoint's LiveView config, for example:

      config :my_app, MyAppWeb.Endpoint,
        ...,
        live_view: [signing_salt: ...]
  """

  @behaviour Plug

  @cookie_key "__phoenix_flash__"

  @max_age :timer.seconds(60)

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  # TODO: We are overriding the session, which overrides all previous
  # flash in there. We need a public API for this. Maybe fetch_flash
  # shouldn't even execute again if the flash was already loaded.
  # Finally, there is a mismatch between string/atom keys in flash
  # that we may need to address. Also, make it official this has to
  # run after the original fetch_flash code.
  def call(conn, _opts) do
    case cookie_flash(conn) do
      {conn, nil} ->
        Phoenix.Controller.fetch_flash(conn, [])

      {conn, flash} ->
        conn
        |> Plug.Conn.put_session("phoenix_flash", flash)
        |> Phoenix.Controller.fetch_flash([])
    end
  end

  defp cookie_flash(%Plug.Conn{cookies: %{@cookie_key => token}} = conn) do
    salt = salt(conn)
    flash =
      case Phoenix.Token.verify(conn, salt, token, max_age: @max_age) do
        {:ok, %{} = flash} -> flash
        other ->
          IO.inspect(other)
          nil
      end

    {Plug.Conn.delete_resp_cookie(conn, @cookie_key), flash}
  end

  defp cookie_flash(%Plug.Conn{} = conn), do: {conn, nil}

  defp salt(%Plug.Conn{} = conn) do
    conn |> Phoenix.Controller.endpoint_module() |> salt()
  end
  defp salt(endpoint_mod) when is_atom(endpoint_mod) do
    "flash:" <> Phoenix.LiveView.Utils.salt!(endpoint_mod)
  end

  @doc false
  def sign(endpoint_mod, %{} = flash) do
    Phoenix.Token.sign(endpoint_mod, salt(endpoint_mod), flash)
  end

  @doc false
  def verify!(endpoint_mod, flash_token) do
    salt = salt(endpoint_mod)
    case Phoenix.Token.verify(endpoint_mod, salt, flash_token, max_age: @max_age) do
      {:ok, flash} -> flash
      {:error, :expired} -> nil
      {:error, :invalid} -> raise "invalid flash token"
    end
  end
end
