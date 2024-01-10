Application.put_env(:phoenix_live_view, Phoenix.LiveViewTest.E2E.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  # TODO: switch to bandit when Phoenix 1.7 is used
  # adapter: Bandit.PhoenixAdapter,
  server: true,
  live_view: [signing_salt: "aaaaaaaa"],
  secret_key_base: String.duplicate("a", 64),
  render_errors: [
    # TODO: uncomment when LV Phoenix 1.7 is used
    # formats: [
    #   html: Phoenix.LiveViewTest.E2E.ErrorHTML,
    # ],
    view: Phoenix.LiveViewTest.E2E.ErrorHTML,
    layout: false
  ],
  debug_errors: true
)

defmodule Phoenix.LiveViewTest.E2E.ErrorHTML do
  def render(template, _), do: Phoenix.Controller.status_message_from_template(template)
end

defmodule Phoenix.LiveViewTest.E2E.Layout do
  use Phoenix.Component

  def render("live.html", assigns) do
    ~H"""
    <script src="/assets/phoenix/phoenix.min.js"></script>
    <script src="/assets/phoenix_live_view/phoenix_live_view.js"></script>
    <script>
      let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket)
      liveSocket.connect()
    </script>
    <style>
      * { font-size: 1.1em; }
    </style>
    <%= @inner_content %>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
  end

  live_session :default, layout: {Phoenix.LiveViewTest.E2E.Layout, :live} do
    scope "/" do
      pipe_through(:browser)

      live("/stream", Phoenix.LiveViewTest.StreamLive, :index)
    end
  end
end

defmodule Phoenix.LiveViewTest.E2E.Endpoint do
  use Phoenix.Endpoint, otp_app: :phoenix_live_view

  socket("/live", Phoenix.LiveView.Socket)

  plug Plug.Static, from: {:phoenix, "priv/static"}, at: "/assets/phoenix"
  plug Plug.Static, from: {:phoenix_live_view, "priv/static"}, at: "/assets/phoenix_live_view"

  plug :health_check

  plug Phoenix.LiveViewTest.E2E.Router

  defp health_check(%{request_path: "/health"} = conn, _opts) do
    conn |> Plug.Conn.send_resp(200, "OK") |> Plug.Conn.halt()
  end

  defp health_check(conn, _opts), do: conn
end

{:ok, _} = Supervisor.start_link([Phoenix.LiveViewTest.E2E.Endpoint], strategy: :one_for_one)
Process.sleep(:infinity)
