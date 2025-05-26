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
      {:ok, Process.get(:new_ast, ast)}
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
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <circle cx="50" cy="50" r="50" />
          </svg>
          <hr />
        </div>
        """
      end
    end

    assert_received {:ast, ast, meta}

    assert {"div",
            [
              {"id", "1"},
              {"other", {:@, [line: _], [{:foo, [line: _], nil}]}}
            ],
            [
              "\n  ",
              {"p", [], ["This is some inner content"], %{}},
              "\n  ",
              {"h1", [], ["Cool"], %{}},
              "\n  ",
              {"svg", [{"viewBox", "0 0 100 100"}, {"xmlns", "http://www.w3.org/2000/svg"}],
               [
                 "\n    ",
                 {"circle", [{"cx", "50"}, {"cy", "50"}, {"r", "50"}], [], %{closing: :self}},
                 "\n  "
               ], %{}},
              "\n  ",
              {"hr", [], [], %{closing: :void}},
              "\n"
            ], %{}} = ast

    assert %{env: env} = meta
    assert env.module == TestComponentAst
    assert env.file == __ENV__.file

    assert render_component(&TestComponentAst.render/1, foo: "bar") |> TreeDOM.normalize_to_tree() ==
             ~X"""
             <div id="1" other="bar">
               <p>This is some inner content</p>
               <h1>Cool</h1>
               <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
                 <circle cx="50" cy="50" r="50" />
               </svg>
               <hr>
             </div>
             """
  end

  test "can replace the rendered content" do
    Process.put(
      :new_ast,
      {:div, [{"data-foo", "bar"}],
       [
         {"h1", [], ["Where is this coming from?"], %{}},
         {"div", [{"id", quote(do: @foo)}], ["I have text content"], %{}},
         {"hr", [], [], %{closing: :void}}
       ], %{}}
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

    rendered = render_component(&TestComponentReplacedAst.render/1, foo: "bar\"baz")

    assert rendered =~ "bar&quot;baz"

    assert render_component(&TestComponentReplacedAst.render/1, foo: "bar\"baz")
           |> TreeDOM.normalize_to_tree() ==
             ~X"""
             <div data-foo="bar">
               <h1>Where is this coming from?</h1>
               <div id="bar&quot;baz">I have text content</div>
               <hr>
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

  test "raises for dynamic attributes" do
    assert_raise ArgumentError,
                 ~r/dynamic attributes are not supported in macro components, got: #{Regex.escape("`{@bar}`")}/,
                 fn ->
                   defmodule TestComponentUnsupportedDynamicAttributes1 do
                     use Phoenix.Component

                     def render(assigns) do
                       ~H"""
                       <div :type={MyComponent} id="1" other={@foo} {@bar}></div>
                       """
                     end
                   end
                 end

    assert_raise ArgumentError,
                 ~r/dynamic attributes are not supported in macro components, got: #{Regex.escape("`{@bar}`")}/,
                 fn ->
                   defmodule TestComponentUnsupportedDynamicAttributes2 do
                     use Phoenix.Component

                     def render(assigns) do
                       ~H"""
                       <div :type={MyComponent} id="1" other={@foo}>
                         <span {@bar}>Hey!</span>
                       </div>
                       """
                     end
                   end
                 end
  end

  test "raises for single quote attributes" do
    assert_raise ArgumentError,
                 ~r/single quote attributes are not supported in macro components/,
                 fn ->
                   defmodule TestComponentUnsupportedSingleQuoteAttributes do
                     use Phoenix.Component

                     def render(assigns) do
                       ~H"""
                       <div :type={MyComponent} id='"hello"'></div>
                       """
                     end
                   end
                 end
  end
end
