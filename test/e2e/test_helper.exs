Application.put_env(:phoenix_live_view, Phoenix.LiveViewTest.E2E.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4004],
  adapter: Bandit.PhoenixAdapter,
  server: true,
  live_view: [signing_salt: "aaaaaaaa"],
  secret_key_base: String.duplicate("a", 64),
  render_errors: [
    formats: [
      html: Phoenix.LiveViewTest.E2E.ErrorHTML
    ],
    layout: false
  ],
  pubsub_server: Phoenix.LiveViewTest.E2E.PubSub,
  debug_errors: false
)

Process.register(self(), :e2e_helper)

defmodule Phoenix.LiveViewTest.E2E.ErrorHTML do
  def render(template, _), do: Phoenix.Controller.status_message_from_template(template)
end

defmodule Phoenix.LiveViewTest.E2E.Layout do
  use Phoenix.Component

  def render("root.html", assigns) do
    ~H"""
    <%!-- no doctype -> quirks mode --%> <!DOCTYPE html> {@inner_content}
    """
  end

  def render("live.html", assigns) do
    ~H"""
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <script src="/assets/phoenix/phoenix.min.js">
    </script>
    <script type="module">
      import {LiveSocket} from "/assets/phoenix_live_view/phoenix_live_view.esm.js"

      let Hooks = {}
      Hooks.FormHook = {
        mounted() {
          this.pushEvent("ping", {}, () => this.el.innerText += "pong")
        }
      }
      Hooks.FormStreamHook = {
        mounted() {
          this.pushEvent("ping", {}, () => this.el.innerText += "pong")
        }
      }
      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
      let liveSocket = new LiveSocket("/live", window.Phoenix.Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks})
      liveSocket.connect()
      window.liveSocket = liveSocket
    </script>
    <style>
      * { font-size: 1.1em; }
    </style>
    {@inner_content}
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Hooks do
  import Phoenix.LiveView

  require Logger

  def on_mount(:default, _params, _session, socket) do
    socket
    |> attach_hook(:eval_handler, :handle_event, &handle_eval_event/3)
    |> then(&{:cont, &1})
  end

  # evaluates the given code in the process of the LiveView
  # see playwright evalLV() function
  defp handle_eval_event("sandbox:eval", %{"value" => code}, socket) do
    {result, _} = Code.eval_string(code, [socket: socket], __ENV__)

    Logger.debug("lv:#{inspect(self())} eval result: #{inspect(result)}")

    case result do
      {:noreply, %Phoenix.LiveView.Socket{} = socket} -> {:halt, %{}, socket}
      %Phoenix.LiveView.Socket{} = socket -> {:halt, %{}, socket}
      result -> {:halt, %{"result" => result}, socket}
    end
  end

  defp handle_eval_event(_, _, socket), do: {:cont, socket}
end

defmodule Phoenix.LiveViewTest.E2E.EvalController do
  use Phoenix.Controller

  plug :accepts, ["json"]

  def eval(conn, %{"code" => code} = _params) do
    {result, _} = Code.eval_string(code, [], __ENV__)
    json(conn, result)
  end
end

defmodule Phoenix.LiveViewTest.E2E.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_root_layout, html: {Phoenix.LiveViewTest.E2E.Layout, :root}
  end

  live_session :default,
    layout: {Phoenix.LiveViewTest.E2E.Layout, :live},
    on_mount: {Phoenix.LiveViewTest.E2E.Hooks, :default} do
    scope "/", Phoenix.LiveViewTest do
      pipe_through(:browser)

      live "/stream", Support.StreamLive
      live "/stream/reset", Support.StreamResetLive
      live "/stream/reset-lc", Support.StreamResetLCLive
      live "/stream/limit", Support.StreamLimitLive
      live "/stream/nested-component-reset", Support.StreamNestedComponentResetLive
      live "/stream/inside-for", Support.StreamInsideForLive
      live "/healthy/:category", Support.HealthyLive

      live "/upload", E2E.UploadLive
      live "/form", E2E.FormLive
      live "/form/dynamic-inputs", E2E.FormDynamicInputsLive
      live "/form/nested", E2E.NestedFormLive
      live "/form/stream", E2E.FormStreamLive
      live "/js", E2E.JsLive
      live "/select", E2E.SelectLive
      live "/portal", E2E.PortalLive
    end

    scope "/issues", Phoenix.LiveViewTest.E2E do
      pipe_through(:browser)

      live "/2787", Issue2787Live
      live "/3026", Issue3026Live
      live "/3040", Issue3040Live
      live "/3083", Issue3083Live
      live "/3107", Issue3107Live
      live "/3117", Issue3117Live
      live "/3200/messages", Issue3200.PanelLive, :messages_tab
      live "/3200/settings", Issue3200.PanelLive, :settings_tab
      live "/3194", Issue3194Live
      live "/3194/other", Issue3194Live.OtherLive
      live "/3378", Issue3378.HomeLive
      live "/3448", Issue3448Live
      live "/3496/a", Issue3496.ALive
      live "/3496/b", Issue3496.BLive
    end
  end

  live_session :navigation, layout: {Phoenix.LiveViewTest.E2E.Navigation.Layout, :live} do
    scope "/navigation" do
      pipe_through(:browser)

      live "/a", Phoenix.LiveViewTest.E2E.Navigation.ALive
      live "/b", Phoenix.LiveViewTest.E2E.Navigation.BLive, :index
      live "/b/:id", Phoenix.LiveViewTest.E2E.Navigation.BLive, :show
    end
  end

  # these routes use a custom layout and therefore cannot be in the live_session
  scope "/", Phoenix.LiveViewTest.E2E do
    pipe_through(:browser)

    live "/form/feedback", FormFeedbackLive
    live "/errors", ErrorLive

    scope "/issues" do
      live "/2965", Issue2965Live
      live "/3047/a", Issue3047ALive
      live "/3047/b", Issue3047BLive
      live "/3169", Issue3169Live
    end
  end

  post "/eval", Phoenix.LiveViewTest.E2E.EvalController, :eval
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
  plug :halt

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

  defp halt(%{request_path: "/halt"}, _opts) do
    send(:e2e_helper, :halt)
    # this ensure playwright waits until the server force stops
    Process.sleep(:infinity)
  end

  defp halt(conn, _opts), do: conn
end

{:ok, _} =
  Supervisor.start_link(
    [
      Phoenix.LiveViewTest.E2E.Endpoint,
      {Phoenix.PubSub, name: Phoenix.LiveViewTest.E2E.PubSub}
    ],
    strategy: :one_for_one
  )

IO.puts("Starting e2e server on port #{Phoenix.LiveViewTest.E2E.Endpoint.config(:http)[:port]}")

if not IEx.started?() do
  # when running the test server manually, we halt after
  # reading from stdin
  spawn(fn ->
    IO.read(:stdio, :line)
    send(:e2e_helper, :halt)
  end)

  receive do
    :halt -> :ok
  end
end
