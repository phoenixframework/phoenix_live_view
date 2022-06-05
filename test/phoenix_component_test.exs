defmodule Phoenix.ComponentTest do
  use ExUnit.Case, async: true

  use Phoenix.Component

  defp render(mod, func, assigns) do
    mod
    |> apply(func, [Map.put(assigns, :__changed__, %{})])
    |> h2s()
  end

  defp h2s(template) do
    template
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  test "__global__?" do
    assert Phoenix.Component.__global__?("id")
    refute Phoenix.Component.__global__?("idnope")
    refute Phoenix.Component.__global__?("not-global")

    # prefixes
    assert Phoenix.Component.__global__?("aria-label")
    assert Phoenix.Component.__global__?("data-whatever")
    assert Phoenix.Component.__global__?("phx-click")
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
      <%= inspect(Map.get(assigns, :__changed__)) %>
      """
    end

    test "without changed assigns on root" do
      assigns = %{foo: 1}
      assert eval(~H"<.changed foo={@foo} />") == [["nil"]]
    end

    test "with tainted variable" do
      foo = 1
      assigns = %{foo: 1}
      assert eval(~H"<.changed foo={foo} />") == [["nil"]]

      assigns = %{foo: 1, __changed__: %{}}
      assert eval(~H"<.changed foo={foo} />") == [["%{foo: true}"]]
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
      <%= inspect(Map.get(assigns, :__changed__)) %>
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
               ~H|<.inner_changed foo={@foo}><%= inspect(Map.get(assigns, :__changed__)) %></.inner_changed>|
             ) ==
               [["%{foo: true, inner_block: true}", ["%{foo: true}"]]]

      assert eval(~H|<.inner_changed><%= @foo %></.inner_changed>|) ==
               [["%{inner_block: true}", ["1"]]]

      assigns = %{foo: 1, __changed__: %{foo: %{bar: true}}}

      assert eval(~H|<.inner_changed foo={@foo}></.inner_changed>|) ==
               [["%{foo: %{bar: true}}", nil]]

      assert eval(
               ~H|<.inner_changed foo={@foo}><%= inspect(Map.get(assigns, :__changed__)) %></.inner_changed>|
             ) ==
               [["%{foo: %{bar: true}, inner_block: true}", ["%{foo: %{bar: true}}"]]]

      assert eval(~H|<.inner_changed><%= @foo %></.inner_changed>|) ==
               [["%{inner_block: %{bar: true}}", ["1"]]]
    end

    test "with let" do
      assigns = %{foo: 1, __changed__: %{}}
      assert eval(~H|<.inner_changed :let={_foo} foo={@foo}></.inner_changed>|) == [nil]

      assigns = %{foo: 1, __changed__: %{foo: true}}

      assert eval(~H|<.inner_changed :let={_foo} foo={@foo}></.inner_changed>|) ==
               [["%{foo: true}", nil]]

      assert eval(
               ~H|<.inner_changed :let={_foo} foo={@foo}><%= inspect(Map.get(assigns, :__changed__)) %></.inner_changed>|
             ) ==
               [["%{foo: true, inner_block: true}", ["%{foo: true}"]]]

      assert eval(
               ~H|<.inner_changed :let={_foo} foo={@foo}><%= "constant" %><%= inspect(Map.get(assigns, :__changed__)) %></.inner_changed>|
             ) ==
               [["%{foo: true, inner_block: true}", [nil, "%{foo: true}"]]]

      assert eval(
               ~H|<.inner_changed :let={foo} foo={@foo}><.inner_changed :let={_bar} bar={foo}><%= "constant" %><%= inspect(Map.get(assigns, :__changed__)) %></.inner_changed></.inner_changed>|
             ) ==
               [
                 [
                   "%{foo: true, inner_block: true}",
                   [["%{bar: true, inner_block: true}", [nil, "%{foo: true}"]]]
                 ]
               ]

      assert eval(
               ~H|<.inner_changed :let={foo} foo={@foo}><%= foo %><%= inspect(Map.get(assigns, :__changed__)) %></.inner_changed>|
             ) ==
               [["%{foo: true, inner_block: true}", ["var", "%{foo: true}"]]]

      assert eval(
               ~H|<.inner_changed :let={foo} foo={@foo}><.inner_changed :let={bar} bar={foo}><%= bar %><%= inspect(Map.get(assigns, :__changed__)) %></.inner_changed></.inner_changed>|
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
      attr :email, :any, default: nil
      def func1(assigns), do: ~H[]

      def func2_line, do: __ENV__.line
      attr :name, :any, required: true
      attr :age, :integer, default: 0
      def func2(assigns), do: ~H[]

      def with_global_line, do: __ENV__.line
      attr :id, :string, default: "container"
      def with_global(assigns), do: ~H[<.button id={@id} class="btn" aria-hidden="true"/>]

      attr :id, :string, required: true
      attr :rest, :global
      def button(assigns), do: ~H[<button id={@id} {@rest}/>]

      def button_with_defaults_line, do: __ENV__.line
      attr :rest, :global, default: %{class: "primary"}
      def button_with_defaults(assigns), do: ~H[<button {@rest}/>]

      def render_line, do: __ENV__.line

      def render(assigns) do
        ~H"""
        <!-- local -->
        <.func1 id="1"/>
        <!-- local with inner content -->
        <.func1 id="2" email>CONTENT</.func1>
        <!-- imported -->
        <.remote id="3"/>
        <!-- remote -->
        <RemoteFunctionComponentWithAttrs.remote id="4"/>
        <!-- remote with inner content -->
        <RemoteFunctionComponentWithAttrs.remote id="5">CONTENT</RemoteFunctionComponentWithAttrs.remote>
        <!-- remote and aliased -->
        <Remote.remote id="6" {[dynamic: :values]}/>
        """
      end
    end

    test "stores attributes definitions" do
      func1_line = FunctionComponentWithAttrs.func1_line()
      func2_line = FunctionComponentWithAttrs.func2_line()
      with_global_line = FunctionComponentWithAttrs.with_global_line()
      button_with_defaults_line = FunctionComponentWithAttrs.button_with_defaults_line()

      assert FunctionComponentWithAttrs.__components__() == %{
               func1: %{
                 kind: :def,
                 attrs: [
                   %{
                     name: :email,
                     type: :any,
                     opts: [default: nil],
                     required: false,
                     desc: "",
                     line: func1_line + 2
                   },
                   %{
                     name: :id,
                     type: :any,
                     opts: [],
                     required: true,
                     desc: "",
                     line: func1_line + 1
                   }
                 ]
               },
               func2: %{
                 kind: :def,
                 attrs: [
                   %{
                     name: :age,
                     type: :integer,
                     opts: [default: 0],
                     required: false,
                     desc: "",
                     line: func2_line + 2
                   },
                   %{
                     name: :name,
                     type: :any,
                     opts: [],
                     required: true,
                     desc: "",
                     line: func2_line + 1
                   }
                 ]
               },
               with_global: %{
                 attrs: [
                   %{
                     line: with_global_line + 1,
                     name: :id,
                     opts: [default: "container"],
                     required: false,
                     desc: "",
                     type: :string
                   }
                 ],
                 kind: :def
               },
               button_with_defaults: %{
                 attrs: [
                   %{
                     line: button_with_defaults_line + 1,
                     name: :rest,
                     opts: [default: %{class: "primary"}],
                     required: false,
                     desc: "",
                     type: :global
                   }
                 ],
                 kind: :def
               },
               button: %{
                 attrs: [
                   %{
                     line: with_global_line + 4,
                     name: :id,
                     opts: [],
                     required: true,
                     type: :string,
                     desc: ""
                   },
                   %{
                     line: with_global_line + 5,
                     name: :rest,
                     opts: [],
                     required: false,
                     desc: "",
                     type: :global
                   }
                 ],
                 kind: :def
               }
             }
    end

    test "stores component calls" do
      render_line = FunctionComponentWithAttrs.render_line()
      with_global_line = FunctionComponentWithAttrs.with_global_line() + 3

      call_1_line = render_line + 5
      call_3_line = render_line + 9
      file = __ENV__.file

      assert [
               %{
                 attrs: %{id: {_, _, :expr}},
                 component: {Phoenix.ComponentTest.FunctionComponentWithAttrs, :button},
                 file: ^file,
                 line: ^with_global_line,
                 root: false
               },
               %{
                 component: {FunctionComponentWithAttrs, :func1},
                 attrs: %{id: {_, _, "1"}},
                 file: ^file,
                 line: ^call_1_line
               },
               %{
                 component: {FunctionComponentWithAttrs, :func1},
                 attrs: %{id: {_, _, "2"}, email: {_, _, nil}}
               },
               %{
                 attrs: %{id: {_, _, "3"}},
                 component: {RemoteFunctionComponentWithAttrs, :remote},
                 file: ^file,
                 line: ^call_3_line
               },
               %{
                 attrs: %{id: {_, _, "4"}},
                 component: {RemoteFunctionComponentWithAttrs, :remote}
               },
               %{
                 attrs: %{id: {_, _, "5"}},
                 component: {RemoteFunctionComponentWithAttrs, :remote},
                 root: false
               },
               %{
                 attrs: %{id: {_, _, "6"}},
                 component: {RemoteFunctionComponentWithAttrs, :remote},
                 root: true
               }
             ] = FunctionComponentWithAttrs.__components_calls__()
    end

    test "does not generate __components_calls__ if there's no call" do
      refute function_exported?(RemoteFunctionComponentWithAttrs, :__components_calls__, 0)
    end

    test "stores components for bodyless clauses" do
      defmodule Bodyless do
        use Phoenix.Component

        attr :example, :any, required: true
        def example(assigns)

        def example(_assigns) do
          "hello"
        end
      end

      assert Bodyless.__components__() == %{
               example: %{
                 kind: :def,
                 attrs: [
                   %{
                     line: __ENV__.line - 13,
                     name: :example,
                     opts: [],
                     desc: "",
                     required: true,
                     type: :any
                   }
                 ]
               }
             }
    end

    test "matches on struct types" do
      defmodule StructTypes do
        use Phoenix.Component

        attr :uri, URI, required: true
        attr :other, :any
        def example(%{other: 1}), do: "one"
        def example(%{other: 2}), do: "two"
      end

      assert_raise FunctionClauseError, fn -> StructTypes.example(%{other: 1, uri: :not_uri}) end
      assert_raise FunctionClauseError, fn -> StructTypes.example(%{other: 2, uri: :not_uri}) end

      uri = URI.parse("/relative")
      assert StructTypes.example(%{other: 1, uri: uri}) == "one"
      assert StructTypes.example(%{other: 2, uri: uri}) == "two"
    end

    test "provides defaults" do
      defmodule Defaults do
        use Phoenix.Component

        attr :one, :integer, default: 1
        attr :two, :integer, default: 2

        def add(assigns) do
          assigns = Phoenix.LiveView.assign(assigns, :foo, :bar)
          ~H[<%= @one + @two %>]
        end

        attr :nil_default, :string, default: nil
        def example(assigns), do: ~H[<%= inspect @nil_default %>]

        attr :value, :string
        def no_default(assigns), do: ~H[<%= inspect @value %>]
      end

      assert render(Defaults, :add, %{}) == "3"
      assert render(Defaults, :example, %{}) == "nil"
      assert render(Defaults, :no_default, %{value: 123}) == "123"

      assert_raise KeyError, ~r/:value not found/, fn ->
        render(Defaults, :no_default, %{})
      end
    end

    test "supports :desc for attr documentation" do
      defmodule Descriptions do
        use Phoenix.Component

        attr :single, :any, desc: "a single line description"

        attr :break, :any, desc: "a description
        with a line break"

        attr :multi, :any,
          desc: """
          a description
          that spans
          multiple lines
          """

        attr :sigil, :any,
          desc: ~S"""
          a description
          within a multi-line
          sigil
          """

        attr :no_doc, :any

        def func_with_attr_descs(assigns), do: ~H[]
      end

      assert Descriptions.__components__() == %{
               func_with_attr_descs: %{
                 kind: :def,
                 attrs: [
                   %{
                     line: 569,
                     name: :break,
                     opts: [],
                     required: false,
                     type: :any,
                     desc: "a description\n        with a line break"
                   },
                   %{
                     line: 572,
                     name: :multi,
                     opts: [],
                     required: false,
                     type: :any,
                     desc: "a description\nthat spans\nmultiple lines\n"
                   },
                   %{
                     line: 586,
                     name: :no_doc,
                     opts: [],
                     required: false,
                     type: :any,
                     desc: ""
                   },
                   %{
                     line: 579,
                     name: :sigil,
                     opts: [],
                     required: false,
                     type: :any,
                     desc: "a description\nwithin a multi-line\nsigil\n"
                   },
                   %{
                     line: 567,
                     name: :single,
                     opts: [],
                     required: false,
                     type: :any,
                     desc: "a single line description"
                   }
                 ]
               }
             }
    end

    test "raise if :desc is not a stirng" do
      msg = ~r/desc must be a string, got: :foo/

      assert_raise CompileError, msg, fn ->
        defmodule Phoenix.ComponentTest.AttrDescInvalidType do
          use Elixir.Phoenix.Component

          attr :invalid, :any, desc: :foo
          def func(assigns), do: ~H[]
        end
      end
    end

    test "raise if attr is not declared before the first function definition" do
      msg = ~r/attributes must be defined before the first function clause at line \d+/

      assert_raise CompileError, msg, fn ->
        defmodule Phoenix.ComponentTest.MultiClauseWrong do
          use Elixir.Phoenix.Component

          attr :foo, :any
          def func(assigns = %{foo: _}), do: ~H[]
          def func(assigns = %{bar: _}), do: ~H[]

          attr :bar, :any
          def func(assigns = %{baz: _}), do: ~H[]
        end
      end
    end

    test "raise if attr is declared on an invalid function" do
      msg =
        ~r/cannot declare attributes for function func\/2\. Components must be functions with arity 1/

      assert_raise CompileError, msg, fn ->
        defmodule Phoenix.ComponentTest.AttrOnInvalidFunction do
          use Elixir.Phoenix.Component

          attr :foo, :any
          def func(a, b), do: a + b
        end
      end
    end

    test "raise if attr is declared without a related function" do
      msg = ~r/cannot define attributes without a related function component/

      assert_raise CompileError, msg, fn ->
        defmodule Phoenix.ComponentTest.AttrOnInvalidFunction do
          use Elixir.Phoenix.Component

          def func(assigns = %{baz: _}), do: ~H[]

          attr :foo, :any
        end
      end
    end

    test "raise if attr type is not supported" do
      assert_raise CompileError, ~r/invalid type :not_a_type for attr :foo/, fn ->
        defmodule Phoenix.ComponentTest.AttrTypeNotSupported do
          use Elixir.Phoenix.Component

          attr :foo, :not_a_type
          def func(assigns), do: ~H[]
        end
      end
    end

    test "raise if attr option is not supported" do
      assert_raise CompileError, ~r"invalid option :not_an_opt for attr :foo", fn ->
        defmodule Phoenix.ComponentTest.AttrOptionNotSupported do
          use Elixir.Phoenix.Component

          attr :foo, :any, not_an_opt: true
          def func(assigns), do: ~H[]
        end
      end
    end

    test "raise if attr is duplicated" do
      assert_raise CompileError, ~r"a duplicate attribute with name :foo already exists", fn ->
        defmodule Phoenix.ComponentTest.AttrDup do
          use Elixir.Phoenix.Component

          attr :foo, :any, required: true
          attr :foo, :string
          def func(assigns), do: ~H[]
        end
      end
    end

    test "raise on more than one :global attr" do
      msg = ~r"cannot define global attribute :rest2 because one is already defined under :rest"

      assert_raise CompileError, msg, fn ->
        defmodule Phoenix.ComponentTest.MultiGlobal do
          use Elixir.Phoenix.Component

          attr :rest, :global
          attr :rest2, :global
          def func(assigns), do: ~H[]
        end
      end
    end

    test "raise if global provides :required" do
      msg = ~r/global attributes do not support the :required option/

      assert_raise CompileError, msg, fn ->
        defmodule Phoenix.ComponentTest.GlobalOpts do
          use Elixir.Phoenix.Component

          attr :rest, :global, required: true
          def func(assigns), do: ~H[<%= @rest %>]
        end
      end
    end

    test "merges globals" do
      assert render(FunctionComponentWithAttrs, :with_global, %{}) ==
               "<button id=\"container\" aria-hidden=\"true\" class=\"btn\"></button>"
    end

    test "merges globals with defaults" do
      assigns = %{id: "btn", style: "display: none;"}

      assert render(FunctionComponentWithAttrs, :button_with_defaults, assigns) ==
               "<button class=\"primary\" id=\"btn\" style=\"display: none;\"></button>"

      assert render(FunctionComponentWithAttrs, :button_with_defaults, %{class: "hidden"}) ==
               "<button class=\"hidden\"></button>"

      # caller passes no globals
      assert render(FunctionComponentWithAttrs, :button_with_defaults, %{}) ==
               "<button class=\"primary\"></button>"
    end

    defp lookup(_key \\ :one)

    for {k, v} <- [one: 1, two: 2, three: 3] do
      defp lookup(unquote(k)), do: unquote(v)
    end

    test "does not change Elixir semantics" do
      assert lookup() == 1
      assert lookup(:two) == 2
      assert lookup(:three) == 3
    end
  end
end
