defmodule Phoenix.LiveView.AssignAsyncTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest

  import Phoenix.LiveViewTest
  import Phoenix.LiveViewTest.Support.AsyncSync
  alias Phoenix.LiveViewTest.Support.Endpoint
  alias Phoenix.LiveViewTest.Support.Repo

  @endpoint Endpoint

  setup do
    Process.flag(:trap_exit, true)
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

    test "keyword list return", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=bad_keyword")

      assert render_async(lv) =~
               "expected assign_async to return {:ok, map} of\\nassigns for [:data] or {:error, reason}, got: {:ok, [data: 123]}"

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
      Process.register(self(), :assign_async_test_process)
      {:ok, lv, _html} = live(conn, "/assign_async?test=lv_exit")
      lv_ref = Process.monitor(lv.pid)

      async_ref = wait_for_async_ready_and_monitor(:lv_exit)
      send(lv.pid, :boom)

      assert_receive {:DOWN, ^lv_ref, :process, _pid, :boom}, 1000
      assert_receive {:DOWN, ^async_ref, :process, _pid, :boom}, 1000
    end

    test "cancel_async", %{conn: conn} do
      Process.register(self(), :assign_async_test_process)
      {:ok, lv, _html} = live(conn, "/assign_async?test=cancel")

      async_ref = wait_for_async_ready_and_monitor(:cancel)
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
               "exit: {%ArgumentError{message: &quot;expected assign_async to return {:ok, map} of\\nassigns for [:lc_data, :other_data] or {:error, reason}, got: 123\\n&quot;}"

      assert render(lv)
    end

    test "missing known key", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=lc_bad_ok")

      assert render_async(lv) =~
               "expected assign_async to return map of assigns for all keys\\nin [:lc_data, :other_data]"

      assert render(lv)
    end

    test "valid return", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=lc_ok")
      assert render_async(lv) =~ "lc_data: 123"
    end

    test "keeps previous values when updating async assign", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=lc_ok")
      assert render_async(lv) =~ "lc_data: 123"

      Phoenix.LiveView.send_update(lv.pid, Phoenix.LiveViewTest.Support.AssignAsyncLive.LC,
        id: "lc",
        action: :assign_async_reset,
        reset: false
      )

      assert render(lv) =~ "lc_data: 123"
      assert render_async(lv) =~ "lc_data: 456"
    end

    test "keeps previous values when using a list for async assign", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=lc_ok")
      rendered = render_async(lv)
      assert rendered =~ "lc_data: 123"
      assert rendered =~ "other_data: 555"

      Phoenix.LiveView.send_update(lv.pid, Phoenix.LiveViewTest.Support.AssignAsyncLive.LC,
        id: "lc",
        action: :assign_async_reset,
        reset: [:other_data]
      )

      rendered = render(lv)
      assert rendered =~ "lc_data: 123"
      assert rendered =~ "other_data loading"
      rendered = render_async(lv)
      assert rendered =~ "lc_data: 456"
      assert rendered =~ "other_data: 999"
    end

    test "when using the reset flag", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/assign_async?test=lc_ok")
      assert render_async(lv) =~ "lc_data: 123"

      Phoenix.LiveView.send_update(lv.pid, Phoenix.LiveViewTest.Support.AssignAsyncLive.LC,
        id: "lc",
        action: :assign_async_reset,
        reset: true
      )

      assert render(lv) =~ "loading"
      refute render(lv) =~ "lc_data: 123"
      assert render_async(lv) =~ "lc_data: 456"
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
      Process.register(self(), :assign_async_test_process)
      {:ok, lv, _html} = live(conn, "/assign_async?test=lc_lv_exit")
      lv_ref = Process.monitor(lv.pid)

      async_ref = wait_for_async_ready_and_monitor(:lc_exit)
      send(lv.pid, :boom)

      assert_receive {:DOWN, ^lv_ref, :process, _pid, :boom}, 1000
      assert_receive {:DOWN, ^async_ref, :process, _pid, :boom}, 1000
    end

    test "cancel_async", %{conn: conn} do
      Process.register(self(), :assign_async_test_process)
      {:ok, lv, _html} = live(conn, "/assign_async?test=lc_cancel")

      async_ref = wait_for_async_ready_and_monitor(:lc_cancel)

      Phoenix.LiveView.send_update(lv.pid, Phoenix.LiveViewTest.Support.AssignAsyncLive.LC,
        id: "lc",
        action: :cancel
      )

      assert_receive {:DOWN, ^async_ref, :process, _pid, {:shutdown, :cancel}}, 1000

      assert render(lv) =~ "exit: {:shutdown, :cancel}"

      Phoenix.LiveView.send_update(lv.pid, Phoenix.LiveViewTest.Support.AssignAsyncLive.LC,
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
      html = render_async(lv)
      assert html =~ "data: 123"
      refute html =~ "expected assign_async to return"
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

  # Reproduces a race where:
  # 1. LiveView starts slow async DB work (holds a sandbox checkout)
  # 2. Test clicks a button that does a `push_navigate`
  # 3. LiveView exits and kills the linked async while it still holds the DB client
  # 4. Cleaning up that crashed client removes the test's sandbox allowance
  #    (the owner process can still be alive)
  # 5. The test process then fails on its next DB use with OwnershipError
  test "sandbox ownership survives push_navigate during async DB work", %{conn: conn} do
    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Repo, shared: false)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)
    owner_ref = Process.monitor(owner)

    Process.register(self(), :async_sandbox_race_test)

    Application.put_env(:phoenix_live_view, :unlink_asyncs_on_navigate, true)
    on_exit(fn -> Application.put_env(:phoenix_live_view, :unlink_asyncs_on_navigate, false) end)

    {:ok, lv, _html} = live(conn, "/async_sandbox_race")

    assert_receive {:async_holding_connection, async_pid}, 1_000
    async_ref = Process.monitor(async_pid)

    # Navigate away while the async still holds the sandbox connection.
    assert {:error, {:live_redirect, %{to: "/async_sandbox_race/done"}}} =
             lv |> element("#navigate") |> render_click()

    # Wait until the async is gone so any ownership fallout has settled.
    assert_receive {:DOWN, ^async_ref, :process, ^async_pid, async_reason}, 1_000

    owner_status =
      receive do
        {:DOWN, ^owner_ref, :process, ^owner, reason} -> {:down, reason}
      after
        50 -> if Process.alive?(owner), do: :alive, else: :dead
      end

    # This is what fails when the race hits: the test process itself can no longer use the DB
    # even though it started the sandbox owner.
    result = Repo.query("SELECT 1")

    assert match?({:ok, %{rows: [[1]]}}, result), """
    test process lost sandbox access

    async exit reason: #{inspect(async_reason)}
    sandbox owner status: #{inspect(owner_status)}
    Repo.query/1 result: #{inspect(result)}
    """
  end
end
