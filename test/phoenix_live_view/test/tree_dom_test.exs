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
end
