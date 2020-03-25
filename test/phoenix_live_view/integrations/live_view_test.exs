defmodule Phoenix.LiveView.LiveViewTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveView
  alias Phoenix.LiveViewTest.{Endpoint, DOM, ClockLive, ClockControlsLive, LayoutView}

  @endpoint Endpoint
  @moduletag :capture_log

  setup config do
    {:ok,
     conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), config[:session] || %{})}
  end

  defp simulate_bad_token_on_page(conn) do
    html = html_response(conn, 200)
    [{_id, session_token, _static} | _] = html |> DOM.parse() |> DOM.find_live_views()
    %Plug.Conn{conn | resp_body: String.replace(html, session_token, "badsession")}
  end

  defp simulate_outdated_token_on_page(conn) do
    html = html_response(conn, 200)
    [{_id, session_token, _static} | _] = html |> DOM.parse() |> DOM.find_live_views()
    salt = Phoenix.LiveView.Utils.salt!(@endpoint)
    outdated_token = Phoenix.Token.sign(@endpoint, salt, {0, %{}})
    %Plug.Conn{conn | resp_body: String.replace(html, session_token, outdated_token)}
  end

  defp simulate_expired_token_on_page(conn) do
    html = html_response(conn, 200)
    [{_id, session_token, _static} | _] = html |> DOM.parse() |> DOM.find_live_views()
    salt = Phoenix.LiveView.Utils.salt!(@endpoint)

    expired_token =
      Phoenix.Token.sign(@endpoint, salt, {Phoenix.LiveView.Static.token_vsn(), %{}}, signed_at: 0)

    %Plug.Conn{conn | resp_body: String.replace(html, session_token, expired_token)}
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

    test "live mount sets caller", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/thermo")
      {:dictionary, dictionary} = Process.info(view.pid, :dictionary)
      assert dictionary[:"$callers"] == [self()]
    end

    test "live mount without issuing request", %{conn: conn} do
      assert_raise ArgumentError, ~r/a request has not yet been sent/, fn ->
        live(conn)
      end
    end

    test "push_redirect when disconnected", %{conn: conn} do
      conn = get(conn, "/redir?during=disconnected&kind=push_redirect&to=/thermo")
      assert redirected_to(conn) == "/thermo"
    end

    test "push_redirect when connected", %{conn: conn} do
      conn = get(conn, "/redir?during=connected&kind=push_redirect&to=/thermo")
      assert html_response(conn, 200) =~ "parent_content"
      assert {:error, %{live_redirect: %{kind: :push, to: "/thermo"}}} = live(conn)
    end

    test "push_patch when disconnected", %{conn: conn} do
      assert_raise Plug.Conn.WrapperError, ~r/attempted to live patch while/, fn ->
        get(conn, "/redir?during=disconnected&kind=push_patch&to=/redir?patched=true")
      end
    end

    test "push_patch when connected", %{conn: conn} do
      conn = get(conn, "/redir?during=connected&kind=push_patch&to=/redir?patched=true")
      assert html_response(conn, 200) =~ "parent_content"

      assert_raise RuntimeError, ~r/attempted to live patch while/, fn ->
        live(conn)
      end
    end

    test "redirect when disconnected", %{conn: conn} do
      conn = get(conn, "/redir?during=disconnected&kind=redirect&to=/thermo")
      assert redirected_to(conn) == "/thermo"
    end

    test "redirect when connected", %{conn: conn} do
      conn = get(conn, "/redir?during=connected&kind=redirect&to=/thermo")
      assert html_response(conn, 200) =~ "parent_content"
      assert {:error, %{redirect: %{to: "/thermo"}}} = live(conn)
    end

    test "child push_redirect when disconnected", %{conn: conn} do
      conn = get(conn, "/redir?during=disconnected&kind=push_redirect&child_to=/thermo")
      assert redirected_to(conn) == "/thermo"
    end

    test "child push_redirect when connected", %{conn: conn} do
      conn =
        get(conn, "/redir?during=connected&kind=push_redirect&child_to=/thermo?from_child=true")

      assert html_response(conn, 200) =~ "child_content"
      assert {:error, %{redirect: "/thermo?from_child=true"}} = live(conn)
    end

    test "child push_patch when disconnected", %{conn: conn} do
      assert_raise Plug.Conn.WrapperError,
                   ~r/a LiveView cannot be mounted while issuing a live patch to the client/,
                   fn ->
                     get(
                       conn,
                       "/redir?during=disconnected&kind=push_patch&child_to=/redir?patched=true"
                     )
                   end
    end

    test "child push_patch when connected", %{conn: conn} do
      conn = get(conn, "/redir?during=connected&kind=push_patch&child_to=/redir?patched=true")
      assert html_response(conn, 200) =~ "child_content"

      assert ExUnit.CaptureLog.capture_log(fn ->
               live(conn)
             end) =~ "a LiveView cannot be mounted while issuing a live patch to the client"
    end

    test "child redirect when disconnected", %{conn: conn} do
      conn =
        get(conn, "/redir?during=disconnected&kind=redirect&child_to=/thermo?from_child=true")

      assert redirected_to(conn) == "/thermo?from_child=true"
    end

    test "child redirect when connected", %{conn: conn} do
      conn = get(conn, "/redir?during=connected&kind=redirect&child_to=/thermo?from_child=true")
      assert html_response(conn, 200) =~ "parent_content"
      assert {:error, %{redirect: "/thermo?from_child=true"}} = live(conn)
    end
  end

  describe "live_isolated" do
    test "renders a live view with custom session", %{conn: conn} do
      {:ok, view, _} =
        live_isolated(conn, Phoenix.LiveViewTest.DashboardLive, session: %{"hello" => "world"})

      assert render(view) =~ "session: %{&quot;hello&quot; =&gt; &quot;world&quot;}"
    end

    test "renders a live view with custom session and a router", %{conn: conn} do
      {:ok, view, _} =
        live_isolated(conn, Phoenix.LiveViewTest.DashboardLive, session: %{"hello" => "world"}, router: MyApp.Router)

      assert render(view) =~ "session: %{&quot;hello&quot; =&gt; &quot;world&quot;}"
    end

    test "raises if handle_params is implemented", %{conn: conn} do
      assert_raise ArgumentError,
                   ~r/it is not mounted nor accessed through the router live\/3 macro/,
                   fn -> live_isolated(conn, Phoenix.LiveViewTest.ParamCounterLive) end
    end

    test "works without an initialized session" do
      {:ok, view, _} =
        live_isolated(Phoenix.ConnTest.build_conn(), Phoenix.LiveViewTest.DashboardLive,
          session: %{"hello" => "world"}
        )

      assert render(view) =~ "session: %{&quot;hello&quot; =&gt; &quot;world&quot;}"
    end

    test "raises on session with atom keys" do
      assert_raise ArgumentError, ~r"LiveView :session must be a map with string keys,", fn ->
        live_isolated(Phoenix.ConnTest.build_conn(), Phoenix.LiveViewTest.DashboardLive,
          session: %{hello: "world"}
        )
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
      {_tag, _attrs, children} = html |> DOM.parse() |> DOM.by_id!(view.id)

      assert children == [
               "Redirect: none\nThe temp is: 1\n",
               {"button", [{"phx-click", "dec"}], ["-"]},
               {"button", [{"phx-click", "inc"}], ["+"]}
             ]
    end

    test "live render with bad session", %{conn: conn} do
      conn = simulate_bad_token_on_page(get(conn, "/thermo"))

      assert ExUnit.CaptureLog.capture_log(fn ->
               assert {:error, %{reason: "badsession"}} = live(conn)
             end) =~ "failed while verifying session"
    end

    test "live render with outdated session", %{conn: conn} do
      conn = simulate_outdated_token_on_page(get(conn, "/thermo"))

      assert ExUnit.CaptureLog.capture_log(fn ->
               assert {:error, %{reason: "outdated"}} = live(conn)
             end)
    end

    test "live render with expired session", %{conn: conn} do
      conn = simulate_expired_token_on_page(get(conn, "/thermo"))

      assert ExUnit.CaptureLog.capture_log(fn ->
               assert {:error, %{reason: "outdated"}} = live(conn)
             end)
    end

    test "render_click with string value", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render_click(view, :save, "22") =~ "The temp is: 22"
    end

    test "render_click with map value", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render_click(view, :save, %{temp: 20}) =~ "The temp is: 20"
    end

    test "render_submit", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render_submit(view, :save, %{temp: 20}) =~ "The temp is: 20"
    end

    test "render_change", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render_change(view, :save, %{temp: 21}) =~ "The temp is: 21"
    end

    test "render_change with _target", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render_change(view, :save, %{_target: "", temp: 21}) =~ "The temp is: 21[]"

      assert render_change(view, :save, %{_target: ["user"], temp: 21}) =~
               "The temp is: 21[&quot;user&quot;]"

      assert render_change(view, :save, %{_target: ["user", "name"], temp: 21}) =~
               "The temp is: 21[&quot;user&quot;, &quot;name&quot;]"

      assert render_change(view, :save, %{_target: ["another", "field"], temp: 21}) =~
               "The temp is: 21[&quot;another&quot;, &quot;field&quot;]"
    end

    test "render_key|up|down", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render(view) =~ "The temp is: 1"
      assert render_keyup(view, :key, %{"key" => "i"}) =~ "The temp is: 2"
      assert render_keydown(view, :key, %{"key" => "d"}) =~ "The temp is: 1"
      assert render_keyup(view, :key, %{"key" => "d"}) =~ "The temp is: 0"
      assert render(view) =~ "The temp is: 0"
    end

    test "render_blur and render_focus", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render(view) =~ "The temp is: 1", view.id
      assert render_blur(view, :inactive, "Zzz") =~ "Tap to wake – Zzz"
      assert render_focus(view, :active, "Hello!") =~ "Waking up – Hello!"
    end

    test "render_hook", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render_hook(view, :save, %{temp: 20}) =~ "The temp is: 20"
    end

    test "module DOM container", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{nest: []})
        |> get("/thermo")

      static_html = html_response(conn, 200)
      {:ok, view, connected_html} = live(conn)

      assert static_html =~
               ~r/<article class="thermo"[^>]*data-phx-main=\"true\".* data-phx-view=\"ThermostatLive\"[^>]*>/

      assert static_html =~ ~r/<\/article>/

      assert static_html =~
               ~r/<section class="clock"[^>]*data-phx-view=\"LiveViewTest.ClockLive\"[^>]*>/

      assert static_html =~ ~r/<\/section>/

      assert connected_html =~
               ~r/<section class="clock"[^>]*data-phx-view=\"LiveViewTest.ClockLive\"[^>]*>/

      assert connected_html =~ ~r/<\/section>/

      assert render(view) =~
               ~r/<section class="clock"[^>]*data-phx-view=\"LiveViewTest.ClockLive\"[^>]*>/

      assert render(view) =~ ~r/<\/section>/
    end

    test "custom DOM container and attributes", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{nest: [container: {:p, class: "clock-flex"}]})
        |> get("/thermo-container")

      static_html = html_response(conn, 200)
      {:ok, view, connected_html} = live(conn)

      assert static_html =~
               ~r/<span class="thermo"[^>]*data-phx-view=\"ThermostatLive\"[^>]*style=\"thermo-flex&lt;script&gt;\">/

      assert static_html =~ ~r/<\/span>/

      assert static_html =~
               ~r/<p class=\"clock-flex"[^>]*data-phx-view=\"LiveViewTest.ClockLive\"[^>]*>/

      assert static_html =~ ~r/<\/p>/

      assert connected_html =~
               ~r/<p class=\"clock-flex"[^>]*data-phx-view=\"LiveViewTest.ClockLive\"[^>]*>/

      assert connected_html =~ ~r/<\/p>/

      assert render(view) =~
               ~r/<p class=\"clock-flex"[^>]*data-phx-view=\"LiveViewTest.ClockLive\"[^>]*>/

      assert render(view) =~ ~r/<\/p>/
    end

    test "widget style live_render", %{conn: conn} do
      conn = get(conn, "/widget")
      assert html_response(conn, 200) =~ ~r/WIDGET:[\S\s]*time: 12:00 NY/
    end

    test "socket.assigns while rendering", %{conn: conn} do
      assert_raise Plug.Conn.WrapperError, ~r/\(KeyError\) key :boom not found in: %Phoenix\.LiveView\.Socket\.AssignsNotInSocket\{\}/, fn ->
        live(conn, "/assigns-not-in-socket")
      end
    end
  end

  describe "messaging callbacks" do
    test "handle_event with no change in socket", %{conn: conn} do
      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 1"
      assert render_click(view, :noop) =~ "The temp is: 1"
    end

    test "handle_info with change", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/thermo")

      assert render(view) =~ "The temp is: 1"

      GenServer.call(view.pid, {:set, :val, 1})
      GenServer.call(view.pid, {:set, :val, 2})
      GenServer.call(view.pid, {:set, :val, 3})

      assert DOM.parse(render_click(view, :inc)) ==
               DOM.parse("""
               Redirect: none\nThe temp is: 4
               <button phx-click="dec">-</button>
               <button phx-click="inc">+</button>
               """)

      assert DOM.parse(render_click(view, :dec)) ==
               DOM.parse("""
               Redirect: none\nThe temp is: 3
               <button phx-click="dec">-</button>
               <button phx-click="inc">+</button>
               """)

      assert DOM.child_nodes(hd(DOM.parse(render(view)))) ==
               DOM.parse("""
               Redirect: none\nThe temp is: 3
               <button phx-click="dec">-</button>
               <button phx-click="inc">+</button>
               """)
    end
  end

  describe "nested live render" do
    test "nested child render on disconnected mount", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{nest: []})
        |> get("/thermo")

      html = html_response(conn, 200)
      assert html =~ "The temp is: 0"
      assert html =~ "time: 12:00"
      assert html =~ "<button phx-click=\"snooze\">+</button>"
    end

    @tag session: %{nest: []}
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
      GenServer.call(thermo_view.pid, {:set, :nest, []})
      assert render(thermo_view) =~ "The temp is: 1"
      assert render(thermo_view) =~ "time"
      assert render(thermo_view) =~ "snooze"

      assert clock_view = find_child(thermo_view, "clock")
      assert controls_view = find_child(clock_view, "NY-controls")
      assert clock_view.module == ClockLive
      assert controls_view.module == ClockControlsLive

      assert render_click(controls_view, :snooze) == "<button phx-click=\"snooze\">+</button>"
      assert render(clock_view) =~ "time: 12:05"
      assert render(clock_view) =~ "<button phx-click=\"snooze\">+</button>"
      assert render(controls_view) =~ "<button phx-click=\"snooze\">+</button>"

      :ok = GenServer.call(clock_view.pid, {:set, "12:01"})

      assert render(clock_view) =~ "time: 12:01"
      assert render(thermo_view) =~ "time: 12:01"

      assert render(thermo_view) =~ "<button phx-click=\"snooze\">+</button>"
    end

    @tag session: %{nest: []}
    test "nested children are removed and killed", %{conn: conn} do
      html_without_nesting =
        DOM.parse("""
        Redirect: none\nThe temp is: 1
        <button phx-click="dec">-</button>
        <button phx-click="inc">+</button>
        """)

      {:ok, thermo_view, _} = live(conn, "/thermo")

      assert clock_view = find_child(thermo_view, "clock")
      assert controls_view = find_child(clock_view, "NY-controls")
      refute render(thermo_view) == html_without_nesting

      GenServer.call(thermo_view.pid, {:set, :nest, false})
      assert_remove(clock_view, {:shutdown, :removed})
      assert_remove(controls_view, {:shutdown, :removed})
      assert [{_, _, ^html_without_nesting}] = DOM.parse(render(thermo_view))

      refute find_child(thermo_view, "clock")
    end

    @tag session: %{dup: false}
    test "multiple nested children of same module", %{conn: conn} do
      {:ok, parent, _} = live(conn, "/same-child")
      assert tokyo = find_child(parent, "Tokyo")
      assert madrid = find_child(parent, "Madrid")
      assert toronto = find_child(parent, "Toronto")
      child_ids = for view <- [tokyo, madrid, toronto], do: view.id

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

    @tag session: %{nest: []}
    test "parent graceful exit removes children", %{conn: conn} do
      {:ok, thermo_view, _} = live(conn, "/thermo")

      assert clock_view = find_child(thermo_view, "clock")
      assert controls_view = find_child(clock_view, "NY-controls")

      stop(thermo_view)
      assert_remove(thermo_view, {:shutdown, :stop})
      assert_remove(clock_view, {:shutdown, :stop})
      assert_remove(controls_view, {:shutdown, :stop})
    end

    @tag session: %{nest: []}
    test "child level 1 graceful exit removes children", %{conn: conn} do
      {:ok, thermo_view, _html} = live(conn, "/thermo")

      assert clock_view = find_child(thermo_view, "clock")
      assert controls_view = find_child(clock_view, "NY-controls")

      stop(clock_view)
      assert_remove(clock_view, {:shutdown, :stop})
      assert_remove(controls_view, {:shutdown, :stop})

      refute find_child(thermo_view, "clock")
    end

    @tag session: %{nest: []}
    test "child level 2 graceful exit removes children", %{conn: conn} do
      {:ok, thermo_view, _html} = live(conn, "/thermo")

      assert clock_view = find_child(thermo_view, "clock")
      assert controls_view = find_child(clock_view, "NY-controls")

      stop(controls_view)
      assert_remove(controls_view, {:shutdown, :stop})
      assert find_child(thermo_view, "clock")
      refute find_child(clock_view, "NY-controls")
    end

    @tag :capture_log
    @tag session: %{nest: []}
    test "abnormal parent exit removes children", %{conn: conn} do
      {:ok, thermo_view, _html} = live(conn, "/thermo")

      assert clock_view = find_child(thermo_view, "clock")
      assert controls_view = find_child(clock_view, "NY-controls")

      send(thermo_view.pid, :boom)

      assert_remove(thermo_view, _)
      assert_remove(clock_view, _)
      assert_remove(controls_view, _)
    end

    @tag :capture_log
    @tag session: %{nest: []}
    test "abnormal child level 1 exit removes children", %{conn: conn} do
      {:ok, thermo_view, _html} = live(conn, "/thermo")

      assert clock_view = find_child(thermo_view, "clock")
      assert controls_view = find_child(clock_view, "NY-controls")

      send(clock_view.pid, :boom)

      assert_remove(clock_view, _)
      assert_remove(controls_view, _)
      refute find_child(thermo_view, "clock")
    end

    @tag :capture_log
    @tag session: %{nest: []}
    test "abnormal child level 2 exit removes children", %{conn: conn} do
      {:ok, thermo_view, _html} = live(conn, "/thermo")

      assert clock_view = find_child(thermo_view, "clock")
      assert controls_view = find_child(clock_view, "NY-controls")

      send(controls_view.pid, :boom)

      assert_remove(controls_view, _)
      assert find_child(thermo_view, "clock")
      refute find_child(clock_view, "NY-controls")
    end

    test "nested for comprehensions", %{conn: conn} do
      users = [
        %{name: "chris", email: "chris@test"},
        %{name: "josé", email: "jose@test"}
      ]

      expected_users = "<i>chris chris@test</i><i>josé jose@test</i>"

      {:ok, thermo_view, html} =
        conn
        |> put_session(:nest, [])
        |> put_session(:users, users)
        |> live("/thermo")

      assert html =~ expected_users
      assert render(thermo_view) =~ expected_users
    end

    test "raises on duplicate child LiveView id", %{conn: conn} do
      Process.flag(:trap_exit, true)

      {:ok, view, _html} =
        conn
        |> Plug.Conn.put_session(:user_id, 13)
        |> live("/root")

      assert ExUnit.CaptureLog.capture_log(fn ->
               :ok = GenServer.call(view.pid, {:dynamic_child, :static})
               catch_exit(render(view))
             end) =~ "duplicate LiveView id: \"static\""
    end

    @tag session: %{nest: []}
    test "push_redirect", %{conn: conn} do
      {:ok, thermo_view, html} = live(conn, "/thermo")
      assert html =~ "Redirect: none"

      assert clock_view = find_child(thermo_view, "clock")

      send(
        clock_view.pid,
        {:run,
         fn socket ->
           {:noreply, LiveView.push_redirect(socket, to: "/thermo?redirect=push")}
         end}
      )

      assert_redirect(thermo_view, "/thermo?redirect=push")
    end

    @tag session: %{nest: []}
    test "push_patch", %{conn: conn} do
      {:ok, thermo_view, html} = live(conn, "/thermo")
      assert html =~ "Redirect: none"
      assert clock_view = find_child(thermo_view, "clock")

      send(
        clock_view.pid,
        {:run,
         fn socket ->
           {:noreply, LiveView.push_patch(socket, to: "/thermo?redirect=patch")}
         end}
      )

      assert_redirect(thermo_view, "/thermo?redirect=patch")
      assert render(thermo_view) =~ "Redirect: patch"
    end

    @tag session: %{nest: []}
    test "redirect", %{conn: conn} do
      {:ok, thermo_view, html} = live(conn, "/thermo")
      assert html =~ "Redirect: none"

      assert clock_view = find_child(thermo_view, "clock")

      send(
        clock_view.pid,
        {:run,
         fn socket ->
           {:noreply, LiveView.redirect(socket, to: "/thermo?redirect=redirect")}
         end}
      )

      assert_redirect(thermo_view, "/thermo?redirect=redirect")
    end
  end

  describe "temporary assigns" do
    test "can be configured with mount options", %{conn: conn} do
      {:ok, conf_live, html} =
        conn
        |> put_session(:opts, temporary_assigns: [description: nil])
        |> live("/opts")

      assert html =~ "long description. canary"
      assert render(conf_live) =~ "long description. canary"
      socket = GenServer.call(conf_live.pid, {:exec, fn socket -> {:reply, socket, socket} end})

      assert socket.assigns.description == nil
      assert socket.assigns.canary == "canary"
    end

    test "raises with invalid options", %{conn: conn} do
      assert_raise Plug.Conn.WrapperError,
                   ~r/invalid option returned from Phoenix.LiveViewTest.OptsLive.mount\/3/,
                   fn ->
                     conn
                     |> put_session(:opts, oops: [:description])
                     |> live("/opts")
                   end
    end
  end

  describe "layout" do
    test "uses dead layout from router", %{conn: conn} do
      assert_raise Plug.Conn.WrapperError,
                   ~r"\(UndefinedFunctionError\) function UnknownView.render/2",
                   fn -> live(conn, "/bad_layout") end

      {:ok, _, _} = live(conn, "/layout")
    end

    test "is picked from config on use", %{conn: conn} do
      {:ok, view, html} = live(conn, "/layout")
      assert html =~ ~r|^LAYOUT<div[^>]+>LIVELAYOUTSTART\-123\-The value is: 123\-LIVELAYOUTEND|

      assert render_click(view, :double, "") ==
               "LIVELAYOUTSTART-246-The value is: 246-LIVELAYOUTEND\n"
    end

    @tag session: %{live_layout: {LayoutView, "live-override.html"}}
    test "is picked from config on mount when given a layout", %{conn: conn} do
      {:ok, view, html} = live(conn, "/layout")

      assert html =~
               ~r|^LAYOUT<div[^>]+>LIVEOVERRIDESTART\-123\-The value is: 123\-LIVEOVERRIDEEND|

      assert render_click(view, :double, "") ==
               "LIVEOVERRIDESTART-246-The value is: 246-LIVEOVERRIDEEND\n"
    end

    @tag session: %{live_layout: false}
    test "is picked from config on mount when given false", %{conn: conn} do
      {:ok, view, html} = live(conn, "/layout")
      assert html =~ "The value is: 123</div>"
      assert render_click(view, :double, "") == "The value is: 246"
    end

    test "is not picked from config on use for child live views", %{conn: conn} do
      assert get(conn, "/parent_layout") |> html_response(200) =~
               "The value is: 123</div>"

      {:ok, _view, html} = live(conn, "/parent_layout")
      assert html =~ "The value is: 123</div>"
    end

    @tag session: %{live_layout: {LayoutView, "live-override.html"}}
    test "is picked from config on mount even on child live views", %{conn: conn} do
      assert get(conn, "/parent_layout") |> html_response(200) =~
               ~r|<div[^>]+>LIVEOVERRIDESTART\-123\-The value is: 123\-LIVEOVERRIDEEND|

      {:ok, _view, html} = live(conn, "/parent_layout")

      assert html =~
               ~r|<div[^>]+>LIVEOVERRIDESTART\-123\-The value is: 123\-LIVEOVERRIDEEND|
    end
  end

  describe "title" do
    test "sends page title updates", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/thermo")
      GenServer.call(view.pid, {:set, :page_title, "New Title"})
      assert_receive {_ref, {:title, "New Title"}}
    end
  end

  describe "transport_pid/1" do
    test "raises when not connected" do
      assert_raise ArgumentError, ~r/may only be called when the socket is connected/, fn ->
        LiveView.transport_pid(%LiveView.Socket{})
      end
    end

    test "return the transport pid when connected", %{conn: conn} do
      {:ok, clock_view, _html} = live(conn, "/clock")
      parent = self()
      ref = make_ref()

      send(
        clock_view.pid,
        {:run,
         fn socket ->
           send(parent, {ref, LiveView.transport_pid(socket)})
         end}
      )

      assert_receive {^ref, transport_pid}
      assert transport_pid == self()
    end
  end
end
