Application.put_env(:phoenix, Example.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5001],
  server: true,
  live_view: [signing_salt: "aaaaaaaa"],
  secret_key_base: String.duplicate("a", 64)
)

Mix.install([
  {:plug_cowboy, "~> 2.5"},
  {:jason, "~> 1.0"},
  {:phoenix, "~> 1.7"},
  # please test your issue using the latest version of LV from GitHub!
  {:phoenix_live_view, github: "phoenixframework/phoenix_live_view", branch: "main", override: true},
  {:floki, ">= 0.30.0"}
])

ExUnit.start()

defmodule Example.ErrorView do
  def render(template, _), do: Phoenix.Controller.status_message_from_template(template)
end

defmodule Example.HomeLive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  def mount(_params, _session, socket) do
    socket
    |> then(&{:ok, &1})
  end

  def render("live.html", assigns) do
    ~H"""
    <script src="/assets/phoenix/phoenix.js"></script>
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

  def render(assigns) do
    ~H"""
    <p>The LiveView content goes here</p>
    """
  end
end

defmodule Example.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
  end

  scope "/", Example do
    pipe_through(:browser)

    live("/", HomeLive, :index)
  end
end

defmodule Example.Endpoint do
  use Phoenix.Endpoint, otp_app: :phoenix
  socket("/live", Phoenix.LiveView.Socket)
  plug Plug.Static, from: {:phoenix, "priv/static"}, at: "/assets/phoenix"
  plug Plug.Static, from: {:phoenix_live_view, "priv/static"}, at: "/assets/phoenix_live_view"
  plug(Example.Router)
end

defmodule Example.HomeLiveTest do
  use ExUnit.Case

  import Phoenix.ConnTest
  import Plug.Conn
  import Phoenix.LiveViewTest

  @endpoint Example.Endpoint

  test "works properly" do
    conn = Phoenix.ConnTest.build_conn()

    {:ok, _view, html} = live(conn, "/")

    assert html =~ "The LiveView content goes here"
  end
end

{:ok, _} = Supervisor.start_link([Example.Endpoint], strategy: :one_for_one)
ExUnit.run()
Process.sleep(:infinity)
