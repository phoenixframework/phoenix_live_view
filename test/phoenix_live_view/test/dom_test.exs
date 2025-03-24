defmodule Phoenix.LiveViewTest.DOMTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveViewTest.DOM

  describe "find_live_views" do
    # >= 4432 characters
    @too_big_session Enum.map_join(1..4432, fn _ -> "t" end)

    test "finds views given html" do
      assert DOM.find_live_views(
               DOM.parse("""
               <h1>top</h1>
               <div data-phx-session="SESSION1"
                 id="phx-123"></div>
               <div data-phx-parent-id="456"
                   data-phx-session="SESSION2"
                   data-phx-static="STATIC2"
                   id="phx-456"></div>
               <div data-phx-session="#{@too_big_session}"
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
               <div data-phx-session="SESSION1"
                 id="phx-123"></div>
               <div data-phx-parent-id="456"
                   data-phx-session="SESSION2"
                   data-phx-static="STATIC2"
                   id="phx-456"></div>
               <div data-phx-session="SESSIONMAIN"
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

  describe "replace_root_html" do
    test "replaces tag name and merges attributes" do
      container =
        DOM.parse("""
        <div id="container"
             data-phx-main="true"
             data-phx-session="session"
             data-phx-static="static"
             class="old">contents</div>
        """)

      assert DOM.replace_root_container(container, :span, %{class: "new"}) ==
               [
                 {"span",
                  [
                    {"id", "container"},
                    {"data-phx-main", "true"},
                    {"data-phx-session", "session"},
                    {"data-phx-static", "static"},
                    {"class", "new"}
                  ], ["contents"]}
               ]
    end

    test "does not overwrite reserved attributes" do
      container =
        DOM.parse("""
        <div id="container"
             data-phx-main="true"
             data-phx-session="session"
             data-phx-static="static">contents</div>
        """)

      new_attrs = %{
        "id" => "new",
        "data-phx-session" => "new",
        "data-phx-static" => "new",
        "data-phx-main" => "new"
      }

      assert DOM.replace_root_container(container, :div, new_attrs) ==
               [
                 {"div",
                  [
                    {"id", "container"},
                    {"data-phx-main", "true"},
                    {"data-phx-session", "session"},
                    {"data-phx-static", "static"}
                  ], ["contents"]}
               ]
    end
  end

  describe "patch_id" do
    test "updates deeply nested html" do
      html = """
      <div data-phx-session="SESSIONMAIN"
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

      {new_html, _removed_cids} =
        DOM.patch_id("phx-458", DOM.parse(html), DOM.parse(inner_html), [])

      new_html = DOM.to_html(new_html)

      refute new_html =~ ~S(<div id="1">a</div>)
      assert new_html =~ ~S(<div id="2" class="foo">a</div>)
      assert new_html =~ ~S(<div id="3"><div id="5">inner</div></div>)
      assert new_html =~ ~S(<div id="4">a</div>)
    end

    test "patches only container data attributes when phx-update=ignore" do
      html = """
      <div data-phx-session="SESSIONMAIN" data-phx-main="true" id="phx-458">
      <div id="div" remove data-remove update="a" data-update="a" phx-update="ignore">
        <div id="1">a</div>
      </div>
      </div>
      """

      inner_html = """
      <div id="div" update="b" data-update="b" add data-add phx-update="ignore">
        <div id="1" class="foo">b</div>
      </div>
      """

      {new_html, _removed_cids} =
        DOM.patch_id("phx-458", DOM.parse(html), DOM.parse(inner_html), [])

      new_html = DOM.to_html(new_html)

      assert new_html =~ ~S( remove)
      refute new_html =~ ~S( data-remove)
      assert new_html =~ ~S( update="a")
      assert new_html =~ ~S( data-update="b")
      refute new_html =~ ~S( add)
      assert new_html =~ ~S( data-add)
      assert new_html =~ ~S(<div id="1">a</div>)
    end

    test "patches elements with special characters in id (issue #3144)" do
      html = """
      <div data-phx-session="SESSIONMAIN" data-phx-main="true" id="phx-458">
      <div id="div?param=foo" phx-update="ignore" data-attr="1">
        <div id="1">a</div>
      </div>
      </div>
      """

      inner_html = """
      <div id="div?param=foo" phx-update="ignore" data-attr="b">
        <div id="1" class="foo">b</div>
      </div>
      """

      {new_html, _removed_cids} =
        DOM.patch_id("phx-458", DOM.parse(html), DOM.parse(inner_html), [])

      new_html = DOM.to_html(new_html)

      assert new_html =~ ~S(data-attr="b")
      assert new_html =~ ~S(<div id="1">a</div>)
    end
  end

  describe "merge_diff" do
    test "merges unless static" do
      assert DOM.merge_diff(%{0 => "bar", s: "foo"}, %{0 => "baz"}) ==
               %{0 => "baz", s: "foo", streams: []}

      assert DOM.merge_diff(%{s: "foo", d: []}, %{s: "bar"}) ==
               %{s: "bar", streams: []}
    end
  end

  describe "parse" do
    test "detects duplicate ids" do
      assert DOM.parse(
               """
               <div id="foo">
                 <div id="foo"></div>
               </div>
               """,
               fn msg -> send(self(), {:error, msg}) end
             )

      assert_receive {:error, msg}
      assert msg =~ "Duplicate id found while testing LiveView"
    end

    test "handles declarations (issue #3594)" do
      assert DOM.parse(
               """
               <div id="foo">
                 <?xml version="1.0" standalone="yes"?>
               </div>
               """,
               fn msg -> send(self(), {:error, msg}) end
             )

      refute_receive {:error, _}
    end
  end
end
