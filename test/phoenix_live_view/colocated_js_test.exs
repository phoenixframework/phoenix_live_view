defmodule Phoenix.LiveView.ColocatedJSTest do
  # we set async: false because we call the colocated JS compiler
  # and it reads / writes to a shared folder
  use ExUnit.Case, async: false

  test "simple script is extracted and available under default export object" do
    defmodule TestComponent do
      use Phoenix.Component
      alias Phoenix.LiveView.ColocatedJS, as: Colo

      def fun(assigns) do
        ~H"""
        <script :type={Colo} name="my-script">
          export default function() {
            console.log("hey!")
          }
        </script>
        """
      end
    end

    assert module_folders =
             File.ls!(Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view"))

    assert folder =
             Enum.find(module_folders, fn folder ->
               folder =~ ~r/#{inspect(__MODULE__)}\.TestComponent$/
             end)

    assert [script] =
             Path.wildcard(
               Path.join(
                 Mix.Project.build_path(),
                 "phoenix-colocated/phoenix_live_view/#{folder}/*.js"
               )
             )

    assert File.read!(script) == """

             export default function() {
               console.log("hey!")
             }
           """

    # now write the manifest manually as we are in a test
    Phoenix.LiveView.ColocatedJS.compile()

    assert manifest =
             File.read!(
               Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view/index.js")
             )

    assert manifest =~ "export default js;"
    assert manifest =~ "js[\"my-script\"] = js_"

    # script is in manifest
    assert manifest =~
             Path.relative_to(
               script,
               Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view/")
             )
  after
    :code.delete(__MODULE__.TestComponent)
    :code.purge(__MODULE__.TestComponent)
  end

  test "keyed script is available under default named export" do
    defmodule TestComponentKey do
      use Phoenix.Component
      alias Phoenix.LiveView.ColocatedJS, as: Colo

      def fun(assigns) do
        ~H"""
        <script :type={Colo} name="my-script" key="components">
          export default function() {
            console.log("hey!")
          }
        </script>
        """
      end
    end

    assert module_folders =
             File.ls!(Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view"))

    assert folder =
             Enum.find(module_folders, fn folder ->
               folder =~ ~r/#{inspect(__MODULE__)}\.TestComponentKey/
             end)

    assert [script] =
             Path.wildcard(
               Path.join(
                 Mix.Project.build_path(),
                 "phoenix-colocated/phoenix_live_view/#{folder}/*.js"
               )
             )

    assert File.read!(script) == """

             export default function() {
               console.log("hey!")
             }
           """

    # now write the manifest manually as we are in a test
    Phoenix.LiveView.ColocatedJS.compile()

    relative_script_path =
      Path.relative_to(
        script,
        Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view/")
      )

    assert manifest =
             File.read!(
               Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view/index.js")
             )

    assert line =
             Enum.find(String.split(manifest, "\n"), fn line ->
               line =~ inspect(__MODULE__.TestComponentKey)
             end)

    assert [_match, js_name] =
             Regex.run(~r/import (js_.*) from "\.\/#{Regex.escape(relative_script_path)}";/, line)

    assert [_match, export_name] = Regex.run(~r/export \{ (imp_.*) as components \}/, manifest)
    assert manifest =~ "#{export_name}[\"my-script\"] = #{js_name};"
  after
    :code.delete(__MODULE__.TestComponentKey)
    :code.purge(__MODULE__.TestComponentKey)
  end

  test "nameless script is imported for side effects only" do
    defmodule TestComponentSideEffects do
      use Phoenix.Component
      alias Phoenix.LiveView.ColocatedJS, as: Colo

      def fun(assigns) do
        ~H"""
        <script :type={Colo}>
          console.log("hey!");
        </script>
        """
      end
    end

    assert module_folders =
             File.ls!(Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view"))

    assert folder =
             Enum.find(module_folders, fn folder ->
               folder =~ ~r/#{inspect(__MODULE__)}\.TestComponentSideEffects/
             end)

    assert [script] =
             Path.wildcard(
               Path.join(
                 Mix.Project.build_path(),
                 "phoenix-colocated/phoenix_live_view/#{folder}/*.js"
               )
             )

    assert File.read!(script) == """

             console.log("hey!");
           """

    # now write the manifest manually as we are in a test
    Phoenix.LiveView.ColocatedJS.compile()

    relative_script_path =
      Path.relative_to(
        script,
        Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view/")
      )

    assert manifest =
             File.read!(
               Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view/index.js")
             )

    assert line =
             Enum.find(String.split(manifest, "\n"), fn line ->
               line =~ inspect(__MODULE__.TestComponentSideEffects)
             end)

    assert [_match] =
             Regex.run(~r/import "\.\/#{Regex.escape(relative_script_path)}";/, line)
  after
    :code.delete(__MODULE__.TestComponentSideEffects)
    :code.purge(__MODULE__.TestComponentSideEffects)
  end

  test "raises for invalid name" do
    assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                 ~r/the name attribute of a colocated script must be a compile-time string\. Got: @foo/,
                 fn ->
                   defmodule TestComponentInvalidName do
                     use Phoenix.Component
                     alias Phoenix.LiveView.ColocatedJS, as: Colo

                     def fun(assigns) do
                       ~H"""
                       <script :type={Colo} name={@foo}>
                         1 + 1
                       </script>
                       """
                     end
                   end
                 end
  end

  test "writes empty index.js when no colocated scripts exist" do
    manifest = Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view/index.js")
    Phoenix.LiveView.ColocatedJS.compile()
    assert File.exists?(manifest)
    assert File.read!(manifest) == "export const hooks = {};\nexport default {};"
  end

  test "symlinks node_modules folder if exists" do
    node_path = Path.expand("../../assets/node_modules", __DIR__)

    if not File.exists?(node_path) do
      on_exit(fn -> File.rm_rf!(node_path) end)
    end

    File.mkdir_p!(Path.join(node_path, "foo"))
    Phoenix.LiveView.ColocatedJS.compile()

    symlink =
      Path.join(
        Mix.Project.build_path(),
        "phoenix-colocated/phoenix_live_view/node_modules"
      )

    assert File.exists?(symlink)
    link = File.read_link!(symlink)

    if function_exported?(Path, :relative_to, 3) do
      assert String.starts_with?(link, "../")
    end

    assert "foo" in File.ls!(symlink)
  end
end
