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
  pubsub_server: Phoenix.LiveViewTest.E2E.PubSub,
  debug_errors: false
)

defmodule Phoenix.LiveViewTest.E2E.ErrorHTML do
  def render(template, _), do: Phoenix.Controller.status_message_from_template(template)
end

defmodule Phoenix.LiveViewTest.E2E.Layout do
  use Phoenix.Component

  def render("live.html", assigns) do
    ~H"""
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <script src="/assets/phoenix/phoenix.min.js"></script>
    <script src="/assets/phoenix_live_view/phoenix_live_view.js"></script>
    <script>
      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
      let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket, {params: {_csrf_token: csrfToken}})
      liveSocket.connect()
      window.liveSocket = liveSocket
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
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
  end

  live_session :default, layout: {Phoenix.LiveViewTest.E2E.Layout, :live} do
    scope "/", Phoenix.LiveViewTest do
      pipe_through(:browser)

      live "/stream", StreamLive
      live "/stream/reset", StreamResetLive
      live "/stream/reset-lc", StreamResetLCLive
      live "/stream/limit", StreamLimitLive
      live "/healthy/:category", HealthyLive

      live "/upload", E2E.UploadLive
      live "/form", E2E.FormLive
      live "/form/dynamic-inputs", E2E.FormDynamicInputsLive
      live "/js", E2E.JsLive
    end

    scope "/issues", Phoenix.LiveViewTest.E2E do
      pipe_through(:browser)

      live "/3026", Issue3026Live
      live "/3040", Issue3040Live
    end
  end

  live_session :navigation, layout: {Phoenix.LiveViewTest.E2E.Navigation.Layout, :live} do
    scope "/navigation" do
      pipe_through(:browser)

      live "/a", Phoenix.LiveViewTest.E2E.Navigation.ALive
      live "/b", Phoenix.LiveViewTest.E2E.Navigation.BLive
      live "/c", Phoenix.LiveViewTest.E2E.Navigation.CLive, :index
      live "/c/:id", Phoenix.LiveViewTest.E2E.Navigation.CLive, :show
    end
  end

  # these routes use a custom layout and therefore cannot be in the live_session
  scope "/issues" do
    pipe_through(:browser)

    live "/3047/a", Phoenix.LiveViewTest.E2E.Issue3047ALive
    live "/3047/b", Phoenix.LiveViewTest.E2E.Issue3047BLive
  end
end

defmodule Phoenix.LiveViewTest.E2E.Endpoint do
  use Phoenix.Endpoint, otp_app: :phoenix_live_view

  @session_options [
    store: :cookie,
    key: "_lv_e2e_key",
    signing_salt: "1gk/d8ms",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Static, from: {:phoenix, "priv/static"}, at: "/assets/phoenix"
  plug Plug.Static, from: {:phoenix_live_view, "priv/static"}, at: "/assets/phoenix_live_view"
  plug Plug.Static, from: System.tmp_dir!(), at: "/tmp"

  plug :health_check

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.Session, @session_options
  plug Phoenix.LiveViewTest.E2E.Router

  defp health_check(%{request_path: "/health"} = conn, _opts) do
    conn |> Plug.Conn.send_resp(200, "OK") |> Plug.Conn.halt()
  end

  defp health_check(conn, _opts), do: conn
end

{:ok, _} =
  Supervisor.start_link(
    [
      Phoenix.LiveViewTest.E2E.Endpoint,
      {Phoenix.PubSub, name: Phoenix.LiveViewTest.E2E.PubSub}
    ],
    strategy: :one_for_one
  )

Process.sleep(:infinity)
