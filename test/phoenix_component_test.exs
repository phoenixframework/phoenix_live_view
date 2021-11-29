defmodule Phoenix.ComponentTest do
  use ExUnit.Case, async: true

  use Phoenix.Component

  defp h2s(template) do
    template
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  describe "rendering" do
    defp hello(assigns) do
      assigns = assign_new(assigns, :name, fn -> "World" end)
      ~H"""
      Hello <%= @name %>
      """
    end

    test "renders component" do
      assigns = %{}

      assert h2s(~H"""
             <%= component &hello/1, name: "WORLD" %>
             """) == """
             Hello WORLD\
             """
    end
  end

  describe "change tracking" do
    defp eval(%Phoenix.LiveView.Rendered{dynamic: dynamic}), do: Enum.map(dynamic.(true), &eval/1)
    defp eval(other), do: other

    defp changed(assigns) do
      ~H"""
      <%= inspect(assigns.__changed__) %>
      """
    end

    test "without changed assigns on root" do
      assigns = %{foo: 1}
      assert eval(~H"<.changed foo={@foo} />") == [["nil"]]
    end

    test "with changed assigns on root" do
      assigns = %{foo: 1, __changed__: %{}}
      assert eval(~H"<.changed foo={@foo} />") == [nil]

      assigns = %{foo: 1, __changed__: %{bar: true}}
      assert eval(~H"<.changed foo={@foo} />") == [nil]

      assigns = %{foo: 1, __changed__: %{foo: true}}
      assert eval(~H"<.changed foo={@foo} />") == [["%{foo: true}"]]

      assigns = %{foo: 1, __changed__: %{foo: %{bar: true}}}
      assert eval(~H"<.changed foo={@foo} />") == [["%{foo: %{bar: true}}"]]
    end

    test "with changed assigns on map" do
      assigns = %{foo: %{bar: :bar}, __changed__: %{}}
      assert eval(~H"<.changed foo={@foo.bar} />") == [nil]

      assigns = %{foo: %{bar: :bar}, __changed__: %{bar: true}}
      assert eval(~H"<.changed foo={@foo.bar} />") == [nil]

      assigns = %{foo: %{bar: :bar}, __changed__: %{foo: true}}
      assert eval(~H"<.changed foo={@foo.bar} />") == [["%{foo: true}"]]

      assigns = %{foo: %{bar: :bar}, __changed__: %{foo: %{bar: :bar}}}
      assert eval(~H"<.changed foo={@foo.bar} />") == [nil]

      assigns = %{foo: %{bar: :bar}, __changed__: %{foo: %{bar: :baz}}}
      assert eval(~H"<.changed foo={@foo.bar} />") == [["%{foo: true}"]]

      assigns = %{foo: %{bar: %{bar: :bar}}, __changed__: %{foo: %{bar: %{bar: :bat}}}}
      assert eval(~H"<.changed foo={@foo.bar} />") == [["%{foo: %{bar: :bat}}"]]
    end

    test "with multiple changed assigns" do
      assigns = %{foo: 1, bar: 2, __changed__: %{}}
      assert eval(~H"<.changed foo={@foo + @bar} />") == [nil]

      assigns = %{foo: 1, bar: 2, __changed__: %{bar: true}}
      assert eval(~H"<.changed foo={@foo + @bar} />") == [["%{foo: true}"]]

      assigns = %{foo: 1, bar: 2, __changed__: %{foo: true}}
      assert eval(~H"<.changed foo={@foo + @bar} />") == [["%{foo: true}"]]

      assigns = %{foo: 1, bar: 2, __changed__: %{baz: true}}
      assert eval(~H"<.changed foo={@foo + @bar} />") == [nil]
    end

    test "with multiple keys" do
      assigns = %{foo: 1, bar: 2, __changed__: %{}}
      assert eval(~H"<.changed foo={@foo} bar={@bar} />") == [nil]

      assigns = %{foo: 1, bar: 2, __changed__: %{bar: true}}
      assert eval(~H"<.changed foo={@foo} bar={@bar} />") == [["%{bar: true}"]]

      assigns = %{foo: 1, bar: 2, __changed__: %{foo: true}}
      assert eval(~H"<.changed foo={@foo} bar={@bar} />") == [["%{foo: true}"]]

      assigns = %{foo: 1, bar: 2, __changed__: %{baz: true}}
      assert eval(~H"<.changed foo={@foo} bar={@bar} />") == [nil]
    end

    test "with multiple keys and one is static" do
      assigns = %{foo: 1, __changed__: %{}}
      assert eval(~H|<.changed foo={@foo} bar="2" />|) == [nil]

      assigns = %{foo: 1, __changed__: %{bar: true}}
      assert eval(~H|<.changed foo={@foo} bar="2" />|) == [nil]

      assigns = %{foo: 1, __changed__: %{foo: true}}
      assert eval(~H|<.changed foo={@foo} bar="2" />|) == [["%{foo: true}"]]
    end

    test "with multiple keys and one is tainted" do
      assigns = %{foo: 1, __changed__: %{}}
      assert eval(~H|<.changed foo={@foo} bar={assigns} />|) == [["%{bar: true}"]]

      assigns = %{foo: 1, __changed__: %{foo: true}}
      assert eval(~H|<.changed foo={@foo} bar={assigns} />|) == [["%{bar: true, foo: true}"]]
    end

    test "with conflict on changed assigns" do
      assigns = %{foo: 1, bar: %{foo: 2}, __changed__: %{}}
      assert eval(~H"<.changed foo={@foo} {@bar} />") == [nil]

      assigns = %{foo: 1, bar: %{foo: 2}, __changed__: %{bar: true}}
      assert eval(~H"<.changed foo={@foo} {@bar} />") == [["%{foo: true}"]]

      assigns = %{foo: 1, bar: %{foo: 2}, __changed__: %{foo: true}}
      assert eval(~H"<.changed foo={@foo} {@bar} />") == [["%{foo: true}"]]

      assigns = %{foo: 1, bar: %{foo: 2}, baz: 3, __changed__: %{baz: true}}
      assert eval(~H"<.changed foo={@foo} {@bar} baz={@baz} />") == [["%{baz: true}"]]
    end

    test "with dynamic assigns" do
      assigns = %{foo: %{a: 1, b: 2}, __changed__: %{}}
      assert eval(~H"<.changed {@foo} />") == [nil]

      assigns = %{foo: %{a: 1, b: 2}, __changed__: %{foo: true}}
      assert eval(~H"<.changed {@foo} />") == [["%{a: true, b: true}"]]

      assigns = %{foo: %{a: 1, b: 2}, bar: 3, __changed__: %{bar: true}}
      assert eval(~H"<.changed {@foo} bar={@bar} />") == [["%{bar: true}"]]

      assigns = %{foo: %{a: 1, b: 2}, bar: 3, __changed__: %{bar: true}}
      assert eval(~H"<.changed {%{a: 1, b: 2}} bar={@bar} />") == [["%{bar: true}"]]

      assigns = %{foo: %{a: 1, b: 2}, bar: 3, __changed__: %{bar: true}}

      assert eval(~H"<.changed {%{a: assigns[:b], b: assigns[:a]}} bar={@bar} />") ==
               [["%{a: true, b: true, bar: true}"]]
    end

    defp inner_changed(assigns) do
      ~H"""
      <%= inspect(assigns.__changed__) %>
      <%= render_slot(@inner_block, "var") %>
      """
    end

    test "with @inner_block" do
      assigns = %{foo: 1, __changed__: %{}}
      assert eval(~H|<.inner_changed foo={@foo}></.inner_changed>|) == [nil]
      assert eval(~H|<.inner_changed><%= @foo %></.inner_changed>|) == [nil]

      assigns = %{foo: 1, __changed__: %{foo: true}}

      assert eval(~H|<.inner_changed foo={@foo}></.inner_changed>|) ==
               [["%{foo: true}", nil]]

      assert eval(
               ~H|<.inner_changed foo={@foo}><%= inspect(assigns.__changed__) %></.inner_changed>|
             ) ==
               [["%{foo: true, inner_block: true}", ["%{foo: true}"]]]

      assert eval(
               ~H|<.inner_changed><%= @foo %></.inner_changed>|
             ) ==
               [["%{inner_block: true}", ["1"]]]

      assigns = %{foo: 1, __changed__: %{foo: %{bar: true}}}

      assert eval(~H|<.inner_changed foo={@foo}></.inner_changed>|) ==
               [["%{foo: %{bar: true}}", nil]]

      assert eval(
               ~H|<.inner_changed foo={@foo}><%= inspect(assigns.__changed__) %></.inner_changed>|
             ) ==
               [["%{foo: %{bar: true}, inner_block: true}", ["%{foo: %{bar: true}}"]]]

      assert eval(
               ~H|<.inner_changed><%= @foo %></.inner_changed>|
             ) ==
               [["%{inner_block: %{bar: true}}", ["1"]]]
    end

    test "with let" do
      assigns = %{foo: 1, __changed__: %{}}
      assert eval(~H|<.inner_changed let={_foo} foo={@foo}></.inner_changed>|) == [nil]

      assigns = %{foo: 1, __changed__: %{foo: true}}

      assert eval(~H|<.inner_changed let={_foo} foo={@foo}></.inner_changed>|) ==
               [["%{foo: true}", nil]]

      assert eval(
               ~H|<.inner_changed let={_foo} foo={@foo}><%= inspect(assigns.__changed__) %></.inner_changed>|
             ) ==
               [["%{foo: true, inner_block: true}", ["%{foo: true}"]]]

      assert eval(
               ~H|<.inner_changed let={_foo} foo={@foo}><%= "constant" %><%= inspect(assigns.__changed__) %></.inner_changed>|
             ) ==
               [["%{foo: true, inner_block: true}", [nil, "%{foo: true}"]]]

      assert eval(
               ~H|<.inner_changed let={foo} foo={@foo}><.inner_changed let={_bar} bar={foo}><%= "constant" %><%= inspect(assigns.__changed__) %></.inner_changed></.inner_changed>|
             ) ==
               [
                 [
                   "%{foo: true, inner_block: true}",
                   [["%{bar: true, inner_block: true}", [nil, "%{foo: true}"]]]
                 ]
               ]

      assert eval(
               ~H|<.inner_changed let={foo} foo={@foo}><%= foo %><%= inspect(assigns.__changed__) %></.inner_changed>|
             ) ==
               [["%{foo: true, inner_block: true}", ["var", "%{foo: true}"]]]

      assert eval(
               ~H|<.inner_changed let={foo} foo={@foo}><.inner_changed let={bar} bar={foo}><%= bar %><%= inspect(assigns.__changed__) %></.inner_changed></.inner_changed>|
             ) ==
               [
                 [
                   "%{foo: true, inner_block: true}",
                   [["%{bar: true, inner_block: true}", ["var", "%{foo: true}"]]]
                 ]
               ]
    end
  end

  describe "testing" do
    import Phoenix.LiveViewTest

    test "render_component/1" do
      assert render_component(&hello/1) == "Hello World"
      assert render_component(&hello/1, name: "WORLD!") == "Hello WORLD!"
    end
  end

  describe "component metadata" do

    defmodule RemoteFunctionComponentWithAttrs do
      use Phoenix.Component

      attr :id, :any, required: true
      def remote(assigns), do: ~H[]
    end

    defmodule FunctionComponentWithAttrs do
      use Phoenix.Component
      import RemoteFunctionComponentWithAttrs
      alias RemoteFunctionComponentWithAttrs, as: Remote

      def func1_line, do: __ENV__.line
      attr :id, :any, required: true
      attr :email, :any
      def func1(assigns), do: ~H[]

      def func2_line, do: __ENV__.line
      attr :name, :any, required: true
      def func2(assigns), do: ~H[]

      def render_line, do: __ENV__.line
      def render(assigns) do
        ~H"""
        <!-- local -->
        <.func1 id="1"/>
        <!-- local with inner content -->
        <.func1 id="2">CONTENT</.func1>
        <!-- imported -->
        <.remote id="3"/>
        <!-- remote -->
        <RemoteFunctionComponentWithAttrs.remote id="4"/>
        <!-- remote with inner content -->
        <RemoteFunctionComponentWithAttrs.remote id="5">CONTENT</RemoteFunctionComponentWithAttrs.remote>
        <!-- remote and aliased -->
        <Remote.remote id="6"/>
        """
      end
    end

    test "store attributes definitions" do
      func1_line = FunctionComponentWithAttrs.func1_line()
      func2_line = FunctionComponentWithAttrs.func2_line()

      assert FunctionComponentWithAttrs.__components__() == %{
        func1: [
          %{name: :id, type: :any, opts: [required: true], line: func1_line + 1},
          %{name: :email, type: :any, opts: [], line: func1_line + 2}
        ],
        func2: [
          %{name: :name, type: :any, opts: [required: true], line: func2_line + 1}
        ]
      }
    end

    test "store component calls" do
      render_line = FunctionComponentWithAttrs.render_line()
      {call_1_line, call_3_line} =
        if Version.match?(System.version(), ">= 1.12.0") do
          {render_line + 4, render_line + 8}
        else
          {2, 6}
        end

      file = __ENV__.file

      assert [
        %{
          component: {FunctionComponentWithAttrs, :func1},
          attrs: [{"id", {:string, "1", %{}}, %{}}],
          file: ^file,
          line: ^call_1_line
        },
        %{
          component: {FunctionComponentWithAttrs, :func1},
          attrs: [{"id", {:string, "2", %{}}, %{}}]
        },
        %{
          attrs: [{"id", {:string, "3", %{}}, %{}}],
          component: {RemoteFunctionComponentWithAttrs, :remote},
          file: ^file,
          line: ^call_3_line
        },
        %{
          attrs: [{"id", {:string, "4", %{}}, %{}}],
          component: {RemoteFunctionComponentWithAttrs, :remote}
        },
        %{
          attrs: [{"id", {:string, "5", %{}}, %{}}],
          component: {RemoteFunctionComponentWithAttrs, :remote}
        },
        %{
          attrs: [{"id", {:string, "6", %{}}, %{}}],
          component: {RemoteFunctionComponentWithAttrs, :remote}
        }
      ] = FunctionComponentWithAttrs.__components_calls__()
    end

    test "do not generate __components_calls__ if there's no call" do
      refute function_exported?(RemoteFunctionComponentWithAttrs, :__components_calls__, 0)
    end

    test "raise if attr is not declared before the first function definition" do
      code = """
      defmodule Phoenix.ComponentTest.MultiClause do
        use Elixir.Phoenix.Component

        attr :foo, :any
        def func(assigns = %{foo: _}), do: ~H[]
        def func(assigns = %{bar: _}), do: ~H[]
      end
      """

      assert {{:module, _, _, _}, _} = Code.eval_string(code)

      code = """
      defmodule Phoenix.ComponentTest.MultiClauseWrong do
        use Elixir.Phoenix.Component

        attr :foo, :any
        def func(assigns = %{foo: _}), do: ~H[]
        def func(assigns = %{bar: _}), do: ~H[]

        attr :bar, :any
        def func(assigns = %{baz: _}), do: ~H[]
      end
      """

      message = "code:8: attributes must be defined before the first function clause at line 5"

      assert_raise(CompileError, message, fn ->
        Code.eval_string(code, [], %{__ENV__ | file: "code", line: 1})
      end)
    end

    test "raise if attr is declared on an invalid function" do
      code = """
      defmodule Phoenix.ComponentTest.AttrOnInvalidFunction do
        use Elixir.Phoenix.Component

        attr :foo, :any
        def func(a, b), do: a + b
      end
      """

      message = """
      code:4: cannot declare attributes for `func/2`. \
      Components must be functions with arity 1.\
      """
      assert_raise(CompileError, message, fn ->
        Code.eval_string(code, [], %{__ENV__ | file: "code", line: 1})
      end)
    end

    test "raise if attr is declared without a related function" do
      code = """
      defmodule Phoenix.ComponentTest.AttrOnInvalidFunction do
        use Elixir.Phoenix.Component

        def func(assigns = %{baz: _}), do: ~H[]

        attr :foo, :any
      end
      """

      message = "code:6: cannot define attributes without a related function component"
      assert_raise(CompileError, message, fn ->
        Code.eval_string(code, [], %{__ENV__ | file: "code", line: 1})
      end)
    end

    test "raise if attr type is not supported" do
      code = """
      defmodule Phoenix.ComponentTest.AttrTypeNotSupported do
        use Elixir.Phoenix.Component

        attr :foo, :not_a_type
        def func(assigns), do: ~H[]
      end
      """

      message = "code:4: invalid type `:not_a_type` for attr `:foo`. Currently, only type `:any` is supported."
      assert_raise(CompileError, message, fn ->
        Code.eval_string(code, [], %{__ENV__ | file: "code", line: 1})
      end)
    end

    test "raise if attr option is not supported" do
      code = """
      defmodule Phoenix.ComponentTest.AttrOptionNotSupported do
        use Elixir.Phoenix.Component

        attr :foo, :any, not_an_opt: true
        def func(assigns), do: ~H[]
      end
      """

      message = "code:4: invalid option `:not_an_opt` for attr `:foo`. Currently, only `:required` is supported."
      assert_raise(CompileError, message, fn ->
        Code.eval_string(code, [], %{__ENV__ | file: "code", line: 1})
      end)
    end
  end
end
