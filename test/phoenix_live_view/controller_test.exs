defmodule Phoenix.LiveView.ControllerTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest

  alias Phoenix.LiveViewTest.Endpoint

  @endpoint Endpoint

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  test "live renders from controller without session", %{conn: conn} do
    conn = get(conn, "/controller/live-render-2")
    assert html_response(conn, 200) =~ "session: %{}"
  end

  test "live renders from controller with session", %{conn: conn} do
    conn = get(conn, "/controller/live-render-3")
    assert html_response(conn, 200) =~ "session: %{\"custom\" => :session}"
  end

  test "live renders from controller with merged assigns", %{conn: conn} do
    conn = get(conn, "/controller/live-render-4")
    assert html_response(conn, 200) =~ "title: Dashboard"
  end
end
