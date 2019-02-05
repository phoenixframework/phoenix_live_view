defmodule Phoenix.LiveView.LiveViewTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  defmodule ClockView do
    use Phoenix.LiveView

    def render(assigns) do
      ~L"time: <%= @time %>"
    end

    def mount(_session, socket) do
      {:ok, assign(socket, time: "12:00")}
    end

    def handle_call({:set, new_time}, _from, socket) do
      {:reply, :ok, assign(socket, :time, new_time)}
    end
  end

  defmodule CounterView do
    use Phoenix.LiveView

    def render(assigns) do
      ~L"""
      The count is: <%= @val %>
      <button phx-click="dec">-</button>
      <button phx-click="inc">+</button><%= if @nest do %>
        <%= live_render(@socket, ClockView) %>
      <% end %>
      """
    end

    def mount(_session, socket) do
      if connected?(socket) do
        {:ok, assign(socket, val: 1, nest: false)}
      else
        {:ok, assign(socket, val: 0, nest: false)}
      end
    end

    def handle_event("noop", _, socket), do: {:noreply, socket}

    def handle_event("inc", _, socket), do: {:noreply, update(socket, :val, &(&1 + 1))}

    def handle_event("dec", _, socket), do: {:noreply, update(socket, :val, &(&1 - 1))}

    def handle_info(:noop, socket), do: {:noreply, socket}

    def handle_info({:set, var, val}, socket) do
      {:noreply, assign(socket, var, val)}
    end
  end

  setup do
    {:ok, view, html} = mount_disconnected(CounterView, session: %{})
    {:ok, view: view, html: html}
  end

  test "mount with disconnected module" do
    {:ok, _view, html} = mount(CounterView)
    assert html =~ "The count is: 1"
  end

  describe "rendering" do
    test "live render with valid session", %{view: view, html: html} do
      assert html =~ """
             The count is: 0
             <button phx-click="dec">-</button>
             <button phx-click="inc">+</button>
             """

      {:ok, view, html} = mount(view)
      assert is_pid(view.pid)

      assert html =~ """
             The count is: 1
             <button phx-click="dec">-</button>
             <button phx-click="inc">+</button>
             """
    end

    test "live render with bad session", %{view: view} do
      assert {:error, %{reason: "badsession"}} =
               mount(%Phoenix.LiveViewTest.View{view | token: "bad"})
    end
  end

  describe "messaging callbacks" do

    test "handle_event with no change in socket", %{view: view} do
      {:ok, view, html} = mount(view)
      assert html =~ "The count is: 1"
      assert render_click(view, :noop) == html
    end

    test "handle_info with change", %{view: view} do
      {:ok, view, _html} = mount(view)

      assert render(view) =~ "The count is: 1"

      send(view.pid, {:set, :val, 1})
      send(view.pid, {:set, :val, 2})
      send(view.pid, {:set, :val, 3})

      assert render_click(view, :inc) =~ """
             The count is: 4
             <button phx-click="dec">-</button>
             <button phx-click="inc">+</button>
             """

      assert render_click(view, :dec) =~ """
             The count is: 3
             <button phx-click="dec">-</button>
             <button phx-click="inc">+</button>
             """

      assert render(view) == """
             The count is: 3
             <button phx-click="dec">-</button>
             <button phx-click="inc">+</button>
             """
    end
  end

  describe "nested live render" do
    test "notifies caller of spawned view" do
      {:ok, view, _html} = mount(CounterView)

      assert render(view) =~ "The count is: 1"
      refute render(view) =~ "data-phx-session"
      send(view.pid, {:set, :nest, true})
      assert render(view) =~ "The count is: 1"
      assert render(view) =~ "data-phx-session"

      {:ok, clock_view, html} = assert_receive_mount(view, ClockView)
      assert html == "time: 12:00"

      :ok = GenServer.call(clock_view.pid, {:set, "12:01"})
      assert render(clock_view) == "time: 12:01"
    end
  end
end
