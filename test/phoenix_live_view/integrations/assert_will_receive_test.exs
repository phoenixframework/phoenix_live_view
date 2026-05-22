defmodule Phoenix.LiveView.AssertWillReceiveTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.Support.Endpoint

  @endpoint Endpoint

  setup do
    {:ok, conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})}
  end

  defmodule AssertWillReceiveLive do
    use Phoenix.LiveView

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def handle_info({:test_message, _num}, socket) do
      {:noreply, socket}
    end

    def render(assigns) do
      ~H""
    end
  end

  describe "assert_will_receive" do
    test "asserts the LiveView process will receive a message", %{conn: conn} do
      {:ok, view, _} = live_isolated(conn, AssertWillReceiveLive)

      Task.start(fn ->
        Process.sleep(25)
        send(view.pid, {:test_message, 1})
      end)

      assert_will_receive(view, {:test_message, num})
      assert num == 1
    end

    test "runs setup function after tracing is set up", %{conn: conn} do
      {:ok, view, _} = live_isolated(conn, AssertWillReceiveLive)

      assert_will_receive(view, {:test_message, num}, fn ->
        send(view.pid, {:test_message, 1})
      end)

      assert num == 1
    end

    test "supports guards", %{conn: conn} do
      {:ok, view, _} = live_isolated(conn, AssertWillReceiveLive)

      assert_will_receive(
        view,
        {:test_message, num} when num > 1,
        fn ->
          send(view.pid, {:test_message, 1})
          send(view.pid, {:test_message, 2})
        end,
        1000
      )

      assert num == 2
    end

    test "stops tracing after the assertion", %{conn: conn} do
      {:ok, view, _} = live_isolated(conn, AssertWillReceiveLive)

      assert_will_receive(
        view,
        {:test_message, :during},
        fn ->
          send(view.pid, {:test_message, :during})
        end,
        1000
      )

      send(view.pid, {:test_message, :after})

      receive do
        {ref, {:test_message, :after}} when is_reference(ref) ->
          flunk("expected assert_will_receive to stop tracing")
      after
        50 -> :ok
      end
    end
  end
end
