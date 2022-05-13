defmodule Mix.Tasks.Compile.PhoenixLiveViewTest do
  use ExUnit.Case, async: true
  use Phoenix.Component

  alias Mix.Task.Compiler.Diagnostic
  import ExUnit.CaptureIO

  describe "validations" do
    defmodule RequiredAttrs do
      use Phoenix.Component

      attr(:name, :any, required: true)
      attr(:phone, :any)
      attr(:email, :any, required: true)

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

      attr(:name, :any, required: true)

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

      attr(:class, :any)
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
                 message:
                   "undefined attribute \"size\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.UndefinedAttrs.func/1",
                 position: line,
                 severity: :warning
               },
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 file: __ENV__.file,
                 message:
                   "undefined attribute \"width\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.UndefinedAttrs.func/1",
                 position: line,
                 severity: :warning
               }
             ]
    end

    defmodule External do
      use Phoenix.Component
      attr :id, :string, required: true
      attr :rest, :global
      def button(assigns), do: ~H[<button id={@id} {@rest}/>]
    end

    defmodule TypeAttrs do
      use Phoenix.Component, globals: ~w(myprefix-)

      attr :boolean, :boolean
      attr :string, :string
      def func(assigns), do: ~H[]

      attr :id, :string, required: true
      attr :rest, :global
      def local_button(assigns), do: ~H[<button id={@id} {@rest}/>]

      def line, do: __ENV__.line + 4

      def render(assigns) do
        ~H"""
        <.func boolean="btn"/>
        <.func string/>
        <.func boolean string="string"/>
        <.func boolean={"can't validate"} string={:wont_validate}/>
        <.local_button id="foo" class="my-class" myprefix-thing="value"/>
        <.local_button id="foo" unknown-global="bad"/>
        <External.button id="foo" class="external" myprefix-external="value"/>
        <External.button id="foo" unknown-global-external="bad"/>
        """
      end
    end

    test "validate literal types" do
      line = get_line(TypeAttrs)
      diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([TypeAttrs])

      assert diagnostics == [
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 file: __ENV__.file,
                 message:
                   "attribute \"boolean\" in component Mix.Tasks.Compile.PhoenixLiveViewTest.TypeAttrs.func/1 must be a :boolean, got string: \"btn\"",
                 position: line,
                 severity: :warning
               },
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 file: __ENV__.file,
                 message:
                   "attribute \"string\" in component Mix.Tasks.Compile.PhoenixLiveViewTest.TypeAttrs.func/1 must be a :string, got boolean: true",
                 position: line + 1,
                 severity: :warning
               },
               %Mix.Task.Compiler.Diagnostic{
                 compiler_name: "phoenix_live_view",
                 file: __ENV__.file,
                 message:
                   "undefined attribute \"unknown-global\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.TypeAttrs.local_button/1",
                 position: line + 5,
                 severity: :warning
               },
               %Mix.Task.Compiler.Diagnostic{
                 compiler_name: "phoenix_live_view",
                 details: nil,
                 file:
                   "/Users/chris/oss/phoenix_live_view/test/mix/tasks/compile/phoenix_live_view_test.exs",
                 message:
                   "undefined attribute \"unknown-global-external\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.External.button/1",
                 position: 144,
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
      diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([NoAttrs])

      assert diagnostics == []
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
