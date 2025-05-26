defmodule Phoenix.LiveView.ColocatedHookTest do
  use ExUnit.Case, async: true

  setup_all do
    on_exit(fn ->
      File.rm_rf!(Path.join(Mix.Project.build_path(), "phoenix-colocated"))
    end)
  end

  test "can use a hook" do
    defmodule TestComponent do
      use Phoenix.Component
      alias Phoenix.LiveView.ColocatedHook, as: Hook

      def fun(assigns) do
        ~H"""
        <script :type={Hook} name=".fun">
          export default {
            mounted() {
              this.el.textContent = "Hello, world!";
            }
          }
        </script>

        <div id="hook" phx-hook=".fun"></div>
        """
      end
    end

    assert module_folders =
             File.ls!(Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view"))

    assert folder =
             Enum.find(module_folders, fn folder ->
               folder =~ ~r/#{inspect(__MODULE__)}\.TestComponent/
             end)

    assert [script] =
             Path.wildcard(
               Path.join(
                 Mix.Project.build_path(),
                 "phoenix-colocated/phoenix_live_view/#{folder}/*.js"
               )
             )

    assert File.read!(script) =~ "Hello, world!"

    # now write the manifest manually as we are in a test
    Phoenix.LiveView.ColocatedJS.compile()

    assert manifest =
             File.read!(
               Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view/index.js")
             )

    assert manifest =~ "export default js;"

    # script is in manifest
    assert manifest =~
             Path.relative_to(
               script,
               Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view/")
             )
  end

  test "raises for invalid name" do
    assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                 ~r/the name attribute of a colocated hook must be a compile-time string\. Got: @foo/,
                 fn ->
                   defmodule TestComponentInvalidName do
                     use Phoenix.Component
                     alias Phoenix.LiveView.ColocatedHook, as: Hook

                     def fun(assigns) do
                       ~H"""
                       <script :type={Hook} name={@foo}>
                         export default {
                           mounted() {
                             this.el.textContent = "Hello, world!";
                           }
                         }
                       </script>

                       <div id="hook" phx-hook=".fun"></div>
                       """
                     end
                   end
                 end
  end
end
