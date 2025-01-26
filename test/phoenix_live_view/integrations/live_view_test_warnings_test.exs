defmodule Phoenix.LiveView.LiveViewTestWarningsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.LiveViewTest.Support.Endpoint

  @endpoint Endpoint

  describe "live" do
    test "warns for duplicate ids when on_error: warn" do
      conn = Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})
      conn = get(conn, "/duplicate-id")

      Process.flag(:trap_exit, true)

      assert capture_io(:stderr, fn ->
               {:ok, view, _html} = live(conn, nil, on_error: :warn)
               render(view)
             end) =~
               "Duplicate id found while testing LiveView: a"

      refute_receive {:EXIT, _, _}
    end

    test "warns for duplicate component when on_error: warn" do
      conn = Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})
      conn = get(conn, "/dynamic-duplicate-component")

      Process.flag(:trap_exit, true)

      warning =
        capture_io(:stderr, fn ->
          {:ok, view, _html} = live(conn, nil, on_error: :warn)

          view |> element("button", "Toggle duplicate LC") |> render_click() =~
            "I am LiveComponent2"

          render(view)
        end)

      assert warning =~ "Duplicate live component found while testing LiveView:"
      assert warning =~ "I am LiveComponent2"
      refute warning =~ "I am a LC inside nested LV"

      refute_receive {:EXIT, _, _}
    end
  end

  describe "live_isolated" do
    test "warns for duplicate ids when on_error: warn" do
      Process.flag(:trap_exit, true)

      assert capture_io(:stderr, fn ->
               {:ok, view, _html} =
                 live_isolated(
                   Phoenix.ConnTest.build_conn(),
                   Phoenix.LiveViewTest.Support.DuplicateIdLive,
                   on_error: :warn
                 )

               render(view)
             end) =~
               "Duplicate id found while testing LiveView: a"

      refute_receive {:EXIT, _, _}
    end

    test "warns for duplicate component when on_error: warn" do
      Process.flag(:trap_exit, true)

      warning =
        capture_io(:stderr, fn ->
          {:ok, view, _html} =
            live_isolated(
              Phoenix.ConnTest.build_conn(),
              Phoenix.LiveViewTest.Support.DynamicDuplicateComponentLive,
              on_error: :warn
            )

          view |> element("button", "Toggle duplicate LC") |> render_click() =~
            "I am LiveComponent2"

          render(view)
        end)

      assert warning =~ "Duplicate live component found while testing LiveView:"
      assert warning =~ "I am LiveComponent2"
      refute warning =~ "I am a LC inside nested LV"

      refute_receive {:EXIT, _, _}
    end
  end
end
