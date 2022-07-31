defmodule Phoenix.ComponentTest do
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
             <.hello name="WORLD" />
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

    defp wrapper(assigns) do
      ~H"""
      <div><%= render_slot(@inner_block) %></div>
      """
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

    test "with :let inside @inner_block" do
      assigns = %{foo: 1, bar: 2, __changed__: %{foo: true}}

      assert eval(~H"""
             <.wrapper>
               <%= @foo %>
               <.inner_changed foo={@bar} :let={var}>
                 <%= var %>
               </.inner_changed>
             </.wrapper>
             """) == [[["1", nil]]]
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
                 slots: []
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
                 slots: []
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
                 slots: []
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
                 slots: []
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
                 slots: []
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
                 slots: %{},
                 attrs: %{id: {_, _, _, _}},
                 component: {Phoenix.ComponentTest.FunctionComponentWithAttrs, :button},
                 file: ^file,
                 line: ^with_global_line,
                 root: false
               },
               %{
                 component: {FunctionComponentWithAttrs, :func1},
                 slots: %{},
                 attrs: %{id: {_, _, :lit, "1"}},
                 file: ^file,
                 line: ^call_1_line
               },
               %{
                 component: {FunctionComponentWithAttrs, :func1},
                 slots: %{},
                 attrs: %{id: {_, _, :lit, "2"}, email: {_, _, :lit, true}}
               },
               %{
                 slots: %{},
                 attrs: %{id: {_, _, :lit, "3"}},
                 component: {RemoteFunctionComponentWithAttrs, :remote},
                 file: ^file,
                 line: ^call_3_line
               },
               %{
                 slots: %{},
                 attrs: %{id: {_, _, :lit, "4"}},
                 component: {RemoteFunctionComponentWithAttrs, :remote}
               },
               %{
                 slots: %{},
                 attrs: %{id: {_, _, :lit, "5"}},
                 component: {RemoteFunctionComponentWithAttrs, :remote},
                 root: false
               },
               %{
                 slots: %{},
                 attrs: %{id: {_, _, :lit, "6"}},
                 component: {RemoteFunctionComponentWithAttrs, :remote},
                 root: true
               }
             ] = FunctionComponentWithAttrs.__components_calls__()
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

      def fun_with_slot_attr_default_line, do: __ENV__.line + 7

      slot :named do
        attr :attr_with_default, :any, default: "a default value"
      end

      def fun_with_slot_attr_default(assigns) do
        ~H"""
        <%= for named <- @named do %>
          <%= named.attr_with_default %>
        <% end %>
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
                     required: false
                   }
                 ]
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
                     required: false
                   },
                   %{
                     doc: nil,
                     line: FunctionComponentWithSlots.fun_with_named_slots_line() - 2,
                     name: :header,
                     opts: [],
                     required: false
                   }
                 ]
               },
               fun_with_slot_attrs: %{
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
                 kind: :def,
                 slots: [
                   %{
                     doc: nil,
                     line: FunctionComponentWithSlots.fun_with_slot_attrs_line() - 4,
                     name: :slot,
                     opts: [],
                     required: true
                   }
                 ]
               },
               table: %{
                 attrs: [
                   %{
                     doc: nil,
                     line: FunctionComponentWithSlots.table_line() - 5,
                     name: :label,
                     opts: [],
                     required: false,
                     slot: :col,
                     type: :string
                   },
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
                     required: false
                   }
                 ]
               },
               fun_with_slot_attr_default: %{
                 attrs: [
                   %{
                     doc: nil,
                     line: FunctionComponentWithSlots.fun_with_slot_attr_default_line() - 4,
                     name: :attr_with_default,
                     opts: [default: "a default value"],
                     required: false,
                     slot: :named,
                     type: :any
                   }
                 ],
                 kind: :def,
                 slots: [
                   %{
                     doc: nil,
                     line: FunctionComponentWithSlots.fun_with_slot_attr_default_line() - 5,
                     name: :named,
                     opts: [],
                     required: false
                   }
                 ]
               }
             }
    end

    test "stores component calls with slots" do
      file = __ENV__.file

      assert [
               %{
                 attrs: %{},
                 component: {Phoenix.ComponentTest.FunctionComponentWithSlots, :fun_with_slot},
                 file: ^file,
                 line: 592,
                 root: false,
                 slots: %{inner_block: [%{inner_block: {594, 9, :expr, _}}]}
               },
               %{
                 attrs: %{},
                 component:
                   {Phoenix.ComponentTest.FunctionComponentWithSlots, :fun_with_named_slots},
                 file: ^file,
                 line: 596,
                 root: false,
                 slots: %{
                   footer: [%{inner_block: {603, 11, :expr, _}}],
                   header: [%{inner_block: {597, 11, :expr, _}}],
                   inner_block: [%{inner_block: {606, 9, :expr, _}}]
                 }
               },
               %{
                 attrs: %{},
                 component:
                   {Phoenix.ComponentTest.FunctionComponentWithSlots, :fun_with_slot_attrs},
                 file: ^file,
                 line: 608,
                 root: false,
                 slots: %{
                   inner_block: [%{inner_block: {610, 9, :expr, _}}],
                   slot: [%{attr: {609, 11, :lit, "1"}, inner_block: {609, 11, :lit, nil}}]
                 }
               },
               %{
                 attrs: %{rows: {612, 17, _kind, _value}},
                 component: {Phoenix.ComponentTest.FunctionComponentWithSlots, :table},
                 file: ^file,
                 line: 612,
                 root: false,
                 slots: %{
                   col: [
                     %{inner_block: {613, 11, :expr, _}, label: {613, 11, :expr, _}},
                     %{inner_block: {617, 11, :expr, _}, label: {617, 11, :lit, "Address"}}
                   ],
                   inner_block: [%{inner_block: {620, 9, :expr, _}}]
                 }
               }
             ] = FunctionComponentWithSlots.__components_calls__()
    end

    test "renders slot attr defaults" do
      assigns = %{}

      rendered = ~H"""
      <FunctionComponentWithSlots.fun_with_slot_attr_default>
        <:named />
      </FunctionComponentWithSlots.fun_with_slot_attr_default>
      """

      assert rendered_to_string(rendered) =~ "a default value"

      rendered = ~H"""
      <FunctionComponentWithSlots.fun_with_slot_attr_default>
        <:named attr_with_default="some other value" />
      </FunctionComponentWithSlots.fun_with_slot_attr_default>
      """

      assert rendered_to_string(rendered) =~ "some other value"
    end

    test "does not generate __components_calls__ if there's no call" do
      refute function_exported?(RemoteFunctionComponentWithAttrs, :__components_calls__, 0)
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
                 slots: []
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
                     required: false
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

      assert_raise KeyError, ~r":value not found", fn ->
        render(Defaults, :no_default, %{})
      end
    end

    test "supports :doc for attr documentation" do
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
                 slots: []
               },
               func_with_slot_docs: %{
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
                 kind: :def,
                 slots: [
                   %{doc: "a named slot", line: line + 25, name: :slot, opts: [], required: false}
                 ]
               }
             }
    end

    test "injects attr docs to function component @doc string" do
      {_, _, :elixir, "text/markdown", _, _, docs} =
        Code.fetch_docs(Phoenix.LiveViewTest.FunctionComponentWithAttrs)

      components = %{
        fun_attr_any: "## Attributes\n\n* `attr` (`:any`)\n",
        fun_attr_string: "## Attributes\n\n* `attr` (`:string`)\n",
        fun_attr_atom: "## Attributes\n\n* `attr` (`:atom`)\n",
        fun_attr_boolean: "## Attributes\n\n* `attr` (`:boolean`)\n",
        fun_attr_integer: "## Attributes\n\n* `attr` (`:integer`)\n",
        fun_attr_float: "## Attributes\n\n* `attr` (`:float`)\n",
        fun_attr_list: "## Attributes\n\n* `attr` (`:list`)\n",
        fun_attr_global: "## Attributes\n\n* `attr` (`:global`)\n",
        fun_attr_struct:
          "## Attributes\n\n* `attr` (`Phoenix.LiveViewTest.FunctionComponentWithAttrs.Struct`)\n",
        fun_attr_required: "## Attributes\n\n* `attr` (`:any`) (required)\n",
        fun_attr_default: "## Attributes\n\n* `attr` (`:any`) - Defaults to `%{}`.\n",
        fun_doc_false: :hidden,
        fun_doc_injection: "fun docs\n\n## Attributes\n\n* `attr` (`:any`)\n\nfun docs\n",
        fun_multiple_attr: "## Attributes\n\n* `attr1` (`:any`)\n* `attr2` (`:any`)\n",
        fun_with_attr_doc: "## Attributes\n\n* `attr` (`:any`) - attr docs\n",
        fun_with_hidden_attr: "## Attributes\n\n* `attr1` (`:any`)\n",
        fun_with_doc: "fun docs\n## Attributes\n\n* `attr` (`:any`)\n",
        fun_slot: "## Slots\n\n* `inner_block`\n",
        fun_slot_doc: "## Slots\n\n* `inner_block` - slot docs\n",
        fun_slot_required: "## Slots\n\n* `inner_block` (required)\n",
        fun_slot_with_attrs:
          "## Slots\n\n* `named` (required) - a named slot. Accepts attributes: \n\t* `attr1` (`:any`) (required) - a slot attr doc\n\t* `attr2` (`:any`) - a slot attr doc. Defaults to `\"some default\"`.\n"
      }

      for {{_, fun, _}, _, _, %{"en" => doc}, _} <- docs do
        assert components[fun] == doc
      end
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

    test "does not raise if multiple slots with different names share the same attr names" do
      mod = fn ->
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

      assert mod.()
    end

    test "raise if an unknown expression is encountered in a slot block" do
      msg =
        ~r"unexpected expression encountered in slot :named, got: foobar\(\). The code given to slot/2 can only contain calls to attr/3 and Elixir comments."

      assert_raise CompileError, msg, fn ->
        defmodule Phoenix.ComponentTest.UnexpectedExpressionInSlotBlock do
          use Elixir.Phoenix.Component

          slot :named do
            foobar()
          end

          def func(assigns), do: ~H[]
        end
      end
    end

    test "raise if an unknown literal is encountered in a slot block" do
      msg =
        ~r"unexpected literal encountered in slot :named, got: :ok. The code given to slot/2 can only contain calls to attr/3 and Elixir comments."

      assert_raise CompileError, msg, fn ->
        defmodule Phoenix.ComponentTest.UnexpectedLiteralInSlotBlock2 do
          use Elixir.Phoenix.Component

          slot :named do
            :ok
          end

          def func(assigns), do: ~H[]
        end
      end
    end

    test "does not raise if code comments are in a slot block" do
      mod = fn ->
        defmodule CodeCommentsInSlotBlock do
          use Phoenix.Component

          slot :named do
            # a comment
            attr :foo, :any
            # another comment
            attr :bar, :any
          end

          def func(assigns), do: ~H[]
        end
      end

      assert mod.()
    end

    test "raise if slot with name :inner_block has slot attrs" do
      msg = ~r"cannot define attributes for the slot :inner_block"

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
      msg = ~r"global attributes do not support the :required option"

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
  end
end
