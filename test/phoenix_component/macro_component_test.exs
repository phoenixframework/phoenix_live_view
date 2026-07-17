defmodule Phoenix.Component.MacroComponentTest do
  use ExUnit.Case, async: true

  alias Phoenix.Component.MacroComponent

  setup_all do
    defmodule MyMacroComponent do
      @behaviour Phoenix.Component.MacroComponent

      @impl true
      def transform(ast, _meta), do: {:ok, ast, %{}}
    end

    :ok
  end

  describe "ast_to_string/1" do
    test "simple cases" do
      assert MacroComponent.ast_to_string({"div", [{"id", "1"}], ["Hello"], %{}}) ==
               "<div id=\"1\">Hello</div>"

      assert MacroComponent.ast_to_string({"div", [{"id", "<bar>"}], ["Hello"], %{}}) ==
               "<div id=\"<bar>\">Hello</div>"
    end

    test "handles self closing and void tags" do
      assert MacroComponent.ast_to_string(
               {"div", [{"id", "<bar>"}], [{"hr", [], [], %{closing: :void}}], %{}}
             ) ==
               "<div id=\"<bar>\"><hr></div>"

      assert MacroComponent.ast_to_string({"circle", [{"id", "1"}], [], %{closing: :self}}) ==
               "<circle id=\"1\"/>"
    end

    test "attribute without value" do
      assert MacroComponent.ast_to_string(
               {"div", [{"foo", nil}, {"bar", "baz"}], [], %{closing: :self}}
             ) ==
               "<div foo bar=\"baz\"/>"
    end

    test "handles quotes" do
      assert MacroComponent.ast_to_string({"div", [{"foo", ~s['bar']}], [], %{}}) ==
               ~s[<div foo="'bar'"></div>]

      assert MacroComponent.ast_to_string({"div", [{"foo", ~s["bar"]}], [], %{}}) ==
               ~s[<div foo='"bar"'></div>]

      assert_raise ArgumentError, ~r/invalid attribute value for "foo"/, fn ->
        MacroComponent.ast_to_string({"div", [{"foo", ~s["'bar'"]}], [], %{}})
      end
    end

    test "invalid attribute" do
      assert_raise ArgumentError,
                   ~r/cannot convert AST with non-string attribute "id" to string. Got: @bar/,
                   fn ->
                     MacroComponent.ast_to_string(
                       {"div", [{"id", quote(do: @bar)}], ["Hello"], %{}}
                     )
                   end
    end
  end

  describe "get_data/1" do
    test "returns an empty map if the component module does not exist" do
      assert MacroComponent.get_data(IDoNotExist) == %{}
    end

    test "returns an empty map if the component does not define any macro components" do
      defmodule MyComponent do
        use Phoenix.Component

        def render(assigns), do: ~H""
      end

      assert MacroComponent.get_data(MyComponent) == %{}
    end
  end
end
