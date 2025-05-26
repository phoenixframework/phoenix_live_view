defmodule Phoenix.Component.MacroComponentTest do
  use ExUnit.Case, async: true

  alias Phoenix.Component.MacroComponent

  test "ast_to_string/1" do
    assert MacroComponent.ast_to_string({"div", [{"id", "1"}], ["Hello"]}) ==
             "<div id=\"1\">Hello</div>"

    assert MacroComponent.ast_to_string({"div", [{"id", "<bar>"}], ["Hello"]}) ==
             "<div id=\"&lt;bar&gt;\">Hello</div>"

    assert MacroComponent.ast_to_string({"div", [{"id", "<bar>"}], ["Hello"]},
             attributes_escape: fn attrs ->
               Enum.map(attrs, fn {key, value} -> [" ", key, "=\"", value, "\"", " "] end)
             end
           ) == "<div id=\"<bar>\" >Hello</div>"

    assert_raise Protocol.UndefinedError, fn ->
      MacroComponent.ast_to_string({"div", [{"id", quote(do: @bar)}], ["Hello"]})
    end
  end
end
