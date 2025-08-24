defmodule Phoenix.LiveViewTest.TreeDOMTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest.TreeDOM, only: [sigil_X: 2, sigil_x: 2]

  alias Phoenix.LiveViewTest.TreeDOM

  describe "find_live_views" do
    # >= 4432 characters
    @too_big_session Enum.map_join(1..4432, fn _ -> "t" end)

    test "finds views given html" do
      assert TreeDOM.find_live_views(~x"""
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
             """) == [
               {"phx-123", "SESSION1", nil},
               {"phx-456", "SESSION2", "STATIC2"},
               {"phx-458", @too_big_session, nil}
             ]

      assert TreeDOM.find_live_views(["none"]) == []
    end

    test "returns main live view as first result" do
      assert TreeDOM.find_live_views(~X"""
             <h1>top</h1>
             <div data-phx-session="SESSION1"
               id="phx-123"></div>
             <div data-phx-parent-id="456"
                 data-phx-session="SESSION2"
                 data-phx-static="STATIC2"
                 id="phx-456"></div>
             <div data-phx-session="SESSIONMAIN"
               data-phx-main
               id="phx-458"></div>
             <h1>bottom</h1>
             """) == [
               {"phx-458", "SESSIONMAIN", nil},
               {"phx-123", "SESSION1", nil},
               {"phx-456", "SESSION2", "STATIC2"}
             ]
    end
  end

  describe "replace_root_html" do
    test "replaces tag name and merges attributes" do
      container =
        ~X"""
        <div id="container"
             data-phx-main="true"
             data-phx-session="session"
             data-phx-static="static"
             class="old">contents</div>
        """

      assert TreeDOM.replace_root_container(container, :span, %{class: "new"})
             |> TreeDOM.normalize_to_tree(sort_attributes: true) ==
               [
                 {"span",
                  [
                    {"class", "new"},
                    {"data-phx-main", "true"},
                    {"data-phx-session", "session"},
                    {"data-phx-static", "static"},
                    {"id", "container"}
                  ], ["contents"]}
               ]
    end

    test "does not overwrite reserved attributes" do
      container =
        ~X"""
        <div id="container"
             data-phx-main="true"
             data-phx-session="session"
             data-phx-static="static">contents</div>
        """

      new_attrs = %{
        "id" => "new",
        "data-phx-session" => "new",
        "data-phx-static" => "new",
        "data-phx-main" => "new"
      }

      assert TreeDOM.replace_root_container(container, :div, new_attrs)
             |> TreeDOM.normalize_to_tree(sort_attributes: true) ==
               [
                 {"div",
                  [
                    {"data-phx-main", "true"},
                    {"data-phx-session", "session"},
                    {"data-phx-static", "static"},
                    {"id", "container"}
                  ], ["contents"]}
               ]
    end
  end

  describe "apply_portal_teleportation" do
    test "teleports portal content to target selector" do
      html = ~x"""
      <div>
        <template id="my-portal" data-phx-portal="#target">
          <div id="portal-content" class="modal">Hello World</div>
        </template>
        <div id="target"></div>
      </div>
      """

      result = TreeDOM.apply_portal_teleportation(html)

      expected = ~x"""
      <div>
        <template id="my-portal" data-phx-portal="#target">
          <div id="portal-content" class="modal">Hello World</div>
        </template>
        <div id="target">
          <div id="portal-content" class="modal">Hello World</div>
        </div>
      </div>
      """

      assert result == expected
    end

    test "updates existing portal content when re-rendering" do
      html = ~x"""
      <div>
        <template id="my-portal" data-phx-portal="#target">
          <div id="portal-content" class="modal">Updated Content</div>
        </template>
        <div id="target">
          <div id="portal-content" class="modal" data-phx-teleported-src="true">Old Content</div>
        </div>
      </div>
      """

      result = TreeDOM.apply_portal_teleportation(html)

      expected = ~x"""
      <div>
        <template id="my-portal" data-phx-portal="#target">
          <div id="portal-content" class="modal">Updated Content</div>
        </template>
        <div id="target">
          <div id="portal-content" class="modal">Updated Content</div>
        </div>
      </div>
      """

      assert result == expected
    end

    test "handles multiple portals to different targets" do
      html = ~x"""
      <div>
        <template id="portal-1" data-phx-portal="#target-1">
          <div id="content-1">Content 1</div>
        </template>
        <template id="portal-2" data-phx-portal="#target-2">
          <div id="content-2">Content 2</div>
        </template>
        <div id="target-1"></div>
        <div id="target-2"></div>
      </div>
      """

      result = TreeDOM.apply_portal_teleportation(html)

      expected = ~x"""
      <div>
        <template id="portal-1" data-phx-portal="#target-1">
          <div id="content-1">Content 1</div>
        </template>
        <template id="portal-2" data-phx-portal="#target-2">
          <div id="content-2">Content 2</div>
        </template>
        <div id="target-1">
          <div id="content-1">Content 1</div>
        </div>
        <div id="target-2">
          <div id="content-2">Content 2</div>
        </div>
      </div>
      """

      assert result == expected
    end

    test "ignores portals when target selector is not found" do
      html = ~x"""
      <div>
        <template id="my-portal" data-phx-portal="#missing-target">
          <div id="portal-content">Content</div>
        </template>
        <div id="existing-target"></div>
      </div>
      """

      result = TreeDOM.apply_portal_teleportation(html)

      # Should remain unchanged since target doesn't exist
      expected = ~x"""
      <div>
        <template id="my-portal" data-phx-portal="#missing-target">
          <div id="portal-content">Content</div>
        </template>
        <div id="existing-target"></div>
      </div>
      """

      assert result == expected
    end

    test "works with nested elements" do
      html =
        TreeDOM.normalize_to_tree(
          """
          <body>
            <template id="my-portal" data-phx-portal="body">
              <div id="modal" class="modal-backdrop">
                <div class="modal-content">
                  <h1>Modal Title</h1>
                  <p>Modal body text</p>
                </div>
              </div>
            </template>
            <div id="app">App content</div>
          </body>
          """,
          full_document: true,
          sort_attributes: true
        )

      result = TreeDOM.apply_portal_teleportation(html)

      expected =
        TreeDOM.normalize_to_tree(
          """
          <body>
            <template id="my-portal" data-phx-portal="body">
              <div id="modal" class="modal-backdrop">
                <div class="modal-content">
                  <h1>Modal Title</h1>
                  <p>Modal body text</p>
                </div>
              </div>
            </template>
            <div id="app">App content</div>
            <div id="modal" class="modal-backdrop">
              <div class="modal-content">
                <h1>Modal Title</h1>
                <p>Modal body text</p>
              </div>
            </div>
          </body>
          """,
          full_document: true,
          sort_attributes: true
        )

      assert result == expected
    end
  end
end
