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
      assert MacroComponent.ast_to_string(
               quote do
                 tag("div", [attribute("id", [], "<bar>")]) do
                   "Hello"
                 end
               end
             ) ==
               "<div id=\"<bar>\">Hello</div>"
    end

    test "handles self closing and void tags" do
      assert MacroComponent.ast_to_string(
               quote do
                 tag("div", [attribute("id", [], "<bar>")]) do
                   tag("hr", [], closing: :void)
                 end
               end
             ) ==
               "<div id=\"<bar>\"><hr></div>"

      assert MacroComponent.ast_to_string(
               quote do
                 tag("circle", [attribute("id", [], "1")], closing: :self)
               end
             ) ==
               "<circle id=\"1\"></circle>"
    end

    test "attribute without value" do
      assert MacroComponent.ast_to_string(
               quote do
                 tag("div", [attribute("foo", nil), attribute("bar", [], "baz")], closing: :self)
               end
             ) ==
               "<div foo bar=\"baz\"></div>"
    end

    test "handles quotes" do
      assert MacroComponent.ast_to_string(
               quote do
                 tag("div", [attribute("foo", [], unquote(~s['bar']))], do: [])
               end
             ) ==
               ~s[<div foo="'bar'"></div>]

      assert MacroComponent.ast_to_string(
               quote do
                 tag("div", [attribute("foo", [], unquote(~s["bar"]))], do: [])
               end
             ) ==
               ~s[<div foo='"bar"'></div>]

      assert_raise ArgumentError, ~r/invalid attribute value for "foo"/, fn ->
        MacroComponent.ast_to_string(
          quote do
            tag("div", [attribute("foo", [], unquote(~s["'bar'"]))], do: [])
          end
        )
      end
    end

    test "invalid attribute" do
      assert_raise KeyError,
                   ~r/:foo not found/,
                   fn ->
                     MacroComponent.ast_to_string(
                       quote do
                         tag("div", [attribute("id", [], @foo)], do: [])
                       end
                     )
                   end
    end
  end

  describe "get_data/2" do
    test "returns an empty list if the component module does not exist" do
      assert MacroComponent.get_data(IDoNotExist, MyMacroComponent) == []
    end

    test "returns an empty list if the component does not define any macro components" do
      defmodule MyComponent do
        use Phoenix.Component

        def render(assigns), do: ~H""
      end

      assert MacroComponent.get_data(MyComponent, MyMacroComponent) == []
    end
  end
end
