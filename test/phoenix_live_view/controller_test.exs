defmodule Phoenix.LiveView.ControllerTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

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

  test "when session data has atom keys, warns on live render", %{conn: conn} do
    assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
             conn = get(conn, "/controller/live-render-4")
             assert html_response(conn, 200) =~ "session: %{custom: :session}"
           end) =~ "Phoenix.LiveView sessions require string keys, got: :custom"
  end
end
