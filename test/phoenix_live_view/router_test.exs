defmodule Phoenix.LiveView.RouterTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.LiveView.Route
  alias Phoenix.LiveViewTest.{Endpoint, DashboardLive}
  alias Phoenix.LiveViewTest.Router.Helpers, as: Routes

  @endpoint Endpoint

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
    assert conn.resp_body =~ ~s(session: %{})
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
             ~r/<span[^>]*class="Phoenix.LiveViewTest.DashboardLive"[^>]*style="flex-grow">/
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
    assert Phoenix.LiveViewTest.Router
           |> Phoenix.Router.route_info("GET", "/thermo-with-metadata", nil)
           |> Map.get(:route_name) == "opts"
  end

  describe "live_session" do
    test "with defaults" do
      assert {:internal, route} = Route.live_link_info(@endpoint, Phoenix.LiveViewTest.Router, "/thermo-live-session")
      assert route.live_session_name == :test
      assert route.live_session_vsn
    end

    test "with extra session metadata" do
      assert {:internal, route} = Route.live_link_info(@endpoint, Phoenix.LiveViewTest.Router, "/thermo-live-session-admin")
      assert route.live_session_name == :admin
      assert route.live_session_vsn
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
  end
end
