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

  @max_age :timer.seconds(60)

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
  # TODO: We are overriding the session, which overrides all previous
  # flash in there. We need a public API for this. Maybe fetch_flash
  # shouldn't even execute again if the flash was already loaded.
  # Finally, there is a mismatch between string/atom keys in flash
  # that we may need to address. Also, make it official this has to
  # run after the original fetch_flash code.
  def call(conn, opts) do
    case cookie_flash(conn, salt(conn, opts)) do
      {conn, nil} -> conn
      {conn, flash} ->
        Enum.reduce(flash, conn, fn {kind, msg}, acc ->
          Phoenix.Controller.put_flash(acc, kind, msg, persist: false)
        end)
    end
  end

  defp cookie_flash(%Plug.Conn{cookies: %{@cookie_key => token}} = conn, salt) do
    flash =
      case Phoenix.Token.verify(conn, salt, token, max_age: 60_000) do
        {:ok, %{} = flash} -> flash
        _ -> nil
      end

    {Plug.Conn.delete_resp_cookie(conn, @cookie_key), flash}
  end

  defp cookie_flash(%Plug.Conn{} = conn, _salt), do: {conn, nil}

  defp salt(conn, opts) do
    "flash:" <>
      (opts[:signing_salt] ||
         conn |> Phoenix.Controller.endpoint_module() |> Phoenix.LiveView.Utils.salt!())
  end

  @doc false
  def sign(endpoint_mod, salt, %{} = flash) do
    Phoenix.Token.sign(endpoint_mod, salt, flash)
  end

  @doc false
  def verify!(endpoint, flash_token) do
    salt = Phoenix.LiveView.Utils.salt!(endpoint)
    case Phoenix.Token.verify(endpoint, salt, flash_token, max_age: @max_age) do
      {:ok, flash} -> flash
      {:error, :expired} -> nil
      {:error, :invalid} -> raise "invalid flash token"
    end
  end
end
