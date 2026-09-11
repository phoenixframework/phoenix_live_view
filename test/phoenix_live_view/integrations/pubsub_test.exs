defmodule Phoenix.LiveViewTest.Support.PubSubLive do
  use Phoenix.LiveView

  alias Phoenix.LiveView

  @pubsub Phoenix.LiveViewTest.PubSubTest.PubSub

  defmodule Child do
    use Phoenix.LiveComponent

    alias Phoenix.LiveView

    @pubsub Phoenix.LiveViewTest.PubSubTest.PubSub

    def mount(socket) do
      socket = assign(socket, :messages, [])
      {:ok, LiveView.subscribe(socket, @pubsub, "lv-pubsub-test", &receive_message/2)}
    end

    def receive_message(message, socket) do
      assign(socket, :messages, socket.assigns.messages ++ [message])
    end

    def render(assigns) do
      ~H"""
      <div id={@id}>{@id}: {inspect(@messages)}</div>
      """
    end

    def handle_event("unsubscribe", _params, socket) do
      {:noreply, LiveView.unsubscribe(socket, @pubsub, "lv-pubsub-test")}
    end
  end

  def mount(_params, _session, socket) do
    socket = assign(socket, messages: [], children: [])
    {:ok, LiveView.subscribe(socket, @pubsub, "lv-pubsub-test", &receive_message/2)}
  end

  def receive_message(message, socket) do
    assign(socket, :messages, socket.assigns.messages ++ [message])
  end

  def render(assigns) do
    ~H"""
    <div id="root">root: {inspect(@messages)}</div>
    <.live_component :for={id <- @children} module={Child} id={id} />
    """
  end

  def handle_event("unsubscribe", _params, socket) do
    {:noreply, LiveView.unsubscribe(socket, @pubsub, "lv-pubsub-test")}
  end

  def handle_event("add-child", %{"id" => id}, socket) do
    {:noreply, assign(socket, :children, socket.assigns.children ++ [id])}
  end

  def handle_event("remove-child", %{"id" => id}, socket) do
    {:noreply, assign(socket, :children, socket.assigns.children -- [id])}
  end
end

defmodule Phoenix.LiveViewTest.Support.PubSubBadCallbackLive do
  use Phoenix.LiveView

  alias Phoenix.LiveView

  @pubsub Phoenix.LiveViewTest.PubSubTest.PubSub

  def mount(_params, _session, socket) do
    {:ok,
     LiveView.subscribe(socket, @pubsub, "lv-pubsub-test", fn _message, _socket -> :boom end)}
  end

  def render(assigns) do
    ~H"""
    <div>bad callback</div>
    """
  end
end

defmodule Phoenix.LiveViewTest.Support.PubSubOutsideLive do
  use Phoenix.LiveView

  alias Phoenix.LiveView

  @pubsub Phoenix.LiveViewTest.PubSubTest.PubSub

  def mount(_params, session, socket) do
    {:ok, assign(socket, :test_pid, session["test_pid"])}
  end

  def render(assigns) do
    ~H"""
    <div>outside</div>
    """
  end

  def handle_event("subscribe-from-task", _params, socket) do
    task =
      Task.async(fn ->
        try do
          LiveView.subscribe(socket, @pubsub, "lv-pubsub-test", fn _msg, socket -> socket end)
          :no_raise
        rescue
          e in ArgumentError -> {:raised, e.message}
        end
      end)

    send(self(), {:task_result, Task.await(task)})
    {:noreply, socket}
  end

  def handle_info({:task_result, result}, socket) do
    send(socket.assigns.test_pid, {:task_result, result})
    {:noreply, socket}
  end
end

