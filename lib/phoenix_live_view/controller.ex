defmodule Phoenix.LiveView.Controller do
  @moduledoc """
  The Controller for LiveView rendering.
  """

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

      defmodule ThermostatController do
        ...
        import Phoenix.LiveView.Controller

        def show(conn, %{"id" => thermostat_id}) do
          live_render(conn, ThermostatLive, session: %{
            thermostat_id: id,
            current_user_id: get_session(conn, :user_id),
          })
        end
      end

  """
  def live_render(%Plug.Conn{} = conn, view, opts \\ []) do
    case LiveView.View.static_render(conn, view, opts) do
      {:ok, content} ->
        conn
        |> Plug.Conn.assign(:live_view_module, view)
        |> Phoenix.Controller.put_view(LiveView.View)
        |> LiveView.Plug.put_cache_headers()
        |> Phoenix.Controller.render("template.html", %{content: content})

      {:stop, {:redirect, opts}} ->
        Phoenix.Controller.redirect(conn, to: Map.fetch!(opts, :to))

      {:stop, {:live, opts}} ->
        Phoenix.Controller.redirect(conn, to: Map.fetch!(opts, :to))
    end
  end
end
