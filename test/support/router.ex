defmodule Phoenix.LiveViewTest.Controller do
  use Phoenix.Controller
  import Phoenix.LiveView.Controller

  plug :put_layout, false

  def incoming(conn, %{"type" => "live-render-2"}) do
    live_render(conn, Phoenix.LiveViewTest.DashboardLive)
  end

  def incoming(conn, %{"type" => "live-render-3"}) do
    live_render(conn, Phoenix.LiveViewTest.DashboardLive, session: %{custom: :session})
  end
end

defmodule Phoenix.LiveViewTest.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
  end

  scope "/", Phoenix.LiveViewTest do
    pipe_through [:browser]

    # controller test
    get "/controller/:type", Controller, :incoming

    # router test
    live "/router/thermo_defaults/:id", DashboardLive
    live "/router/thermo_session/:id", DashboardLive, session: [:user_id]
    live "/router/thermo_container/:id", DashboardLive, container: {:span, style: "flex-grow"}

    live "/router/thermo_layout/:id", DashboardLive,
      layout: {Phoenix.LiveViewTest.AlternativeLayout, :layout}

    # live view test
    live "/thermo", ThermostatLive, session: [:nest, :users, :redir]
    live "/thermo/:id", ThermostatLive, session: [:nest, :users, :redir]

    live "/thermo-container", ThermostatLive,
      session: [:nest],
      container: {:span, style: "thermo-flex<script>"}

    live "/same-child", SameChildLive, session: [:dup]
    live "/root", RootLive, session: [:user_id]
    live "/counter/:id", ParamCounterLive, session: [:test, :test_pid, :on_handle_params]
    live "/opts", OptsLive, session: [:opts]
    live "/time-zones", AppendLive, session: [:time_zones]
    live "/shuffle", ShuffleLive, session: [:time_zones]
    live "/components", WithComponentLive, session: [:names, :from]
  end

  forward "/other", Phoenix.LiveViewTest.Other.Router
end

defmodule Phoenix.LiveViewTest.Other.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
  end

  scope "/", Phoenix.LiveViewTest.Other do
    pipe_through [:browser]

    live "/with_params/:id", WithParamsLive, layout: {Phoenix.LiveViewTest.LayoutView, :app}
  end
end
