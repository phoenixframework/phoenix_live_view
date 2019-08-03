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

  test "finds session given html" do
    assert DOM.find_sessions(@html) == [
             {"SESSION1", nil, "phx-123"},
             {"SESSION2", "STATIC2", "phx-456"},
             {@too_big_session, nil, "phx-458"}
           ]

    assert DOM.find_sessions("none") == []
  end

  test "inserts session within html" do
    assert DOM.insert_attr(@html, "data-phx-session", "SESSION1", "<span>session1</span>") == """
           <h1>top</h1>
           <div data-phx-view="789"
             data-phx-session="SESSION1"
             id="phx-123"><span>session1</span></div>
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

    assert_raise MatchError, fn ->
      assert DOM.insert_attr(@html, "data-phx-session", "not exists", "content") == @html
    end
  end
end
