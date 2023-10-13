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
    live "/shuffle", ShuffleLive
    live "/components", WithComponentLive
    live "/multi-targets", WithMultipleTargets
    live "/assigns-not-in-socket", AssignsNotInSocketLive
    live "/log-override", WithLogOverride
    live "/log-disabled", WithLogDisabled
    live "/errors", ErrorsLive
    live "/live-reload", ReloadLive
    live "/assign_async", AssignAsyncLive
    live "/start_async", StartAsyncLive

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
    live_session :styled_layout, root_layout: {Phoenix.LiveViewTest.LayoutView, :styled} do
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
    live "/events-multi-js", EventsMultiJSLive
    live "/events-multi-js-in-component", EventsInComponentMultiJSLive

    # integration components
    live "/component_in_live", ComponentInLive.Root
    live "/cids_destroyed", CidsDestroyedLive
    live "/component_and_nested_in_live", ComponentAndNestedInLive

    # integration lifecycle
    live "/lifecycle", HooksLive
    live "/lifecycle/bad-mount", HooksLive.BadMount
    live "/lifecycle/own-mount", HooksLive.OwnMount
    live "/lifecycle/halt-mount", HooksLive.HaltMount
    live "/lifecycle/redirect-cont-mount", HooksLive.RedirectMount, :cont
    live "/lifecycle/redirect-halt-mount", HooksLive.RedirectMount, :halt
    live "/lifecycle/components", HooksLive.WithComponent
    live "/lifecycle/handle-params-not-defined", HooksLive.HandleParamsNotDefined
    live "/lifecycle/handle-info-not-defined", HooksLive.HandleInfoNotDefined

    # integration stream
    live "/stream", StreamLive

    # healthy
    live "/healthy/:category", HealthyLive

    # integration connect
    live "/connect", ConnectLive

    # live_patch
    scope host: "app.example.com" do
      live "/with-host/full", HostLive, :full
      live "/with-host/path", HostLive, :path
    end

    # live_session
    live_session :test do
      live "/thermo-live-session", ThermostatLive
      live "/thermo-live-session/nested-thermo", ThermostatLive
      live "/clock-live-session", ClockLive
      live "/classlist", ClassListLive
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

    live_session :lifecycle, on_mount: Phoenix.LiveViewTest.HaltConnectedMount do
      live "/lifecycle/halt-connected-mount", HooksLive.Noop
    end

    live_session :mount_mod_arg, on_mount: {Phoenix.LiveViewTest.MountArgs, :inlined} do
      live "/lifecycle/mount-mod-arg", HooksLive.Noop
    end

    live_session :mount_mods,
      on_mount: [Phoenix.LiveViewTest.OnMount, Phoenix.LiveViewTest.OtherOnMount] do
      live "/lifecycle/mount-mods", HooksLive.Noop
    end

    live_session :mount_mod_args,
      on_mount: [
        {Phoenix.LiveViewTest.OnMount, :other},
        {Phoenix.LiveViewTest.OtherOnMount, :other}
      ] do
      live "/lifecycle/mount-mods-args", HooksLive.Noop
    end

    live_session :layout, layout: {Phoenix.LiveViewTest.LayoutView, :live_override} do
      live "/dashboard-live-session-layout", LayoutLive
    end
  end

  scope "/", as: :user_defined_metadata, alias: Phoenix.LiveViewTest do
    live "/sessionless-thermo", ThermostatLive
    live "/thermo-with-metadata", ThermostatLive, metadata: %{route_name: "opts"}
  end

  def session(%Plug.Conn{}, extra), do: Map.merge(extra, %{"called" => true})
end
