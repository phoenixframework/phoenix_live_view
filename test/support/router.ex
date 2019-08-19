defmodule Phoenix.LiveViewTest.AlternativeLayout do
  use Phoenix.View, root: ""

  def render("layout.html", assigns) do
    ["ALTERNATE", render(assigns.view_module, assigns.view_template, assigns)]
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

    # router test
    live "/router/thermo_defaults/:id", DashboardLive
    live "/router/thermo_session/:id", DashboardLive, session: [:path_params, :user_id]
    live "/router/thermo_container/:id", DashboardLive, container: {:span, style: "flex-grow"}
    live "/router/thermo_layout/:id", DashboardLive, layout: {Phoenix.LiveViewTest.AlternativeLayout , :layout}

    # live view test
    live "/thermo", ThermostatLive, session: [:nest, :users, :redir]
    live "/thermo/:id", ThermostatLive, session: [:nest, :users, :redir]
    live "/thermo-container", ThermostatLive, session: [:nest], container: {:span, style: "thermo-flex<script>"}
    live "/same-child", SameChildLive, session: [:dup]
    live "/root", RootLive, session: [:user_id]
    live "/counter/:id", ParamCounterLive, session: [:test, :test_pid]
    live "/configure", ConfigureLive
  end
end
