defmodule Phoenix.Component.MacroComponentTest do
  use ExUnit.Case, async: true

  alias Phoenix.Component.MacroComponent

  test "ast_to_string/1" do
    assert MacroComponent.ast_to_string({"div", [{"id", "1"}], ["Hello"], %{}}) ==
             "<div id=\"1\">Hello</div>"

    assert MacroComponent.ast_to_string({"div", [{"id", "<bar>"}], ["Hello"], %{}}) ==
             "<div id=\"<bar>\">Hello</div>"

    assert MacroComponent.ast_to_string(
             {"div", [{"id", "<bar>"}], [{"hr", [], [], %{closing: :void}}], %{}}
           ) ==
             "<div id=\"<bar>\"><hr></div>"

    assert MacroComponent.ast_to_string({"circle", [{"id", "1"}], [], %{closing: :self}}) ==
             "<circle id=\"1\"/>"

    assert_raise Protocol.UndefinedError, fn ->
      MacroComponent.ast_to_string({"div", [{"id", quote(do: @bar)}], ["Hello"], %{}})
    end
  end
end
