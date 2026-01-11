defmodule Phoenix.LiveView.ColocatedCSSTest do
  # we set async: false because we call the colocated CSS compiler
  # and it reads / writes to a shared folder
  use ExUnit.Case, async: false

  test "simple global style is extracted and available under manifest import" do
    defmodule TestGlobalComponent do
      use Phoenix.Component
      alias Phoenix.LiveView.ColocatedCSS, as: Colo

      def fun(assigns) do
        ~H"""
        <style :type={Colo} global>
          .sample-class {
              background-color: #FFFFFF;
          }
        </style>
        """
      end
    end

    assert module_folders =
             File.ls!(
               Path.join(Mix.Project.build_path(), "phoenix-colocated-css/phoenix_live_view")
             )

    assert folder =
             Enum.find(module_folders, fn folder ->
               folder =~ ~r/#{inspect(__MODULE__)}\.TestGlobalComponent$/
             end)

    assert [style] =
             Path.wildcard(
               Path.join(
                 Mix.Project.build_path(),
                 "phoenix-colocated-css/phoenix_live_view/#{folder}/*.css"
               )
             )

    assert File.read!(style) == "\n  .sample-class {\n      background-color: #FFFFFF;\n  }\n"

    # now write the manifest manually as we are in a test
    Phoenix.LiveView.ColocatedCSS.compile()

    assert manifest =
             File.read!(
               Path.join(
                 Mix.Project.build_path(),
                 "phoenix-colocated-css/phoenix_live_view/colocated.css"
               )
             )

    path =
      Path.relative_to(
        style,
        Path.join(Mix.Project.build_path(), "phoenix-colocated-css/phoenix_live_view/")
      )

    # style is in manifest
    assert manifest =~ ~s[@import "./#{path}";\n]
  after
    :code.delete(__MODULE__.TestGlobalComponent)
    :code.purge(__MODULE__.TestGlobalComponent)
  end

  test "simple scoped style is extracted and available under manifest import" do
    defmodule TestScopedComponent do
      use Phoenix.Component
      alias Phoenix.LiveView.ColocatedCSS, as: Colo

      def fun(assigns) do
        ~H"""
        <style :type={Colo}>
          .sample-class {
              background-color: #FFFFFF;
          }
        </style>
        """
      end
    end

    assert module_folders =
             File.ls!(
               Path.join(Mix.Project.build_path(), "phoenix-colocated-css/phoenix_live_view")
             )

    assert folder =
             Enum.find(module_folders, fn folder ->
               folder =~ ~r/#{inspect(__MODULE__)}\.TestScopedComponent$/
             end)

    assert [style] =
             Path.wildcard(
               Path.join(
                 Mix.Project.build_path(),
                 "phoenix-colocated-css/phoenix_live_view/#{folder}/*.css"
               )
             )

    file_contents = File.read!(style)

    file_contents =
      Regex.replace(~r/data-phx-css=".+"/, file_contents, "data-phx-css=\"SCOPE_HERE\"")

    # The scope is a generated value, so for testing reliability we just replace it with a known
    # value to assert against.
    assert file_contents ==
             "@scope ([data-phx-css=\"SCOPE_HERE\"]) to ([data-phx-css]) { \n  .sample-class {\n      background-color: #FFFFFF;\n  }\n  }"

    # now write the manifest manually as we are in a test
    Phoenix.LiveView.ColocatedCSS.compile()

    assert manifest =
             File.read!(
               Path.join(
                 Mix.Project.build_path(),
                 "phoenix-colocated-css/phoenix_live_view/colocated.css"
               )
             )

    path =
      Path.relative_to(
        style,
        Path.join(Mix.Project.build_path(), "phoenix-colocated-css/phoenix_live_view/")
      )

    # style is in manifest
    assert manifest =~ ~s[@import "./#{path}";\n]
  after
    :code.delete(__MODULE__.TestScopedComponent)
    :code.purge(__MODULE__.TestScopedComponent)
  end

  test "writes empty colocated.css when no colocated styles exist" do
    manifest =
      Path.join(Mix.Project.build_path(), "phoenix-colocated-css/phoenix_live_view/colocated.css")

    Phoenix.LiveView.ColocatedCSS.compile()
    assert File.exists?(manifest)
    assert File.read!(manifest) == ""
  end
end
