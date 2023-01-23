defmodule Phoenix.LiveView.NestedTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.LiveView
  alias Phoenix.LiveViewTest.{Endpoint, DOM, ClockLive, ClockControlsLive, LiveInComponent}

  @endpoint Endpoint

  setup config do
    {:ok, conn: Plug.Test.init_test_session(build_conn(), config[:session] || %{})}
  end

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

    assert clock_view = find_live_child(thermo_view, "clock")
    assert controls_view = find_live_child(clock_view, "NY-controls")
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
    Process.flag(:trap_exit, true)

    html_without_nesting =
      DOM.parse("""
      Redirect: none\nThe temp is: 1
      <button phx-click="dec">-</button>
      <button phx-click="inc">+</button>
      """)

    {:ok, thermo_view, _} = live(conn, "/thermo")

    assert find_live_child(thermo_view, "clock")
    refute DOM.child_nodes(hd(DOM.parse(render(thermo_view)))) == html_without_nesting

    GenServer.call(thermo_view.pid, {:set, :nest, false})
    assert DOM.child_nodes(hd(DOM.parse(render(thermo_view)))) == html_without_nesting
    refute find_live_child(thermo_view, "clock")
  end

  @tag session: %{dup: false}
  test "multiple nested children of same module", %{conn: conn} do
    {:ok, parent, _} = live(conn, "/same-child")
    assert tokyo = find_live_child(parent, "Tokyo")
    assert madrid = find_live_child(parent, "Madrid")
    assert toronto = find_live_child(parent, "Toronto")
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

  test "nested within comprehensions", %{conn: conn} do
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

  test "nested within live component" do
    assert {:ok, _view, _html} = live_isolated(build_conn(), LiveInComponent.Root)
  end

  test "raises on duplicate child LiveView id", %{conn: conn} do
    Process.flag(:trap_exit, true)

    {:ok, view, _html} =
      conn
      |> Plug.Conn.put_session(:user_id, 13)
      |> live("/root")

    :ok = GenServer.call(view.pid, {:dynamic_child, :static})

    assert Exception.format(:exit, catch_exit(render(view))) =~
             "expected selector \"#static\" to return a single element, but got 2"
  end

  describe "navigation helpers" do
    @tag session: %{nest: []}
    test "push_navigate", %{conn: conn} do
      {:ok, thermo_view, html} = live(conn, "/thermo")
      assert html =~ "Redirect: none"

      assert clock_view = find_live_child(thermo_view, "clock")

      send(
        clock_view.pid,
        {:run,
         fn socket ->
           {:noreply, LiveView.push_navigate(socket, to: "/thermo?redirect=push")}
         end}
      )

      assert_redirect(thermo_view, "/thermo?redirect=push")
    end

    @tag session: %{nest: []}
    test "refute_redirect", %{conn: conn} do
      {:ok, thermo_view, _html} = live(conn, "/thermo")

      clock_view = find_live_child(thermo_view, "clock")

      send(
        clock_view.pid,
        {:run,
         fn socket ->
           {:noreply, LiveView.push_navigate(socket, to: "/some_url")}
         end}
      )

      refute_redirected(thermo_view, "/not_going_here")

      send(
        clock_view.pid,
        {:run,
         fn socket ->
           {:noreply, LiveView.push_navigate(socket, to: "/another_url")}
         end}
      )

      try do
        refute_redirected(thermo_view, "/another_url")
      rescue
        e ->
          assert %ArgumentError{message: message} = e
          assert message =~ "not to redirect to"
      end
    end

    @tag session: %{nest: []}
    test "push_navigate with destination that can vary", %{conn: conn} do
      {:ok, thermo_view, html} = live(conn, "/thermo")
      assert html =~ "Redirect: none"

      assert clock_view = find_live_child(thermo_view, "clock")

      id = Enum.random(1000..9999)

      send(
        clock_view.pid,
        {:run,
         fn socket ->
           {:noreply, LiveView.push_navigate(socket, to: "/thermo?redirect=#{id}")}
         end}
      )

      {path, _flash} = assert_redirect(thermo_view)
      assert path =~ ~r/\/thermo\?redirect=[0-9]+/
    end

    @tag session: %{nest: []}
    test "push_patch", %{conn: conn} do
      {:ok, thermo_view, html} = live(conn, "/thermo")
      assert html =~ "Redirect: none"
      assert clock_view = find_live_child(thermo_view, "clock")

      send(
        clock_view.pid,
        {:run,
         fn socket ->
           {:noreply, LiveView.push_patch(socket, to: "/thermo?redirect=patch")}
         end}
      )

      assert_patch(thermo_view, "/thermo?redirect=patch")
      assert render(thermo_view) =~ "Redirect: patch"
    end

    @tag session: %{nest: []}
    test "push_patch to destination which can vary", %{conn: conn} do
      {:ok, thermo_view, html} = live(conn, "/thermo")
      assert html =~ "Redirect: none"
      assert clock_view = find_live_child(thermo_view, "clock")

      id = Enum.random(1000..9999)

      send(
        clock_view.pid,
        {:run,
         fn socket ->
           {:noreply, LiveView.push_patch(socket, to: "/thermo?redirect=#{id}")}
         end}
      )

      path = assert_patch(thermo_view)
      assert path =~ ~r/\/thermo\?redirect=[0-9]+/
      assert render(thermo_view) =~ "Redirect: #{id}"
    end

    @tag session: %{nest: []}
    test "redirect from child", %{conn: conn} do
      {:ok, thermo_view, html} = live(conn, "/thermo")
      assert html =~ "Redirect: none"

      assert clock_view = find_live_child(thermo_view, "clock")

      send(
        clock_view.pid,
        {:run,
         fn socket ->
           {:noreply, LiveView.redirect(socket, to: "/thermo?redirect=redirect")}
         end}
      )

      assert_redirect(thermo_view, "/thermo?redirect=redirect")
    end

    @tag session: %{nest: []}
    test "external redirect from child", %{conn: conn} do
      {:ok, thermo_view, html} = live(conn, "/thermo")
      assert html =~ "Redirect: none"

      assert clock_view = find_live_child(thermo_view, "clock")

      send(
        clock_view.pid,
        {:run,
         fn socket ->
           {:noreply, LiveView.redirect(socket, external: "https://phoenixframework.org")}
         end}
      )

      assert_redirect(thermo_view, "https://phoenixframework.org")
    end
  end

  describe "sticky" do
    @tag session: %{name: "ny"}
    test "process does not go down with parent", %{conn: conn} do
      {:ok, clock_view, _html} = live(conn, "/clock?sticky=true")
      %Phoenix.LiveViewTest.View{} = sticky_child = find_live_child(clock_view, "ny-controls")
      child_pid = sticky_child.pid
      assert Process.alive?(child_pid)
      Process.monitor(child_pid)

      send(
        clock_view.pid,
        {:run,
         fn socket ->
           {:noreply, LiveView.push_navigate(socket, to: "/clock?sticky=true&redirected=true")}
         end}
      )

      assert_redirect(clock_view, "/clock?sticky=true&redirected=true")
      refute_receive {:DOWN, _ref, :process, ^child_pid, {:shutdown, :parent_exited}}
      # client proxy transport
      assert_receive {:DOWN, _ref, :process, ^child_pid, {:shutdown, :closed}}
    end
  end
end
