defmodule Phoenix.LiveView.InnerBlockTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint Phoenix.LiveViewTest.Endpoint
  @moduletag :capture_log

  setup do
    {:ok, conn: Plug.Test.init_test_session(build_conn(), %{test_process: self()})}
  end

  test "inner content with do block", %{conn: conn} do
    {:ok, view, html} = live(conn, "/inner_block_do")

    assert html =~ "Inner: 0"
    assert html =~ "Outer: 0"

    # We receive the initial content twice, one for dead and another for the live render
    assert_received 0
    assert_received 0

    html = view |> element("#inner") |> render_click()

    assert html =~ "Inner: 1"
    assert html =~ "Outer: 0"
    refute_received 0

    html = view |> element("#outer") |> render_click()

    assert html =~ "Inner: 1"
    assert html =~ "Outer: 1"
    assert_received 1

    html = view |> element("#inner") |> render_click()

    assert html =~ "Inner: 2"
    assert html =~ "Outer: 1"
    refute_received 1
  end

  test "inner content with fun block", %{conn: conn} do
    {:ok, view, html} = live(conn, "/inner_block_fun")

    assert html =~ "Inner: 0"
    assert html =~ "Outer: 0"

    # We receive the initial content twice, one for dead and another for the live render
    assert_received 0
    assert_received 0

    html = view |> element("#inner") |> render_click()

    assert html =~ "Inner: 1"
    assert html =~ "Outer: 0"
    refute_received 0

    html = view |> element("#outer") |> render_click()

    assert html =~ "Inner: 1"
    assert html =~ "Outer: 1"
    assert_received 1

    html = view |> element("#inner") |> render_click()

    assert html =~ "Inner: 2"
    assert html =~ "Outer: 1"
    refute_received 1
  end
end
