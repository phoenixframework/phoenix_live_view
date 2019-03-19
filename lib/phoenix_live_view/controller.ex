defmodule Phoenix.LiveView.Controller do
  @moduledoc """
  The Controller for LiveView rendering.
  """

  @behaviour Plug

  alias Phoenix.LiveView

  @doc """
  Renders a live view from a Plug request and sends an HTML response.

  ## Options

    * `:session` - the map of session data to sign and send
      to the client. When connecting from the client, the live view
      will receive the signed session from the client and verify
      the contents before proceeding with `mount/2`.

  Before render the `@live_view_module` assign will be added to the
  connection assigns for reference.

  ## Examples

      alias Phoenix.LiveView

      def ThermostatController do
        def show(conn, %{"id" => thermostat_id}) do
          LiveView.Controller.live_render(conn, ThermostatView, session: %{
            thermostat_id: id,
            current_user_id: get_session(conn, :user_id),
          })
        end
      end

  """
  def live_render(%Plug.Conn{} = conn, view, opts) do
    endpoint = Phoenix.Controller.endpoint_module(conn)

    case LiveView.View.static_render(endpoint, view, opts) do
      {:ok, content} ->
        conn
        |> Plug.Conn.assign(:live_view_module, view)
        |> Phoenix.Controller.put_view(__MODULE__)
        |> Phoenix.Controller.render("template.html", %{
          conn: conn,
          content: content
        })

      {:stop, {:redirect, opts}} ->
        Phoenix.Controller.redirect(conn, to: Map.fetch!(opts, :to))
    end
  end

  @doc false
  @impl Plug
  def init(opts), do: opts

  @doc false
  @impl Plug
  def call(conn, view) do
    session_opts = conn.private.phoenix_live_view[:session] || [:path_params]
    live_render(conn, view, session: session(conn, session_opts))
  end

  defp session(conn, session_opts) do
    Enum.reduce(session_opts, %{}, fn
      :path_params, acc -> Map.put(acc, :path_params, conn.path_params)
      key, acc -> Map.put(acc, key, Plug.Conn.get_session(conn, key))
    end)
  end

  @doc false
  # acts as a view via put_view to maintain the
  # controller render + instrumentation stack
  def render("template.html", %{content: content}) do
    content
  end
  def render(_other, _assigns), do: nil
end
