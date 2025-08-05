defmodule Phoenix.LiveView.UpdateTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.TreeDOM
  alias Phoenix.LiveViewTest.Support.Endpoint

  @endpoint Endpoint

  setup config do
    {:ok,
     conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), config[:session] || %{})}
  end

  describe "regular updates" do
    @tag session: %{
           time_zones: [%{"id" => "ny", "name" => "NY"}, %{"id" => "sf", "name" => "SF"}]
         }
    test "existing ids are replaced when patched without respawning children", %{conn: conn} do
      {:ok, view, html} = live(conn, "/shuffle")

      assert [
               {"div", _, ["time: 12:00 NY" | _]},
               {"div", _, ["time: 12:00 SF" | _]}
             ] = find_time_zones(html, ["ny", "sf"])

      children_pids_before = for child <- live_children(view), do: child.pid
      html = render_click(view, :reverse)
      children_pids_after = for child <- live_children(view), do: child.pid

      assert [
               {"div", _, ["time: 12:00 SF" | _]},
               {"div", _, ["time: 12:00 NY" | _]}
             ] = find_time_zones(html, ["ny", "sf"])

      assert children_pids_after == children_pids_before
    end
  end

  defp find_time_zones(html, zones) do
    ids = Enum.map(zones, fn zone -> "tz-" <> zone end)

    html
    |> TreeDOM.normalize_to_tree(sort_attributes: true)
    |> TreeDOM.filter(fn node -> TreeDOM.attribute(node, "id") in ids end)
  end
end
