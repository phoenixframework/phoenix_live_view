defmodule Phoenix.LiveView.LiveComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest

  import Phoenix.LiveViewTest

  alias Phoenix.LiveViewTest.{DOM, TreeDOM}
  alias Phoenix.LiveViewTest.Support.{Endpoint, StatefulComponent}

  @endpoint Endpoint
  @moduletag session: %{names: ["chris", "jose"], from: nil}

  setup config do
    {:ok,
     conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), config[:session] || %{})}
  end

  test "@myself" do
    cid = %Phoenix.LiveComponent.CID{cid: 123}
    assert String.Chars.to_string(cid) == "123"
    assert Phoenix.HTML.Safe.to_iodata(cid) == "123"
  end

  test "renders successfully when disconnected", %{conn: conn} do
    conn = get(conn, "/components")

    assert html_response(conn, 200) =~
             "<div phx-click=\"transform\" id=\"chris\" phx-target=\"#chris\">"
  end

  test "renders successfully when connected", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/components")

    assert [
             {"div", _,
              [
                _,
                {"div",
                 [{"data-phx-component", "1"}, {"id", "chris"}, {"phx-click", "transform"} | _],
                 ["\n  chris says hi\n  \n"]},
                {"div",
                 [{"data-phx-component", "2"}, {"id", "jose"}, {"phx-click", "transform"} | _],
                 ["\n  jose says hi\n  \n"]}
              ]}
           ] = TreeDOM.normalize_to_tree(render(view), sort_attributes: true)
  end

  test "tracks additions and updates", %{conn: conn} do
    {:ok, view, _} = live(conn, "/components")
    html = render_click(view, "dup-and-disable", %{})

    assert [
             "Redirect: none\n\n  ",
             {"div", [{"data-phx-component", "1"}], ["\n  DISABLED\n"]},
             {"div", [{"data-phx-component", "2"}], ["\n  DISABLED\n"]},
             {"div",
              [
                {"data-phx-component", "3"},
                {"id", "chris-new"},
                {"phx-click", "transform"},
                {"phx-target", "#chris-new"}
              ], ["\n  chris-new says hi\n  \n"]},
             {"div",
              [
                {"data-phx-component", "4"},
                {"id", "jose-new"},
                {"phx-click", "transform"},
                {"phx-target", "#jose-new"}
              ], ["\n  jose-new says hi\n  \n"]}
           ] = TreeDOM.normalize_to_tree(html, sort_attributes: true)
  end

  test "tracks removals", %{conn: conn} do
    ref =
      :telemetry_test.attach_event_handlers(self(), [[:phoenix, :live_component, :destroyed]])

    {:ok, view, html} = live(conn, "/components")

    assert [
             {"div",
              [{"data-phx-component", "1"}, {"id", "chris"}, {"phx-click", "transform"} | _],
              ["\n  chris says" <> _]},
             {"div",
              [{"data-phx-component", "2"}, {"id", "jose"}, {"phx-click", "transform"} | _],
              ["\n  jose says" <> _]}
           ] =
             html
             |> DOM.parse_fragment()
             |> elem(0)
             |> DOM.all("#chris, #jose")
             |> TreeDOM.normalize_to_tree(sort_attributes: true)

    html = render_click(view, "delete-name", %{"name" => "chris"})

    assert [
             {"div",
              [{"data-phx-component", "2"}, {"id", "jose"}, {"phx-click", "transform"} | _],
              ["\n  jose says" <> _]}
           ] =
             html
             |> DOM.parse_fragment()
             |> elem(0)
             |> DOM.all("#chris, #jose")
             |> TreeDOM.normalize_to_tree(sort_attributes: true)

    refute view |> element("#chris") |> has_element?()

    assert_received {[:phoenix, :live_component, :destroyed], ^ref, _,
                     %{
                       component: StatefulComponent,
                       cid: 1,
                       socket: %{assigns: %{name: "chris"}},
                       live_view_socket: %{assigns: %{names: ["jose"]}}
                     }}
  end

  test "tracks removals when whole root changes", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/components")
    assert render_click(view, "disable-all", %{}) =~ "Disabled\n"
    # Sync to make sure it is still alive
    assert render(view) =~ "Disabled\n"
  end

  test "tracks removals from a nested LiveView", %{conn: conn} do
    {:ok, view, _} = live(conn, "/component_in_live")
    assert render(view) =~ "Hello World"
    view |> find_live_child("nested_live") |> render_click("disable", %{})
    refute render(view) =~ "Hello World"
  end

  test "tracks removals of a nested LiveView alongside with a LiveComponent in the root view", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, "/component_and_nested_in_live")
    html = render(view)
    assert html =~ "hello"
    assert html =~ "world"
    render_click(view, "disable", %{})

    html = render(view)
    refute html =~ "hello"
    refute html =~ "world"
  end

  test "tracks removals when there is a race between server and client", %{conn: conn} do
    {:ok, view, _} = live(conn, "/cids_destroyed")

    # The button is on the page
    assert render(view) =~ "Hello World</button>"

    # Make sure we can bump the component
    assert view |> element("#bumper") |> render_click() =~ "Bump: 1"

    # Now click the form
    assert view |> element("form") |> render_submit() =~ "loading..."

    # Which will be reset almost immediately
    assert render(view) =~ "Hello World</button>"

    # But the client did not have time to remove it so the bumper still keeps going
    assert view |> element("#bumper") |> render_click() =~ "Bump: 2"
  end

  describe "handle_event" do
    test "delegates event to component", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/components")

      html = view |> element("#chris") |> render_click(%{"op" => "upcase"})

      assert [
               _,
               {"div",
                [{"data-phx-component", "1"}, {"id", "chris"}, {"phx-click", "transform"} | _],
                ["\n  CHRIS says hi\n" <> _]},
               {"div",
                [{"data-phx-component", "2"}, {"id", "jose"}, {"phx-click", "transform"} | _],
                ["\n  jose says hi\n" <> _]}
             ] = TreeDOM.normalize_to_tree(html, sort_attributes: true)

      html = view |> with_target("#jose") |> render_click("transform", %{"op" => "title-case"})

      assert [
               _,
               {"div",
                [{"data-phx-component", "1"}, {"id", "chris"}, {"phx-click", "transform"} | _],
                ["\n  CHRIS says hi\n" <> _]},
               {"div",
                [{"data-phx-component", "2"}, {"id", "jose"}, {"phx-click", "transform"} | _],
                ["\n  Jose says hi\n" <> _]}
             ] = TreeDOM.normalize_to_tree(html, sort_attributes: true)

      html = view |> element("#jose") |> render_click(%{"op" => "dup"})

      assert [
               _,
               {"div",
                [{"data-phx-component", "1"}, {"id", "chris"}, {"phx-click", "transform"} | _],
                ["\n  CHRIS says hi\n" <> _]},
               {"div",
                [{"data-phx-component", "2"}, {"id", "jose"}, {"phx-click", "transform"} | _],
                [
                  "\n  Jose says hi\n  ",
                  {"div",
                   [
                     {"data-phx-component", "3"},
                     {"id", "Jose-dup"},
                     {"phx-click", "transform"} | _
                   ], ["\n  Jose-dup says hi\n" <> _]}
                ]}
             ] = TreeDOM.normalize_to_tree(html, sort_attributes: true)

      html = view |> element("#jose #Jose-dup") |> render_click(%{"op" => "upcase"})

      assert [
               _,
               {"div",
                [{"data-phx-component", "1"}, {"id", "chris"}, {"phx-click", "transform"} | _],
                ["\n  CHRIS says hi\n" <> _]},
               {"div",
                [{"data-phx-component", "2"}, {"id", "jose"}, {"phx-click", "transform"} | _],
                [
                  "\n  Jose says hi\n  ",
                  {"div",
                   [
                     {"data-phx-component", "3"},
                     {"id", "Jose-dup"},
                     {"phx-click", "transform"} | _
                   ], ["\n  JOSE-DUP says hi\n" <> _]}
                ]}
             ] = TreeDOM.normalize_to_tree(html, sort_attributes: true)

      assert view |> element("#jose #Jose-dup") |> render() ==
               "<div data-phx-component=\"3\" phx-click=\"transform\" id=\"Jose-dup\" phx-target=\"#Jose-dup\">\n  JOSE-DUP says hi\n  \n</div>"
    end

    test "works with_target to component", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/components")

      html = view |> with_target("#chris") |> render_click("transform", %{"op" => "upcase"})

      assert [
               _,
               {"div",
                [{"data-phx-component", "1"}, {"id", "chris"}, {"phx-click", "transform"} | _],
                ["\n  CHRIS says hi\n" <> _]},
               {"div",
                [{"data-phx-component", "2"}, {"id", "jose"}, {"phx-click", "transform"} | _],
                ["\n  jose says hi\n" <> _]}
             ] = TreeDOM.normalize_to_tree(html, sort_attributes: true)
    end

    test "works with multiple phx-targets", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/multi-targets")

      view |> element("#chris") |> render_click(%{"op" => "upcase"})

      html = render(view)

      assert [
               {"div", _,
                [
                  {"div", [{"class", "parent"}, {"id", "parent_id"}],
                   [
                     "\n  Parent was updated\n" <> _,
                     {"div",
                      [
                        {"data-phx-component", "1"},
                        {"id", "chris"},
                        {"phx-click", "transform"} | _
                      ], ["\n  CHRIS says hi\n" <> _]},
                     {"div",
                      [
                        {"data-phx-component", "2"},
                        {"id", "jose"},
                        {"phx-click", "transform"} | _
                      ], ["\n  jose says hi\n" <> _]}
                   ]}
                ]}
             ] = TreeDOM.normalize_to_tree(html, sort_attributes: true)
    end

    test "phx-target works with non id selector", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> Plug.Conn.put_session(:parent_selector, ".parent")
        |> live("/multi-targets")

      view |> element("#chris") |> render_click(%{"op" => "upcase"})

      html = render(view)

      assert [
               {"div", _,
                [
                  {"div", [{"class", "parent"}, {"id", "parent_id"}],
                   [
                     "\n  Parent was updated\n" <> _,
                     {"div",
                      [
                        {"data-phx-component", "1"},
                        {"id", "chris"},
                        {"phx-click", "transform"} | _
                      ], ["\n  CHRIS says hi\n" <> _]},
                     {"div",
                      [
                        {"data-phx-component", "2"},
                        {"id", "jose"},
                        {"phx-click", "transform"} | _
                      ], ["\n  jose says hi\n" <> _]}
                   ]}
                ]}
             ] = TreeDOM.normalize_to_tree(html, sort_attributes: true)
    end
  end

  describe "send_update" do
    test "updates child from parent", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/components")

      send(
        view.pid,
        {:send_update,
         [
           {StatefulComponent, id: "chris", name: "NEW-chris", from: self()},
           {StatefulComponent, id: "jose", name: "NEW-jose", from: self()}
         ]}
      )

      assert_receive {:updated, %{id: "chris", name: "NEW-chris"}}
      assert_receive {:updated, %{id: "jose", name: "NEW-jose"}}
      refute_receive {:updated, _}

      assert [
               {"div",
                [{"data-phx-component", "1"}, {"id", "chris"}, {"phx-click", "transform"} | _],
                ["\n  NEW-chris says hi\n  \n"]}
             ] =
               view
               |> element("#chris")
               |> render()
               |> TreeDOM.normalize_to_tree(sort_attributes: true)

      assert [
               {"div",
                [{"data-phx-component", "2"}, {"id", "jose"}, {"phx-click", "transform"} | _],
                ["\n  NEW-jose says hi\n  \n"]}
             ] =
               view
               |> element("#jose")
               |> render()
               |> TreeDOM.normalize_to_tree(sort_attributes: true)
    end

    test "updates child from independent pid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/components")

      Phoenix.LiveView.send_update(view.pid, StatefulComponent,
        id: "chris",
        name: "NEW-chris",
        from: self()
      )

      Phoenix.LiveView.send_update_after(
        view.pid,
        StatefulComponent,
        [id: "jose", name: "NEW-jose", from: self()],
        10
      )

      assert_receive {:updated, %{id: "chris", name: "NEW-chris"}}
      assert_receive {:updated, %{id: "jose", name: "NEW-jose"}}
      refute_receive {:updated, _}
    end

    test "updates with cid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/components")

      Phoenix.LiveView.send_update_after(
        view.pid,
        StatefulComponent,
        [id: "jose", name: "NEW-jose", from: self(), all_assigns: true],
        10
      )

      assert_receive {:updated, %{id: "jose", name: "NEW-jose", myself: myself}}

      Phoenix.LiveView.send_update(view.pid, myself, name: "NEXTGEN-jose", from: self())
      assert_receive {:updated, %{id: "jose", name: "NEXTGEN-jose"}}

      Phoenix.LiveView.send_update_after(
        view.pid,
        myself,
        [name: "after-NEXTGEN-jose", from: self()],
        10
      )

      assert_receive {:updated, %{id: "jose", name: "after-NEXTGEN-jose"}}, 500
    end

    test "updates without :id raise", %{conn: conn} do
      Process.flag(:trap_exit, true)
      {:ok, view, _html} = live(conn, "/components")

      assert ExUnit.CaptureLog.capture_log(fn ->
               send(view.pid, {:send_update, [{StatefulComponent, name: "NEW-chris"}]})
               ref = Process.monitor(view.pid)
               assert_receive {:DOWN, ^ref, _, _, _}, 500
             end) =~ "** (ArgumentError) missing required :id in send_update"
    end

    test "warns if component doesn't exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/components")

      # with module and id
      assert ExUnit.CaptureLog.capture_log(fn ->
               send(view.pid, {:send_update, [{StatefulComponent, id: "nemo", name: "NEW-nemo"}]})
               render(view)
               refute_receive {:updated, _}
             end) =~
               "send_update failed because component Phoenix.LiveViewTest.Support.StatefulComponent with ID \"nemo\" does not exist or it has been removed"

      # with @myself
      assert ExUnit.CaptureLog.capture_log(fn ->
               send(
                 view.pid,
                 {:send_update, [{%Phoenix.LiveComponent.CID{cid: 999}, name: "NEW-nemo"}]}
               )

               render(view)
               refute_receive {:updated, _}
             end) =~
               "send_update failed because component with CID 999 does not exist or it has been removed"
    end

    test "raises if component module is not available", %{conn: conn} do
      Process.flag(:trap_exit, true)
      {:ok, view, _html} = live(conn, "/components")

      assert ExUnit.CaptureLog.capture_log(fn ->
               send(
                 view.pid,
                 {:send_update, [{NonexistentComponent, id: "chris", name: "NEW-chris"}]}
               )

               ref = Process.monitor(view.pid)
               assert_receive {:DOWN, ^ref, _, _, _}, 500
             end) =~
               "** (ArgumentError) send_update failed (module NonexistentComponent is not available)"
    end
  end

  describe "redirects" do
    test "push_navigate", %{conn: conn} do
      {:ok, view, html} = live(conn, "/components")
      assert html =~ "Redirect: none"

      assert {:error, {:live_redirect, %{to: "/components?redirect=push"}}} =
               view |> element("#chris") |> render_click(%{"op" => "push_navigate"})

      assert_redirect(view, "/components?redirect=push")
    end

    test "push_patch", %{conn: conn} do
      {:ok, view, html} = live(conn, "/components")
      assert html =~ "Redirect: none"

      assert view |> element("#chris") |> render_click(%{"op" => "push_patch"}) =~
               "Redirect: patch"

      assert_patch(view, "/components?redirect=patch")
    end

    test "redirect", %{conn: conn} do
      {:ok, view, html} = live(conn, "/components")
      assert html =~ "Redirect: none"

      assert view |> element("#chris") |> render_click(%{"op" => "redirect"}) ==
               {:error, {:redirect, %{to: "/components?redirect=redirect", status: 302}}}

      assert_redirect(view, "/components?redirect=redirect")
    end
  end

  defmodule MyComponent do
    use Phoenix.LiveComponent

    # Assert endpoint was set
    def mount(%{endpoint: Endpoint, router: SomeRouter} = socket) do
      send(self(), {:mount, socket})
      {:ok, assign(socket, hello: "world")}
    end

    def update(assigns, socket) do
      send(self(), {:update, assigns, socket})
      {:ok, assign(socket, assigns)}
    end

    def render(assigns) do
      send(self(), :render)

      ~H"""
      <div>
        FROM {@from} {@hello}
      </div>
      """
    end
  end

  defmodule RenderOnlyComponent do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <div>
        RENDER ONLY {@from}
      </div>
      """
    end
  end

  defmodule NestedRenderOnlyComponent do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <.live_component module={RenderOnlyComponent} from={@from} id="render-only-component" />
      """
    end
  end

  defmodule BadRootComponent do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <foo>{@id}</foo>
      <bar>{@id}</bar>
      """
    end
  end

  describe "render_component/2" do
    test "life-cycle" do
      assert render_component(MyComponent, %{from: "test", id: "stateful"}, router: SomeRouter) =~
               "FROM test world"

      assert_received {:mount,
                       %{assigns: %{flash: %{}, myself: %Phoenix.LiveComponent.CID{cid: -1}}}}

      assert_received {:update, %{from: "test", id: "stateful"},
                       %{assigns: %{flash: %{}, myself: %Phoenix.LiveComponent.CID{cid: -1}}}}
    end

    test "render only" do
      assert render_component(RenderOnlyComponent, %{from: "test"}) =~ "RENDER ONLY test"
    end

    test "nested render only" do
      assert render_component(NestedRenderOnlyComponent, %{from: "test"}) =~ "RENDER ONLY test"
    end

    test "raises on bad root" do
      assert_raise ArgumentError, ~r/have a single static HTML tag at the root/, fn ->
        render_component(BadRootComponent, %{id: "id"})
      end
    end

    test "loads unloaded component" do
      module = Phoenix.LiveViewTest.Support.ComponentInLive.Component
      :code.purge(module)
      :code.delete(module)
      assert render_component(module, %{}) =~ "<div>Hello World</div>"
    end
  end
end
