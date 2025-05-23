defmodule Phoenix.Component.MacroComponentIntegrationTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import Phoenix.LiveViewTest.TreeDOM, only: [sigil_X: 2]
  alias Phoenix.LiveViewTest.TreeDOM

  defmodule MyComponent do
    @behaviour Phoenix.Component.MacroComponent

    @impl true
    def transform(ast, meta) do
      send(self(), {:ast, ast, meta})
      Process.get(:new_ast, ast)
    end
  end

  test "receives ast" do
    defmodule TestComponentAst do
      use Phoenix.Component

      def render(assigns) do
        ~H"""
        <div :type={MyComponent} id="1" other={@foo}>
          <p>This is some inner content</p>
          <h1>Cool</h1>
        </div>
        """
      end
    end

    assert_received {:ast, ast, meta}

    assert ast ==
             {"div",
              [
                {":type", {:__aliases__, [line: 1], [:MyComponent]}},
                {"id", "1"},
                {"other", {:@, [line: 1], [{:foo, [line: 1], nil}]}}
              ],
              [
                "\n  ",
                {"p", [], ["This is some inner content"]},
                "\n  ",
                {"h1", [], ["Cool"]},
                "\n"
              ]}

    assert %{env: env, file: file, line: _line} = meta
    assert env.module == TestComponentAst
    assert file == __ENV__.file

    assert render_component(&TestComponentAst.render/1, foo: "bar") |> TreeDOM.normalize_to_tree() ==
             ~X"""
             <div id="1" other="bar">
               <p>This is some inner content</p>
               <h1>Cool</h1>
             </div>
             """
  end

  test "can replace the rendered content" do
    Process.put(
      :new_ast,
      {:div, [{"data-foo", "bar"}],
       [
         {"h1", [], ["Where is this coming from?"]},
         {"div", [{"id", quote(do: @foo)}], ["I have text content"]}
       ]}
    )

    defmodule TestComponentReplacedAst do
      use Phoenix.Component

      def render(assigns) do
        ~H"""
        <div :type={MyComponent} id="1" other={@foo}>
          <p>This is some inner content</p>
          <h1>Cool</h1>
        </div>
        """
      end
    end

    assert_received {:ast, _ast, _meta}

    assert render_component(&TestComponentReplacedAst.render/1, foo: "bar")
           |> TreeDOM.normalize_to_tree() ==
             ~X"""
             <div data-foo="bar">
               <h1>Where is this coming from?</h1>
               <div id="bar">I have text content</div>
             </div>
             """
  end

  test "raises when there is EEx inside" do
    assert_raise ArgumentError,
                 ~r/EEx is not currently supported in macro components/,
                 fn ->
                   defmodule TestComponentUnsupportedEEx do
                     use Phoenix.Component

                     def render(assigns) do
                       ~H"""
                       <div :type={MyComponent} id="1" other={@foo}>
                         <%= if @foo do %>
                           <p>foo</p>
                         <% end %>
                       </div>
                       """
                     end
                   end
                 end
  end

  test "raises when there is interpolation inside" do
    assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                 ~r/interpolation is not currently supported in macro components/,
                 fn ->
                   defmodule TestComponentUnsupportedInterpolation do
                     use Phoenix.Component

                     def render(assigns) do
                       ~H"""
                       <div :type={MyComponent} id="1" other={@foo}>
                         {@foo}
                       </div>
                       """
                     end
                   end
                 end
  end

  test "raises when there are components inside" do
    assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                 ~r/function components cannot be nested inside a macro component/,
                 fn ->
                   defmodule TestComponentUnsupportedComponents do
                     use Phoenix.Component

                     def render(assigns) do
                       ~H"""
                       <div :type={MyComponent} id="1" other={@foo}>
                         <.my_other_component />
                       </div>
                       """
                     end
                   end
                 end
  end
end
