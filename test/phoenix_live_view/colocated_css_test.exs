defmodule Phoenix.LiveView.ColocatedCSSTest do
  # we set async: false because we call the colocated CSS compiler
  # and it reads / writes to a shared folder
  use ExUnit.Case, async: false

  test "simple style is extracted and available under manifest import" do
    defmodule TestComponent do
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
               folder =~ ~r/#{inspect(__MODULE__)}\.TestComponent$/
             end)

    assert [style] =
             Path.wildcard(
               Path.join(
                 Mix.Project.build_path(),
                 "phoenix-colocated-css/phoenix_live_view/#{folder}/*.css"
               )
             )

    assert File.read!(style) == """

             .sample-class {
                 background-color: #FFFFFF;
             }
           """

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
    :code.delete(__MODULE__.TestComponent)
    :code.purge(__MODULE__.TestComponent)
  end

  test "writes empty colocated.css when no colocated styles exist" do
    manifest =
      Path.join(Mix.Project.build_path(), "phoenix-colocated-css/phoenix_live_view/colocated.css")

    Phoenix.LiveView.ColocatedCSS.compile()
    assert File.exists?(manifest)
    assert File.read!(manifest) == ""
  end
end
