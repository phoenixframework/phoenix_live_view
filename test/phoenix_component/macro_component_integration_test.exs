defmodule Phoenix.Component.MacroComponentIntegrationTest do
  # async: false due to manipulating the Application env
  # for :root_tag_attribute
  use ExUnit.Case, async: false

  use Phoenix.Component

  import Phoenix.LiveViewTest
  import Phoenix.LiveViewTest.TreeDOM, only: [sigil_X: 2]

  alias Phoenix.LiveViewTest.TreeDOM
  alias Phoenix.Component.MacroComponent

  defmodule MyComponent do
    @behaviour Phoenix.Component.MacroComponent

    @impl true
    def transform(ast, meta) do
      send(self(), {:ast, ast, meta})
      {:ok, Process.get(:new_ast, ast)}
    end
  end

  defmodule DirectiveMacroComponent do
    @behaviour Phoenix.Component.MacroComponent

    @impl true
    def directives(_ast, _meta) do
      {:ok,
       [
         root_tag_attribute: {"phx-sample-one", "test"},
         root_tag_attribute: {"phx-sample-two", "test"}
       ]}
    end

    @impl true
    def transform(_ast, _meta) do
      {:ok, "", %{}}
    end
  end

  defmodule BadRootTagAttrDirectiveMacroComponent do
    @behaviour Phoenix.Component.MacroComponent

    @impl true
    def directives(_ast, _meta) do
      {:ok, [root_tag_attribute: false]}
    end

    @impl true
    def transform(_ast, _meta) do
      {:ok, "", %{}}
    end
  end

  defmodule UnknownDirectiveMacroComponent do
    @behaviour Phoenix.Component.MacroComponent

    @impl true
    def directives(_ast, _meta) do
      {:ok, [unknown: true]}
    end

    @impl true
    def transform(_ast, _meta) do
      {:ok, "", %{}}
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
    assert_raise Phoenix.LiveView.Tokenizer.ParseError,
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

  test "raises when trying to use :type on a component" do
    assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                 ~r/unsupported attribute \":type\"/,
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

    assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                 ~r/unsupported attribute \":type\"/,
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
    assert_raise Phoenix.LiveView.Tokenizer.ParseError,
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

    assert_raise Phoenix.LiveView.Tokenizer.ParseError,
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

  test "raises if :root_tag_attribute is not configured and the :root_tag_attribute directive is provided" do
    message = ~r"""
    a global :root_tag_attribute must be configured for macro components to use the :root_tag_attribute directive

    Macro Component: #{__MODULE__}\.DirectiveMacroComponent

    Expected global :root_tag_attribute to be a string, got: nil

    The global :root_tag_attribute defaults to "phx-r". If you are getting this warning, the global
    :root_tag_attribute has been explicitly disabled in your application's config. You will be unable
    to use this macro component until the global `:root_tag_attribute` is re-enabled.

    If you wish to use a global :root_tag_attribute other than "phx-r", you can configure a
    custom attribute like so:

        config :phoenix_live_view, root_tag_attribute: "your-attribute-here"
    """

    assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                 message,
                 fn ->
                   defmodule TestRootTagAttrNotConfig do
                     use Phoenix.Component

                     def render(assigns) do
                       ~H"""
                       <div :type={DirectiveMacroComponent}></div>
                       """
                     end
                   end
                 end
  end

  test "raises if an unknown directive is provided" do
    message =
      ~r/unknown directive {:unknown, true} provided by macro component #{__MODULE__}\.UnknownDirectiveMacroComponent/

    assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                 message,
                 fn ->
                   defmodule TestUnknownDirective do
                     use Phoenix.Component

                     def render(assigns) do
                       ~H"""
                       <div :type={UnknownDirectiveMacroComponent}></div>
                       """
                     end
                   end
                 end
  end

  describe "macro components with directives" do
    setup do
      # Need to set a :root_tag_attribute as the only directive supported
      # by macro components currently is [root_tag_attribute: {name, value}] which
      # requires a :root_tag_attribute to be configured
      Application.put_env(:phoenix_live_view, :root_tag_attribute, "phx-r")
      on_exit(fn -> Application.put_env(:phoenix_live_view, :root_tag_attribute, nil) end)
    end

    test "raises if :root_tag_attribute directive is provided with an invalid value" do
      message = ~r"""
      expected {name, value} for :root_tag_attribute directive from macro component #{__MODULE__}\.BadRootTagAttrDirectiveMacroComponent, got: false

      name must be a compile-time string, and value must be a compile-time string or true
      """

      assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                   message,
                   fn ->
                     defmodule TestBadRootTagAttrDirective do
                       use Phoenix.Component

                       def render(assigns) do
                         ~H"""
                         <div :type={BadRootTagAttrDirectiveMacroComponent}></div>
                         """
                       end
                     end
                   end
    end

    test "raises if macro components with directives are not defined at the beginning of the template" do
      message =
        ~r/macro component #{__MODULE__}\.DirectiveMacroComponent specified directives and therefore must appear at the very beginning of the template/

      defmodule TestComponentDirectiveAtBeginning1 do
        use Phoenix.Component

        def render(assigns) do
          ~H"""
          <div :type={DirectiveMacroComponent}></div>
          """
        end
      end

      defmodule TestComponentDirectiveAtBeginning2 do
        use Phoenix.Component

        def render(assigns) do
          ~H"""
          <div :type={DirectiveMacroComponent}></div>
          """
        end
      end

      assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                   message,
                   fn ->
                     defmodule TestComponentDirectiveAtBeginning3 do
                       use Phoenix.Component

                       def render(assigns) do
                         ~H"""
                         <div />
                         <div :type={DirectiveMacroComponent}></div>
                         """
                       end
                     end
                   end

      assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                   message,
                   fn ->
                     defmodule TestComponentDirectiveAtBeginning4 do
                       use Phoenix.Component

                       def render(assigns) do
                         ~H"""
                         <div></div>
                         <div :type={DirectiveMacroComponent}></div>
                         """
                       end
                     end
                   end

      assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                   message,
                   fn ->
                     defmodule TestComponentDirectiveAtBeginning5 do
                       use Phoenix.Component

                       def render(assigns) do
                         ~H"""
                         <.link>Link</.link>
                         <div :type={DirectiveMacroComponent}></div>
                         """
                       end
                     end
                   end

      assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                   message,
                   fn ->
                     defmodule TestComponentDirectiveAtBeginning6 do
                       use Phoenix.Component

                       def render(assigns) do
                         ~H"""
                         <Phoenix.Component.link>Link</Phoenix.Component.link>
                         <div :type={DirectiveMacroComponent}></div>
                         """
                       end
                     end
                   end

      assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                   message,
                   fn ->
                     defmodule TestComponentDirectiveAtBeginning7 do
                       use Phoenix.Component

                       def render(assigns) do
                         ~H"""
                         {if true, do: "Test"}
                         <div :type={DirectiveMacroComponent}></div>
                         """
                       end
                     end
                   end

      assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                   message,
                   fn ->
                     defmodule TestComponentDirectiveAtBeginning8 do
                       use Phoenix.Component

                       def render(assigns) do
                         ~H"""
                         <%= if true do %>
                           <div :type={DirectiveMacroComponent}></div>
                         <% end %>
                         """
                       end
                     end
                   end

      assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                   message,
                   fn ->
                     defmodule TestComponentDirectiveAtBeginning9 do
                       use Phoenix.Component

                       def render(assigns) do
                         ~H"""
                         <div>
                           <div :type={DirectiveMacroComponent}></div>
                         </div>
                         """
                       end
                     end
                   end

      assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                   message,
                   fn ->
                     defmodule TestComponentDirectiveAtBeginning10 do
                       use Phoenix.Component

                       def render(assigns) do
                         ~H"""
                         <.link>
                           <div :type={DirectiveMacroComponent}></div>
                         </.link>
                         """
                       end
                     end
                   end

      assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                   message,
                   fn ->
                     defmodule TestComponentDirectiveAtBeginning11 do
                       use Phoenix.Component

                       def render(assigns) do
                         ~H"""
                         <Phoenix.Component.link>
                           <div :type={DirectiveMacroComponent}></div>
                         </Phoenix.Component.link>
                         """
                       end
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
    assert_raise ArgumentError,
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

    Process.put(:new_ast, "some text")

    refute eval_heex("""
           <div :type={MyComponent}>Test</div>
           <span>Another</span>
           """).root
  end

  defp eval_heex(source) do
    EEx.compile_string(source,
      engine: Phoenix.LiveView.TagEngine,
      line: 1,
      file: __ENV__.file,
      trim: true,
      caller: __ENV__,
      source: source,
      tag_handler: Phoenix.LiveView.HTMLEngine
    )
    |> Code.eval_quoted(assigns: %{})
    |> elem(0)
  end
end
