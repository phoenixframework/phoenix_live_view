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
      line = get_line(RequiredAttrs)
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
          severity: :warning
        },
        %Diagnostic{
          compiler_name: "live_view",
          file: __ENV__.file,
          message: """
          missing required attribute `email` for component \
          `Mix.Tasks.Compile.LiveViewTest.RequiredAttrs.func/1`\
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
      diagnostics = Mix.Tasks.Compile.LiveView.validate_components_calls([RequiredAttrsWithDynamic])
      assert diagnostics == []
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
      line = get_line(UndefinedAttrs)
      diagnostics = Mix.Tasks.Compile.LiveView.validate_components_calls([UndefinedAttrs])

      assert diagnostics == [
        %Diagnostic{
          compiler_name: "live_view",
          file: __ENV__.file,
          message: "undefined attribute `width` for component `Mix.Tasks.Compile.LiveViewTest.UndefinedAttrs.func/1`",
          position: line,
          severity: :warning
        },
        %Diagnostic{
          compiler_name: "live_view",
          file: __ENV__.file,
          message: "undefined attribute `size` for component `Mix.Tasks.Compile.LiveViewTest.UndefinedAttrs.func/1`",
          position: line,
          severity: :warning
        }
      ]
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
      diagnostics = Mix.Tasks.Compile.LiveView.validate_components_calls([NoAttrs])

      assert diagnostics == []
    end
  end

  describe "live_view compiler" do
    test "run validations for all project modules and return diagnostics" do
      {:ok, diagnostics} = Mix.Tasks.Compile.LiveView.run(["--return-errors", "--force"])
      file = to_string(Mix.Tasks.Compile.LiveViewTest.Comp1.module_info(:compile)[:source])

      assert Enum.all?(diagnostics, &match?(%Diagnostic{file: ^file}, &1))
    end

    test "create manifest with diagnostics if file doesn't exist" do
      [manifest] = Mix.Tasks.Compile.LiveView.manifests()
      File.rm(manifest)

      refute File.exists?(manifest)

      {:ok, diagnostics} = Mix.Tasks.Compile.LiveView.run(["--return-errors"])

      assert {1, ^diagnostics} = manifest |> File.read!() |> :erlang.binary_to_term()
    end

    test "update manifest if file is older than other manifests" do
      {:ok, _diagnostics} = Mix.Tasks.Compile.LiveView.run(["--return-errors", "--force"])

      # Doesn't update it as the modification time is newer
      assert {:noop, _diagnostics} = Mix.Tasks.Compile.LiveView.run(["--return-errors"])

      [manifest] = Mix.Tasks.Compile.LiveView.manifests()
      [other_manifest | _] = Mix.Tasks.Compile.Elixir.manifests()

      new_manifest_mtime =
        File.stat!(other_manifest).mtime
        |> :calendar.datetime_to_gregorian_seconds()
        |> Kernel.-(1)
        |> :calendar.gregorian_seconds_to_datetime()

      File.touch!(manifest, new_manifest_mtime)

      # Update it as the modification time is older now
      assert {:ok, _diagnostics} = Mix.Tasks.Compile.LiveView.run(["--return-errors"])
    end

    test "update manifest if the version differs" do
      {:ok, _diagnostics} = Mix.Tasks.Compile.LiveView.run(["--return-errors", "--force"])

      # Doesn't update it as the version is the same
      assert {:noop, _diagnostics} = Mix.Tasks.Compile.LiveView.run(["--return-errors"])

      [manifest] = Mix.Tasks.Compile.LiveView.manifests()
      {version, diagnostics} = File.read!(manifest) |> :erlang.binary_to_term()
      File.write!(manifest, :erlang.term_to_binary({version + 1, diagnostics}))

      # Update it as the version changed
      assert {:ok, _diagnostics} = Mix.Tasks.Compile.LiveView.run(["--return-errors"])
    end

    test "read diagnostics from manifest only when --all-warnings is passed" do
      {:ok, diagnostics} = Mix.Tasks.Compile.LiveView.run(["--return-errors", "--force"])
      assert length(diagnostics) > 0

      assert {:noop, []} == Mix.Tasks.Compile.LiveView.run(["--return-errors"])
      assert {:noop, ^diagnostics} = Mix.Tasks.Compile.LiveView.run(["--return-errors", "--all-warnings"])
    end

    test "always return {:error. diagnostics} when --warnings-as-errors is passed" do
      {:error, _diagnostics} = Mix.Tasks.Compile.LiveView.run(["--return-errors", "--force", "--warnings-as-errors"])
      {:error, _diagnostics} = Mix.Tasks.Compile.LiveView.run(["--return-errors", "--all-warnings", "--warnings-as-errors"])
    end

    if Version.match?(System.version(), ">= 1.12.0") do
      test "print diagnostics when --return-errors is not passed" do
        messages = """
        \e[33mwarning: \e[0mmissing required attribute `name` for component `Mix.Tasks.Compile.LiveViewTest.Comp1.func/1`
          test/support/mix/tasks/compile/live_view_test_components.ex:9: (file)

        \e[33mwarning: \e[0mmissing required attribute `name` for component `Mix.Tasks.Compile.LiveViewTest.Comp1.func/1`
          test/support/mix/tasks/compile/live_view_test_components.ex:15: (file)

        \e[33mwarning: \e[0mmissing required attribute `name` for component `Mix.Tasks.Compile.LiveViewTest.Comp2.func/1`
          test/support/mix/tasks/compile/live_view_test_components.ex:28: (file)

        \e[33mwarning: \e[0mmissing required attribute `name` for component `Mix.Tasks.Compile.LiveViewTest.Comp2.func/1`
          test/support/mix/tasks/compile/live_view_test_components.ex:34: (file)

        """

        assert capture_io(:standard_error, fn ->
          Mix.Tasks.Compile.LiveView.run(["--force"])
        end) == messages
      end
    else
      test "print diagnostics when --return-errors is not passed" do
        messages = """
        warning: missing required attribute `name` for component `Mix.Tasks.Compile.LiveViewTest.Comp1.func/1`
          test/support/mix/tasks/compile/live_view_test_components.ex:1: (file)

        warning: missing required attribute `name` for component `Mix.Tasks.Compile.LiveViewTest.Comp1.func/1`
          test/support/mix/tasks/compile/live_view_test_components.ex:1: (file)

        warning: missing required attribute `name` for component `Mix.Tasks.Compile.LiveViewTest.Comp2.func/1`
          test/support/mix/tasks/compile/live_view_test_components.ex:1: (file)

        warning: missing required attribute `name` for component `Mix.Tasks.Compile.LiveViewTest.Comp2.func/1`
          test/support/mix/tasks/compile/live_view_test_components.ex:1: (file)

        """

        assert capture_io(:standard_error, fn ->
          Mix.Tasks.Compile.LiveView.run(["--force"])
        end) == messages
      end
    end
  end

  defp get_line(module) do
    if Version.match?(System.version(), ">= 1.12.0") do
      module.line()
    else
      1
    end
  end
end
