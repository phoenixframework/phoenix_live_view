defmodule Phoenix.LiveViewTest.DOMTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveViewTest.DOM

  describe "find_live_views" do
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

  describe "patch_id" do
    test "updates deeply nested html" do
      html = """
      <div data-phx-session="SESSIONMAIN"
                     data-phx-view="789"
                     data-phx-main="true"
                     id="phx-458">
      <div id="foo">Hello</div>
      <div id="list">
        <div id="1">a</div>
        <div id="2">a</div>
        <div id="3">a</div>
      </div>
      </div>
      """

      inner_html = """
      <div id="foo">Hello World</div>
      <div id="list">
        <div id="2" class="foo">a</div>
        <div id="3">
          <div id="5">inner</div>
        </div>
        <div id="4">a</div>
      </div>
      """

      {new_html, _removed_cids} = DOM.patch_id("phx-458", DOM.parse(html), DOM.parse(inner_html))

      new_html = DOM.to_html(new_html)

      refute new_html =~ ~S(<div id="1">a</div>)
      assert new_html =~ ~S(<div id="2" class="foo">a</div>)
      assert new_html =~ ~S(<div id="3"><div id="5">inner</div></div>)
      assert new_html =~ ~S(<div id="4">a</div>)
    end

    test "inserts new elements when phx-update=append" do
      html = """
      <div data-phx-session="SESSIONMAIN"
                     data-phx-view="789"
                     data-phx-main="true"
                     id="phx-458">
      <div id="list" phx-update="append">
        <div id="1">a</div>
        <div id="2">a</div>
        <div id="3">a</div>
      </div>
      </div>
      """

      inner_html = """
      <div id="list" phx-update="append">
        <div id="4" class="foo">a</div>
      </div>
      """

      {new_html, _removed_cids} = DOM.patch_id("phx-458", DOM.parse(html), DOM.parse(inner_html))

      new_html = DOM.to_html(new_html)

      assert new_html =~ ~S(<div id="1">a</div>)
      assert new_html =~ ~S(<div id="2">a</div>)
      assert new_html =~ ~S(<div id="3">a</div><div id="4" class="foo">a</div>)
    end

    test "inserts new elements when phx-update=prepend" do
      html = """
      <div data-phx-session="SESSIONMAIN"
                     data-phx-view="789"
                     data-phx-main="true"
                     id="phx-458">
      <div id="list" phx-update="append">
        <div id="1">a</div>
        <div id="2">a</div>
        <div id="3">a</div>
      </div>
      </div>
      """

      inner_html = """
      <div id="list" phx-update="prepend">
        <div id="4">a</div>
      </div>
      """

      {new_html, _removed_cids} = DOM.patch_id("phx-458", DOM.parse(html), DOM.parse(inner_html))

      new_html = DOM.to_html(new_html)

      assert new_html =~ ~S(<div id="4">a</div><div id="1">a</div>)
      assert new_html =~ ~S(<div id="2">a</div>)
      assert new_html =~ ~S(<div id="3">a</div>)
    end

    test "updates existing elements when phx-update=append" do
      html = """
      <div data-phx-session="SESSIONMAIN"
                     data-phx-view="789"
                     data-phx-main="true"
                     id="phx-458">
      <div id="list" phx-update="append">
        <div id="1">a</div>
        <div id="2">a</div>
        <div id="3">a</div>
      </div>
      </div>
      """

      inner_html = """
      <div id="list" phx-update="append">
        <div id="1" class="foo">b</div>
        <div id="2">b</div>
      </div>
      """

      {new_html, _removed_cids} = DOM.patch_id("phx-458", DOM.parse(html), DOM.parse(inner_html))

      new_html = DOM.to_html(new_html)

      assert new_html =~ ~S(<div id="1" class="foo">b</div>)
      assert new_html =~ ~S(<div id="2">b</div>)
      assert new_html =~ ~S(<div id="3">a</div>)
    end
  end
end