defmodule Phoenix.LiveViewTest.PubSubTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Phoenix.LiveViewTest.Support.{PubSubBadCallbackLive, PubSubLive, PubSubOutsideLive}

  @endpoint Phoenix.LiveViewTest.Support.Endpoint
  @pubsub Phoenix.LiveViewTest.PubSubTest.PubSub

  setup do
    start_supervised!({Phoenix.PubSub, name: @pubsub})
    %{conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})}
  end

  defp subscriptions do
    Registry.lookup(@pubsub, "lv-pubsub-test")
  end

  # the registry cleans up after a DOWN and the client sends "cids_destroyed"
  # asynchronously, so unsubscription is not observable right away
  defp eventually(fun, retries \\ 100) do
    fun.()
  rescue
    error ->
      if retries > 0 do
        Process.sleep(10)
        eventually(fun, retries - 1)
      else
        reraise(error, __STACKTRACE__)
      end
  end

  describe "LiveView" do
    test "receives messages through the callback", %{conn: conn} do
      {:ok, lv, html} = live_isolated(conn, PubSubLive)
      assert html =~ "root: []"

      Phoenix.PubSub.broadcast(@pubsub, "lv-pubsub-test", :hello)
      assert render(lv) =~ "root: [:hello]"

      Phoenix.PubSub.broadcast(@pubsub, "lv-pubsub-test", :world)
      assert render(lv) =~ "root: [:hello, :world]"
    end

    test "is a no-op on the dead render", %{conn: conn} do
      conn =
        conn
        |> put_in([Access.key!(:private), :phoenix_endpoint], @endpoint)
        |> Phoenix.LiveView.Router.fetch_live_flash([])
        |> Phoenix.LiveView.Controller.live_render(PubSubLive, [])

      assert conn.resp_body =~ "root: []"
      assert [] = subscriptions()
    end

    test "unsubscribe stops delivery and removes the global subscription", %{conn: conn} do
      {:ok, lv, _html} = live_isolated(conn, PubSubLive)
      assert [_] = subscriptions()

      render_click(lv, "unsubscribe", %{})
      assert [] = subscriptions()

      Phoenix.PubSub.broadcast(@pubsub, "lv-pubsub-test", :hello)
      assert render(lv) =~ "root: []"
    end

    test "unsubscribes when the LiveView terminates", %{conn: conn} do
      {:ok, lv, _html} = live_isolated(conn, PubSubLive)
      assert [_] = subscriptions()

      ref = Process.monitor(lv.pid)
      GenServer.stop(lv.pid)
      assert_receive {:DOWN, ^ref, :process, _, _}

      eventually(fn -> assert [] = subscriptions() end)
    end

    test "raises when the callback does not return a socket", %{conn: conn} do
      Process.flag(:trap_exit, true)
      {:ok, lv, _html} = live_isolated(conn, PubSubBadCallbackLive)

      ref = Process.monitor(lv.pid)
      Phoenix.PubSub.broadcast(@pubsub, "lv-pubsub-test", :hello)

      assert_receive {:DOWN, ^ref, :process, _, {%ArgumentError{message: message}, _}}
      assert message =~ "expected pubsub subscription callback to return a %Socket{}"
    end

    test "raises when called outside of the LiveView process", %{conn: conn} do
      {:ok, lv, _html} =
        live_isolated(conn, PubSubOutsideLive, session: %{"test_pid" => self()})

      render_click(lv, "subscribe-from-task", %{})

      assert_receive {:task_result, {:raised, message}}
      assert message =~ "can only be called from the LiveView process itself"
    end
  end

  describe "LiveComponent" do
    test "receives messages through the callback", %{conn: conn} do
      {:ok, lv, _html} = live_isolated(conn, PubSubLive)
      render_click(lv, "add-child", %{"id" => "child-1"})

      Phoenix.PubSub.broadcast(@pubsub, "lv-pubsub-test", :hello)

      html = render(lv)
      assert html =~ "root: [:hello]"
      assert html =~ "child-1: [:hello]"
    end

    test "subscribes globally only once for multiple subscribers", %{conn: conn} do
      {:ok, lv, _html} = live_isolated(conn, PubSubLive)
      render_click(lv, "add-child", %{"id" => "child-1"})
      render_click(lv, "add-child", %{"id" => "child-2"})

      assert [_] = subscriptions()

      Phoenix.PubSub.broadcast(@pubsub, "lv-pubsub-test", :hello)

      html = render(lv)
      assert html =~ "root: [:hello]"
      assert html =~ "child-1: [:hello]"
      assert html =~ "child-2: [:hello]"
    end

    test "a component unsubscribing keeps the other subscribers", %{conn: conn} do
      {:ok, lv, _html} = live_isolated(conn, PubSubLive)
      render_click(lv, "add-child", %{"id" => "child-1"})

      lv |> with_target("#child-1") |> render_click("unsubscribe", %{})
      assert [_] = subscriptions()

      Phoenix.PubSub.broadcast(@pubsub, "lv-pubsub-test", :hello)

      html = render(lv)
      assert html =~ "root: [:hello]"
      assert html =~ "child-1: []"
    end

    test "unsubscribes when the last component is removed from the page", %{conn: conn} do
      {:ok, lv, _html} = live_isolated(conn, PubSubLive)
      render_click(lv, "unsubscribe", %{})
      render_click(lv, "add-child", %{"id" => "child-1"})

      assert [_] = subscriptions()

      render_click(lv, "remove-child", %{"id" => "child-1"})

      eventually(fn -> assert [] = subscriptions() end)
    end
  end
end
