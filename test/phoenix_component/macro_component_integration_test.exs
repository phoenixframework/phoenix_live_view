defmodule Phoenix.Component.MacroComponentIntegrationTest do
  use ExUnit.Case, async: true

  use Phoenix.Component

  import Phoenix.LiveViewTest
  import Phoenix.LiveViewTest.TreeDOM, only: [sigil_X: 2]

  alias Phoenix.LiveViewTest.TreeDOM
  alias Phoenix.Component.MacroComponent
  alias Phoenix.LiveView.TagEngine.Tokenizer.ParseError

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
    assert_raise ParseError,
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
    assert_raise ParseError,
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
    assert_raise ParseError,
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

  test "raises when trying to use :type on a component" do
    assert_raise ParseError,
                 ~r/macro components are only supported on HTML tags/,
                 fn ->
                   defmodule TestUnsupportedComponent do
                     use Phoenix.Component

                     def render(assigns) do
                       ~H"""
                       <.my_other_component :type={MyComponent} />
                       """
                     end
                   end
                 end

    assert_raise ParseError,
                 ~r/macro components are only supported on HTML tags/,
                 fn ->
                   defmodule TestUnsupportedComponent do
                     use Phoenix.Component

                     def render(assigns) do
                       ~H"""
                       <.my_other_component>
                         <:my_slot :type={MyComponent} />
                       </.my_other_component>
                       """
                     end
                   end
                 end
  end

  test "raises for dynamic attributes" do
    assert_raise ParseError,
                 ~r/dynamic attributes are not supported in macro components, got: @bar/,
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

    assert_raise ParseError,
                 ~r/dynamic attributes are not supported in macro components, got: @bar/,
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

  test "handles quotes" do
    Process.put(
      :new_ast,
      {:div, [{"id", "1"}],
       [
         {"span", [{"class", "\"foo\""}], ["Test"], %{}},
         {"span", [{"class", "'foo'"}], ["Test"], %{}}
       ], %{}}
    )

    defmodule TestComponentQuotes do
      use Phoenix.Component

      def render(assigns) do
        ~H"""
        <div :type={MyComponent}></div>
        """
      end
    end

    assert_received {:ast, _ast, _meta}

    assert render_component(&TestComponentQuotes.render/1) == """
           <div id="1"><span class='"foo"'>Test</span><span class="'foo'">Test</span></div>\
           """

    # mixed quotes are invalid
    assert_raise ParseError,
                 ~r/invalid attribute value for "class"/,
                 fn ->
                   Process.put(:new_ast, {:div, [{"class", ~s["'"]}], [], %{}})

                   defmodule TestComponentQuotesInvalid do
                     use Phoenix.Component

                     def render(assigns) do
                       ~H"""
                       <div :type={MyComponent}></div>
                       """
                     end
                   end
                 end
  end

  test "get_data/2 provides a list of all data entries" do
    defmodule MyMacroComponent do
      @behaviour Phoenix.Component.MacroComponent

      @impl true
      def transform({_tag, attrs, _children, _meta} = ast, meta) do
        {:ok, ast, %{file: meta.env.file, line: meta.env.line, opts: Map.new(attrs)}}
      end
    end

    defmodule TestComponentWithData1 do
      use Phoenix.Component

      def render(assigns) do
        ~H"""
        <div :type={MyMacroComponent} foo="bar" baz></div>
        <div>
          <h1 :type={MyMacroComponent} id="2">Content</h1>
        </div>
        """
      end
    end

    assert data = MacroComponent.get_data(TestComponentWithData1, MyMacroComponent)
    assert length(data) == 2

    assert Enum.find(data, fn %{opts: opts} -> opts == %{"baz" => nil, "foo" => "bar"} end)
    assert Enum.find(data, fn %{opts: opts} -> opts == %{"id" => "2"} end)
  end

  test "root tracking" do
    assert eval_heex("<div :type={MyComponent}>Test</div>").root

    refute eval_heex("""
           <div :type={MyComponent}>Test</div>
           <span>Another</span>
           """).root

    Process.put(
      :new_ast,
      {:div, [{"id", "1"}],
       [
         {"span", [{"class", "\"foo\""}], ["Test"], %{}},
         {"span", [{"class", "'foo'"}], ["Test"], %{}}
       ], %{}}
    )

    assert eval_heex("<div :type={MyComponent}>Test</div>").root

    Process.put(:new_ast, "")

    assert eval_heex("""
           <div :type={MyComponent}>Test</div><span>Another</span>
           """).root

    Process.put(:new_ast, "")

    assert eval_heex("""
           <div :type={MyComponent}>Test</div>\n<span>Another</span>
           """).root

    Process.put(:new_ast, "some text")

    refute eval_heex("""
           <div :type={MyComponent}>Test</div>
           <span>Another</span>
           """).root
  end

  defp eval_heex(source) do
    Phoenix.LiveView.TagEngine.compile(source,
      file: __ENV__.file,
      caller: __ENV__,
      tag_handler: Phoenix.LiveView.HTMLEngine
    )
    |> Code.eval_quoted(assigns: %{})
    |> elem(0)
  end
end
