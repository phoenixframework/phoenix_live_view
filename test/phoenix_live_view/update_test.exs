defmodule Phoenix.LiveView.UpdateTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.{Endpoint, DOM}

  @endpoint Endpoint
  @moduletag :capture_log

  setup config do
    {:ok,
     conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), config[:session] || %{})}
  end

  describe "phx-update=append" do
    @tag session: %{time_zones: {:append, [%{id: "ny", name: "NY"}]}}
    test "static mount followed by connected mount", %{conn: conn} do
      conn = get(conn, "/time-zones")
      html = html_response(conn, 200)
      assert [{"section", _, ["time: 12:00 NY\n" | _]}] = find_time_zones(html, ["ny", "tokyo"])

      {:ok, view, _html} = live(conn)
      html = render(view)
      assert [{"section", _, ["time: 12:00 NY\n" | _]}] = find_time_zones(html, ["ny", "tokyo"])

      html = render_click(view, "add-tz", %{id: "tokyo", name: "Tokyo"})

      assert [
               {"section", _, ["time: 12:00 NY\n" | _]},
               {"section", _, ["time: 12:00 Tokyo\n" | _]}
             ] = find_time_zones(html, ["ny", "tokyo"])

      _html = render_click(view, "add-tz", %{id: "la", name: "LA"})
      html = render_click(view, "add-tz", %{id: "sf", name: "SF"})

      assert [
               {"section", _, ["time: 12:00 NY\n" | _]},
               {"section", _, ["time: 12:00 Tokyo\n" | _]},
               {"section", _, ["time: 12:00 LA\n" | _]},
               {"section", _, ["time: 12:00 SF\n" | _]}
             ] = find_time_zones(html, ["ny", "tokyo", "la", "sf"])
    end

    @tag session: %{time_zones: {:append, [%{id: "ny", name: "NY"}, %{id: "sf", name: "SF"}]}}
    test "updates to existing ids patch in place", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/time-zones")

      assert [
               {"h1", [{"id", "title-ny"}], ["NY"]},
               {"h1", [{"id", "title-sf"}], ["SF"]}
             ] = find_time_titles(render(view), ["ny", "sf"])

      html = render_click(view, "add-tz", %{id: "sf", name: "SanFran"})

      assert [
               {"h1", [{"id", "title-ny"}], ["NY"]},
               {"h1", [{"id", "title-sf"}], ["SanFran"]}
             ] = find_time_titles(html, ["ny", "sf"])
    end
  end

  describe "phx-update=prepend" do
    @tag session: %{time_zones: {:prepend, [%{id: "ny", name: "NY"}]}}
    test "static mount followed by connected mount", %{conn: conn} do
      conn = get(conn, "/time-zones")
      html = html_response(conn, 200)
      assert [{"section", _, ["time: 12:00 NY\n" | _]}] = find_time_zones(html, ["ny", "tokyo"])

      {:ok, view, _html} = live(conn)
      html = render(view)
      assert [{"section", _, ["time: 12:00 NY\n" | _]}] = find_time_zones(html, ["ny", "tokyo"])

      html = render_click(view, "add-tz", %{id: "tokyo", name: "Tokyo"})

      assert [
               {"section", _, ["time: 12:00 Tokyo\n" | _]},
               {"section", _, ["time: 12:00 NY\n" | _]}
             ] = find_time_zones(html, ["ny", "tokyo"])

      _html = render_click(view, "add-tz", %{id: "la", name: "LA"})
      html = render_click(view, "add-tz", %{id: "sf", name: "SF"})

      assert [
               {"section", _, ["time: 12:00 SF\n" | _]},
               {"section", _, ["time: 12:00 LA\n" | _]},
               {"section", _, ["time: 12:00 Tokyo\n" | _]},
               {"section", _, ["time: 12:00 NY\n" | _]}
             ] = find_time_zones(html, ["ny", "tokyo", "la", "sf"])
    end

    @tag session: %{time_zones: {:prepend, [%{id: "ny", name: "NY"}, %{id: "sf", name: "SF"}]}}
    test "updates to existing ids patch in place", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/time-zones")

      assert [
               {"h1", [{"id", "title-ny"}], ["NY"]},
               {"h1", [{"id", "title-sf"}], ["SF"]}
             ] = find_time_titles(render(view), ["ny", "sf"])

      html = render_click(view, "add-tz", %{id: "sf", name: "SanFran"})

      assert [
               {"h1", [{"id", "title-ny"}], ["NY"]},
               {"h1", [{"id", "title-sf"}], ["SanFran"]}
             ] = find_time_titles(html, ["ny", "sf"])
    end
  end

  describe "regular updates" do
    @tag session: %{time_zones: [%{id: "ny", name: "NY"}, %{id: "sf", name: "SF"}]}
    test "existing ids are replaced when patched without respawning children", %{conn: conn} do
      {:ok, view, html} = live(conn, "/shuffle")

      assert [
               {"section", _, ["time: 12:00 NY\n" | _]},
               {"section", _, ["time: 12:00 SF\n" | _]}
             ] = find_time_zones(html, ["ny", "sf"])

      children_pids_before = for child <- children(view), do: child.pid
      html = render_click(view, :reverse)
      children_pids_after = for child <- children(view), do: child.pid

      assert [
               {"section", _, ["time: 12:00 SF\n" | _]},
               {"section", _, ["time: 12:00 NY\n" | _]}
             ] = find_time_zones(html, ["ny", "sf"])

      assert children_pids_after == children_pids_before
    end
  end

  @tag session: %{data: %{names: ["chris", "jose"]}}
  describe "component updates" do
    test "send cids_destroyed event when compontent children are removed", %{conn: conn} do
      {:ok, view, html} = live(conn, "/components")

      assert [
               {"div", [{"id", "chris"}, {"data-phx-compontent", "chris"}], ["\n    chris\n  "]},
               {"div", [{"id", "jose"}, {"data-phx-compontent", "jose"}], ["\n    jose\n  "]}
             ] = DOM.all(html, "#chris, #jose")

      html = render_click(view, "delete-name", %{"name" => "chris"})

      assert [
               {"div", [{"id", "jose"}, {"data-phx-compontent", "jose"}], ["\n    jose\n  "]}
             ] = DOM.all(html, "#chris, #jose")

      assert_remove_component(view, "chris")
    end
  end

  defp find_time_zones(html, zones) do
    DOM.all(html, Enum.join(for(tz <- zones, do: "#tz-#{tz}"), ","))
  end

  defp find_time_titles(html, zones) do
    DOM.all(html, Enum.join(for(tz <- zones, do: "#title-#{tz}"), ","))
  end
end
