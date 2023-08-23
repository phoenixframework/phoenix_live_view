defmodule Phoenix.LiveView.StartAsyncTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.Endpoint

  @endpoint Endpoint

  setup do
    {:ok, conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})}
  end

  describe "LiveView start_async" do
    test "ok task", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=ok")

      assert render_async(lv) =~ "result: :good"
    end

    test "raise during execution", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=raise")

      assert render_async(lv) =~ "result: {:exit, %RuntimeError{message: &quot;boom&quot;}}"
      assert render(lv)
    end

    test "exit during execution", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=exit")

      assert render_async(lv) =~ "result: {:exit, :boom}"
      assert render(lv)
    end

    test "lv exit brings down asyncs", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=lv_exit")
      Process.unlink(lv.pid)
      lv_ref = Process.monitor(lv.pid)
      async_ref = Process.monitor(Process.whereis(:start_async_exit))
      send(lv.pid, :boom)

      assert_receive {:DOWN, ^lv_ref, :process, _pid, :boom}, 1000
      assert_receive {:DOWN, ^async_ref, :process, _pid, :boom}, 1000
    end

    test "cancel_async", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=cancel")
      Process.unlink(lv.pid)
      async_ref = Process.monitor(Process.whereis(:start_async_cancel))
      send(lv.pid, :cancel)

      assert_receive {:DOWN, ^async_ref, :process, _pid, {:shutdown, :cancel}}, 1000

      assert render(lv) =~ "result: :loading"

      send(lv.pid, :renew_canceled)

      assert render(lv) =~ "result: :loading"
      assert render_async(lv, 200) =~ "result: :renewed"
    end

    test "trapping exits", %{conn: conn} do
      Process.register(self(), :start_async_trap_exit_test)
      {:ok, lv, _html} = live(conn, "/start_async?test=trap_exit")

      assert render_async(lv, 200) =~ "result: :loading"
      assert render(lv)
      assert_receive {:exit, _pid, :boom}, 1000
    end
  end

  describe "LiveComponent start_async" do
    test "ok task", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=lc_ok")

      assert render_async(lv) =~ "lc: :good"
    end

    test "raise during execution", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=lc_raise")

      assert render_async(lv) =~ "lc: {:exit, %RuntimeError{message: &quot;boom&quot;}}"
      assert render(lv)
    end

    test "exit during execution", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=lc_exit")

      assert render_async(lv) =~ "lc: {:exit, :boom}"
      assert render(lv)
    end

    test "lv exit brings down asyncs", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=lc_lv_exit")
      Process.unlink(lv.pid)
      lv_ref = Process.monitor(lv.pid)
      async_ref = Process.monitor(Process.whereis(:start_async_exit))
      send(lv.pid, :boom)

      assert_receive {:DOWN, ^lv_ref, :process, _pid, :boom}, 1000
      assert_receive {:DOWN, ^async_ref, :process, _pid, :boom}, 1000
    end

    test "cancel_async", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=lc_cancel")
      Process.unlink(lv.pid)
      async_ref = Process.monitor(Process.whereis(:start_async_cancel))

      Phoenix.LiveView.send_update(lv.pid, Phoenix.LiveViewTest.StartAsyncLive.LC,
        id: "lc",
        action: :cancel
      )

      assert_receive {:DOWN, ^async_ref, :process, _pid, {:shutdown, :cancel}}

      assert render(lv) =~ "lc: :loading"

      Phoenix.LiveView.send_update(lv.pid, Phoenix.LiveViewTest.StartAsyncLive.LC,
        id: "lc",
        action: :renew_canceled
      )

      assert render(lv) =~ "lc: :loading"
      assert render_async(lv, 200) =~ "lc: :renewed"
    end
  end
end
