defmodule Phoenix.LiveView.ComponentTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.{Endpoint, DOM}

  @endpoint Endpoint
  @moduletag :capture_log

  @moduletag session: %{names: ["chris", "jose"]}

  setup config do
    {:ok,
     conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), config[:session] || %{})}
  end

  test "renders successfully", %{conn: conn} do
    conn = get(conn, "/components")
    assert html_response(conn, 200) =~ "<div id=\"chris\">"

    {:ok, view, _html} = live(conn, "/components")

    assert {"div", _,
            [
              {"div", [], ["\n  unknown says hi with socket: true\n"]},
              {"div", [{"id", "chris"}, {"data-phx-component", "0"}],
               ["\n  chris says hi with socket: true\n"]},
              {"div", [{"id", "jose"}, {"data-phx-component", "1"}],
               ["\n  jose says hi with socket: true\n"]}
            ]} = DOM.parse(render(view))
  end

  test "tracks removals", %{conn: conn} do
    {:ok, view, html} = live(conn, "/components")

    assert [
             {"div", [{"id", "chris"}, {"data-phx-component", "0"}], ["\n  chris says" <> _]},
             {"div", [{"id", "jose"}, {"data-phx-component", "1"}], ["\n  jose says" <> _]}
           ] = DOM.all(html, "#chris, #jose")

    html = render_click(view, "delete-name", %{"name" => "chris"})

    assert [
             {"div", [{"id", "jose"}, {"data-phx-component", "1"}], ["\n  jose says" <> _]}
           ] = DOM.all(html, "#chris, #jose")

    assert_remove_component(view, "chris")
  end

  test "handle_event delegates event to component", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/components")

    html = render_click([view, "chris"], "transform", %{"op" => "upcase"})

    assert [
             {"div", [], ["\n  unknown says hi with socket: true\n"]},
             {"div", [{"id", "chris"}, {"data-phx-component", "0"}],
              ["\n  CHRIS says hi with socket: true\n"]},
             {"div", [{"id", "jose"}, {"data-phx-component", "1"}],
              ["\n  jose says hi with socket: true\n"]}
           ] = DOM.parse(html)

    html = render_click([view, "jose"], "transform", %{"op" => "title-case"})

    assert [
             {"div", [], ["\n  unknown says hi with socket: true\n"]},
             {"div", [{"id", "chris"}, {"data-phx-component", "0"}],
              ["\n  CHRIS says hi with socket: true\n"]},
             {"div", [{"id", "jose"}, {"data-phx-component", "1"}],
              ["\n  Jose says hi with socket: true\n"]}
           ] = DOM.parse(html)

    html = render_click([view, "jose"], "transform", %{"op" => "dup"})

    assert [
             {"div", [], ["\n  unknown says hi with socket: true\n"]},
             {"div", [{"id", "chris"}, {"data-phx-component", "0"}],
              ["\n  CHRIS says hi with socket: true\n"]},
             {"div", [{"id", "jose"}, {"data-phx-component", "1"}],
              [
                "\n  Jose says hi with socket: true",
                {"div", [{"id", "Jose-dup"}, {"data-phx-component", "2"}],
                 ["\n  Jose-dup says hi with socket: true\n"]}
              ]}
           ] = DOM.parse(html)

    html = render_click([view, "jose", "Jose-dup"], "transform", %{"op" => "upcase"})

    assert [
             {"div", [], ["\n  unknown says hi with socket: true\n"]},
             {"div", [{"id", "chris"}, {"data-phx-component", "0"}],
              ["\n  CHRIS says hi with socket: true\n"]},
             {"div", [{"id", "jose"}, {"data-phx-component", "1"}],
              [
                "\n  Jose says hi with socket: true",
                {"div", [{"id", "Jose-dup"}, {"data-phx-component", "2"}],
                 ["\n  JOSE-DUP says hi with socket: true\n"]}
              ]}
           ] = DOM.parse(html)

    assert render([view, "jose", "Jose-dup"]) ==
             "<div id=\"Jose-dup\" data-phx-component=\"2\">\n  JOSE-DUP says hi with socket: true\n</div>"
  end

  defmodule MyComponent do
    use Phoenix.LiveComponent

    def mount(socket) do
      send(self(), {:mount, socket})
      {:ok, assign(socket, hello: "world")}
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

  describe "render_component/2" do
    test "full life-cycle" do
      assert render_component(MyComponent, from: "test") =~ "FROM test world"
    end

    test "render only" do
      assert render_component(RenderOnlyComponent, %{from: "test"}) =~ "RENDER ONLY test"
    end
  end
end
