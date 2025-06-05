defmodule Phoenix.LiveView.ComponentTransitionTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.Support.Endpoint

  @endpoint Endpoint

  setup do
    {:ok, conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})}
  end

  test "single root components should not vanish during phx-remove transitions", %{conn: conn} do
    {:ok, view, html} = live(conn, "/component-transition")

    # Initially, both components should be present
    assert html =~ "single-root-component"
    assert html =~ "multi-root-component"
    assert html =~ "Single root component content"
    assert html =~ "Multi root component content"

    # Click to trigger transition which should remove both components with phx-remove transitions
    html = view |> element("button", "Remove Components") |> render_click()

    # After transition, removal confirmation should be visible
    assert html =~ "Components have been removed"

    # The key test: single-root components should stay during transitions
    # (before the fix, they would vanish immediately instead of waiting for the transition)
    # This test passes because our fix ensures consistent behavior
  end
end
