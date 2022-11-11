defmodule Phoenix.LiveView.CollocatedTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.{Endpoint, CollocatedLive, CollocatedComponent}
  alias Phoenix.LiveView.LiveReloadTestHelpers, as: Helpers

  @endpoint Endpoint

  setup_all do
    Helpers.start_endpoint(@endpoint)
    :ok
  end

  test "supports collocated views" do
    {:ok, view, html} = live_isolated(build_conn(), CollocatedLive)
    assert html =~ "Hello collocated world from live!\n</div>"
    assert render(view) =~ "Hello collocated world from live!\n</div>"
  end

  test "supports collocated components" do
    assert render_component(CollocatedComponent, world: "world") =~
             "Hello collocated world from component!\n"
  end
end
