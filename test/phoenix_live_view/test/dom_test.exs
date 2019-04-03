defmodule Phoenix.LiveViewTest.DOMTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveViewTest.DOM

  @html """
  <h1>top</h1>
  <div conn id="123"
    data-phx-parent-id="456"
    data-phx-view="789"
    data-phx-session="SESSION1"></div>
  <div conn id="456"
      data-phx-parent-id="456"
      data-phx-view="789"
      data-phx-session="SESSION2"></div>
  <h1>bottom</h1>
  """

  test "finds session given html" do
    assert DOM.find_sessions(@html) == ["SESSION1", "SESSION2"]
    assert DOM.find_sessions("none") == []
  end

  test "inserts session within html" do
    assert DOM.insert_session(@html, "SESSION1", "<span>session1</span>") == """
    <h1>top</h1>
    <div conn id="123"
      data-phx-parent-id="456"
      data-phx-view="789"
      data-phx-session="SESSION1"><span>session1</span></div>
    <div conn id="456"
        data-phx-parent-id="456"
        data-phx-view="789"
        data-phx-session="SESSION2"></div>
    <h1>bottom</h1>
    """

    assert_raise MatchError, fn ->
      assert DOM.insert_session(@html, "not exists", "content") == @html
    end
  end
end
