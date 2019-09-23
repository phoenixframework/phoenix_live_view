defmodule Phoenix.LiveView.ComponentTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.{Endpoint, DOM}

  @endpoint Endpoint
  @moduletag :capture_log

  @moduletag session: %{names: ["chris", "jose"]}
  @moduletag :skip

  setup config do
    {:ok,
     conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), config[:session] || %{})}
  end

  test "renders successfully", %{conn: conn} do
    conn = get(conn, "/components")
    assert html_response(conn, 200) =~ "<div id=\"chris\">"

    {:ok, view, _html} = live(conn, "/components")
    assert render(view) == "<div"
  end

  test "send cids_destroyed event when components are removed", %{conn: conn} do
    {:ok, view, html} = live(conn, "/components")

    assert [
             {"div", [{"id", "chris"}, {"data-phx-component", "chris"}], ["\n    chris\n  "]},
             {"div", [{"id", "jose"}, {"data-phx-component", "jose"}], ["\n    jose\n  "]}
           ] = DOM.all(html, "#chris, #jose")

    html = render_click(view, "delete-name", %{"name" => "chris"})

    assert [
             {"div", [{"id", "jose"}, {"data-phx-component", "jose"}], ["\n    jose\n  "]}
           ] = DOM.all(html, "#chris, #jose")

    assert_remove_component(view, "chris")
  end
end
