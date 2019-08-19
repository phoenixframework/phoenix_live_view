defmodule Phoenix.LiveView.LiveViewTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveView
  alias Phoenix.LiveViewTest.{Endpoint, DOM, ThermostatLive, ClockLive, ClockControlsLive}

  @endpoint Endpoint
  @moduletag :capture_log

  setup config do
    {:ok,
     conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), config[:session] || %{})}
  end

  defp session(view) do
    {:ok, session} =
      Phoenix.LiveView.View.verify_session(view.endpoint, view.session_token, view.static_token)

    session
  end

  defp simulate_bad_token_on_page(conn) do
    html = html_response(conn, 200)
    [{session_token, nil, _id} | _] = DOM.find_sessions(html)
    %Plug.Conn{conn | resp_body: String.replace(html, session_token, "badsession")}
  end

  describe "mounting" do
    test "static mount followed by connected mount", %{conn: conn} do
      conn = get(conn, "/thermo")
      assert html_response(conn, 200) =~ "The temp is: 0"

      {:ok, _view, html} = live(conn)
      assert html =~ "The temp is: 1"
    end

    test "live mount in single call", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 1"
    end

    test "live mount without issuing request", %{conn: conn} do
      assert_raise ArgumentError, ~r/a request has not yet been sent/, fn ->
        live(conn)
      end
    end
  end

  describe "rendering" do
    test "live render with valid session", %{conn: conn} do
      conn = get(conn, "/thermo")
      html = html_response(conn, 200)

      assert html =~ """
             The temp is: 0
             <button phx-click="dec">-</button>
             <button phx-click="inc">+</button>
             """

      {:ok, view, html} = live(conn)
      assert is_pid(view.pid)

      assert html =~ """
             The temp is: 1
             <button phx-click="dec">-</button>
             <button phx-click="inc">+</button>
             """
    end

    test "live render with bad session", %{conn: conn} do
      conn = simulate_bad_token_on_page(get(conn, "/thermo"))

      assert ExUnit.CaptureLog.capture_log(fn ->
               assert {:error, %{reason: "badsession"}} = live(conn)
             end) =~ "failed while verifying session"
    end

    test "render_submit", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render_submit(view, :save, %{temp: 20}) =~ "The temp is: 20"
    end

    test "render_change", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render_change(view, :save, %{temp: 21}) =~ "The temp is: 21"
    end

    @key_i 73
    @key_d 68
    test "render_key|up|down", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render(view) =~ "The temp is: 1"
      assert render_keyup(view, :key, @key_i) =~ "The temp is: 2"
      assert render_keydown(view, :key, @key_d) =~ "The temp is: 1"
      assert render_keyup(view, :key, @key_d) =~ "The temp is: 0"
      assert render(view) =~ "The temp is: 0"
    end

    test "render_blur and render_focus", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render(view) =~ "The temp is: 1"
      assert render_blur(view, :inactive, "Zzz") =~ "Tap to wake – Zzz"
      assert render_focus(view, :active, "Hello!") =~ "Waking up – Hello!"
    end

    test "custom DOM container and attributes", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{nest: [container: {:p, style: "clock-flex"}]})
        |> get("/thermo-container")

      static_html = html_response(conn, 200)

      {:ok, view, connected_html} = live(conn)

      assert static_html =~
               ~r/<span[^>]*data-phx-view=\"Phoenix.LiveViewTest.ThermostatLive\"[^>]*style=\"thermo-flex&lt;script&gt;\">/

      assert static_html =~ ~r/<\/span>/

      assert static_html =~
               ~r/<p[^>]*data-phx-view=\"Phoenix.LiveViewTest.ClockLive\"[^>]*style=\"clock-flex">/

      assert static_html =~ ~r/<\/p>/

      assert connected_html =~
               ~r/<p[^>]*data-phx-view=\"Phoenix.LiveViewTest.ClockLive\"[^>]*style=\"clock-flex">/

      assert connected_html =~ ~r/<\/p>/

      assert render(view) =~
               ~r/<p[^>]*data-phx-view=\"Phoenix.LiveViewTest.ClockLive\"[^>]*style=\"clock-flex">/

      assert render(view) =~ ~r/<\/p>/
    end
  end

  describe "messaging callbacks" do
    test "handle_event with no change in socket", %{conn: conn} do
      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 1"
      assert render_click(view, :noop) == html
    end

    test "handle_info with change", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/thermo")

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
    test "nested child render on disconnected mount", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{nest: true})
        |> get("/thermo")

      html = html_response(conn, 200)
      assert html =~ "The temp is: 0"
      assert html =~ "time: 12:00"
      assert html =~ "<button phx-click=\"snooze\">+</button>"
    end

    @tag session: %{nest: true}
    test "nested child render on connected mount", %{conn: conn} do
      {:ok, thermo_view, _} = live(conn, "/thermo")

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

    test "dynamically added children", %{conn: conn} do
      {:ok, thermo_view, _html} = live(conn, "/thermo")

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

    @tag session: %{nest: true}
    test "nested children are removed and killed", %{conn: conn} do
      html_without_nesting = """
      The temp is: 1
      <button phx-click="dec">-</button>
      <button phx-click="inc">+</button>
      """

      {:ok, thermo_view, _} = live(conn, "/thermo")

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      refute render(thermo_view) == html_without_nesting

      GenServer.call(thermo_view.pid, {:set, :nest, false})

      assert_remove(clock_view, {:shutdown, :removed})
      assert_remove(controls_view, {:shutdown, :removed})

      assert render(thermo_view) == html_without_nesting
      assert children(thermo_view) == []
    end

    @tag session: %{dup: false}
    test "multiple nested children of same module", %{conn: conn} do
      {:ok, parent, _} = live(conn, "/same-child")
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

    @tag session: %{dup: false}
    test "multiple nested children of same module with new session", %{conn: conn} do
      {:ok, parent, _} = live(conn, "/same-child")
      assert render_click(parent, :inc) =~ "Toronto"
    end

    @tag session: %{dup: true}
    test "duplicate nested children raises", %{conn: conn} do
      assert ExUnit.CaptureLog.capture_log(fn ->
               pid = spawn(fn -> live(conn, "/same-child") end)
               Process.monitor(pid)
               assert_receive {:DOWN, _ref, :process, ^pid, _}
             end) =~ "unable to start child Phoenix.LiveViewTest.ClockLive under duplicate name"
    end

    @tag session: %{nest: true}
    test "parent graceful exit removes children", %{conn: conn} do
      {:ok, thermo_view, _} = live(conn, "/thermo")

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      stop(thermo_view)
      assert_remove(thermo_view, {:shutdown, :stop})
      assert_remove(clock_view, {:shutdown, :stop})
      assert_remove(controls_view, {:shutdown, :stop})
    end

    @tag session: %{nest: true}
    test "child level 1 graceful exit removes children", %{conn: conn} do
      {:ok, thermo_view, _html} = live(conn, "/thermo")

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      stop(clock_view)
      assert_remove(clock_view, {:shutdown, :stop})
      assert_remove(controls_view, {:shutdown, :stop})
      assert children(thermo_view) == []
    end

    @tag session: %{nest: true}
    test "child level 2 graceful exit removes children", %{conn: conn} do
      {:ok, thermo_view, _html} = live(conn, "/thermo")

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      stop(controls_view)
      assert_remove(controls_view, {:shutdown, :stop})
      assert children(thermo_view) == [clock_view]
      assert children(clock_view) == []
    end

    @tag :capture_log
    @tag session: %{nest: true}
    test "abnormal parent exit removes children", %{conn: conn} do
      {:ok, thermo_view, _html} = live(conn, "/thermo")

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      send(thermo_view.pid, :boom)

      assert_remove(thermo_view, _)
      assert_remove(clock_view, _)
      assert_remove(controls_view, _)
    end

    @tag :capture_log
    @tag session: %{nest: true}
    test "abnormal child level 1 exit removes children", %{conn: conn} do
      {:ok, thermo_view, _html} = live(conn, "/thermo")

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      send(clock_view.pid, :boom)

      assert_remove(clock_view, _)
      assert_remove(controls_view, _)
      assert children(thermo_view) == []
    end

    @tag :capture_log
    @tag session: %{nest: true}
    test "abnormal child level 2 exit removes children", %{conn: conn} do
      {:ok, thermo_view, _html} = live(conn, "/thermo")

      [clock_view] = children(thermo_view)
      [controls_view] = children(clock_view)

      send(controls_view.pid, :boom)

      assert_remove(controls_view, _)
      assert children(thermo_view) == [clock_view]
      assert children(clock_view) == []
    end

    test "nested for comprehensions", %{conn: conn} do
      users = [
        %{name: "chris", email: "chris@test"},
        %{name: "josé", email: "jose@test"}
      ]

      expected_users = "<i>chris chris@test</i>\n  \n    <i>josé jose@test</i>"

      {:ok, thermo_view, html} =
        conn
        |> put_session(:nest, true)
        |> put_session(:users, users)
        |> live("/thermo")

      assert html =~ expected_users
      assert render(thermo_view) =~ expected_users
    end
  end

  describe "redirects" do
    @tag session: %{redir: {:disconnected, ThermostatLive}}
    test "redirect from root view on disconnected mount", %{conn: conn} do
      assert {:error, %{redirect: %{to: "/thermostat_disconnected"}}} = live(conn, "/thermo")
    end

    @tag session: %{redir: {:connected, ThermostatLive}}
    test "redirect from root view on connected mount", %{conn: conn} do
      assert {:error, %{redirect: %{to: "/thermostat_connected"}}} = live(conn, "/thermo")
    end

    @tag session: %{nest: true, redir: {:disconnected, ClockLive}}
    test "redirect from child view on disconnected mount", %{conn: conn} do
      assert {:error, %{redirect: %{to: "/clock_disconnected"}}} = live(conn, "/thermo")
    end

    @tag session: %{nest: true, redir: {:connected, ClockLive}}
    test "redirect from child view on connected mount", %{conn: conn} do
      assert {:error, %{redirect: %{to: "/clock_connected"}}} = live(conn, "/thermo")
    end

    test "redirect after connected mount from root thru sync call", %{conn: conn} do
      assert {:ok, view, _} = live(conn, "/thermo")

      assert_redirect(view, "/path", fn ->
        assert render_click(view, :redir, "/path") == {:error, {:redirect, %{to: "/path"}}}
      end)

      assert_remove(view, {:redirect, "/path"})
    end

    test "redirect after connected mount from root thru async call", %{conn: conn} do
      assert {:ok, view, _} = live(conn, "/thermo")

      assert_redirect(view, "/async", fn ->
        send(view.pid, {:redir, "/async"})
      end)
    end

    test "live_redirect from child raises", %{conn: conn} do
      {:ok, thermo_view, _html} = live(conn, "/thermo")
      GenServer.call(thermo_view.pid, {:set, :nest, true})
      assert [clock_view] = children(thermo_view)

      send(
        clock_view.pid,
        {:run,
         fn socket ->
           {:noreply, LiveView.live_redirect(socket, to: "/anywhere")}
         end}
      )

      assert_remove(clock_view, {%ArgumentError{message: msg}, _stack})
      assert msg =~ "attempted to live_redirect from a nested child socket"
    end
  end

  describe "live_link" do
    test "forwards dom attribute options" do
      dom =
        LiveView.live_link("next", to: "/", class: "btn btn-large", data: [page_number: 2])
        |> Phoenix.HTML.safe_to_string()

      assert dom =~ ~s|class="btn btn-large"|
      assert dom =~ ~s|data-page-number="2"|
    end

    test "overwrites reserved options" do
      dom =
        LiveView.live_link("next", to: "page-1", href: "page-2", data: [phx_live_link: "other"])
        |> Phoenix.HTML.safe_to_string()

      assert dom =~ ~s|href="page-1"|
      refute dom =~ ~s|href="page-2"|
      assert dom =~ ~s|data-phx-live-link="push"|
      refute dom =~ ~s|data-phx-live-link="other"|
    end
  end

  describe "temporary assigns" do
    test "can only be configured on mount", %{conn: conn} do
      {:ok, conf_live, html} = live(conn, "/configure")

      assert html == "long description"
      assert render(conf_live) == "long description"
      socket = GenServer.call(conf_live.pid, {:exec, fn socket -> {:reply, socket, socket} end})

      assert socket.assigns.description == nil

      assert_raise RuntimeError, ~r/attempted to configure/, fn ->
        LiveView.configure_temporary_assigns(socket, [:name])
      end
    end
  end
end
