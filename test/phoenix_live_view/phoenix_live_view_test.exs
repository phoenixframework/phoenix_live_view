defmodule Phoenix.LiveView.LiveViewTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.{Endpoint, ThermostatLive, ClockLive, ClockControlsLive}

  def session(view) do
    {:ok, session} =
      Phoenix.LiveView.View.verify_session(view.endpoint, view.session_token, view.static_token)

    session
  end

  describe "mounting" do
    test "mount with disconnected module" do
      {:ok, _view, html} = mount(Endpoint, ThermostatLive)
      assert html =~ "The temp is: 1"
    end
  end

  describe "rendering" do
    setup do
      {:ok, view, html} = mount_disconnected(Endpoint, ThermostatLive, session: %{})
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
      assert ExUnit.CaptureLog.capture_log(fn ->
        assert {:error, %{reason: "badsession"}} =
                mount(%Phoenix.LiveViewTest.View{view | session_token: "bad"})
      end) =~ "failed while verifying session"
    end

    test "render_submit", %{view: view} do
      {:ok, view, _} = mount(view)
      assert render_submit(view, :save, %{temp: 20}) =~ "The temp is: 20"
    end

    test "render_change", %{view: view} do
      {:ok, view, _} = mount(view)
      assert render_change(view, :save, %{temp: 21}) =~ "The temp is: 21"
    end

    @key_i 73
    @key_d 68
    test "render_key|up|down", %{view: view} do
      {:ok, view, _} = mount(view)
      assert render(view) =~ "The temp is: 1"
      assert render_keyup(view, :key, @key_i) =~ "The temp is: 2"
      assert render_keydown(view, :key, @key_d) =~ "The temp is: 1"
      assert render_keyup(view, :key, @key_d) =~ "The temp is: 0"
      assert render(view) =~ "The temp is: 0"
    end

    test "render_blur and render_focus", %{view: view} do
      {:ok, view, _} = mount(view)
      assert render(view) =~ "The temp is: 1"
      assert render_blur(view, :inactive, "Zzz") =~ "Tap to wake – Zzz"
      assert render_focus(view, :active, "Hello!") =~ "Waking up – Hello!"
    end

    test "custom DOM container and attributes" do
      {:ok, view, static_html} =
        mount_disconnected(Endpoint, ThermostatLive,
          session: %{nest: [container: {:p, style: "clock-flex"}]},
          container: {:span, style: "thermo-flex<script>"}
        )

      {:ok, view, mount_html} = mount(view)

      assert static_html =~
               ~r/<span[^>]*data-phx-view=\"Phoenix.LiveViewTest.ThermostatLive\"[^>]*style=\"thermo-flex&lt;script&gt;\">/

      assert static_html =~ ~r/<\/span>/

      assert static_html =~
               ~r/<p[^>]*data-phx-view=\"Phoenix.LiveViewTest.ClockLive\"[^>]*style=\"clock-flex">/

      assert static_html =~ ~r/<\/p>/

      assert mount_html =~
               ~r/<p[^>]*data-phx-view=\"Phoenix.LiveViewTest.ClockLive\"[^>]*style=\"clock-flex">/

      assert mount_html =~ ~r/<\/p>/

      assert render(view) =~
               ~r/<p[^>]*data-phx-view=\"Phoenix.LiveViewTest.ClockLive\"[^>]*style=\"clock-flex">/

      assert render(view) =~ ~r/<\/p>/
    end
  end

  describe "messaging callbacks" do
    test "handle_event with no change in socket" do
      {:ok, view, html} = mount(Endpoint, ThermostatLive)
      assert html =~ "The temp is: 1"
      assert render_click(view, :noop) == html
    end

    test "handle_info with change" do
      {:ok, view, _html} = mount(Endpoint, ThermostatLive)

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
      {:ok, _thermo_view, html} =
        mount_disconnected(Endpoint, ThermostatLive, session: %{nest: true})

      assert html =~ "The temp is: 0"
      assert html =~ "time: 12:00"
      assert html =~ "<button phx-click=\"snooze\">+</button>"
    end

    test "nested child render on connected mount" do
      {:ok, thermo_view, _html} = mount(Endpoint, ThermostatLive, session: %{nest: true})
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
      {:ok, thermo_view, _html} = mount(Endpoint, ThermostatLive)

      assert render(thermo_view) =~ "The temp is: 1"
      refute render(thermo_view) =~ "time"
      refute render(thermo_view) =~ "snooze"
      GenServer.call(thermo_view.pid, {:set, :nest, true})
      assert render(thermo_view) =~ "The temp is: 1"
      assert render(thermo_view) =~ "time"
      assert render(thermo_view) =~ "snooze"

      assert [clock_view] = children(thermo_view)
      assert [controls_view] = children(clock_view)
      assert clock_view.module == ClockLive
      assert controls_view.module == ClockControlsLive

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

      {:ok, thermo_view, _html} = mount(Endpoint, ThermostatLive, session: %{nest: true})

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      refute render(thermo_view) == html_without_nesting

      GenServer.call(thermo_view.pid, {:set, :nest, false})

      assert_remove(clock_view, {:shutdown, :removed})
      assert_remove(controls_view, {:shutdown, :removed})

      assert render(thermo_view) == html_without_nesting
      assert children(thermo_view) == []
    end

    defmodule SameChildLive do
      use Phoenix.LiveView

      def render(%{dup: true} = assigns) do
        ~L"""
        <%= for name <- @names do %>
          <%= live_render(@socket, ClockLive, session: %{name: name}) %>
        <% end %>
        """
      end

      def render(%{dup: false} = assigns) do
        ~L"""
        <%= for name <- @names do %>
          <%= live_render(@socket, ClockLive, session: %{name: name}, child_id: name) %>
        <% end %>
        """
      end

      def mount(%{dup: dup}, socket) do
        {:ok, assign(socket, dup: dup, names: ~w(Tokyo Madrid Toronto))}
      end
    end

    test "multiple nested children of same module" do
      {:ok, parent, _html} = mount(Endpoint, SameChildLive, session: %{dup: false})
      [tokyo, madrid, toronto] = children(parent)

      child_ids =
        for sess <- [tokyo, madrid, toronto],
            %{id: id} = session(sess),
            do: id

      assert Enum.uniq(child_ids) == child_ids
      assert render(parent) =~ "Tokyo"
      assert render(parent) =~ "Madrid"
      assert render(parent) =~ "Toronto"
    end

    test "duplicate nested children raises" do
      assert ExUnit.CaptureLog.capture_log(fn ->
               pid = spawn(fn -> mount(Endpoint, SameChildLive, session: %{dup: true}) end)
               Process.monitor(pid)
               assert_receive {:DOWN, _ref, :process, ^pid, _}
             end) =~ "unable to start child Phoenix.LiveViewTest.ClockLive under duplicate name"
    end

    test "parent graceful exit removes children" do
      {:ok, thermo_view, _html} = mount(Endpoint, ThermostatLive, session: %{nest: true})

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      stop(thermo_view)
      assert_remove(thermo_view, {:shutdown, :stop})
      assert_remove(clock_view, {:shutdown, :stop})
      assert_remove(controls_view, {:shutdown, :stop})
    end

    test "child level 1 graceful exit removes children" do
      {:ok, thermo_view, _html} = mount(Endpoint, ThermostatLive, session: %{nest: true})

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      stop(clock_view)
      assert_remove(clock_view, {:shutdown, :stop})
      assert_remove(controls_view, {:shutdown, :stop})
      assert children(thermo_view) == []
    end

    test "child level 2 graceful exit removes children" do
      {:ok, thermo_view, _html} = mount(Endpoint, ThermostatLive, session: %{nest: true})

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      stop(controls_view)
      assert_remove(controls_view, {:shutdown, :stop})
      assert children(thermo_view) == [clock_view]
      assert children(clock_view) == []
    end

    @tag :capture_log
    test "abnormal parent exit removes children" do
      {:ok, thermo_view, _html} = mount(Endpoint, ThermostatLive, session: %{nest: true})

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      send(thermo_view.pid, :boom)

      assert_remove(thermo_view, _)
      assert_remove(clock_view, _)
      assert_remove(controls_view, _)
    end

    @tag :capture_log
    test "abnormal child level 1 exit removes children" do
      {:ok, thermo_view, _html} = mount(Endpoint, ThermostatLive, session: %{nest: true})

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      send(clock_view.pid, :boom)

      assert_remove(clock_view, _)
      assert_remove(controls_view, _)
      assert children(thermo_view) == []
    end

    @tag :capture_log
    test "abnormal child level 2 exit removes children" do
      {:ok, thermo_view, _html} = mount(Endpoint, ThermostatLive, session: %{nest: true})

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      send(controls_view.pid, :boom)

      assert_remove(controls_view, _)
      assert children(thermo_view) == [clock_view]
      assert children(clock_view) == []
    end

    test "nested for comprehensions" do
      users = [
        %{name: "chris", email: "chris@test"},
        %{name: "josé", email: "jose@test"}
      ]

      expected_users = "<i>chris chris@test</i>\n  \n    <i>josé jose@test</i>"

      {:ok, thermo_view, html} =
        mount(Endpoint, ThermostatLive, session: %{nest: true, users: users})

      assert html =~ expected_users
      assert render(thermo_view) =~ expected_users
    end
  end

  describe "redirects" do
    test "redirect from root view on disconnected mount" do
      assert {:error, %{redirect: "/thermostat_disconnected"}} =
               mount(Endpoint, ThermostatLive, session: %{redir: {:disconnected, ThermostatLive}})
    end

    test "redirect from root view on connected mount" do
      assert {:error, %{redirect: "/thermostat_connected"}} =
               mount(Endpoint, ThermostatLive, session: %{redir: {:connected, ThermostatLive}})
    end

    test "redirect from child view on disconnected mount" do
      assert {:error, %{redirect: "/clock_disconnected"}} =
               mount(Endpoint, ThermostatLive,
                 session: %{nest: true, redir: {:disconnected, ClockLive}}
               )
    end

    test "redirect from child view on connected mount" do
      assert {:error, %{redirect: "/clock_connected"}} =
               mount(Endpoint, ThermostatLive,
                 session: %{nest: true, redir: {:connected, ClockLive}}
               )
    end

    test "redirect after connected mount from root thru sync call" do
      assert {:ok, view, _} = mount(Endpoint, ThermostatLive)

      assert_redirect(view, "/path", fn ->
        assert render_click(view, :redir, "/path") == {:error, :redirect}
      end)
    end

    test "redirect after connected mount from root thru async call" do
      assert {:ok, view, _} = mount(Endpoint, ThermostatLive)

      assert_redirect(view, "/async", fn ->
        send(view.pid, {:redir, "/async"})
      end)
    end
  end
end
