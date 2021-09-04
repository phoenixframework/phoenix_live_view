defmodule Phoenix.LiveView.UpdateTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest

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
      assert [{"div", _, ["time: 12:00 NY\n" | _]}] = find_time_zones(html, ["ny", "tokyo"])

      {:ok, view, _html} = live(conn)
      html = render(view)
      assert [{"div", _, ["time: 12:00 NY\n" | _]}] = find_time_zones(html, ["ny", "tokyo"])

      html = render_click(view, "add-tz", %{id: "tokyo", name: "Tokyo"})

      assert [
               {"div", _, ["time: 12:00 NY\n" | _]},
               {"div", _, ["time: 12:00 Tokyo\n" | _]}
             ] = find_time_zones(html, ["ny", "tokyo"])

      _html = render_click(view, "add-tz", %{id: "la", name: "LA"})
      html = render_click(view, "add-tz", %{id: "sf", name: "SF"})

      assert [
               {"div", _, ["time: 12:00 NY\n" | _]},
               {"div", _, ["time: 12:00 Tokyo\n" | _]},
               {"div", _, ["time: 12:00 LA\n" | _]},
               {"div", _, ["time: 12:00 SF\n" | _]}
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

    @tag session: %{time_zones: {:append, [%{id: "nested-append", name: "NestedAppend"}]}}
    test "with nested append child", %{conn: conn} do
      conn = get(conn, "/time-zones")
      html = html_response(conn, 200)

      assert [
               {"div", _,
                [
                  "time: 12:00 NestedAppend\n",
                  {"div", [{"id", "append-NestedAppend"}, {"phx-update", "append"}], []}
                ]}
             ] = find_time_zones(html, ["nested-append", "tokyo"])

      {:ok, view, _html} = live(conn)
      assert nested_view = find_live_child(view, "tz-nested-append")

      GenServer.call(nested_view.pid, {:append, ["item1"]})
      GenServer.call(nested_view.pid, {:append, ["item2"]})

      html = render(view)

      assert [
               {"div", _,
                [
                  "time: 12:00 NestedAppend\n",
                  {"div", [{"id", "append-NestedAppend"}, {"phx-update", "append"}],
                   [
                     {:comment, " example "},
                     {"div", [{"id", "item-item1"}], ["item1"]},
                     {:comment, " example "},
                     {"div", [{"id", "item-item2"}], ["item2"]}
                   ]}
                ]}
             ] = find_time_zones(html, ["nested-append", "tokyo"])

      html = render_click(view, "add-tz", %{id: "tokyo", name: "Tokyo"})

      assert [
               {"div", _, ["time: 12:00 NestedAppend\n", _]},
               {"div", _, ["time: 12:00 Tokyo\n" | _]}
             ] = find_time_zones(html, ["nested-append", "tokyo"])
    end

    @tag session: %{time_zones: {:append, [%{id: "ny", name: "NY"}]}}
    test "raises without id on the parent", %{conn: conn} do
      Process.flag(:trap_exit, true)
      {:ok, view, _html} = live(conn, "/time-zones")

      assert Exception.format(:exit, catch_exit(render_click(view, "remove-id", %{}))) =~
               "setting phx-update to \"append\" requires setting an ID on the container"
    end

    @tag session: %{time_zones: {:append, [%{id: "ny", name: "NY"}]}}
    test "raises without id on the child", %{conn: conn} do
      Process.flag(:trap_exit, true)
      {:ok, view, _html} = live(conn, "/time-zones")

      assert Exception.format(
               :exit,
               catch_exit(render_click(view, "add-tz", %{id: nil, name: "Tokyo"}))
             ) =~
               "setting phx-update to \"append\" requires setting an ID on each child"
    end
  end

  describe "phx-update=prepend" do
    @tag session: %{time_zones: {:prepend, [%{id: "ny", name: "NY"}]}}
    test "static mount followed by connected mount", %{conn: conn} do
      conn = get(conn, "/time-zones")
      html = html_response(conn, 200)
      assert [{"div", _, ["time: 12:00 NY\n" | _]}] = find_time_zones(html, ["ny", "tokyo"])

      {:ok, view, _html} = live(conn)
      html = render(view)
      assert [{"div", _, ["time: 12:00 NY\n" | _]}] = find_time_zones(html, ["ny", "tokyo"])

      html = render_click(view, "add-tz", %{id: "tokyo", name: "Tokyo"})

      assert [
               {"div", _, ["time: 12:00 Tokyo\n" | _]},
               {"div", _, ["time: 12:00 NY\n" | _]}
             ] = find_time_zones(html, ["ny", "tokyo"])

      _html = render_click(view, "add-tz", %{id: "la", name: "LA"})
      html = render_click(view, "add-tz", %{id: "sf", name: "SF"})

      assert [
               {"div", _, ["time: 12:00 SF\n" | _]},
               {"div", _, ["time: 12:00 LA\n" | _]},
               {"div", _, ["time: 12:00 Tokyo\n" | _]},
               {"div", _, ["time: 12:00 NY\n" | _]}
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
    @tag session: %{
           time_zones: [%{"id" => "ny", "name" => "NY"}, %{"id" => "sf", "name" => "SF"}]
         }
    test "existing ids are replaced when patched without respawning children", %{conn: conn} do
      {:ok, view, html} = live(conn, "/shuffle")

      assert [
               {"div", _, ["time: 12:00 NY\n" | _]},
               {"div", _, ["time: 12:00 SF\n" | _]}
             ] = find_time_zones(html, ["ny", "sf"])

      children_pids_before = for child <- live_children(view), do: child.pid
      html = render_click(view, :reverse)
      children_pids_after = for child <- live_children(view), do: child.pid

      assert [
               {"div", _, ["time: 12:00 SF\n" | _]},
               {"div", _, ["time: 12:00 NY\n" | _]}
             ] = find_time_zones(html, ["ny", "sf"])

      assert children_pids_after == children_pids_before
    end
  end

  defp find_time_zones(html, zones) do
    html |> DOM.parse() |> DOM.all(Enum.join(for(tz <- zones, do: "#tz-#{tz}"), ","))
  end

  defp find_time_titles(html, zones) do
    html |> DOM.parse() |> DOM.all(Enum.join(for(tz <- zones, do: "#title-#{tz}"), ","))
  end
end
