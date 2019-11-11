defmodule Phoenix.LiveViewTest.DOMTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveViewTest.DOM

  # >= 4432 characters
  @too_big_session Enum.map(1..4432, fn _ -> "t" end) |> Enum.join()

  @html """
  <h1>top</h1>
  <div data-phx-view="789"
    data-phx-session="SESSION1"
    id="phx-123"></div>
  <div data-phx-parent-id="456"
      data-phx-view="789"
      data-phx-session="SESSION2"
      data-phx-static="STATIC2"
      id="phx-456"></div>
  <div data-phx-session="#{@too_big_session}"
    data-phx-view="789"
    id="phx-458"></div>
  <h1>bottom</h1>
  """

  test "finds views given html" do
    assert DOM.find_views(@html) == [
             {"phx-123", "SESSION1", nil},
             {"phx-456", "SESSION2", "STATIC2"},
             {"phx-458", @too_big_session, nil}
           ]

    assert DOM.find_views("none") == []
  end
end
