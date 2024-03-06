defmodule Phoenix.LiveViewTest.ExpensiveAssignsTest do
  # this is intentionally async: false as we change the application
  # environment and recompile files!
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  import Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.Endpoint

  @endpoint Endpoint

  setup_all do
    Application.put_env(:phoenix_live_view, :warn_on_expensive_assigns, true)
    # TODO: can we make this better?
    Code.compile_file(__DIR__ <> "/../../../lib/phoenix_live_view/async.ex")
    Code.compile_file(__DIR__ <> "/../../../lib/phoenix_live_view/utils.ex")

    on_exit(fn ->
      Application.put_env(:phoenix_live_view, :warn_on_expensive_assigns, false)
      Code.compile_file(__DIR__ <> "/../../../lib/phoenix_live_view/async.ex")
      Code.compile_file(__DIR__ <> "/../../../lib/phoenix_live_view/utils.ex")
    end)
  end

  setup do
    {:ok, conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})}
  end

  test "warns when storing socket in assigns", %{conn: conn} do
    _ =
      capture_io(:stderr, fn ->
        {:ok, lv, _html} = live(conn, "/warn-on-expensive-assigns")
        render_async(lv)

        send(self(), {:lv, lv})
      end)

    lv =
      receive do
        {:lv, lv} -> lv
      end

    warnings =
      capture_io(:stderr, fn ->
        render_hook(lv, "expensive_assigns")
      end)

    assert warnings =~ "you are accessing the LiveView socket in the assigned function my_fun"
    assert warnings =~ "you are accessing the LiveView socket in the assigned function fun"

    assert warnings =~
             "you are assigning the LiveView socket itself into the assign nested_socket"
  end
end
