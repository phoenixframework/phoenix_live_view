defmodule Phoenix.LiveView.LayoutTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.{Endpoint, LayoutView}

  @endpoint Endpoint

  setup config do
    {:ok,
     conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), config[:session] || %{})}
  end

  test "uses dead layout from router", %{conn: conn} do
    assert_raise Plug.Conn.WrapperError,
                 ~r"\(UndefinedFunctionError\) function UnknownView.render/2",
                 fn -> live(conn, "/bad_layout") end

    {:ok, _, _} = live(conn, "/layout")
  end

  test "is picked from config on use", %{conn: conn} do
    {:ok, view, html} = live(conn, "/layout")
    assert html =~ ~r|^LAYOUT<div[^>]+>LIVELAYOUTSTART\-123\-The value is: 123\-LIVELAYOUTEND|

    assert render_click(view, :double) ==
             "LIVELAYOUTSTART-246-The value is: 246-LIVELAYOUTEND\n"
  end

  @tag session: %{live_layout: {LayoutView, "live-override.html"}}
  test "is picked from config on mount when given a layout", %{conn: conn} do
    {:ok, view, html} = live(conn, "/layout")

    assert html =~
             ~r|^LAYOUT<div[^>]+>LIVEOVERRIDESTART\-123\-The value is: 123\-LIVEOVERRIDEEND|

    assert render_click(view, :double) ==
             "LIVEOVERRIDESTART-246-The value is: 246-LIVEOVERRIDEEND\n"
  end

  @tag session: %{live_layout: false}
  test "is picked from config on mount when given false", %{conn: conn} do
    {:ok, view, html} = live(conn, "/layout")
    assert html =~ "The value is: 123</div>"
    assert render_click(view, :double) == "The value is: 246"
  end

  test "is not picked from config on use for child live views", %{conn: conn} do
    assert get(conn, "/parent_layout") |> html_response(200) =~
             "The value is: 123</div>"

    {:ok, _view, html} = live(conn, "/parent_layout")
    assert html =~ "The value is: 123</div>"
  end

  @tag session: %{live_layout: {LayoutView, "live-override.html"}}
  test "is picked from config on mount even on child live views", %{conn: conn} do
    assert get(conn, "/parent_layout") |> html_response(200) =~
             ~r|<div[^>]+>LIVEOVERRIDESTART\-123\-The value is: 123\-LIVEOVERRIDEEND|

    {:ok, _view, html} = live(conn, "/parent_layout")

    assert html =~
             ~r|<div[^>]+>LIVEOVERRIDESTART\-123\-The value is: 123\-LIVEOVERRIDEEND|
  end
end
