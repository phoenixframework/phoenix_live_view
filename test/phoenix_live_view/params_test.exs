defmodule Phoenix.LiveView.ParamsTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  import Phoenix.LiveViewTest

  alias Phoenix.LiveViewTest.{Endpoint}

  @endpoint Endpoint
  @moduletag :capture_log

  setup do
    {:ok, conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})}
  end

  describe "handle_params on mount" do
    test "is called on disconnected mount with named and query string params", %{conn: conn} do
      conn = get(conn, "/thermo/123", query1: "query1", query2: "query2")

      assert html_response(conn, 200) =~
               ~s|%{"id" => "123", "query1" => "query1", "query2" => "query2"}|
    end

    test "is called on connected mount with named and query string params", %{conn: conn} do
      {:ok, _, html} =
        conn
        |> get("/thermo/123?q1=1", q2: "2")
        |> live()

      assert html =~ ~s|%{"id" => "123", "q1" => "1", "q2" => "2"}|
    end
  end

  describe "handle_params on live_link" do
    test "internal links invokes handle_params", %{conn: conn} do
      {:ok, thermo_live, _html} = live(conn, "/thermo/123")

      assert render_live_link(thermo_live, "/thermo/123?filter=true") =~
               ~s|%{"filter" => "true", "id" => "123"}|
    end

    test "external links" do
      flunk "todo"
    end
  end

  describe "internal live_redirect" do
    test "from event callback", %{conn: conn} do
      flunk "todo"
    end

    test "from mount", %{conn: conn} do
      flunk "should this be supported?"
    end

    test "from handle_params", %{conn: conn} do
      flunk "immediately processes another handle_params"
    end
  end

  describe "internal live_redirect" do
    test "from event callback", %{conn: conn} do
      flunk "shuts down"
    end

    test "from mount", %{conn: conn} do
      flunk "should this be supported?"
    end

    test "from handle_params", %{conn: conn} do
      flunk "shuts down"
    end
  end
end
