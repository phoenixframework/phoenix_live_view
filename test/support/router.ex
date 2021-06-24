defmodule Phoenix.LiveViewTest.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :setup_session do
    plug Plug.Session,
      store: :cookie,
      key: "_live_view_key",
      signing_salt: "/VEDsdfsffMnp5"

    plug :fetch_session
  end

  pipeline :browser do
    plug :setup_session
    plug :accepts, ["html"]
    plug :fetch_live_flash
  end

  pipeline :bad_layout do
    plug :put_root_layout, {UnknownView, :unknown_template}
  end

  scope "/", Phoenix.LiveViewTest do
    pipe_through [:browser]

    live "/thermo", ThermostatLive
    live "/thermo/:id", ThermostatLive
    live "/thermo-container", ThermostatLive, container: {:span, style: "thermo-flex<script>"}
    live "/", ThermostatLive, as: :live_root
    live "/clock", ClockLive
    live "/redir", RedirLive
    live "/elements", ElementsLive
    live "/inner_block", InnerLive

    live "/same-child", SameChildLive
    live "/root", RootLive
    live "/opts", OptsLive
    live "/time-zones", AppendLive
    live "/shuffle", ShuffleLive
    live "/components", WithComponentLive
    live "/assigns-not-in-socket", AssignsNotInSocketLive
    live "/errors", ErrorsLive

    # controller test
    get "/controller/:type", Controller, :incoming
    get "/widget", Controller, :widget
    get "/not_found", Controller, :not_found
    post "/not_found", Controller, :not_found

    # router test
    live "/router/thermo_defaults/:id", DashboardLive
    live "/router/thermo_session/:id", DashboardLive
    live "/router/thermo_container/:id", DashboardLive, container: {:span, style: "flex-grow"}
    live "/router/thermo_session/custom/:id", DashboardLive, as: :custom_live
    live "/router/foobarbaz", FooBarLive, :index
    live "/router/foobarbaz/index", FooBarLive.Index, :index
    live "/router/foobarbaz/show", FooBarLive.Index, :show
    live "/router/foobarbaz/nested/index", FooBarLive.Nested.Index, :index
    live "/router/foobarbaz/nested/show", FooBarLive.Nested.Index, :show
    live "/router/foobarbaz/custom", FooBarLive, :index, as: :custom_foo_bar
    live "/router/foobarbaz/with_live", Phoenix.LiveViewTest.Live.Nested.Module, :action
    live "/router/foobarbaz/nosuffix", NoSuffix, :index, as: :custom_route

    # integration layout
    live_session :styled_layout, root_layout: {Phoenix.LiveViewTest.LayoutView, "styled.html"} do
      live "/styled-elements", ElementsLive
    end
    live_session :app_layout, root_layout: {Phoenix.LiveViewTest.LayoutView, :app} do
      live "/layout", LayoutLive
    end

    scope "/" do
      pipe_through [:bad_layout]

      # The layout option needs to have higher precedence than bad layout
      live "/bad_layout", LayoutLive
      live_session :parent_layout, root_layout: false do
        live "/parent_layout", ParentLayoutLive
      end
    end

    # integration params
    live "/counter/:id", ParamCounterLive
    live "/action", ActionLive
    live "/action/index", ActionLive, :index
    live "/action/:id/edit", ActionLive, :edit

    # integration flash
    live "/flash-root", FlashLive
    live "/flash-child", FlashChildLive

    # integration events
    live "/events", EventsLive
    live "/events-in-mount", EventsInMountLive
    live "/events-in-component", EventsInComponentLive

    # integration components
    live "/component_in_live", ComponentInLive.Root
    live "/cids_destroyed", CidsDestroyedLive

    # integration lifecycle
    live "/lifecycle", HooksLive

    # live_session
    live_session :test do
      live "/thermo-live-session", ThermostatLive
      live "/clock-live-session", ClockLive
    end

    live_session :admin, session: %{"admin" => true} do
      live "/thermo-live-session-admin", ThermostatLive
      live "/clock-live-session-admin", ClockLive
    end

    live_session :mfa, session: {__MODULE__, :session, [%{"inlined" => true}]} do
      live "/thermo-live-session-mfa", ThermostatLive
    end

    live_session :merged, session: %{"top-level" => true} do
      live "/thermo-live-session-merged", ThermostatLive
    end
  end

  scope "/", as: :user_defined_metadata, alias: Phoenix.LiveViewTest do
    live "/sessionless-thermo", ThermostatLive
    live "/thermo-with-metadata", ThermostatLive, metadata: %{route_name: "opts"}
  end

  def session(%Plug.Conn{}, extra), do: Map.merge(extra, %{"called" => true})
end
