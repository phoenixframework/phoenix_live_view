defmodule Phoenix.LiveViewTest.DOMTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveViewTest.DOM

  # >= 4432 characters
  @too_big_session Enum.map(1..4432, fn _ -> "t" end) |> Enum.join()

  test "finds views given html" do
    assert DOM.find_live_views(
             DOM.parse("""
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
             """)
           ) == [
             {"phx-123", "SESSION1", nil},
             {"phx-456", "SESSION2", "STATIC2"},
             {"phx-458", @too_big_session, nil}
           ]

    assert DOM.find_live_views(["none"]) == []
  end

  test "returns main live view as first result" do
    assert DOM.find_live_views(
             DOM.parse("""
             <h1>top</h1>
             <div data-phx-view="789"
               data-phx-session="SESSION1"
               id="phx-123"></div>
             <div data-phx-parent-id="456"
                 data-phx-view="789"
                 data-phx-session="SESSION2"
                 data-phx-static="STATIC2"
                 id="phx-456"></div>
             <div data-phx-session="SESSIONMAIN"
               data-phx-view="789"
               data-phx-main="true"
               id="phx-458"></div>
             <h1>bottom</h1>
             """)
           ) == [
             {"phx-458", "SESSIONMAIN", nil},
             {"phx-123", "SESSION1", nil},
             {"phx-456", "SESSION2", "STATIC2"}
           ]
  end
end
