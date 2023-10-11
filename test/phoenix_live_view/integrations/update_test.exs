defmodule Phoenix.LiveView.UpdateTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.{Endpoint, DOM}

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
    html |> DOM.parse() |> DOM.all(Enum.join(for(tz <- zones, do: "#tz-#{tz}"), ","))
  end
end
