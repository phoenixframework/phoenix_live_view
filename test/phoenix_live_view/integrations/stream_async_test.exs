defmodule Phoenix.LiveView.StreamAsyncTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest

  import Phoenix.LiveViewTest
  import Phoenix.LiveViewTest.Support.AsyncSync
  alias Phoenix.LiveViewTest.Support.Endpoint

  @endpoint Endpoint

  setup do
    Process.flag(:trap_exit, true)
    {:ok, conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})}
  end

  describe "LiveView stream_async" do
    test "bad return", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream_async?test=bad_return")

      assert render_async(lv) =~
               "expected stream_async to return {:ok, Enumerable.t()} or {:error, reason}, got: 123"
    end

    test "not enumerable", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream_async?test=bad_ok")

      assert render_async(lv) =~
               "does not implement the Enumerable protocol"
    end

    test "valid return", %{conn: conn} do
      {:ok, lv, html} = live(conn, "/stream_async?test=ok")
      # Initial value is already in stream
      assert html =~ "Initial"
      assert html =~ "my_stream loading..."

      rendered = render_async(lv)
      assert rendered =~ "First"
      assert rendered =~ "Second"
      refute rendered =~ "loading..."

      lazy = LazyHTML.from_fragment(rendered)

      # assert the correct order
      assert [
               {"li", [{"id", "my_stream-0"}, _], ["Initial"]},
               {"li", [{"id", "my_stream-1"}, _], ["First"]},
               {"li", [{"id", "my_stream-2"}, _], ["Second"]}
             ] = LazyHTML.query(lazy, "li") |> LazyHTML.to_tree()
    end

    test "valid return with opts", %{conn: conn} do
      {:ok, lv, html} = live(conn, "/stream_async?test=ok_with_opts")
      # Initial value is already in stream
      assert html =~ "Initial"

      rendered = render_async(lv)
      lazy = LazyHTML.from_fragment(rendered)

      # assert the correct order
      assert [
               {"li", [{"id", "my_stream-2"}, _], ["Second"]},
               {"li", [{"id", "my_stream-1"}, _], ["First"]},
               {"li", [{"id", "my_stream-0"}, _], ["Initial"]}
             ] = LazyHTML.query(lazy, "li") |> LazyHTML.to_tree()
    end

    test "valid return with reset", %{conn: conn} do
      {:ok, lv, html} = live(conn, "/stream_async?test=ok_with_reset")
      # Initial value is already in stream
      assert html =~ "Initial"

      rendered = render_async(lv)
      assert rendered =~ "First"
      assert rendered =~ "Second"
      # Initial value is reset
      refute rendered =~ "Initial"
    end

    test "error return", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream_async?test=error")

      assert render_async(lv) =~ "error: :something_wrong"
    end

    test "raise during execution", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream_async?test=raise")

      assert render_async(lv) =~ "exit:"
      assert render_async(lv) =~ "RuntimeError"
      assert render_async(lv) =~ "boom"
    end

    test "exit during execution", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream_async?test=exit")

      assert render_async(lv) =~ "exit: :boom"
    end

    test "lv exit brings down asyncs", %{conn: conn} do
      Process.register(self(), :stream_async_test_process)
      {:ok, lv, _html} = live(conn, "/stream_async?test=lv_exit")
      lv_ref = Process.monitor(lv.pid)

      async_ref = wait_for_async_ready_and_monitor(:stream_async_exit)
      send(lv.pid, :boom)

      assert_receive {:DOWN, ^lv_ref, :process, _pid, :boom}, 1000
      assert_receive {:DOWN, ^async_ref, :process, _pid, :boom}, 1000
    end

    test "cancel_async", %{conn: conn} do
      Process.register(self(), :stream_async_test_process)
      {:ok, lv, _html} = live(conn, "/stream_async?test=cancel")

      async_ref = wait_for_async_ready_and_monitor(:cancel_stream)
      send(lv.pid, :cancel)
      assert_receive {:DOWN, ^async_ref, :process, _pid, {:shutdown, :cancel}}, 1000

      send(lv.pid, :renew_canceled)

      assert render(lv) =~ "my_stream loading..."
      assert render_async(lv, 200) =~ "renewed"
    end

    test "reset option does not clear stream during loading", %{conn: conn} do
      {:ok, lv, html} = live(conn, "/stream_async?test=reset_option")
      # Initial value is already in stream
      assert html =~ "Initial"
      assert render(lv) =~ "my_stream loading..."

      rendered = render_async(lv)
      assert rendered =~ "First"
      # Reset only changed the loading state, not the stream itself
      assert rendered =~ "Initial"
    end

    test "multiple stream_async calls", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream_async?test=ok")

      # Wait for first load
      assert render_async(lv) =~ "Second"

      # Add more items
      send(lv.pid, :add_items)
      rendered = render_async(lv)
      assert rendered =~ "Third"
      assert rendered =~ "Fourth"

      # Should still have original items
      assert render(lv) =~ "First"
      assert render(lv) =~ "Second"
    end

    test "stream_async with reset in return", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream_async?test=ok")

      # Wait for first load
      assert render_async(lv) =~ "Second"

      # Reset with new items
      send(lv.pid, :reset_items)
      rendered = render_async(lv)

      assert rendered =~ "Fifth"
      assert rendered =~ "Sixth"
      refute rendered =~ "First"
      refute rendered =~ "Second"
    end

    test "stream is available (empty) before async finishes", %{conn: conn} do
      {:ok, lv, html} = live(conn, "/stream_async?test=ok&no_init=true")

      refute html =~ "Initial"

      rendered = render_async(lv)
      lazy = LazyHTML.from_fragment(rendered)

      assert [
               {"li", [{"id", "my_stream-1"}, _], ["First"]},
               {"li", [{"id", "my_stream-2"}, _], ["Second"]}
             ] = LazyHTML.query(lazy, "li") |> LazyHTML.to_tree()
    end
  end

  describe "LiveComponent stream_async" do
    test "bad return", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream_async?test=lc_bad_return")

      assert render_async(lv) =~
               "expected stream_async to return {:ok, Enumerable.t()} or {:error, reason}, got: 123"
    end

    test "not enumerable", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream_async?test=lc_bad_ok")

      assert render_async(lv) =~
               "does not implement the Enumerable protocol"
    end

    test "valid return", %{conn: conn} do
      {:ok, lv, html} = live(conn, "/stream_async?test=lc_ok")
      assert html =~ "lc_stream loading..."

      rendered = render_async(lv)
      assert rendered =~ "LC First"
      assert rendered =~ "LC Second"
    end

    test "raise during execution", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream_async?test=lc_raise")

      assert render_async(lv) =~ "exit:"
      assert render_async(lv) =~ "RuntimeError"
      assert render_async(lv) =~ "boom"
    end

    test "exit during execution", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream_async?test=lc_exit")

      assert render_async(lv) =~ "exit: :boom"
    end

    test "lv exit brings down asyncs", %{conn: conn} do
      Process.register(self(), :stream_async_test_process)
      {:ok, lv, _html} = live(conn, "/stream_async?test=lc_lv_exit")
      lv_ref = Process.monitor(lv.pid)

      async_ref = wait_for_async_ready_and_monitor(:lc_stream_exit)
      send(lv.pid, :boom)

      assert_receive {:DOWN, ^lv_ref, :process, _pid, :boom}, 1000
      assert_receive {:DOWN, ^async_ref, :process, _pid, :boom}, 1000
    end

    test "cancel_async", %{conn: conn} do
      Process.register(self(), :stream_async_test_process)
      {:ok, lv, _html} = live(conn, "/stream_async?test=lc_cancel")

      async_ref = wait_for_async_ready_and_monitor(:lc_stream_cancel)

      # Send cancel to the LiveView, which will forward to the component
      send(lv.pid, {:cancel_lc, "lc"})

      assert_receive {:DOWN, ^async_ref, :process, _pid, {:shutdown, :cancel}}, 1000

      refute render(lv) =~ "LC First"
    end
  end
end
