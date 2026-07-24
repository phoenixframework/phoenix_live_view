defmodule Phoenix.LiveView.LinkAsyncsToTestTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Phoenix.LiveViewTest.Support.AsyncSync

  alias Phoenix.LiveViewTest.Support.Endpoint

  @endpoint Endpoint

  setup do
    Process.flag(:trap_exit, true)
    previous = Application.fetch_env(:phoenix_live_view, :link_asyncs_to_test)

    on_exit(fn ->
      case previous do
        {:ok, value} ->
          Application.put_env(:phoenix_live_view, :link_asyncs_to_test, value)

        :error ->
          Application.delete_env(:phoenix_live_view, :link_asyncs_to_test)
      end
    end)

    {:ok, conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})}
  end

  test "uses the configured link_asyncs_to_test default", %{conn: conn} do
    Application.put_env(:phoenix_live_view, :link_asyncs_to_test, true)
    Process.register(self(), :start_async_test_process)

    {:ok, lv, _html} = live(conn, "/start_async?test=lv_exit")
    async_ref = wait_for_async_ready_and_monitor(:start_async_exit)
    async_pid = Process.whereis(:start_async_exit)

    assert {:error, {:live_redirect, %{to: "/start_async?test=ok"}}} =
             render_click(lv, "navigate_while_async")

    assert Process.alive?(async_pid)
    refute_receive {:DOWN, ^async_ref, :process, _name, _reason}, 50

    Process.exit(async_pid, :kill)
    assert_receive {:DOWN, ^async_ref, :process, _name, :killed}
  end

  test "a live option overrides the configured default", %{conn: conn} do
    Application.put_env(:phoenix_live_view, :link_asyncs_to_test, true)
    Process.register(self(), :start_async_test_process)

    {:ok, lv, _html} =
      live(conn, "/start_async?test=lv_exit", link_asyncs_to_test: false)

    lv_ref = Process.monitor(lv.pid)
    async_ref = wait_for_async_ready_and_monitor(:start_async_exit)
    send(lv.pid, :boom)

    assert_receive {:DOWN, ^lv_ref, :process, _pid, :boom}, 1_000
    assert_receive {:DOWN, ^async_ref, :process, _pid, :boom}, 1_000
  end
end
