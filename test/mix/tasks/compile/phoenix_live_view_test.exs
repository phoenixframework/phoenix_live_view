defmodule Mix.Tasks.Compile.PhoenixLiveViewTest do
  use ExUnit.Case, async: true
  use Phoenix.Component

  alias Mix.Task.Compiler.Diagnostic
  import ExUnit.CaptureIO

  describe "validations" do
    defmodule RequiredAttrs do
      use Phoenix.Component

      attr :name, :any, required: true
      attr :phone, :any
      attr :email, :any, required: true

      def func(assigns), do: ~H[]

      def line, do: __ENV__.line + 4

      def render(assigns) do
        ~H"""
        <.func/>
        """
      end
    end

    test "validate required attributes" do
      line = get_line(RequiredAttrs)
      diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([RequiredAttrs])

      assert diagnostics == [
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 file: __ENV__.file,
                 message: """
                 missing required attribute "email" for component \
                 Mix.Tasks.Compile.PhoenixLiveViewTest.RequiredAttrs.func/1\
                 """,
                 position: line,
                 severity: :warning
               },
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 file: __ENV__.file,
                 message: """
                 missing required attribute "name" for component \
                 Mix.Tasks.Compile.PhoenixLiveViewTest.RequiredAttrs.func/1\
                 """,
                 position: line,
                 severity: :warning
               }
             ]
    end

    defmodule RequiredAttrsWithDynamic do
      use Phoenix.Component

      attr :name, :any, required: true

      def func(assigns), do: ~H[]

      def render(assigns) do
        ~H"""
        <.func {[foo: 1]}/>
        """
      end
    end

    test "do not validate required attributes when passing dynamic attr" do
      diagnostics =
        Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([RequiredAttrsWithDynamic])

      assert diagnostics == []
    end

    defmodule UndefinedAttrs do
      use Phoenix.Component

      attr :class, :any
      def func(assigns), do: ~H[]

      def line, do: __ENV__.line + 4

      def render(assigns) do
        ~H"""
        <.func width="btn" size={@size} phx-no-format />
        """
      end
    end

    test "validate undefined attributes" do
      line = get_line(UndefinedAttrs)
      diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([UndefinedAttrs])

      assert diagnostics == [
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 file: __ENV__.file,
                 message: """
                 undefined attribute \"size\" \
                 for component Mix.Tasks.Compile.PhoenixLiveViewTest.UndefinedAttrs.func/1\
                 """,
                 position: line,
                 severity: :warning
               },
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 file: __ENV__.file,
                 message: """
                 undefined attribute \"width\" \
                 for component Mix.Tasks.Compile.PhoenixLiveViewTest.UndefinedAttrs.func/1\
                 """,
                 position: line,
                 severity: :warning
               }
             ]
    end

    defmodule External do
      use Phoenix.Component
      attr :id, :string, required: true

      slot :named do
        attr :attr, :any, required: true
      end

      def render(assigns), do: ~H[]
    end

    defmodule ExternalCalls do
      use Phoenix.Component

      def line, do: __ENV__.line + 4

      def render(assigns) do
        ~H"""
        <External.render>
          <:named />
        </External.render>
        """
      end
    end

    test "validates attrs and slots for external function components" do
      diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([ExternalCalls])

      assert diagnostics == [
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 file: __ENV__.file,
                 message: """
                 missing required attribute \"attr\" \
                 in slot \"named\" \
                 for component Mix.Tasks.Compile.PhoenixLiveViewTest.External.render/1\
                 """,
                 position: ExternalCalls.line() + 1,
                 severity: :warning
               },
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 file: __ENV__.file,
                 message: """
                 missing required attribute \"id\" \
                 for component Mix.Tasks.Compile.PhoenixLiveViewTest.External.render/1\
                 """,
                 position: ExternalCalls.line(),
                 severity: :warning
               }
             ]
    end

    defmodule TypeAttrs do
      use Phoenix.Component, global_prefixes: ~w(myprefix-)

      attr :any, :any
      attr :string, :string
      attr :atom, :atom
      attr :boolean, :boolean
      attr :integer, :integer
      attr :float, :float
      attr :list, :list
      attr :global, :global

      def func(assigns), do: ~H[]

      def global_line, do: __ENV__.line + 4

      def global_render(assigns) do
        ~H"""
        <.func global="global" />
        <.func phx-click="click" id="id"/>
        """
      end

      def any_line, do: __ENV__.line + 4

      def any_render(assigns) do
        ~H"""
        <.func any="any" />
        <.func any={:any} />
        <.func any={true} />
        <.func any={1} />
        <.func any={1.0} />
        <.func any={[]} />
        <.func any={nil} />
        """
      end

      def render_string_line, do: __ENV__.line + 4

      def string_render(assigns) do
        ~H"""
        <.func string="string" />
        <.func string={:string} />
        <.func string={true} />
        <.func string={1} />
        <.func string={1.0} />
        <.func string={[]} />
        <.func string={nil} />
        """
      end

      def render_atom_line, do: __ENV__.line + 4

      def atom_render(assigns) do
        ~H"""
        <.func atom="atom" />
        <.func atom={:atom} />
        <.func atom={true} />
        <.func atom={1} />
        <.func atom={1.0} />
        <.func atom={[]} />
        <.func atom={nil} />
        """
      end

      def render_boolean_line, do: __ENV__.line + 4

      def boolean_render(assigns) do
        ~H"""
        <.func boolean="boolean" />
        <.func boolean={:boolean} />
        <.func boolean={true} />
        <.func boolean={1} />
        <.func boolean={1.0} />
        <.func boolean={[]} />
        <.func boolean={nil} />
        """
      end

      def render_integer_line, do: __ENV__.line + 4

      def integer_render(assigns) do
        ~H"""
        <.func integer="integer" />
        <.func integer={:integer} />
        <.func integer={true} />
        <.func integer={1} />
        <.func integer={1.0} />
        <.func integer={[]} />
        <.func integer={nil} />
        """
      end

      def render_float_line, do: __ENV__.line + 4

      def float_render(assigns) do
        ~H"""
        <.func float="float" />
        <.func float={:float} />
        <.func float={true} />
        <.func float={1} />
        <.func float={1.0} />
        <.func float={[]} />
        <.func float={nil} />
        """
      end

      def render_list_line, do: __ENV__.line + 4

      def list_render(assigns) do
        ~H"""
        <.func list="list" />
        <.func list={:list} />
        <.func list={true} />
        <.func list={1} />
        <.func list={1.0} />
        <.func list={[]} />
        <.func list={nil} />
        """
      end
    end

    test "validate literal types" do
      diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([TypeAttrs])

      global_warnings = [
        %Diagnostic{
          compiler_name: "phoenix_live_view",
          details: nil,
          file: __ENV__.file,
          severity: :warning,
          position: TypeAttrs.global_line(),
          message: """
          global attribute \"global\" \
          in component Mix.Tasks.Compile.PhoenixLiveViewTest.TypeAttrs.func/1 \
          may not be provided directly\
          """
        }
      ]

      string_warnings =
        for {value, line} <- [
              {:string, 1},
              {true, 2},
              {1, 3},
              {1.0, 4},
              {[], 5},
              {nil, 6}
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: TypeAttrs.render_string_line() + line,
            message: """
            attribute \"string\" \
            in component Mix.Tasks.Compile.PhoenixLiveViewTest.TypeAttrs.func/1 \
            must be a :string, \
            got: #{inspect(value)}\
            """
          }
        end

      atom_warnings =
        for {value, line} <- [
              {"atom", 0},
              {1, 3},
              {1.0, 4},
              {[], 5}
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: TypeAttrs.render_atom_line() + line,
            message: """
            attribute \"atom\" \
            in component Mix.Tasks.Compile.PhoenixLiveViewTest.TypeAttrs.func/1 \
            must be an :atom, \
            got: #{inspect(value)}\
            """
          }
        end

      boolean_warnings =
        for {value, line} <- [
              {"boolean", 0},
              {:boolean, 1},
              {1, 3},
              {1.0, 4},
              {[], 5},
              {nil, 6}
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: TypeAttrs.render_boolean_line() + line,
            message: """
            attribute \"boolean\" \
            in component Mix.Tasks.Compile.PhoenixLiveViewTest.TypeAttrs.func/1 \
            must be a :boolean, \
            got: #{inspect(value)}\
            """
          }
        end

      integer_warnings =
        for {value, line} <- [
              {"integer", 0},
              {:integer, 1},
              {true, 2},
              {1.0, 4},
              {[], 5},
              {nil, 6}
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: TypeAttrs.render_integer_line() + line,
            message: """
            attribute \"integer\" \
            in component Mix.Tasks.Compile.PhoenixLiveViewTest.TypeAttrs.func/1 \
            must be an :integer, \
            got: #{inspect(value)}\
            """
          }
        end

      float_warnings =
        for {value, line} <- [
              {"float", 0},
              {:float, 1},
              {true, 2},
              {1, 3},
              {[], 5},
              {nil, 6}
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: TypeAttrs.render_float_line() + line,
            message: """
            attribute \"float\" \
            in component Mix.Tasks.Compile.PhoenixLiveViewTest.TypeAttrs.func/1 \
            must be a :float, \
            got: #{inspect(value)}\
            """
          }
        end

      list_warnings =
        for {value, line} <- [
              {"list", 0},
              {:list, 1},
              {true, 2},
              {1, 3},
              {1.0, 4},
              {nil, 6}
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: TypeAttrs.render_list_line() + line,
            message: """
            attribute \"list\" \
            in component Mix.Tasks.Compile.PhoenixLiveViewTest.TypeAttrs.func/1 \
            must be a :list, \
            got: #{inspect(value)}\
            """
          }
        end

      assert diagnostics ==
               List.flatten([
                 global_warnings,
                 string_warnings,
                 atom_warnings,
                 boolean_warnings,
                 integer_warnings,
                 float_warnings,
                 list_warnings,
               ])
    end

    defmodule NoAttrs do
      use Phoenix.Component

      def func(assigns), do: ~H[]

      def render(assigns) do
        ~H"""
        <.func width="btn"/>
        """
      end
    end

    test "do not validate if component doesn't have any attr declared" do
      diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([NoAttrs])

      assert diagnostics == []
    end

    defmodule RequiredSlots do
      use Phoenix.Component

      slot :inner_block, required: true

      def func(assigns), do: ~H[]

      slot :named, required: true

      def func_named_slot(assigns), do: ~H[]

      def render_line, do: __ENV__.line + 2

      def render(assigns) do
        ~H"""
        <!-- no default slot provided -->
        <.func/>

        <!-- with an empty default slot -->
        <.func></.func>

        <!-- with content in the default slot -->
        <.func>Hello!</.func>

        <!-- no named slots provided -->
        <.func_named_slot/>

        <!-- with an empty named slot -->
        <.func_named_slot>
          <:named />
        </.func_named_slot>

        <!-- with content in the named slots -->
        <.func_named_slot>
          <:named>
            Hello!
          </:named>
        </.func_named_slot>

        <!-- with entires for the named slot -->
        <.func_named_slot>
          <:named>
            Hello,
          </:named>
          <:named>
            World!
          </:named>
        </.func_named_slot>
        """
      end
    end

    test "validate required slots" do
      line = RequiredSlots.render_line()
      diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([RequiredSlots])

      assert diagnostics == [
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 details: nil,
                 file: __ENV__.file,
                 message: """
                 missing required slot \"inner_block\" \
                 for component Mix.Tasks.Compile.PhoenixLiveViewTest.RequiredSlots.func/1\
                 """,
                 position: line + 3,
                 severity: :warning
               },
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 details: nil,
                 file: __ENV__.file,
                 message: """
                 missing required slot \"named\" \
                 for component Mix.Tasks.Compile.PhoenixLiveViewTest.RequiredSlots.func_named_slot/1\
                 """,
                 position: line + 12,
                 severity: :warning
               }
             ]
    end

    defmodule SlotAttrs do
      use Phoenix.Component

      slot :slot do
        attr :any, :any
        attr :string, :string
        attr :atom, :atom
        attr :boolean, :boolean
        attr :integer, :integer
        attr :float, :float
        attr :list, :list
        attr :global, :global
      end

      def func(assigns), do: ~H[]

      def render_global_line, do: __ENV__.line + 5

      def render_global(assigns) do
        ~H"""
        <.func>
          <:slot global="global" />
          <:slot phx-click="click" id="id" />
        </.func>
        """
      end

      def render_any_line, do: __ENV__.line + 5

      def render_any(assigns) do
        ~H"""
        <.func>
          <:slot any />
          <:slot any="any" />
          <:slot any={:any} />
          <:slot any={true} />
          <:slot any={1} />
          <:slot any={1.0} />
          <:slot any={[]} />
        </.func>
        """
      end

      def render_string_line, do: __ENV__.line + 5

      def render_string(assigns) do
        ~H"""
        <.func>
          <:slot string="string" />
          <:slot string={:string} />
          <:slot string={true} />
          <:slot string={1} />
          <:slot string={1.0} />
          <:slot string={[]} />
          <:slot string={nil} />
        </.func>
        """
      end

      def render_atom_line, do: __ENV__.line + 5

      def render_atom(assigns) do
        ~H"""
        <.func>
          <:slot atom="atom" />
          <:slot atom={:atom} />
          <:slot atom={true} />
          <:slot atom={1} />
          <:slot atom={1.0} />
          <:slot atom={[]} />
          <:slot atom={nil} />
        </.func>
        """
      end

      def render_boolean_line, do: __ENV__.line + 5

      def render_boolean(assigns) do
        ~H"""
        <.func>
          <:slot boolean="boolean" />
          <:slot boolean={:boolean} />
          <:slot boolean={true} />
          <:slot boolean={1} />
          <:slot boolean={1.0} />
          <:slot boolean={[]} />
          <:slot boolean={nil} />
        </.func>
        """
      end

      def render_integer_line, do: __ENV__.line + 5

      def render_integer(assigns) do
        ~H"""
        <.func>
          <:slot integer="integer" />
          <:slot integer={:integer} />
          <:slot integer={true} />
          <:slot integer={1} />
          <:slot integer={1.0} />
          <:slot integer={[]} />
          <:slot integer={nil} />
        </.func>
        """
      end

      def render_float_line, do: __ENV__.line + 5

      def render_float(assigns) do
        ~H"""
        <.func>
          <:slot float="float" />
          <:slot float={:float} />
          <:slot float={true} />
          <:slot float={1} />
          <:slot float={1.0} />
          <:slot float={[]} />
          <:slot float={nil} />
        </.func>
        """
      end

      def render_list_line, do: __ENV__.line + 5

      def render_list(assigns) do
        ~H"""
        <.func>
          <:slot list="list" />
          <:slot list={:list} />
          <:slot list={true} />
          <:slot list={1} />
          <:slot list={1.0} />
          <:slot list={[]} />
          <:slot list={nil} />
        </.func>
        """
      end
    end

    test "validate slot attr types" do
      diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([SlotAttrs])

      global_warnings = [
        %Diagnostic{
          compiler_name: "phoenix_live_view",
          details: nil,
          file: __ENV__.file,
          severity: :warning,
          position: SlotAttrs.render_global_line(),
          message: """
          global attribute \"global\" \
          in slot \"slot\" \
          for component Mix.Tasks.Compile.PhoenixLiveViewTest.SlotAttrs.func/1 \
          may not be provided directly\
          """
        }
      ]

      string_warnings =
        for {value, line} <- [
              {nil, 6},
              {[], 5},
              {1.0, 4},
              {1, 3},
              {true, 2},
              {:string, 1}
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: SlotAttrs.render_string_line() + line,
            message: """
            attribute \"string\" \
            in slot \"slot\" \
            for component Mix.Tasks.Compile.PhoenixLiveViewTest.SlotAttrs.func/1 \
            must be a :string, \
            got: #{inspect(value)}\
            """
          }
        end

      atom_warnings =
        for {value, line} <- [
              {[], 5},
              {1.0, 4},
              {1, 3},
              {"atom", 0}
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: SlotAttrs.render_atom_line() + line,
            message: """
            attribute \"atom\" \
            in slot \"slot\" \
            for component Mix.Tasks.Compile.PhoenixLiveViewTest.SlotAttrs.func/1 \
            must be an :atom, \
            got: #{inspect(value)}\
            """
          }
        end

      boolean_warnings =
        for {value, line} <- [
              {nil, 6},
              {[], 5},
              {1.0, 4},
              {1, 3},
              {:boolean, 1},
              {"boolean", 0}
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: SlotAttrs.render_boolean_line() + line,
            message: """
            attribute \"boolean\" \
            in slot \"slot\" \
            for component Mix.Tasks.Compile.PhoenixLiveViewTest.SlotAttrs.func/1 \
            must be a :boolean, \
            got: #{inspect(value)}\
            """
          }
        end

      integer_warnings =
        for {value, line} <- [
              {nil, 6},
              {[], 5},
              {1.0, 4},
              {true, 2},
              {:integer, 1},
              {"integer", 0}
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: SlotAttrs.render_integer_line() + line,
            message: """
            attribute \"integer\" \
            in slot \"slot\" \
            for component Mix.Tasks.Compile.PhoenixLiveViewTest.SlotAttrs.func/1 \
            must be an :integer, \
            got: #{inspect(value)}\
            """
          }
        end

      float_warnings =
        for {value, line} <- [
              {nil, 6},
              {[], 5},
              {1, 3},
              {true, 2},
              {:float, 1},
              {"float", 0}
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: SlotAttrs.render_float_line() + line,
            message: """
            attribute \"float\" \
            in slot \"slot\" \
            for component Mix.Tasks.Compile.PhoenixLiveViewTest.SlotAttrs.func/1 \
            must be a :float, \
            got: #{inspect(value)}\
            """
          }
        end

      list_warnings =
        for {value, line} <- [
              {nil, 6},
              {1.0, 4},
              {1, 3},
              {true, 2},
              {:list, 1},
              {"list", 0}
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: SlotAttrs.render_list_line() + line,
            message: """
            attribute \"list\" \
            in slot \"slot\" \
            for component Mix.Tasks.Compile.PhoenixLiveViewTest.SlotAttrs.func/1 \
            must be a :list, \
            got: #{inspect(value)}\
            """
          }
        end

      assert diagnostics ==
               List.flatten([
                 global_warnings,
                 string_warnings,
                 atom_warnings,
                 boolean_warnings,
                 integer_warnings,
                 float_warnings,
                 list_warnings
               ])
    end

    defmodule RequiredSlotAttrs do
      use Phoenix.Component

      slot :slot do
        attr :attr, :string, required: true
      end

      def func(assigns) do
        ~H"""
        <div>
          <%= render_slot(@slot) %>
        </div>
        """
      end

      def render_line(), do: __ENV__.line + 4

      def render(assigns) do
        ~H"""
        <.func>
          <:slot />
          <:slot attr="foo" />
          <:slot>
            foo
          </:slot>
          <:slot attr="bar">
            bar
          </:slot>
          <:slot {[attr: "bar"]} />
        </.func>
        """
      end
    end

    test "validates required slot attrs" do
      diagnostics =
        Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([RequiredSlotAttrs])

      assert diagnostics == [
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 details: nil,
                 file: __ENV__.file,
                 severity: :warning,
                 position: RequiredSlotAttrs.render_line() + 1,
                 message: """
                 missing required attribute \"attr\" \
                 in slot \"slot\" \
                 for component Mix.Tasks.Compile.PhoenixLiveViewTest.RequiredSlotAttrs.func/1\
                 """
               },
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 details: nil,
                 file: __ENV__.file,
                 severity: :warning,
                 position: RequiredSlotAttrs.render_line() + 3,
                 message: """
                 missing required attribute \"attr\" \
                 in slot \"slot\" \
                 for component Mix.Tasks.Compile.PhoenixLiveViewTest.RequiredSlotAttrs.func/1\
                 """
               }
             ]
    end

    defmodule UndefinedSlots do
      use Phoenix.Component

      slot :inner_block

      def func(assigns), do: ~H[]

      slot :named

      def func_undefined_slot_attrs(assigns), do: ~H[]

      def render_line, do: __ENV__.line + 2

      def render(assigns) do
        ~H"""
        <!-- undefined slot -->
        <.func>
          <:undefined />
        </.func>

        <!-- slot with undefined attrs -->
        <.func_undefined_slot_attrs>
          <:named undefined />
          <:named undefined="undefined" />
        </.func_undefined_slot_attrs>
        """
      end
    end

    test "validates undefined slots" do
      line = UndefinedSlots.render_line()
      diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([UndefinedSlots])

      assert diagnostics == [
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 details: nil,
                 file: __ENV__.file,
                 message: """
                 undefined slot \"undefined\" \
                 for component Mix.Tasks.Compile.PhoenixLiveViewTest.UndefinedSlots.func/1\
                 """,
                 position: line + 4,
                 severity: :warning
               },
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 details: nil,
                 file: __ENV__.file,
                 message: """
                 undefined attribute \"undefined\" \
                 in slot \"named\" \
                 for component Mix.Tasks.Compile.PhoenixLiveViewTest.UndefinedSlots.func_undefined_slot_attrs/1\
                 """,
                 position: line + 10,
                 severity: :warning
               },
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 details: nil,
                 file: __ENV__.file,
                 message: """
                 undefined attribute \"undefined\" \
                 in slot \"named\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.UndefinedSlots.func_undefined_slot_attrs/1\
                 """,
                 position: line + 9,
                 severity: :warning
               }
             ]
    end
  end

  describe "integration tests" do
    test "run validations for all project modules and return diagnostics" do
      {:ok, diagnostics} = Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors", "--force"])
      file = to_string(Mix.Tasks.Compile.PhoenixLiveViewTest.Comp1.module_info(:compile)[:source])

      assert Enum.all?(diagnostics, &match?(%Diagnostic{file: ^file}, &1))
    end

    test "create manifest with diagnostics if file doesn't exist" do
      [manifest] = Mix.Tasks.Compile.PhoenixLiveView.manifests()
      File.rm(manifest)

      refute File.exists?(manifest)

      {:ok, diagnostics} = Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors"])

      assert {1, ^diagnostics} = manifest |> File.read!() |> :erlang.binary_to_term()
    end

    test "update manifest if file is older than other manifests" do
      {:ok, _diagnostics} = Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors", "--force"])

      # Doesn't update it as the modification time is newer
      assert {:noop, _diagnostics} = Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors"])

      [manifest] = Mix.Tasks.Compile.PhoenixLiveView.manifests()
      [other_manifest | _] = Mix.Tasks.Compile.Elixir.manifests()

      new_manifest_mtime =
        File.stat!(other_manifest).mtime
        |> :calendar.datetime_to_gregorian_seconds()
        |> Kernel.-(1)
        |> :calendar.gregorian_seconds_to_datetime()

      File.touch!(manifest, new_manifest_mtime)

      # Update it as the modification time is older now
      assert {:ok, _diagnostics} = Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors"])
    end

    test "update manifest if the version differs" do
      {:ok, _diagnostics} = Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors", "--force"])

      # Doesn't update it as the version is the same
      assert {:noop, _diagnostics} = Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors"])

      [manifest] = Mix.Tasks.Compile.PhoenixLiveView.manifests()
      {version, diagnostics} = File.read!(manifest) |> :erlang.binary_to_term()
      File.write!(manifest, :erlang.term_to_binary({version + 1, diagnostics}))

      # Update it as the version changed
      assert {:ok, _diagnostics} = Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors"])
    end

    test "read diagnostics from manifest only when --all-warnings is passed" do
      {:ok, diagnostics} = Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors", "--force"])
      assert length(diagnostics) > 0

      assert {:noop, []} == Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors"])

      assert {:noop, ^diagnostics} =
               Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors", "--all-warnings"])
    end

    test "always return {:error. diagnostics} when --warnings-as-errors is passed" do
      {:error, _diagnostics} =
        Mix.Tasks.Compile.PhoenixLiveView.run([
          "--return-errors",
          "--force",
          "--warnings-as-errors"
        ])

      {:error, _diagnostics} =
        Mix.Tasks.Compile.PhoenixLiveView.run([
          "--return-errors",
          "--all-warnings",
          "--warnings-as-errors"
        ])
    end
  end

  describe "integration warnings" do
    # setup do
    #   ansi_enabled? = Application.put_env(:elixir, :ansi_enabled, false)
    #   Application.put_env(:elixir, :ansi_enabled, false)
    #   on_exit(fn -> Application.put_env(:elixir, :ansi_enabled, ansi_enabled?) end)
    # end

    test "print diagnostics when --return-errors is not passed" do
      messages =
        capture_io(:stderr, fn ->
          Mix.Tasks.Compile.PhoenixLiveView.run(["--force"])
        end)

      assert messages =~ """
             missing required attribute "name" for component Mix.Tasks.Compile.PhoenixLiveViewTest.Comp1.func/1
               test/support/mix/tasks/compile/phoenix_live_view_test_components.ex:9: (file)
             """

      assert messages =~ """
             missing required attribute "name" for component Mix.Tasks.Compile.PhoenixLiveViewTest.Comp1.func/1
               test/support/mix/tasks/compile/phoenix_live_view_test_components.ex:15: (file)
             """

      assert messages =~ """
             missing required attribute "name" for component Mix.Tasks.Compile.PhoenixLiveViewTest.Comp2.func/1
               test/support/mix/tasks/compile/phoenix_live_view_test_components.ex:28: (file)
             """

      assert messages =~ """
             missing required attribute "name" for component Mix.Tasks.Compile.PhoenixLiveViewTest.Comp2.func/1
               test/support/mix/tasks/compile/phoenix_live_view_test_components.ex:34: (file)
             """
    end
  end

  test "only runs diagnostics on Phoenix.Component modules" do
    alias Mix.Tasks.Compile.WithDiagnostics
    diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([WithDiagnostics])
    assert diagnostics == []
  end

  defp get_line(module) do
    module.line()
  end
end
