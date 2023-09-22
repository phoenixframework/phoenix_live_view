defmodule Phoenix.LiveView.AssignAsyncTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.Endpoint

  @endpoint Endpoint

  setup do
    {:ok, conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})}
  end

  describe "LiveView assign_async" do
    test "bad return", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=bad_return")

      assert render_async(lv) =~
               "{:exit, {%ArgumentError{message: &quot;expected assign_async to return {:ok, map} of\\nassigns for [:data] or {:error, reason}, got: 123\\n&quot;}"

      assert render(lv)
    end

    test "missing known key", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=bad_ok")

      assert render_async(lv) =~
               "expected assign_async to return map of assigns for all keys\\nin [:data]"

      assert render(lv)
    end

    test "valid return", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=ok")
      assert render_async(lv) =~ "data: 123"
    end

    test "raise during execution", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=raise")

      assert render_async(lv) =~ "{:exit, {%RuntimeError{message: &quot;boom&quot;}"
      assert render(lv)
    end

    test "exit during execution", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=exit")

      assert render_async(lv) =~ "{:exit, :boom}"
      assert render(lv)
    end

    test "lv exit brings down asyncs", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=lv_exit")
      Process.unlink(lv.pid)
      lv_ref = Process.monitor(lv.pid)
      async_ref = Process.monitor(Process.whereis(:lv_exit))
      send(lv.pid, :boom)

      assert_receive {:DOWN, ^lv_ref, :process, _pid, :boom}, 1000
      assert_receive {:DOWN, ^async_ref, :process, _pid, :boom}, 1000
    end

    test "cancel_async", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=cancel")
      Process.unlink(lv.pid)
      async_ref = Process.monitor(Process.whereis(:cancel))
      send(lv.pid, :cancel)

      assert_receive {:DOWN, ^async_ref, :process, _pid, {:shutdown, :cancel}}, 1000

      assert render(lv) =~ ":cancel"

      send(lv.pid, :renew_canceled)

      assert render(lv) =~ "data loading..."
      assert render_async(lv, 200) =~ "data: 123"
    end

    test "trapping exits", %{conn: conn} do
      Process.register(self(), :trap_exit_test)
      {:ok, lv, _html} = live(conn, "/assign_async?test=trap_exit")

      assert render_async(lv, 200) =~ "{:exit, :boom}"
      assert render(lv)
      assert_receive {:exit, _pid, :boom}, 1000
    end
  end

  describe "LiveComponent assign_async" do
    test "bad return", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=lc_bad_return")

      assert render_async(lv) =~
               "exit: {%ArgumentError{message: &quot;expected assign_async to return {:ok, map} of\\nassigns for [:lc_data] or {:error, reason}, got: 123\\n&quot;}"

      assert render(lv)
    end

    test "missing known key", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=lc_bad_ok")

      assert render_async(lv) =~
               "expected assign_async to return map of assigns for all keys\\nin [:lc_data]"

      assert render(lv)
    end

    test "valid return", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=lc_ok")
      assert render_async(lv) =~ "lc_data: 123"
    end

    test "raise during execution", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=lc_raise")

      assert render_async(lv) =~ "exit: {%RuntimeError{message: &quot;boom&quot;}"
      assert render(lv)
    end

    test "exit during execution", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=lc_exit")

      assert render_async(lv) =~ "exit: :boom"
      assert render(lv)
    end

    test "lv exit brings down asyncs", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=lc_lv_exit")
      Process.unlink(lv.pid)
      lv_ref = Process.monitor(lv.pid)
      async_ref = Process.monitor(Process.whereis(:lc_exit))
      send(lv.pid, :boom)

      assert_receive {:DOWN, ^lv_ref, :process, _pid, :boom}, 1000
      assert_receive {:DOWN, ^async_ref, :process, _pid, :boom}, 1000
    end

    test "cancel_async", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=lc_cancel")
      Process.unlink(lv.pid)
      async_ref = Process.monitor(Process.whereis(:lc_cancel))

      Phoenix.LiveView.send_update(lv.pid, Phoenix.LiveViewTest.AssignAsyncLive.LC,
        id: "lc",
        action: :cancel
      )

      assert_receive {:DOWN, ^async_ref, :process, _pid, {:shutdown, :cancel}}, 1000

      assert render(lv) =~ "exit: {:shutdown, :cancel}"

      Phoenix.LiveView.send_update(lv.pid, Phoenix.LiveViewTest.AssignAsyncLive.LC,
        id: "lc",
        action: :renew_canceled
      )

      assert render(lv) =~ "lc_data loading..."
      assert render_async(lv, 200) =~ "lc_data: 123"
    end
  end

  describe "LiveView assign_async, supervised" do
    setup do
      start_supervised!({Task.Supervisor, name: TestAsyncSupervisor})
      :ok
    end

    test "valid return", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=sup_ok")
      assert render_async(lv) =~ "data: 123"
    end

    test "raise during execution", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=sup_raise")

      assert render_async(lv) =~ "{:exit, {%RuntimeError{message: &quot;boom&quot;}"
      assert render(lv)
    end

    test "exit during execution", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=sup_exit")

      assert render_async(lv) =~ "{:exit, :boom}"
      assert render(lv)
    end
  end
end
