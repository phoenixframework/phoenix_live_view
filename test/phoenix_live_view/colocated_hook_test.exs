defmodule Phoenix.LiveView.ColocatedHookTest do
  # we set async: false because we call the colocated JS compiler
  # and it reads / writes to a shared folder
  use ExUnit.Case, async: false

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

    assert manifest =~ ~r/export \{ imp_.* as hooks \}/

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

  test "raises for invalid name" do
    assert_raise Phoenix.LiveView.TagEngine.Tokenizer.ParseError,
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
