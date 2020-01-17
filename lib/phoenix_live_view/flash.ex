defmodule Phoenix.LiveView.Flash do
  @moduledoc """
  Fetches Phoenix LiveView flash messages from cookie token.

  ## Examples

      plug Phoenix.LiveView.Flash

  By default, the signing salt for the token is pulled from
  your endpoint's LiveView config, for example:

      config :my_app, MyAppWeb.Endpoint,
        ...,
        live_view: [signing_salt: ...]

  The `:signing_salt` option may also be passed directly to the plug.
  """

  @valid_keys [:signing_salt]

  @behaviour Plug

  @cookie_key "__phoenix_flash__"

  @impl Plug
  def init(opts) do
    if Keyword.keys(opts) -- @valid_keys != [] do
      raise ArgumentError, """
      invalid options passed to #{inspect(__MODULE__)}.

      Valid options include #{inspect(@valid_keys)}, got: #{inspect(opts)}
      """
    end

    opts
  end

  @impl Plug
  def call(conn, opts) do
    case cookie_flash(conn, salt(conn, opts)) do
      {conn, nil} ->
        Phoenix.Controller.fetch_flash(conn, [])

      {conn, flash} ->
        conn
        |> Plug.Conn.put_session("phoenix_flash", flash)
        |> Phoenix.Controller.fetch_flash([])
    end
  end

  defp cookie_flash(%Plug.Conn{cookies: %{@cookie_key => token}} = conn, salt) do
    flash =
      case Phoenix.Token.verify(conn, salt, token, max_age: 60_000) do
        {:ok, %{} = flash} ->
          for {k, v} when is_binary(k) and is_binary(v) <- flash, into: %{}, do: {k, v}

        _ ->
          nil
      end

    {Plug.Conn.delete_resp_cookie(conn, @cookie_key), flash}
  end

  defp cookie_flash(%Plug.Conn{} = conn, _salt), do: {conn, nil}

  defp salt(conn, opts) do
    endpoint = Phoenix.Controller.endpoint_module(conn)
    opts[:signing_salt] || Phoenix.LiveView.Utils.salt!(endpoint)
  end

  @doc false
  def sign(endpoint_mod, salt, %{} = flash) do
    Phoenix.Token.sign(endpoint_mod, salt, flash)
  end
end
