defmodule Phoenix.LiveView.PlugTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  alias Phoenix.LiveView.Plug, as: LiveViewPlug
  alias Phoenix.LiveViewTest.{ThermostatLive, DashboardLive, Endpoint}

  setup config do
    conn =
      build_conn()
      |> Plug.Test.init_test_session(config[:plug_session] || %{})
      |> Plug.Conn.put_private(:phoenix_router, Router)
      |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
      |> Plug.Conn.put_private(:phoenix_live_view, [])

    {:ok, conn: conn}
  end

  test "with no session opts", %{conn: conn} do
    conn = LiveViewPlug.call(conn, DashboardLive)

    assert conn.resp_body =~ ~s(session: %{})
  end

  test "with existing #{LiveViewPlug.link_header()} header", %{conn: conn} do
    conn =
      conn
      |> put_req_header(LiveViewPlug.link_header(), "some.site.com")
      |> LiveViewPlug.call(DashboardLive)

    assert conn.resp_body =~ ~s(session: %{})
  end

  @tag plug_session: %{user_id: "alex"}
  test "with session opts", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_private(:phoenix_live_view, session: [:user_id])
      |> LiveViewPlug.call(DashboardLive)

    assert conn.resp_body =~ ~s(session: %{user_id: "alex"})
  end

  test "with a module container", %{conn: conn} do
    conn = LiveViewPlug.call(conn, ThermostatLive)

    assert conn.resp_body =~
             ~r/<article[^>]*data-phx-view="Phoenix.LiveViewTest.ThermostatLive"[^>]*>/
  end

  test "with container options", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_private(:phoenix_live_view, container: {:span, style: "phx-flex"})
      |> LiveViewPlug.call(DashboardLive)

    assert conn.resp_body =~
             ~r/<span[^>]*data-phx-view="Phoenix.LiveViewTest.DashboardLive"[^>]*style="phx-flex">/
  end
end
