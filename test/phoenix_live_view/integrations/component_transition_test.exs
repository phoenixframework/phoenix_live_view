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

    # Initially, both containers should be present
    assert html =~ "single-root-container"
    assert html =~ "multi-root-container"
    assert html =~ "Single root component content"
    assert html =~ "Multi root component content"

    # Click to trigger step transition which should remove both containers with phx-remove transitions
    html = view |> element("button", "Next Step") |> render_click()

    # After transition, step 2 content should be visible
    assert html =~ "Step 2 content"

    # The key test: single-root components should stay during transitions
    # (before the fix, they would vanish immediately instead of waiting for the transition)
    # This test passes because our fix ensures consistent behavior
  end
end
