defmodule Phoenix.LiveView.ComponentTest do
  use ExUnit.Case, async: false
  use Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.{Endpoint, DOM, StatefulComponent}

  @endpoint Endpoint
  @moduletag session: %{names: ["chris", "jose"], from: nil}

  setup config do
    {:ok,
     conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), config[:session] || %{})}
  end

  test "renders successfully when disconnected", %{conn: conn} do
    conn = get(conn, "/components")

    assert html_response(conn, 200) =~
             "<div id=\"chris\" phx-target=\"#chris\" phx-click=\"transform\">"
  end

  test "renders successfully when connected", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/components")

    assert [
             {"div", _,
              [
                _,
                {"div", [{"data-phx-component", "0"}, {"id", "chris"} | _],
                 ["\n  chris says hi with socket: true\n  \n"]},
                {"div", [{"data-phx-component", "1"}, {"id", "jose"} | _],
                 ["\n  jose says hi with socket: true\n  \n"]}
              ]}
           ] = DOM.parse(render(view))
  end

  test "tracks removals", %{conn: conn} do
    {:ok, view, html} = live(conn, "/components")

    assert [
             {"div", [{"data-phx-component", "0"}, {"id", "chris"} | _], ["\n  chris says" <> _]},
             {"div", [{"data-phx-component", "1"}, {"id", "jose"} | _], ["\n  jose says" <> _]}
           ] = html |> DOM.parse() |> DOM.all("#chris, #jose")

    html = render_click(view, "delete-name", %{"name" => "chris"})

    assert [
             {"div", [{"data-phx-component", "1"}, {"id", "jose"} | _], ["\n  jose says" <> _]}
           ] = html |> DOM.parse() |> DOM.all("#chris, #jose")

    refute view |> element("#chris") |> has_element?()
  end

  test "preloads", %{conn: conn} do
    conn =
      conn
      |> Plug.Test.init_test_session(%{from: self()})
      |> get("/components")

    assert_receive {:preload, [%{id: "chris"}, %{id: "jose"}]}

    {:ok, _view, _html} = live(conn)
    assert_receive {:preload, [%{id: "chris"}, %{id: "jose"}]}
  end

  test "handle_event delegates event to component", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/components")

    html = view |> element("#chris") |> render_click(%{"op" => "upcase"})

    assert [
             _,
             {"div", [{"data-phx-component", "0"}, {"id", "chris"} | _],
              ["\n  CHRIS says hi with socket: true\n" <> _]},
             {"div", [{"data-phx-component", "1"}, {"id", "jose"} | _],
              ["\n  jose says hi with socket: true\n" <> _]}
           ] = DOM.parse(html)

    html = view |> element("#jose") |> render_click(%{"op" => "title-case"})

    assert [
             _,
             {"div", [{"data-phx-component", "0"}, {"id", "chris"} | _],
              ["\n  CHRIS says hi with socket: true\n" <> _]},
             {"div", [{"data-phx-component", "1"}, {"id", "jose"} | _],
              ["\n  Jose says hi with socket: true\n" <> _]}
           ] = DOM.parse(html)

    html = view |> element("#jose") |> render_click(%{"op" => "dup"})

    assert [
             _,
             {"div", [{"data-phx-component", "0"}, {"id", "chris"} | _],
              ["\n  CHRIS says hi with socket: true\n" <> _]},
             {"div", [{"data-phx-component", "1"}, {"id", "jose"} | _],
              [
                "\n  Jose says hi with socket: true\n  ",
                {"div", [{"data-phx-component", "2"}, {"id", "Jose-dup"} | _],
                 ["\n  Jose-dup says hi with socket: true\n" <> _]}
              ]}
           ] = DOM.parse(html)

    html = view |> element("#jose #Jose-dup") |> render_click(%{"op" => "upcase"})

    assert [
             _,
             {"div", [{"data-phx-component", "0"}, {"id", "chris"} | _],
              ["\n  CHRIS says hi with socket: true\n" <> _]},
             {"div", [{"data-phx-component", "1"}, {"id", "jose"} | _],
              [
                "\n  Jose says hi with socket: true\n  ",
                {"div", [{"data-phx-component", "2"}, {"id", "Jose-dup"} | _],
                 ["\n  JOSE-DUP says hi with socket: true\n" <> _]}
              ]}
           ] = DOM.parse(html)

    assert view |> element("#jose #Jose-dup") |> render() ==
             "<div data-phx-component=\"2\" id=\"Jose-dup\" phx-target=\"#Jose-dup\" phx-click=\"transform\">\n  JOSE-DUP says hi with socket: true\n  \n</div>"
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

      assert_receive {:preload, [%{id: "chris", name: "NEW-chris"}]}
      assert_receive {:preload, [%{id: "jose", name: "NEW-jose"}]}
      assert_receive {:updated, %{id: "chris", name: "NEW-chris"}}
      assert_receive {:updated, %{id: "jose", name: "NEW-jose"}}
      refute_receive {:updated, _}
      refute_receive {:preload, _}

      assert [
               {"div", [{"data-phx-component", "0"}, {"id", "chris"} | _],
                ["\n  NEW-chris says hi with socket: true\n  \n"]}
             ] = view |> element("#chris") |> render() |> DOM.parse()

      assert [
               {"div", [{"data-phx-component", "1"}, {"id", "jose"} | _],
                ["\n  NEW-jose says hi with socket: true\n  \n"]}
             ] = view |> element("#jose") |> render() |> DOM.parse()
    end

    test "updates without :id raise", %{conn: conn} do
      Process.flag(:trap_exit, true)
      {:ok, view, _html} = live(conn, "/components")

      assert ExUnit.CaptureLog.capture_log(fn ->
               send(view.pid, {:send_update, [{StatefulComponent, name: "NEW-chris"}]})
               ref = Process.monitor(view.pid)
               assert_receive {:DOWN, ^ref, _, _, _}
             end) =~ "** (ArgumentError) missing required :id in send_update"
    end
  end

  describe "redirects" do
    test "push_redirect", %{conn: conn} do
      {:ok, view, html} = live(conn, "/components")
      assert html =~ "Redirect: none"

      assert {:error, {:live_redirect, %{to: "/components?redirect=push"}}} =
               view |> element("#chris") |> render_click(%{"op" => "push_redirect"})

      assert_redirect(view, "/components?redirect=push")
    end

    test "push_patch", %{conn: conn} do
      {:ok, view, html} = live(conn, "/components")
      assert html =~ "Redirect: none"

      assert view |> element("#chris") |> render_click(%{"op" => "push_patch"}) =~
               "Redirect: none"

      assert_patch(view, "/components?redirect=patch")
    end

    test "redirect", %{conn: conn} do
      {:ok, view, html} = live(conn, "/components")
      assert html =~ "Redirect: none"

      assert view |> element("#chris") |> render_click(%{"op" => "redirect"}) ==
               {:error, {:redirect, %{to: "/components?redirect=redirect"}}}

      assert_redirect(view, "/components?redirect=redirect")
    end
  end

  defmodule MyComponent do
    use Phoenix.LiveComponent

    # Assert endpoint was set
    def mount(%{endpoint: Endpoint} = socket) do
      send(self(), {:mount, socket})
      {:ok, assign(socket, hello: "world")}
    end

    def preload(list_of_assigns) do
      send(self(), {:preload, list_of_assigns})
      list_of_assigns
    end

    def update(assigns, socket) do
      send(self(), {:update, assigns, socket})
      {:ok, assign(socket, assigns)}
    end

    def render(assigns) do
      send(self(), :render)

      ~L"""
      FROM <%= @from %> <%= @hello %>
      """
    end
  end

  defmodule RenderOnlyComponent do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~L"""
      RENDER ONLY <%= @from %>
      """
    end
  end

  defmodule NestedRenderOnlyComponent do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~L"""
      <%= live_component @socket, RenderOnlyComponent, from: @from %>
      """
    end
  end

  describe "render_component/2" do
    test "full life-cycle without id" do
      assert render_component(MyComponent, from: "test") =~ "FROM test world"
      assert_received {:mount, %{assigns: %{flash: %{}}}}
      assert_received {:preload, [%{from: "test"}]}
      assert_received {:update, %{from: "test"}, %{assigns: %{flash: %{}}}}
    end

    test "full life-cycle with id" do
      assert render_component(MyComponent, from: "test", id: "stateful") =~ "FROM test world"
      assert_received {:mount, %{assigns: %{flash: %{}, myself: -1}}}
      assert_received {:preload, [%{from: "test", id: "stateful"}]}

      assert_received {:update, %{from: "test", id: "stateful"},
                       %{assigns: %{flash: %{}, myself: -1}}}
    end

    test "render only" do
      assert render_component(RenderOnlyComponent, %{from: "test"}) =~ "RENDER ONLY test"
    end

    test "nested render only" do
      assert render_component(NestedRenderOnlyComponent, %{from: "test"}) =~ "RENDER ONLY test"
    end
  end
end
