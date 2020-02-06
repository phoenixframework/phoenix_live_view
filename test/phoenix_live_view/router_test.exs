defmodule Phoenix.LiveView.RouterTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.LiveViewTest.{Endpoint, ThermostatLive}

  @endpoint Endpoint
  @moduletag :capture_log

  setup config do
    conn = Plug.Test.init_test_session(build_conn(), config[:plug_session] || %{})
    {:ok, conn: conn}
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
    assert conn.resp_body =~ ~r/<article[^>]*data-phx-view="ThermostatLive"[^>]*>/
  end

  test "routing with container", %{conn: conn} do
    conn = get(conn, "/router/thermo_container/123")

    assert conn.resp_body =~
             ~r/<span[^>]*data-phx-view="LiveViewTest.DashboardLive"[^>]*style="flex-grow">/
  end

  test "default layout is inflected", %{conn: conn} do
    conn = get(conn, "/router/thermo_session/123")
    assert conn.resp_body =~ "LAYOUT"
  end

  test "routing with custom layout", %{conn: conn} do
    conn = get(conn, "/router/thermo_layout/123")
    assert conn.resp_body =~ "ALTERNATIVE"
  end

  test "routing with custom layout overrides pipeline", %{conn: conn} do
    conn = get(conn, "/alt/router/thermo/123")
    assert conn.resp_body =~ "ALTERNATIVE"
  end

  test "routing with custom layout and live layout", %{conn: conn} do
    conn = get(conn, "/alt/layout")
    assert conn.resp_body =~ "ALTERNATIVE"
    assert conn.resp_body =~ "LIVELAYOUTSTART"
  end

  test "live_path helper", %{conn: conn} do
    assert Phoenix.LiveViewTest.Router.Helpers.live_path(conn, ThermostatLive) == "/thermo"
  end

  test "routing at root", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    assert html =~ ~r/<article[^>]*data-phx-view="ThermostatLive"[^>]*>/
  end
end
