defmodule Phoenix.LiveView.LiveViewTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  alias Phoenix.LiveView.LiveViewTest.{ClockView, ClockControlsView}

  defmodule ThermostatView do
    use Phoenix.LiveView

    def render(assigns) do
      ~L"""
      The temp is: <%= @val %>
      <button phx-click="dec">-</button>
      <button phx-click="inc">+</button><%= if @nest do %>
        <%= live_render(@socket, ClockView, session: %{redir: @redir}) %>
      <% end %>
      """
    end

    def mount(%{redir: {:disconnected, __MODULE__}} = session, socket) do
      if connected?(socket) do
        do_mount(session, socket)
      else
        {:stop, redirect(socket, to: "/thermostat_disconnected")}
      end
    end

    def mount(%{redir: {:connected, __MODULE__}} = session, socket) do
      if connected?(socket) do
        {:stop, redirect(socket, to: "/thermostat_connected")}
      else
        do_mount(session, socket)
      end
    end

    def mount(session, socket), do: do_mount(session, socket)

    defp do_mount(session, socket) do
      nest = Map.get(session, :nest, false)
      if connected?(socket) do
        {:ok, assign(socket, val: 1, nest: nest, redir: session[:redir])}
      else
        {:ok, assign(socket, val: 0, nest: nest, redir: session[:redir])}
      end
    end

    def handle_event("redir", to, socket) do
      {:stop, redirect(socket, to: to)}
    end

    def handle_event("noop", _, socket), do: {:noreply, socket}

    def handle_event("inc", _, socket), do: {:noreply, update(socket, :val, &(&1 + 1))}

    def handle_event("dec", _, socket), do: {:noreply, update(socket, :val, &(&1 - 1))}

    def handle_info(:noop, socket), do: {:noreply, socket}

    def handle_info({:redir, to}, socket) do
      {:stop, redirect(socket, to: to)}
    end

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

    def mount(%{redir: {:disconnected, __MODULE__}} = session, socket) do
      if connected?(socket) do
        do_mount(session, socket)
      else
        {:stop, redirect(socket, to: "/clock_disconnected")}
      end
    end

    def mount(%{redir: {:connected, __MODULE__}} = session, socket) do
      if connected?(socket) do
        {:stop, redirect(socket, to: "/clock_connected")}
      else
        do_mount(session, socket)
      end
    end

    def mount(session, socket), do: do_mount(session, socket)

    defp do_mount(_session, socket) do
      if connected?(socket) do
        Process.register(self(), :clock)
      end
      {:ok, assign(socket, time: "12:00")}
    end

    def handle_info(:snooze, socket) do
      {:noreply, assign(socket, :time, "12:05")}
    end

    def handle_call({:set, new_time}, _from, socket) do
      {:reply, :ok, assign(socket, :time, new_time)}
    end
  end

  defmodule ClockControlsView do
    use Phoenix.LiveView

    def render(assigns), do: ~L|<button phx-click="snooze">+</button>|

    def mount(_session, socket), do: {:ok, socket}

    def handle_event("snooze", _, socket) do
      send(Process.whereis(:clock), :snooze)
      {:noreply, socket}
    end
  end

  describe "mounting" do
    test "mount with disconnected module" do
      {:ok, _view, html} = mount(ThermostatView)
      assert html =~ "The temp is: 1"
    end
  end

  describe "rendering" do
    setup do
      {:ok, view, html} = mount_disconnected(ThermostatView, session: %{})
      {:ok, view: view, html: html}
    end

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

    test "handle_event with no change in socket" do
      {:ok, view, html} = mount(ThermostatView)
      assert html =~ "The temp is: 1"
      assert render_click(view, :noop) == html
    end

    test "handle_info with change" do
      {:ok, view, _html} = mount(ThermostatView)

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
    test "nested child render on disconnected mount" do
      {:ok, _thermo_view, html} = mount_disconnected(ThermostatView, session: %{nest: true})
      assert html =~ "The temp is: 0"
      assert html =~ "time: 12:00"
      assert html =~ "<button phx-click=\"snooze\">+</button>"
    end

    test "nested child render on connected mount" do
      {:ok, thermo_view, _html} = mount(ThermostatView, session: %{nest: true})
      html = render(thermo_view)
      assert html =~ "The temp is: 1"
      assert html =~ "time: 12:00"
      assert html =~ "<button phx-click=\"snooze\">+</button>"

      GenServer.call(thermo_view.pid, {:set, :nest, false})
      html = render(thermo_view)
      assert html =~ "The temp is: 1"
      refute html =~ "time"
      refute html =~ "snooze"
    end

    test "dynamically added children" do
      {:ok, thermo_view, _html} = mount(ThermostatView)

      assert render(thermo_view) =~ "The temp is: 1"
      refute render(thermo_view) =~ "time"
      refute render(thermo_view) =~ "snooze"
      GenServer.call(thermo_view.pid, {:set, :nest, true})
      assert render(thermo_view) =~ "The temp is: 1"
      assert render(thermo_view) =~ "time"
      assert render(thermo_view) =~ "snooze"

      assert [clock_view] = children(thermo_view)
      assert [controls_view] = children(clock_view)
      assert clock_view.module == ClockView
      assert controls_view.module == ClockControlsView

      assert render_click(controls_view, :snooze) == "<button phx-click=\"snooze\">+</button>"
      assert render(clock_view) =~ "time: 12:05"
      assert render(controls_view) == "<button phx-click=\"snooze\">+</button>"
      assert render(clock_view) =~ "<button phx-click=\"snooze\">+</button>"

      :ok = GenServer.call(clock_view.pid, {:set, "12:01"})

      assert render(clock_view) =~ "time: 12:01"
      assert render(thermo_view) =~ "time: 12:01"
      assert render(thermo_view) =~ "<button phx-click=\"snooze\">+</button>"
    end

    test "nested children are removed and killed" do
      html_without_nesting = """
      The temp is: 1
      <button phx-click="dec">-</button>
      <button phx-click="inc">+</button>
      """
      {:ok, thermo_view, _html} = mount(ThermostatView, session: %{nest: true})

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      refute render(thermo_view) == html_without_nesting

      GenServer.call(thermo_view.pid, {:set, :nest, false})

      assert_remove clock_view, {:shutdown, :removed}
      assert_remove controls_view, {:shutdown, :removed}

      assert render(thermo_view) == html_without_nesting
      assert children(thermo_view) == []
    end

    test "parent graceful exit removes children" do
      {:ok, thermo_view, _html} = mount(ThermostatView, session: %{nest: true})

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      stop(thermo_view)
      assert_remove thermo_view, {:shutdown, :stop}
      assert_remove clock_view, {:shutdown, :stop}
      assert_remove controls_view, {:shutdown, :stop}
    end

    test "child level 1 graceful exit removes children" do
      {:ok, thermo_view, _html} = mount(ThermostatView, session: %{nest: true})

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      stop(clock_view)
      assert_remove clock_view, {:shutdown, :stop}
      assert_remove controls_view, {:shutdown, :stop}
      assert children(thermo_view) == []
    end

    test "child level 2 graceful exit removes children" do
      {:ok, thermo_view, _html} = mount(ThermostatView, session: %{nest: true})

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      stop(controls_view)
      assert_remove controls_view, {:shutdown, :stop}
      assert children(thermo_view) == [clock_view]
      assert children(clock_view) == []
    end


    @tag :capture_log
    test "abnormal parent exit removes children" do
      {:ok, thermo_view, _html} = mount(ThermostatView, session: %{nest: true})

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      send(thermo_view.pid, :boom)

      assert_remove thermo_view, _
      assert_remove clock_view, _
      assert_remove controls_view, _
    end

    @tag :capture_log
    test "abnormal child level 1 exit removes children" do
      {:ok, thermo_view, _html} = mount(ThermostatView, session: %{nest: true})

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      send(clock_view.pid, :boom)

      assert_remove clock_view, _
      assert_remove controls_view, _
      assert children(thermo_view) == []
    end

    @tag :capture_log
    test "abnormal child level 2 exit removes children" do
      {:ok, thermo_view, _html} = mount(ThermostatView, session: %{nest: true})

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      send(controls_view.pid, :boom)

      assert_remove controls_view, _
      assert children(thermo_view) == [clock_view]
      assert children(clock_view) == []
    end
  end

  describe "redirects" do
    test "redirect from root view on disconnected mount" do
      assert {:error, %{redirect: "/thermostat_disconnected"}} =
             mount(ThermostatView, session: %{redir: {:disconnected, ThermostatView}})
    end

    test "redirect from root view on connected mount" do
      assert {:error, %{redirect: "/thermostat_connected"}} =
             mount(ThermostatView, session: %{redir: {:connected, ThermostatView}})
    end

    test "redirect from child view on disconnected mount" do
      assert {:error, %{redirect: "/clock_disconnected"}} =
             mount(ThermostatView, session: %{nest: true, redir: {:disconnected, ClockView}})
    end

    test "redirect from child view on connected mount" do
      assert {:error, %{redirect: "/clock_connected"}} =
             mount(ThermostatView, session: %{nest: true, redir: {:connected, ClockView}})
    end

    test "redirect after connected mount from root thru sync call" do
      assert {:ok, view, _} = mount(ThermostatView)

      assert_redirect view, "/path", fn ->
        assert render_click(view, :redir, "/path") == {:error, :redirect}
      end
    end

    test "redirect after connected mount from root thru async call" do
      assert {:ok, view, _} = mount(ThermostatView)

      assert_redirect view, "/async", fn ->
        send(view.pid, {:redir, "/async"})
      end
    end
  end
end
