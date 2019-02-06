defmodule Phoenix.LiveView.LiveViewTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  alias Phoenix.LiveView.LiveViewTest.{ClockView, ClockControlsView}

  defmacro assert_removed(view, reason, timeout \\ 100) do
    quote do
      %Phoenix.LiveViewTest.View{pid: pid} = unquote(view)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, unquote(reason)}, unquote(timeout)
    end
  end

  defmodule ThermostatView do
    use Phoenix.LiveView

    def render(assigns) do
      ~L"""
      The temp is: <%= @val %>
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

    def handle_call({:set, var, val}, _, socket) do
      {:reply, :ok, assign(socket, var, val)}
    end
  end

  defmodule ClockView do
    use Phoenix.LiveView

    def render(assigns) do
      ~L"""
      time: <%= @time %>
      <%= live_render(@socket, ClockControlsView) %>
      """
    end

    def mount(_session, socket) do
      if connected?(socket) do
        Process.register(self(), :clock)
      end
      {:ok, assign(socket, time: "12:00")}
    end

    def handle_info(:advance, socket), do: {:noreply, socket}

    def handle_call({:set, new_time}, _from, socket) do
      {:reply, :ok, assign(socket, :time, new_time)}
    end
  end

  defmodule ClockControlsView do
    use Phoenix.LiveView

    def render(assigns), do: ~L|<button phx-click="advance">+</button>|

    def mount(_session, socket), do: {:ok, socket}

    def handle_event("advance", _, socket) do
      send(Process.whereis(:clock), :advance)
      {:noreply, socket}
    end
  end

  setup do
    {:ok, view, html} = mount_disconnected(ThermostatView, session: %{})
    {:ok, view: view, html: html}
  end

  test "mount with disconnected module" do
    {:ok, _view, html} = mount(ThermostatView)
    assert html =~ "The temp is: 1"
  end

  describe "rendering" do
    test "live render with valid session", %{view: view, html: html} do
      assert html =~ """
             The temp is: 0
             <button phx-click="dec">-</button>
             <button phx-click="inc">+</button>
             """

      {:ok, view, html} = mount(view)
      assert is_pid(view.pid)

      assert html =~ """
             The temp is: 1
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
      assert html =~ "The temp is: 1"
      assert render_click(view, :noop) == html
    end

    test "handle_info with change", %{view: view} do
      {:ok, view, _html} = mount(view)

      assert render(view) =~ "The temp is: 1"

      GenServer.call(view.pid, {:set, :val, 1})
      GenServer.call(view.pid, {:set, :val, 2})
      GenServer.call(view.pid, {:set, :val, 3})

      assert render_click(view, :inc) =~ """
             The temp is: 4
             <button phx-click="dec">-</button>
             <button phx-click="inc">+</button>
             """

      assert render_click(view, :dec) =~ """
             The temp is: 3
             <button phx-click="dec">-</button>
             <button phx-click="inc">+</button>
             """

      assert render(view) == """
             The temp is: 3
             <button phx-click="dec">-</button>
             <button phx-click="inc">+</button>
             """
    end
  end

  describe "nested live render" do
    test "nested render on mount" do
    end

    test "renders nested children" do
      {:ok, thermo_view, _html} = mount(ThermostatView)

      assert render(thermo_view) =~ "The temp is: 1"
      refute render(thermo_view) =~ "data-phx-session"
      GenServer.call(thermo_view.pid, {:set, :nest, true})
      assert render(thermo_view) =~ "The temp is: 1"
      assert render(thermo_view) =~ "data-phx-session"

      assert [clock_view] = children(thermo_view)
      assert [controls_view] = children(clock_view)

      assert render(clock_view) =~ "time: 12:00"
      assert render(controls_view) == "<button phx-click=\"advance\">+</button>"
      assert render(clock_view) =~ "<button phx-click=\"advance\">+</button>"

      :ok = GenServer.call(clock_view.pid, {:set, "12:01"})

      assert render(clock_view) =~ "time: 12:01"
      assert render(thermo_view) =~ "time: 12:01"
      assert render(thermo_view) =~ "<button phx-click=\"advance\">+</button>"
    end

    test "nested children are removed and killed" do
      html_without_nesting = """
      The temp is: 1
      <button phx-click="dec">-</button>
      <button phx-click="inc">+</button>
      """
      {:ok, thermo_view, _html} = mount(ThermostatView)
      GenServer.call(thermo_view.pid, {:set, :nest, true})

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      refute render(thermo_view) == html_without_nesting

      GenServer.call(thermo_view.pid, {:set, :nest, false})

      assert_removed clock_view, {:shutdown, :removed}
      assert_removed controls_view, {:shutdown, :removed}

      assert render(thermo_view) == html_without_nesting
      assert children(thermo_view) == []
    end
  end
end
