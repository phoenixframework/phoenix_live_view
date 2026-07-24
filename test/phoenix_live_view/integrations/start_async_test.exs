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

    test "render_async drains tasks started by async callbacks", %{conn: conn} do
      test_pid = self()

      coordinator =
        spawn(fn ->
          # Ensures the tasks only finish when render_async
          # starts monitoring them
          release_when_monitored(:first, test_pid)
          release_when_monitored(:second, test_pid)
        end)

      Process.register(coordinator, :start_async_chain_test)
      {:ok, lv, _html} = live(conn, "/start_async?test=chain")

      assert render_async(lv, 1_000) =~ "result: :second"
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

    test "link_asyncs_to_test keeps asyncs alive across navigation", %{conn: conn} do
      Process.register(self(), :start_async_test_process)

      {:ok, lv, _html} =
        live(conn, "/start_async?test=lv_exit", link_asyncs_to_test: true)

      async_ref = wait_for_async_ready_and_monitor(:start_async_exit)
      async_pid = Process.whereis(:start_async_exit)

      assert {:error, {:live_redirect, %{to: "/start_async?test=ok"}}} =
               render_click(lv, "navigate_while_async")

      assert Process.alive?(async_pid)
      refute_receive {:DOWN, ^async_ref, :process, _name, _reason}, 50

      Process.exit(async_pid, :kill)
      assert_receive {:DOWN, ^async_ref, :process, _name, :killed}
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

    test "cancel_async remains isolated from the test lifecycle", %{conn: conn} do
      Process.register(self(), :start_async_test_process)

      {:ok, lv, _html} =
        live(conn, "/start_async?test=cancel", link_asyncs_to_test: true)

      async_ref = wait_for_async_ready_and_monitor(:start_async_cancel)
      send(lv.pid, :cancel)

      assert_receive {:DOWN, ^async_ref, :process, _pid, {:shutdown, :cancel}}, 1_000
      assert Process.alive?(lv.pid)
      assert render(lv) =~ "result: {:exit, {:shutdown, :cancel}}"
    end

    test "trapping exits", %{conn: conn} do
      Process.register(self(), :start_async_trap_exit_test)
      {:ok, lv, _html} = live(conn, "/start_async?test=trap_exit")

      assert render_async(lv, 200) =~ "{:exit, :boom}"
      assert render(lv)
      assert_receive {:exit, _pid, :boom}, 1000
    end

    test "does not leak normal task exit to handle_info when trapping exits", %{conn: conn} do
      {:ok, lv, _html} =
        live_isolated(conn, Phoenix.LiveViewTest.Support.StartAsyncLive.TrapExitLeak)

      # The LiveView deliberately does not handle exit messages,
      # so we'd expect it to crash if the exit leaks
      assert render_async(lv) =~ "complete"
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

    test "link_asyncs_to_test applies to LiveComponent asyncs", %{conn: conn} do
      Process.register(self(), :start_async_test_process)

      {:ok, lv, _html} =
        live(conn, "/start_async?test=lc_lv_exit", link_asyncs_to_test: true)

      lv_ref = Process.monitor(lv.pid)
      async_ref = wait_for_async_ready_and_monitor(:start_async_exit)
      async_pid = Process.whereis(:start_async_exit)
      send(lv.pid, :boom)

      assert_receive {:DOWN, ^lv_ref, :process, _pid, :boom}, 1_000
      assert Process.alive?(async_pid)
      refute_receive {:DOWN, ^async_ref, :process, _name, _reason}, 50

      Process.exit(async_pid, :kill)
      assert_receive {:DOWN, ^async_ref, :process, _name, :killed}
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

  defp release_when_monitored(label, test_pid) do
    receive do
      {:async_started, ^label, async_pid} ->
        wait_until_monitored(async_pid, test_pid)
        send(async_pid, :finish)
    end
  end

  defp wait_until_monitored(async_pid, test_pid) do
    case Process.info(async_pid, :monitored_by) do
      {:monitored_by, monitored_by} ->
        if test_pid in monitored_by do
          :ok
        else
          Process.sleep(10)
          wait_until_monitored(async_pid, test_pid)
        end

      nil ->
        :ok
    end
  end
end
