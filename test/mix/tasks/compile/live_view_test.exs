defmodule Mix.Tasks.Compile.LiveViewTest do
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

      def line, do: __ENV__.line + 3
      def render(assigns) do
        ~H"""
        <.func/>
        """
      end
    end

    test "validate required attributes" do
      line = RequiredAttrs.line()
      diagnostics = Mix.Tasks.Compile.LiveView.validate_components_calls([RequiredAttrs])

      assert diagnostics == [
        %Diagnostic{
          compiler_name: "live_view",
          file: __ENV__.file,
          message: """
          missing required attribute `name` for component \
          `Mix.Tasks.Compile.LiveViewTest.RequiredAttrs.func/1`\
          """,
          position: line,
          severity: :error
        },
        %Diagnostic{
          compiler_name: "live_view",
          file: __ENV__.file,
          message: """
          missing required attribute `email` for component \
          `Mix.Tasks.Compile.LiveViewTest.RequiredAttrs.func/1`\
          """,
          position: line,
          severity: :error
        }
      ]
    end

    defmodule UndefinedAttrs do
      use Phoenix.Component

      attr :class, :any
      def func(assigns), do: ~H[]

      def line, do: __ENV__.line + 3
      def render(assigns) do
        ~H"""
        <.func width="btn" size={@size}/>
        """
      end
    end

    test "validate undefined attributes" do
      line = UndefinedAttrs.line()
      diagnostics = Mix.Tasks.Compile.LiveView.validate_components_calls([UndefinedAttrs])

      assert diagnostics == [
        %Diagnostic{
          compiler_name: "live_view",
          file: __ENV__.file,
          message: "undefined attribute `width` for component `Mix.Tasks.Compile.LiveViewTest.UndefinedAttrs.func/1`",
          position: line,
          severity: :error
        },
        %Diagnostic{
          compiler_name: "live_view",
          file: __ENV__.file,
          message: "undefined attribute `size` for component `Mix.Tasks.Compile.LiveViewTest.UndefinedAttrs.func/1`",
          position: line,
          severity: :error
        }
      ]
    end
  end

  describe "live_view compiler" do
    test "run validations for all project modules and return diagnostics" do
      {:ok, diagnostics} = Mix.Tasks.Compile.LiveView.run(["--return-errors"])
      file = to_string(Mix.Tasks.Compile.LiveViewTest.Comp1.module_info(:compile)[:source])

      assert Enum.all?(diagnostics, &match?(%Diagnostic{file: ^file}, &1))
    end

    test "print diagnostics when --return-errors is not passed" do
      messages = """
      ** (CompileError) test/support/mix/tasks/compile/live_view_test_components.ex:9: \
      missing required attribute `name` for component `Mix.Tasks.Compile.LiveViewTest.Comp1.func/1`
      ** (CompileError) test/support/mix/tasks/compile/live_view_test_components.ex:15: \
      missing required attribute `name` for component `Mix.Tasks.Compile.LiveViewTest.Comp1.func/1`
      ** (CompileError) test/support/mix/tasks/compile/live_view_test_components.ex:28: \
      missing required attribute `name` for component `Mix.Tasks.Compile.LiveViewTest.Comp2.func/1`
      ** (CompileError) test/support/mix/tasks/compile/live_view_test_components.ex:34: \
      missing required attribute `name` for component `Mix.Tasks.Compile.LiveViewTest.Comp2.func/1`
      """

      assert capture_io(:standard_error, fn ->
        Mix.Tasks.Compile.LiveView.run([])
      end) == messages
    end
  end
end
