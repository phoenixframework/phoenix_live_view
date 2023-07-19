defmodule Phoenix.ComponentDeclarativeAssignsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
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
    assert Phoenix.Component.Declarative.__global__?("id")
    refute Phoenix.Component.Declarative.__global__?("idnope")
    refute Phoenix.Component.Declarative.__global__?("not-global")

    # prefixes
    assert Phoenix.Component.Declarative.__global__?("aria-label")
    assert Phoenix.Component.Declarative.__global__?("data-whatever")
    assert Phoenix.Component.Declarative.__global__?("phx-click")
  end

  defmodule RemoteFunctionComponentWithAttrs do
    use Phoenix.Component

    attr :id, :any, required: true
    slot :inner_block
    def remote(assigns), do: ~H[]
  end

  defmodule FunctionComponentWithAttrs do
    use Phoenix.Component
    import RemoteFunctionComponentWithAttrs
    alias RemoteFunctionComponentWithAttrs, as: Remote

    def func1_line, do: __ENV__.line
    attr :id, :any, required: true
    attr :email, :string, default: nil
    slot :inner_block
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

    def button_with_values_line, do: __ENV__.line
    attr :text, :string, values: ["Save", "Cancel"]
    def button_with_values(assigns), do: ~H[<button><%= @text %></button>]

    def button_with_values_and_default_1_line, do: __ENV__.line
    attr :text, :string, values: ["Save", "Cancel"], default: "Save"
    def button_with_values_and_default_1(assigns), do: ~H[<button><%= @text %></button>]

    def button_with_values_and_default_2_line, do: __ENV__.line
    attr :text, :string, default: "Save", values: ["Save", "Cancel"]
    def button_with_values_and_default_2(assigns), do: ~H[<button><%= @text %></button>]

    def button_with_examples_line, do: __ENV__.line
    attr :text, :string, examples: ["Save", "Cancel"]
    def button_with_examples(assigns), do: ~H[<button><%= @text %></button>]

    def render_line, do: __ENV__.line

    def render(assigns) do
      ~H"""
      <!-- local -->
      <.func1 id="1"/>
      <!-- local with inner content -->
      <.func1 id="2" email="foo@bar">CONTENT</.func1>
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

  test "stores attributes definitions" do
    func1_line = FunctionComponentWithAttrs.func1_line()
    func2_line = FunctionComponentWithAttrs.func2_line()
    with_global_line = FunctionComponentWithAttrs.with_global_line()
    button_with_defaults_line = FunctionComponentWithAttrs.button_with_defaults_line()
    button_with_values_line = FunctionComponentWithAttrs.button_with_values_line()

    button_with_values_and_default_1_line =
      FunctionComponentWithAttrs.button_with_values_and_default_1_line()

    button_with_values_and_default_2_line =
      FunctionComponentWithAttrs.button_with_values_and_default_2_line()

    button_with_examples_line = FunctionComponentWithAttrs.button_with_examples_line()

    assert FunctionComponentWithAttrs.__components__() == %{
             func1: %{
               kind: :def,
               attrs: [
                 %{
                   name: :email,
                   type: :string,
                   opts: [default: nil],
                   required: false,
                   doc: nil,
                   slot: nil,
                   line: func1_line + 2
                 },
                 %{
                   name: :id,
                   type: :any,
                   opts: [],
                   required: true,
                   doc: nil,
                   slot: nil,
                   line: func1_line + 1
                 }
               ],
               slots: [
                 %{
                   attrs: [],
                   doc: nil,
                   line: func1_line + 3,
                   name: :inner_block,
                   opts: [],
                   required: false
                 }
               ],
               line: func1_line + 4,
             },
             func2: %{
               kind: :def,
               attrs: [
                 %{
                   name: :age,
                   type: :integer,
                   opts: [default: 0],
                   required: false,
                   doc: nil,
                   slot: nil,
                   line: func2_line + 2
                 },
                 %{
                   name: :name,
                   type: :any,
                   opts: [],
                   required: true,
                   doc: nil,
                   slot: nil,
                   line: func2_line + 1
                 }
               ],
               slots: [],
               line: func2_line + 3
             },
             with_global: %{
               kind: :def,
               attrs: [
                 %{
                   line: with_global_line + 1,
                   name: :id,
                   opts: [default: "container"],
                   required: false,
                   doc: nil,
                   slot: nil,
                   type: :string
                 }
               ],
               slots: [],
               line: with_global_line + 2
             },
             button_with_defaults: %{
               kind: :def,
               attrs: [
                 %{
                   line: button_with_defaults_line + 1,
                   name: :rest,
                   opts: [default: %{class: "primary"}],
                   required: false,
                   doc: nil,
                   slot: nil,
                   type: :global
                 }
               ],
               slots: [],
               line: button_with_defaults_line + 2
             },
             button: %{
               kind: :def,
               attrs: [
                 %{
                   line: with_global_line + 4,
                   name: :id,
                   opts: [],
                   required: true,
                   doc: nil,
                   slot: nil,
                   type: :string
                 },
                 %{
                   line: with_global_line + 5,
                   name: :rest,
                   opts: [],
                   required: false,
                   doc: nil,
                   slot: nil,
                   type: :global
                 }
               ],
               slots: [],
               line: with_global_line + 6,
             },
             button_with_values: %{
               kind: :def,
               attrs: [
                 %{
                   line: button_with_values_line + 1,
                   name: :text,
                   opts: [values: ["Save", "Cancel"]],
                   required: false,
                   doc: nil,
                   slot: nil,
                   type: :string
                 }
               ],
               slots: [],
               line: button_with_values_line + 2,
             },
             button_with_values_and_default_1: %{
               kind: :def,
               attrs: [
                 %{
                   line: button_with_values_and_default_1_line + 1,
                   name: :text,
                   opts: [values: ["Save", "Cancel"], default: "Save"],
                   required: false,
                   doc: nil,
                   slot: nil,
                   type: :string
                 }
               ],
               slots: [],
               line: button_with_values_and_default_1_line + 2,
             },
             button_with_values_and_default_2: %{
               kind: :def,
               attrs: [
                 %{
                   line: button_with_values_and_default_2_line + 1,
                   name: :text,
                   opts: [default: "Save", values: ["Save", "Cancel"]],
                   required: false,
                   doc: nil,
                   slot: nil,
                   type: :string
                 }
               ],
               slots: [],
               line: button_with_values_and_default_2_line + 2,
             },
             button_with_examples: %{
               kind: :def,
               attrs: [
                 %{
                   line: button_with_examples_line + 1,
                   name: :text,
                   opts: [examples: ["Save", "Cancel"]],
                   required: false,
                   doc: nil,
                   slot: nil,
                   type: :string
                 }
               ],
               slots: [],
               line: button_with_examples_line + 2
             }
           }
  end

  defmodule FunctionComponentWithSlots do
    use Phoenix.Component

    def fun_with_slot_line, do: __ENV__.line + 3

    slot :inner_block
    def fun_with_slot(assigns), do: ~H[]

    def fun_with_named_slots_line, do: __ENV__.line + 4

    slot :header
    slot :footer
    def fun_with_named_slots(assigns), do: ~H[]

    def fun_with_slot_attrs_line, do: __ENV__.line + 6

    slot :slot, required: true do
      attr :attr, :any
    end

    def fun_with_slot_attrs(assigns), do: ~H[]

    def table_line, do: __ENV__.line + 8

    slot :col do
      attr :label, :string
    end

    attr :rows, :list

    def table(assigns) do
      ~H"""
      <table>
        <tr>
          <%= for col <- @col do %>
            <th><%= col.label %></th>
          <% end %>
        </tr>
        <%= for row <- @rows do %>
          <tr>
            <%= for col <- @col do %>
              <td><%= render_slot(col, row) %></td>
            <% end %>
          </tr>
        <% end %>
      </table>
      """
    end

    def render_line, do: __ENV__.line + 2

    def render(assigns) do
      ~H"""
      <.fun_with_slot>
        Hello, World
      </.fun_with_slot>

      <.fun_with_named_slots>
        <:header>
          This is a header.
        </:header>

        Hello, World

        <:footer>
          This is a footer.
        </:footer>
      </.fun_with_named_slots>

      <.fun_with_slot_attrs>
        <:slot attr="1" />
      </.fun_with_slot_attrs>

      <.table rows={@users}>
        <:col :let={user} label={@name}>
          <%= user.name %>
        </:col>

        <:col :let={user} label="Address">
          <%= user.address %>
        </:col>
      </.table>
      """
    end
  end

  test "stores slots definitions" do
    assert FunctionComponentWithSlots.__components__() == %{
             fun_with_slot: %{
               attrs: [],
               kind: :def,
               slots: [
                 %{
                   doc: nil,
                   line: FunctionComponentWithSlots.fun_with_slot_line() - 1,
                   name: :inner_block,
                   opts: [],
                   attrs: [],
                   required: false
                 }
               ],
               line: FunctionComponentWithSlots.fun_with_slot_line(),
             },
             fun_with_named_slots: %{
               attrs: [],
               kind: :def,
               slots: [
                 %{
                   doc: nil,
                   line: FunctionComponentWithSlots.fun_with_named_slots_line() - 1,
                   name: :footer,
                   opts: [],
                   attrs: [],
                   required: false
                 },
                 %{
                   doc: nil,
                   line: FunctionComponentWithSlots.fun_with_named_slots_line() - 2,
                   name: :header,
                   opts: [],
                   attrs: [],
                   required: false
                 }
               ],
               line: FunctionComponentWithSlots.fun_with_named_slots_line()
             },
             fun_with_slot_attrs: %{
               attrs: [],
               kind: :def,
               slots: [
                 %{
                   doc: nil,
                   line: FunctionComponentWithSlots.fun_with_slot_attrs_line() - 4,
                   name: :slot,
                   opts: [],
                   attrs: [
                     %{
                       doc: nil,
                       line: FunctionComponentWithSlots.fun_with_slot_attrs_line() - 3,
                       name: :attr,
                       opts: [],
                       required: false,
                       slot: :slot,
                       type: :any
                     }
                   ],
                   required: true
                 }
               ],
               line: FunctionComponentWithSlots.fun_with_slot_attrs_line(),
             },
             table: %{
               attrs: [
                 %{
                   doc: nil,
                   line: FunctionComponentWithSlots.table_line() - 2,
                   name: :rows,
                   opts: [],
                   required: false,
                   slot: nil,
                   type: :list
                 }
               ],
               kind: :def,
               slots: [
                 %{
                   doc: nil,
                   line: FunctionComponentWithSlots.table_line() - 6,
                   name: :col,
                   opts: [],
                   attrs: [
                     %{
                       doc: nil,
                       line: FunctionComponentWithSlots.table_line() - 5,
                       name: :label,
                       opts: [],
                       required: false,
                       slot: :col,
                       type: :string
                     }
                   ],
                   required: false
                 }
               ],
               line: FunctionComponentWithSlots.table_line()
             }
           }
  end

  test "stores components for bodyless clauses" do
    defmodule Bodyless do
      use Phoenix.Component

      def example_line, do: __ENV__.line + 2

      attr :example, :any, required: true
      def example(assigns)

      def example(_assigns) do
        "hello"
      end

      def example2_line, do: __ENV__.line + 2

      slot :slot
      def example2(assigns)

      def example2(_assigns) do
        "world"
      end
    end

    assert Bodyless.__components__() == %{
             example: %{
               kind: :def,
               attrs: [
                 %{
                   line: Bodyless.example_line(),
                   name: :example,
                   opts: [],
                   doc: nil,
                   required: true,
                   type: :any,
                   slot: nil
                 }
               ],
               slots: [],
               line: Bodyless.example_line() + 1
             },
             example2: %{
               kind: :def,
               attrs: [],
               slots: [
                 %{
                   doc: nil,
                   line: Bodyless.example2_line(),
                   name: :slot,
                   opts: [],
                   attrs: [],
                   required: false
                 }
               ],
               line: Bodyless.example2_line() + 1,
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

  test "provides attr defaults" do
    defmodule AttrDefaults do
      use Phoenix.Component

      attr :one, :integer, default: 1
      attr :two, :integer, default: 2

      def add(assigns) do
        assigns = Phoenix.Component.assign(assigns, :foo, :bar)
        ~H[<%= @one + @two %>]
      end

      attr :nil_default, :string, default: nil
      def example(assigns), do: ~H[<%= inspect @nil_default %>]

      attr :value, :string
      def no_default(assigns), do: ~H[<%= inspect @value %>]

      attr :id, :any
      attr :errors, :list, default: []
      def assigned_with_same_default(assigns) do
        assign(assigns, errors: [])
      end
    end

    assert render(AttrDefaults, :add, %{}) == "3"
    assert render(AttrDefaults, :example, %{}) == "nil"
    assert render(AttrDefaults, :no_default, %{value: 123}) == "123"

    assert_raise KeyError, ~r":value not found", fn ->
      render(AttrDefaults, :no_default, %{})
    end

    assigns = AttrDefaults.assigned_with_same_default(%{__changed__: %{}})
    assert Phoenix.Component.changed?(assigns, :errors)

    assigns = AttrDefaults.assigned_with_same_default(%{__changed__: %{}, errors: []})
    refute Phoenix.Component.changed?(assigns, :errors)

    assigns = AttrDefaults.assigned_with_same_default(%{__changed__: %{errors: true}, errors: []})
    assert Phoenix.Component.changed?(assigns, :errors)
  end

  test "provides slot defaults" do
    defmodule SlotDefaults do
      use Phoenix.Component

      slot :inner_block
      def func(assigns), do: ~H[<%= render_slot(@inner_block) %>]

      slot :inner_block, required: true
      def func_required(assigns), do: ~H[<%= render_slot(@inner_block) %>]
    end

    assigns = %{}
    assert "" == rendered_to_string(~H[<SlotDefaults.func />])
    assert "hello" == rendered_to_string(~H[<SlotDefaults.func>hello</SlotDefaults.func>])
  end

  test "slots with rest" do
    defmodule SlotWithGlobal do
      use Phoenix.Component

      attr :rest, :global
      slot :inner_block, required: true
      slot :col, required: true

      def test(assigns) do
        ~H"""
        <div {@rest}>
          <%= render_slot(@inner_block) %>
          <%= for col <- @col do %><%= render_slot(col) %>,<% end %>
        </div>
        """
      end
    end

    assigns = %{}

    template = ~H"""
    <SlotWithGlobal.test class="my-class">
      block
      <:col>col1</:col>
      <:col>col2</:col>
    </SlotWithGlobal.test>
    """

    assert h2s(template) == ~s|<div class="my-class">\n  \n  block\n  \n  col1,col2,\n</div>|
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

  test "does not raise when there is a nested module" do
    mod = fn ->
      defmodule NestedModules do
        use Phoenix.Component

        defmodule Nested do
          def fun(arg), do: arg
        end
      end
    end

    assert mod.()
  end

  test "supports :doc for attr and slot documentation" do
    defmodule AttrDocs do
      use Phoenix.Component

      def attr_line, do: __ENV__.line
      attr :single, :any, doc: "a single line description"

      attr :break, :any, doc: "a description
        with a line break"

      attr :multi, :any,
        doc: """
        a description
        that spans
        multiple lines
        """

      attr :sigil, :any,
        doc: ~S"""
        a description
        within a multi-line
        sigil
        """

      attr :no_doc, :any

      @doc "my function component with attrs"
      def func_with_attr_docs(assigns), do: ~H[]

      slot :slot, doc: "a named slot" do
        attr :attr, :any, doc: "a slot attr"
      end

      def func_with_slot_docs(assigns), do: ~H[]
    end

    line = AttrDocs.attr_line()

    assert AttrDocs.__components__() == %{
             func_with_attr_docs: %{
               attrs: [
                 %{
                   line: line + 3,
                   doc: "a description\n        with a line break",
                   slot: nil,
                   name: :break,
                   opts: [],
                   required: false,
                   type: :any
                 },
                 %{
                   line: line + 6,
                   doc: "a description\nthat spans\nmultiple lines\n",
                   slot: nil,
                   name: :multi,
                   opts: [],
                   required: false,
                   type: :any
                 },
                 %{
                   line: line + 20,
                   doc: nil,
                   slot: nil,
                   name: :no_doc,
                   opts: [],
                   required: false,
                   type: :any
                 },
                 %{
                   line: line + 13,
                   doc: "a description\nwithin a multi-line\nsigil\n",
                   slot: nil,
                   name: :sigil,
                   opts: [],
                   required: false,
                   type: :any
                 },
                 %{
                   line: line + 1,
                   doc: "a single line description",
                   slot: nil,
                   name: :single,
                   opts: [],
                   required: false,
                   type: :any
                 }
               ],
               kind: :def,
               slots: [],
               line: line + 23,
             },
             func_with_slot_docs: %{
               attrs: [],
               kind: :def,
               slots: [
                 %{
                   doc: "a named slot",
                   line: line + 25,
                   name: :slot,
                   attrs: [
                     %{
                       doc: "a slot attr",
                       line: line + 26,
                       name: :attr,
                       opts: [],
                       required: false,
                       slot: :slot,
                       type: :any
                     }
                   ],
                   opts: [],
                   required: false
                 }
               ],
               line: line + 29,
             }
           }
  end

  test "inserts attr & slot docs into function component @doc string" do
    {_, _, :elixir, "text/markdown", _, _, docs} =
      Code.fetch_docs(Phoenix.LiveViewTest.FunctionComponentWithAttrs)

    components = %{
      fun_attr_any: """
      ## Attributes

      * `attr` (`:any`)
      """,
      fun_attr_string: """
      ## Attributes

      * `attr` (`:string`)
      """,
      fun_attr_atom: """
      ## Attributes

      * `attr` (`:atom`)
      """,
      fun_attr_boolean: """
      ## Attributes

      * `attr` (`:boolean`)
      """,
      fun_attr_integer: """
      ## Attributes

      * `attr` (`:integer`)
      """,
      fun_attr_float: """
      ## Attributes

      * `attr` (`:float`)
      """,
      fun_attr_map: """
      ## Attributes

      * `attr` (`:map`)
      """,
      fun_attr_list: """
      ## Attributes

      * `attr` (`:list`)
      """,
      fun_attr_global: """
      ## Attributes

      * Global attributes are accepted.
      """,
      fun_attr_struct: """
      ## Attributes

      * `attr` (`Phoenix.LiveViewTest.FunctionComponentWithAttrs.Struct`)
      """,
      fun_attr_required: """
      ## Attributes

      * `attr` (`:any`) (required)
      """,
      fun_attr_default: """
      ## Attributes

      * `attr` (`:any`) - Defaults to `%{}`.
      """,
      fun_doc_false: :hidden,
      fun_doc_injection: """
      fun docs

      ## Attributes

      * `attr` (`:any`)

      fun docs
      """,
      fun_multiple_attr: """
      ## Attributes

      * `attr1` (`:any`)
      * `attr2` (`:any`)
      """,
      fun_with_attr_doc: """
      ## Attributes

      * `attr` (`:any`) - attr docs.
      """,
      fun_with_attr_doc_period: """
      ## Attributes

      * `attr` (`:any`) - attr docs. Defaults to `\"foo\"`.
      """,
      fun_with_attr_doc_multiline: """
      ## Attributes

      * `attr` (`:any`) - attr docs with bullets:

          * foo
          * bar

        and that's it.

        Defaults to `"foo"`.
      """,
      fun_with_hidden_attr: """
      ## Attributes

      * `attr1` (`:any`)
      """,
      fun_with_doc: """
      fun docs
      ## Attributes

      * `attr` (`:any`)
      """,
      fun_slot: """
      ## Slots

      * `inner_block`
      """,
      fun_slot_doc: """
      ## Slots

      * `inner_block` - slot docs.
      """,
      fun_slot_required: """
      ## Slots

      * `inner_block` (required)
      """,
      fun_slot_with_attrs: """
      ## Slots

      * `named` (required) - a named slot. Accepts attributes:

        * `attr1` (`:any`) (required) - a slot attr doc.
        * `attr2` (`:any`) - a slot attr doc.
      """,
      fun_slot_no_doc_with_attrs: """
      ## Slots

      * `named` (required) - Accepts attributes:

        * `attr1` (`:any`) (required) - a slot attr doc.
        * `attr2` (`:any`) - a slot attr doc.
      """,
      fun_slot_doc_multiline_with_attrs: """
      ## Slots

      * `named` (required) - Important slot:

        * for a
        * for b

        Accepts attributes:

        * `attr1` (`:any`) (required) - a slot attr doc.
        * `attr2` (`:any`) - a slot attr doc.
      """,
      fun_slot_doc_with_attrs_multiline: """
      ## Slots

      * `named` (required) - Accepts attributes:

        * `attr1` (`:any`) (required) - attr docs with bullets:

            * foo
            * bar

          and that's it.

        * `attr2` (`:any`) - a slot attr doc.
      """,
      fun_attr_values_examples: """
      ## Attributes

      * `attr1` (`:atom`) - Must be one of `:foo`, `:bar`, or `:baz`.
      * `attr2` (`:atom`) - Examples include `:foo`, `:bar`, and `:baz`.
      * `attr3` (`:list`) - Must be one of `[60, 40]`.
      * `attr4` (`:list`) - Examples include `[60, 40]`.
      """
    }

    for {{_, fun, _}, _, _, %{"en" => doc}, _} <- docs do
      assert components[fun] == doc
    end
  end

  test "stores correct line number on AST" do
    module = Phoenix.LiveViewTest.FunctionComponentWithAttrs

    {^module, binary, _file} = :code.get_object_code(module)

    {:ok, {_, [{:abstract_code, {_vsn, abstract_code}}]}} =
      :beam_lib.chunks(binary, [:abstract_code])

    assert Enum.find_value(abstract_code, fn
             {:function, line, :identity, 1, _} -> line
             _ -> nil
           end) == 24

    assert Enum.find_value(abstract_code, fn
             {:function, line, :fun_doc_false, 1, _} -> line
             _ -> nil
           end) == 105
  end

  test "does not override signature of Elixir functions" do
    {:docs_v1, _, :elixir, "text/markdown", _, _, docs} =
      Code.fetch_docs(Phoenix.LiveViewTest.FunctionComponentWithAttrs)

    assert {{:function, :identity, 1}, _, ["identity(var)"], _, %{}} =
             List.keyfind(docs, {:function, :identity, 1}, 0)

    assert {{:function, :map_identity, 1}, _, ["map_identity(map)"], _, %{}} =
             List.keyfind(docs, {:function, :map_identity, 1}, 0)

    assert Phoenix.LiveViewTest.FunctionComponentWithAttrs.identity(:not_a_map) == :not_a_map
    assert Phoenix.LiveViewTest.FunctionComponentWithAttrs.identity(%{}) == %{}
  end

  test "raise if attr :doc is not a string" do
    msg = ~r"doc must be a string or false, got: :foo"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.AttrDocsInvalidType do
        use Elixir.Phoenix.Component

        attr :invalid, :any, doc: :foo
        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if slot :doc is not a string" do
    msg = ~r"doc must be a string or false, got: :foo"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.SlotDocsInvalidType do
        use Elixir.Phoenix.Component

        slot :invalid, doc: :foo
        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise on invalid attr/2 args" do
    assert_raise FunctionClauseError, fn ->
      defmodule Phoenix.ComponentTest.AttrMacroInvalidName do
        use Elixir.Phoenix.Component

        attr "not an atom", :any
        def func(assigns), do: ~H[]
      end
    end

    assert_raise FunctionClauseError, fn ->
      defmodule Phoenix.ComponentTest.AttrMacroInvalidOpts do
        use Elixir.Phoenix.Component

        attr :attr, :any, "not a list"
        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise on invalid slot/3 args" do
    assert_raise FunctionClauseError, fn ->
      defmodule Phoenix.ComponentTest.SlotMacroInvalidName do
        use Elixir.Phoenix.Component

        slot "not an atom"
        def func(assigns), do: ~H[]
      end
    end

    assert_raise FunctionClauseError, fn ->
      defmodule Phoenix.ComponentTest.SlotMacroInvalidOpts do
        use Elixir.Phoenix.Component

        slot :slot, "not a list"
        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if attr is declared between multiple function heads" do
    msg = ~r"attributes must be defined before the first function clause at line \d+"

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

  test "raise if slot is declared between multiple function heads" do
    msg = ~r"slots must be defined before the first function clause at line \d+"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.MultiClauseWrong do
        use Elixir.Phoenix.Component

        slot :inner_block
        def func(assigns = %{foo: _}), do: ~H[]
        def func(assigns = %{bar: _}), do: ~H[]

        slot :named
        def func(assigns = %{baz: _}), do: ~H[]
      end
    end
  end

  test "raise if attr is declared on an invalid function" do
    msg =
      ~r"cannot declare attributes for function func\/2\. Components must be functions with arity 1"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.AttrOnInvalidFunction do
        use Elixir.Phoenix.Component

        attr :foo, :any
        def func(a, b), do: a + b
      end
    end
  end

  test "raise if slot is declared on an invalid function" do
    msg =
      ~r"cannot declare slots for function func\/2\. Components must be functions with arity 1"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.SlotOnInvalidFunction do
        use Elixir.Phoenix.Component

        slot :inner_block
        def func(a, b), do: a + b
      end
    end
  end

  test "raise if attr is declared without a related function" do
    msg = ~r"cannot define attributes without a related function component"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.AttrOnInvalidFunction do
        use Elixir.Phoenix.Component

        def func(assigns = %{baz: _}), do: ~H[]

        attr :foo, :any
      end
    end
  end

  test "raise if slot is declared without a related function" do
    msg = ~r"cannot define slots without a related function component"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.SlotOnInvalidFunction do
        use Elixir.Phoenix.Component

        def func(assigns = %{baz: _}), do: ~H[]

        slot :inner_block
      end
    end
  end

  test "raise if attr type is not supported" do
    msg = ~r"invalid type :not_a_type for attr :foo"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.AttrTypeNotSupported do
        use Elixir.Phoenix.Component

        attr :foo, :not_a_type
        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if slot attr type is not supported" do
    msg = ~r"invalid type :not_a_type for attr :foo in slot :named"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.SlotAttrTypeNotSupported do
        use Elixir.Phoenix.Component

        slot :named do
          attr :foo, :not_a_type
        end

        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if slot attr type is :global" do
    msg = ~r"cannot define :global slot attributes"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.SlotAttrGlobalNotSupported do
        use Elixir.Phoenix.Component

        slot :named do
          attr :foo, :global
        end

        def func(assigns), do: ~H[]
      end
    end
  end

  test "reraise exceptions in slot/3 blocks" do
    assert_raise RuntimeError, "boom!", fn ->
      defmodule Phoenix.ComponentTest.SlotExceptionRaised do
        use Elixir.Phoenix.Component

        slot :named do
          raise "boom!"
        end

        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if attr :values does not match the type" do
    msg = ~r"expected the values for attr :foo to be a :string, got: :not_a_string"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.AttrValueTypeMismatch do
        use Elixir.Phoenix.Component

        attr :foo, :string, values: ["a string", :not_a_string]

        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if attr :example does not match the type" do
    msg = ~r"expected the examples for attr :foo to be a :string, got: :not_a_string"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.AttrExampleTypeMismatch do
        use Elixir.Phoenix.Component

        attr :foo, :string, examples: ["a string", :not_a_string]

        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if attr :values is not a enum" do
    msg = ~r":values must be a non-empty enumerable, got: :ok"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.AttrsValuesNotAList do
        use Elixir.Phoenix.Component

        attr :foo, :string, values: :ok

        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if attr :examples is not a list" do
    msg = ~r":examples must be a non-empty list, got: :ok"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.AttrsExamplesNotAList do
        use Elixir.Phoenix.Component

        attr :foo, :string, examples: :ok

        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if attr :values is an empty enum" do
    msg = ~r":values must be a non-empty enumerable, got: \[\]"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.AttrsValuesEmptyList do
        use Elixir.Phoenix.Component

        attr :foo, :string, values: []

        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if attr :examples is an empty list" do
    msg = ~r":examples must be a non-empty list, got: \[\]"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.AttrsExamplesEmptyList do
        use Elixir.Phoenix.Component

        attr :foo, :string, examples: []

        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if attr has both :values and :examples" do
    msg = ~r"only one of :values or :examples must be given"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.AttrDefaultTypeMismatch do
        use Elixir.Phoenix.Component

        attr :foo, :string, values: ["a string"], examples: ["a string"]

        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if attr :default does not match the type" do
    msg = ~r"expected the default value for attr :foo to be a :string, got: :not_a_string"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.AttrDefaultTypeMismatch do
        use Elixir.Phoenix.Component

        attr :foo, :string, default: :not_a_string

        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if attr :default is not one of :values" do
    msg =
      ~r'expected the default value for attr :foo to be one of \["foo", "bar", "baz"\], got: "boom"'

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.AttrDefaultValuesMismatch do
        use Elixir.Phoenix.Component

        attr :foo, :string, default: "boom", values: ["foo", "bar", "baz"]

        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if attr :default is not in range" do
    msg = ~r'expected the default value for attr :foo to be one of 1\.\.10, got: 11'

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.AttrDefaultValuesMismatch do
        use Elixir.Phoenix.Component

        attr :foo, :integer, default: 11, values: 1..10
        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if slot attr has :default" do
    msg = ~r" invalid option :default for attr :foo in slot :named"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.SlotAttrDefault do
        use Elixir.Phoenix.Component

        slot :named do
          attr :foo, :any, default: :whatever
        end

        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if attr option is not supported" do
    msg = ~r"invalid option :not_an_opt for attr :foo"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.AttrOptionNotSupported do
        use Elixir.Phoenix.Component

        attr :foo, :any, not_an_opt: true
        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if slot attr option is not supported" do
    msg = ~r"invalid option :not_an_opt for attr :foo in slot :named"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.SlotAttrOptionNotSupported do
        use Elixir.Phoenix.Component

        slot :named do
          attr :foo, :any, not_an_opt: true
        end

        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if attr is duplicated" do
    msg = ~r"a duplicate attribute with name :foo already exists"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.AttrDup do
        use Elixir.Phoenix.Component

        attr :foo, :any, required: true
        attr :foo, :string
        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if slot is duplicated" do
    msg = ~r"a duplicate slot with name :foo already exists"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.SlotDup do
        use Elixir.Phoenix.Component

        slot :foo
        slot :foo
        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if slot attr is duplicated" do
    msg = ~r"a duplicate attribute with name :foo in slot :named already exists"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.SlotAttrDup do
        use Elixir.Phoenix.Component

        slot :named do
          attr :foo, :any, required: true
          attr :foo, :string
        end

        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if a slot and attr share the same name" do
    msg = ~r"cannot define a slot with name :named, as an attribute with that name already exists"

    assert_raise CompileError, msg, fn ->
      defmodule SlotAttrNameConflict do
        use Elixir.Phoenix.Component

        slot :named
        attr :named, :any

        def func(assigns), do: ~H[]
      end
    end

    assert_raise CompileError, msg, fn ->
      defmodule SlotAttrNameConflict do
        use Elixir.Phoenix.Component

        attr :named, :any
        slot :named

        def func(assigns), do: ~H[]
      end
    end
  end

  test "does not raise if multiple slots with different names share the same attr names" do
    defmodule MultipleSlotAttrs do
      use Phoenix.Component

      slot :foo do
        attr :attr, :any
      end

      slot :bar do
        attr :attr, :any
      end

      def func(assigns), do: ~H[]
    end
  end

  test "raise if slot with name :inner_block has slot attrs" do
    msg = ~r"cannot define attributes in a slot with name :inner_block"

    assert_raise CompileError, msg, fn ->
      defmodule AttrsInDefaultSlot do
        use Elixir.Phoenix.Component

        slot :inner_block do
          attr :attr, :any
        end

        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise if :inner_block is attribute" do
    msg = ~r"cannot define attribute called :inner_block. Maybe you wanted to use `slot` instead?"

    assert_raise CompileError, msg, fn ->
      defmodule InnerSlotAttr do
        use Elixir.Phoenix.Component

        attr :inner_block, :string
        def func(assigns), do: ~H[]
      end
    end
  end

  test "raise on more than one :global attr" do
    msg = ~r"cannot define :global attribute :rest2 because one is already defined as :rest"

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
    msg = ~r"global attributes do not support the :required option"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.GlobalRequiredOpts do
        use Elixir.Phoenix.Component

        attr :rest, :global, required: true
        def func(assigns), do: ~H[<%= @rest %>]
      end
    end
  end

  test "raise if global provides :values" do
    msg = ~r"global attributes do not support the :values option"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.GlobalValueOpts do
        use Elixir.Phoenix.Component

        attr :rest, :global, values: ["placeholder", "rel"]
        def func(assigns), do: ~H[<%= @rest %>]
      end
    end
  end

  test "raise if global provides :examples" do
    msg = ~r"global attributes do not support the :examples option"

    assert_raise CompileError, msg, fn ->
      defmodule Phoenix.ComponentTest.GlobalExampleOpts do
        use Elixir.Phoenix.Component

        attr :rest, :global, examples: ["placeholder", "rel"]
        def func(assigns), do: ~H[<%= @rest %>]
      end
    end
  end
end
