defmodule Phoenix.LiveView.RouterTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.LiveView.{Route, Session}
  alias Phoenix.LiveViewTest.DOM
  alias Phoenix.LiveViewTest.Support.{Endpoint, DashboardLive}
  alias Phoenix.LiveViewTest.Support.Router.Helpers, as: Routes

  @endpoint Endpoint

  def verified_session(html) do
    [{id, session_token, static_token} | _] = html |> DOM.parse() |> DOM.find_live_views()

    {:ok, live_session} =
      Session.verify_session(@endpoint, "lv:#{id}", session_token, static_token, nil)

    live_session.session
  end

  setup config do
    conn = Plug.Test.init_test_session(build_conn(), config[:plug_session] || %{})
    {:ok, conn: conn}
  end

  test "routing at root", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    assert html =~ ~r/<article[^>]*class="thermo"[^>]*>/
  end

  test "routing with empty session", %{conn: conn} do
    conn = get(conn, "/router/thermo_defaults/123")
    assert conn.resp_body =~ ~s()
  end

  @tag plug_session: %{user_id: "chris"}
  test "routing with custom session", %{conn: conn} do
    conn = get(conn, "/router/thermo_session/123")
    assert conn.resp_body =~ ~s(session: %{"user_id" => "chris"})
  end

  test "routing with module container", %{conn: conn} do
    conn = get(conn, "/thermo")
    assert conn.resp_body =~ ~r/<article[^>]*class="thermo"[^>]*>/
  end

  test "routing with container", %{conn: conn} do
    conn = get(conn, "/router/thermo_container/123")

    assert conn.resp_body =~
             ~r/<span[^>]*class="Phoenix.LiveViewTest.Support.DashboardLive"[^>]*style="flex-grow">/
  end

  test "live non-action helpers", %{conn: conn} do
    assert Routes.live_path(conn, DashboardLive, 1) == "/router/thermo_defaults/1"
    assert Routes.custom_live_path(conn, DashboardLive, 1) == "/router/thermo_session/custom/1"
  end

  test "live action helpers", %{conn: conn} do
    assert Routes.foo_bar_path(conn, :index) == "/router/foobarbaz"
    assert Routes.foo_bar_index_path(conn, :index) == "/router/foobarbaz/index"
    assert Routes.foo_bar_index_path(conn, :show) == "/router/foobarbaz/show"
    assert Routes.foo_bar_nested_index_path(conn, :index) == "/router/foobarbaz/nested/index"
    assert Routes.foo_bar_nested_index_path(conn, :show) == "/router/foobarbaz/nested/show"
    assert Routes.custom_foo_bar_path(conn, :index) == "/router/foobarbaz/custom"
    assert Routes.nested_module_path(conn, :action) == "/router/foobarbaz/with_live"
    assert Routes.custom_route_path(conn, :index) == "/router/foobarbaz/nosuffix"
  end

  test "user-defined metadata is available inside of metadata key" do
    assert Phoenix.LiveViewTest.Support.Router
           |> Phoenix.Router.route_info("GET", "/thermo-with-metadata", nil)
           |> Map.get(:route_name) == "opts"
  end

  describe "live_session" do
    test "with defaults", %{conn: conn} do
      path = "/thermo-live-session"

      assert {:internal, route} =
               Route.live_link_info_without_checks(
                 @endpoint,
                 Phoenix.LiveViewTest.Support.Router,
                 path
               )

      assert route.live_session.name == :test
      assert route.live_session.vsn

      assert conn |> get(path) |> html_response(200) |> verified_session() == %{}
    end

    test "with extra session metadata", %{conn: conn} do
      path = "/thermo-live-session-admin"

      assert {:internal, route} =
               Route.live_link_info_without_checks(
                 @endpoint,
                 Phoenix.LiveViewTest.Support.Router,
                 path
               )

      assert route.live_session.name == :admin
      assert route.live_session.vsn

      assert conn |> get(path) |> html_response(200) |> verified_session() ==
               %{"admin" => true}
    end

    test "with session MFA metadata", %{conn: conn} do
      path = "/thermo-live-session-mfa"

      assert {:internal, route} =
               Route.live_link_info_without_checks(
                 @endpoint,
                 Phoenix.LiveViewTest.Support.Router,
                 path
               )

      assert route.live_session.name == :mfa
      assert route.live_session.vsn

      assert conn |> get(path) |> html_response(200) |> verified_session() ==
               %{"inlined" => true, "called" => true}
    end

    test "with on_mount hook", %{conn: conn} do
      path = "/lifecycle/halt-connected-mount"

      assert {:internal, route} =
               Route.live_link_info_without_checks(
                 @endpoint,
                 Phoenix.LiveViewTest.Support.Router,
                 path
               )

      assert route.live_session.extra == %{
               on_mount: [
                 %{
                   id: {Phoenix.LiveViewTest.Support.HaltConnectedMount, :default},
                   stage: :mount,
                   function:
                     Function.capture(
                       Phoenix.LiveViewTest.Support.HaltConnectedMount,
                       :on_mount,
                       4
                     )
                 }
               ]
             }

      assert conn |> get(path) |> html_response(200) =~
               "last_on_mount:Phoenix.LiveViewTest.Support.HaltConnectedMount"

      assert {:error, {:live_redirect, %{to: "/lifecycle"}}} = live(conn, path)
    end

    test "with on_mount {Module, arg}", %{conn: conn} do
      path = "/lifecycle/mount-mod-arg"

      assert {:internal, route} =
               Route.live_link_info_without_checks(
                 @endpoint,
                 Phoenix.LiveViewTest.Support.Router,
                 path
               )

      assert route.live_session.extra == %{
               on_mount: [
                 %{
                   id: {Phoenix.LiveViewTest.Support.MountArgs, :inlined},
                   stage: :mount,
                   function:
                     Function.capture(Phoenix.LiveViewTest.Support.MountArgs, :on_mount, 4)
                 }
               ]
             }

      assert {:error, {:live_redirect, %{to: "/lifecycle?called=true&inlined=true"}}} =
               live(conn, path)
    end

    test "with on_mount [Module, ...]", %{conn: conn} do
      path = "/lifecycle/mount-mods"

      assert {:internal, route} =
               Route.live_link_info_without_checks(
                 @endpoint,
                 Phoenix.LiveViewTest.Support.Router,
                 path
               )

      assert route.live_session.extra == %{
               on_mount: [
                 %{
                   id: {Phoenix.LiveViewTest.Support.OnMount, :default},
                   stage: :mount,
                   function: Function.capture(Phoenix.LiveViewTest.Support.OnMount, :on_mount, 4)
                 },
                 %{
                   id: {Phoenix.LiveViewTest.Support.OtherOnMount, :default},
                   stage: :mount,
                   function:
                     Function.capture(Phoenix.LiveViewTest.Support.OtherOnMount, :on_mount, 4)
                 }
               ]
             }

      assert {:ok, _, _} = live(conn, path)
    end

    test "with on_mount [{Module, arg}, ...]", %{conn: conn} do
      path = "/lifecycle/mount-mods-args"

      assert {:internal, route} =
               Route.live_link_info_without_checks(
                 @endpoint,
                 Phoenix.LiveViewTest.Support.Router,
                 path
               )

      assert route.live_session.extra == %{
               on_mount: [
                 %{
                   id: {Phoenix.LiveViewTest.Support.OnMount, :other},
                   stage: :mount,
                   function: Function.capture(Phoenix.LiveViewTest.Support.OnMount, :on_mount, 4)
                 },
                 %{
                   id: {Phoenix.LiveViewTest.Support.OtherOnMount, :other},
                   stage: :mount,
                   function:
                     Function.capture(Phoenix.LiveViewTest.Support.OtherOnMount, :on_mount, 4)
                 }
               ]
             }

      assert {:ok, _, _} = live(conn, path)
    end

    test "raises when nesting" do
      assert_raise(RuntimeError, ~r"attempting to define live_session :invalid inside :ok", fn ->
        Code.eval_quoted(
          quote do
            defmodule NestedRouter do
              import Phoenix.LiveView.Router

              live_session :ok do
                live_session :invalid do
                end
              end
            end
          end
        )
      end)
    end

    test "raises when redefining" do
      assert_raise(RuntimeError, ~r"attempting to redefine live_session :one", fn ->
        Code.eval_quoted(
          quote do
            defmodule DupRouter do
              import Phoenix.LiveView.Router

              live_session :one do
              end

              live_session :two do
              end

              live_session :one do
              end
            end
          end
        )
      end)
    end

    test "with layout override", %{conn: conn} do
      path = "/dashboard-live-session-layout"

      assert {:internal, route} =
               Route.live_link_info_without_checks(
                 @endpoint,
                 Phoenix.LiveViewTest.Support.Router,
                 path
               )

      assert route.live_session.extra == %{
               layout: {Phoenix.LiveViewTest.Support.LayoutView, :live_override}
             }

      {:ok, view, html} = live(conn, path)

      assert html =~
               ~r|<div[^>]+>LIVEOVERRIDESTART\-123\-The value is: 123\-LIVEOVERRIDEEND|

      assert render(view) =~
               ~r|<div[^>]+>LIVEOVERRIDESTART\-123\-The value is: 123\-LIVEOVERRIDEEND|
    end

    test "with layout override on disconnected render", %{conn: conn} do
      path = "/dashboard-live-session-layout"

      assert {:internal, route} =
               Route.live_link_info_without_checks(
                 @endpoint,
                 Phoenix.LiveViewTest.Support.Router,
                 path
               )

      assert route.live_session.extra == %{
               layout: {Phoenix.LiveViewTest.Support.LayoutView, :live_override}
             }

      conn = get(conn, path)

      assert html_response(conn, 200) =~
               ~r|<div[^>]+>LIVEOVERRIDESTART\-123\-The value is: 123\-LIVEOVERRIDEEND|
    end

    test "classifies route as external when same view, but different session" do
      # previously, a patch to the same LV, but a different path in a different live_session
      # would succeed when it should not
      {_, %Route{live_session: %{vsn: vsn}}} =
        Route.live_link_info_without_checks(
          @endpoint,
          Phoenix.LiveViewTest.Support.Router,
          "/clock-live-session"
        )

      socket = %Phoenix.LiveView.Socket{
        router: Phoenix.LiveViewTest.Support.Router,
        endpoint: @endpoint,
        private: %{live_session_name: :test, live_session_vsn: vsn}
      }

      assert {:external, _} =
               Route.live_link_info!(
                 socket,
                 Phoenix.LiveViewTest.Support.ClockLive,
                 "/clock-live-session-admin"
               )

      assert {:internal, _} =
               Route.live_link_info!(
                 socket,
                 Phoenix.LiveViewTest.Support.ClockLive,
                 "/clock-live-session"
               )
    end
  end
end
