defmodule Phoenix.LiveView.StartAsyncTest do
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
      Process.register(self(), :start_async_test_process)
      {:ok, lv, _html} = live(conn, "/start_async?test=lv_exit")
      lv_ref = Process.monitor(lv.pid)

      async_ref = wait_for_async_ready_and_monitor(:start_async_exit)
      send(lv.pid, :boom)

      assert_receive {:DOWN, ^lv_ref, :process, _pid, :boom}, 1000
      assert_receive {:DOWN, ^async_ref, :process, _pid, :boom}, 1000
    end

    test "cancel_async", %{conn: conn} do
      Process.register(self(), :start_async_test_process)
      {:ok, lv, _html} = live(conn, "/start_async?test=cancel")

      async_ref = wait_for_async_ready_and_monitor(:start_async_cancel)

      assert render(lv) =~ "result: :loading"

      send(lv.pid, :cancel)

      assert_receive {:DOWN, ^async_ref, :process, _pid, {:shutdown, :cancel}}, 1000

      assert render(lv) =~ "result: {:exit, {:shutdown, :cancel}}"

      send(lv.pid, :renew_canceled)

      assert render(lv) =~ "result: :loading"
      assert render_async(lv, 200) =~ "result: :renewed"
    end

    test "trapping exits", %{conn: conn} do
      Process.register(self(), :start_async_trap_exit_test)
      {:ok, lv, _html} = live(conn, "/start_async?test=trap_exit")

      assert render_async(lv, 200) =~ "{:exit, :boom}"
      assert render(lv)
      assert_receive {:exit, _pid, :boom}, 1000
    end

    test "complex key task", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=complex_key")

      assert render_async(lv) =~ "result: :complex_key"
    end

    test "navigate", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=navigate")

      assert_redirect(lv, "/start_async?test=ok")
    end

    test "patch", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=patch")

      assert_patch(lv, "/start_async?test=ok")
    end

    test "redirect", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=redirect")

      assert_redirect(lv, "/not_found")
    end

    test "put_flash", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=put_flash")

      assert render_async(lv) =~ "flash: hello"
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
      Process.register(self(), :start_async_test_process)
      {:ok, lv, _html} = live(conn, "/start_async?test=lc_lv_exit")
      lv_ref = Process.monitor(lv.pid)

      async_ref = wait_for_async_ready_and_monitor(:start_async_exit)
      send(lv.pid, :boom)

      assert_receive {:DOWN, ^lv_ref, :process, _pid, :boom}, 1000
      assert_receive {:DOWN, ^async_ref, :process, _pid, :boom}, 1000
    end

    test "cancel_async", %{conn: conn} do
      Process.register(self(), :start_async_test_process)
      {:ok, lv, _html} = live(conn, "/start_async?test=lc_cancel")

      async_ref = wait_for_async_ready_and_monitor(:start_async_cancel)

      Phoenix.LiveView.send_update(lv.pid, Phoenix.LiveViewTest.Support.StartAsyncLive.LC,
        id: "lc",
        action: :cancel
      )

      assert_receive {:DOWN, ^async_ref, :process, _pid, {:shutdown, :cancel}}

      assert render(lv) =~ "lc: {:exit, {:shutdown, :cancel}}"

      Phoenix.LiveView.send_update(lv.pid, Phoenix.LiveViewTest.Support.StartAsyncLive.LC,
        id: "lc",
        action: :renew_canceled
      )

      assert render(lv) =~ "lc: :loading"
      assert render_async(lv, 200) =~ "lc: :renewed"
    end

    test "complex key task", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=lc_complex_key")

      assert render_async(lv) =~ "lc: :complex_key"
    end

    test "navigate", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=lc_navigate")

      assert_redirect(lv, "/start_async?test=ok")
    end

    test "patch", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=lc_patch")

      assert_patch(lv, "/start_async?test=ok")
    end

    test "redirect", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=lc_redirect")

      assert_redirect(lv, "/not_found")
    end

    test "navigate with flash", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/start_async?test=lc_navigate_flash")

      flash = assert_redirect(lv, "/start_async?test=ok")
      assert %{"info" => "hello"} = flash
    end
  end
end
