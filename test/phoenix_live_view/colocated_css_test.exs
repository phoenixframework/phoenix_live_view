defmodule Phoenix.LiveView.ColocatedCSSTest do
  # we set async: false because we call the colocated CSS compiler
  # and it reads / writes to a shared folder, and also because
  # we manipulate the Application env for :root_tag_attribute
  use ExUnit.Case, async: false

  alias Phoenix.LiveView.TagEngine.Tokenizer.ParseError

  setup do
    Application.put_env(:phoenix_live_view, :root_tag_attribute, "phx-r")
    on_exit(fn -> Application.delete_env(:phoenix_live_view, :root_tag_attribute) end)
  end

  describe "global styles" do
    test "are extracted and available under manifest import" do
      defmodule TestGlobalComponent do
        use Phoenix.Component

        def fun(assigns) do
          ~H"""
          <style :type={Phoenix.LiveView.ColocatedCSS} global>
            .sample-class { background-color: #FFFFFF; }
          </style>
          """
        end
      end

      assert module_folders =
               File.ls!(
                 Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view")
               )

      assert folder =
               Enum.find(module_folders, fn folder ->
                 folder =~ ~r/#{inspect(__MODULE__)}\.TestGlobalComponent$/
               end)

      assert [style] =
               Path.wildcard(
                 Path.join(
                   Mix.Project.build_path(),
                   "phoenix-colocated/phoenix_live_view/#{folder}/*.css"
                 )
               )

      assert File.read!(style) == "\n  .sample-class { background-color: #FFFFFF; }\n"

      # now write the manifest manually as we are in a test
      Phoenix.LiveView.ColocatedAssets.compile()

      assert manifest =
               File.read!(
                 Path.join(
                   Mix.Project.build_path(),
                   "phoenix-colocated/phoenix_live_view/colocated.css"
                 )
               )

      path =
        Path.relative_to(
          style,
          Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view/")
        )

      # style is in manifest
      assert manifest =~ ~s[@import "./#{path}";\n]
    after
      :code.delete(__MODULE__.TestGlobalComponent)
      :code.purge(__MODULE__.TestGlobalComponent)
    end

    test "raises for invalid global attribute value" do
      message = ~r/expected nil or true for the `global` attribute of colocated css, got: "bad"/

      assert_raise ParseError,
                   message,
                   fn ->
                     defmodule TestBadGlobalAttrComponent do
                       use Phoenix.Component

                       def fun(assigns) do
                         ~H"""
                         <style :type={Phoenix.LiveView.ColocatedCSS} global="bad">
                           .sample-class { background-color: #FFFFFF; }
                         </style>
                         """
                       end
                     end
                   end
    after
      :code.delete(__MODULE__.TestBadGlobalAttrComponent)
      :code.purge(__MODULE__.TestBadGlobalAttrComponent)
    end

    test "raises if scoped css specific options are provided" do
      message =
        ~r/colocated css must be scoped to use the `lower-bound` attribute, but `global` attribute was provided/

      assert_raise ParseError,
                   message,
                   fn ->
                     defmodule TestScopedAttrWhileGlobalComponent do
                       use Phoenix.Component

                       def fun(assigns) do
                         ~H"""
                         <style :type={Phoenix.LiveView.ColocatedCSS} global lower-bound="inclusive">
                           .sample-class { background-color: #FFFFFF; }
                         </style>
                         """
                       end
                     end
                   end
    after
      :code.delete(__MODULE__.TestScopedAttrWhileGlobalComponent)
      :code.purge(__MODULE__.TestScopedAttrWhileGlobalComponent)
    end
  end

  describe "scoped styles" do
    test "with exclusive (default) lower-bound is extracted and available under manifest import" do
      defmodule TestScopedExclusiveComponent do
        use Phoenix.Component

        def fun(assigns) do
          ~H"""
          <style :type={Phoenix.LiveView.ColocatedCSS}>
            .sample-class { background-color: #FFFFFF; }
          </style>
          """
        end
      end

      assert module_folders =
               File.ls!(
                 Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view")
               )

      assert folder =
               Enum.find(module_folders, fn folder ->
                 folder =~ ~r/#{inspect(__MODULE__)}\.TestScopedExclusiveComponent$/
               end)

      assert [style] =
               Path.wildcard(
                 Path.join(
                   Mix.Project.build_path(),
                   "phoenix-colocated/phoenix_live_view/#{folder}/*.css"
                 )
               )

      file_contents = File.read!(style)

      file_contents =
        Regex.replace(~r/\[phx-css-.+?\]/, file_contents, ~s|[phx-css-SCOPE_HERE]|)

      # The scope is a generated value, so for testing reliability we just replace it with a known
      # value to assert against.
      assert file_contents ==
               ~s|@scope ([phx-css-SCOPE_HERE]) to ([phx-r]) { \n  .sample-class { background-color: #FFFFFF; }\n }|

      # now write the manifest manually as we are in a test
      Phoenix.LiveView.ColocatedAssets.compile()

      assert manifest =
               File.read!(
                 Path.join(
                   Mix.Project.build_path(),
                   "phoenix-colocated/phoenix_live_view/colocated.css"
                 )
               )

      path =
        Path.relative_to(
          style,
          Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view/")
        )

      # style is in manifest
      assert manifest =~ ~s[@import "./#{path}";\n]
    after
      :code.delete(__MODULE__.TestScopedExclusiveComponent)
      :code.purge(__MODULE__.TestScopedExclusiveComponent)
    end

    test "with inclusive lower-bound is extracted and available under manifest import" do
      defmodule TestScopedInclusiveComponent do
        use Phoenix.Component

        def fun(assigns) do
          ~H"""
          <style :type={Phoenix.LiveView.ColocatedCSS} lower-bound="inclusive">
            .sample-class { background-color: #FFFFFF; }
          </style>
          """
        end
      end

      assert module_folders =
               File.ls!(
                 Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view")
               )

      assert folder =
               Enum.find(module_folders, fn folder ->
                 folder =~ ~r/#{inspect(__MODULE__)}\.TestScopedInclusiveComponent$/
               end)

      assert [style] =
               Path.wildcard(
                 Path.join(
                   Mix.Project.build_path(),
                   "phoenix-colocated/phoenix_live_view/#{folder}/*.css"
                 )
               )

      file_contents = File.read!(style)

      file_contents =
        Regex.replace(~r/\[phx-css-.+?\]/, file_contents, ~s|[phx-css-SCOPE_HERE]|)

      # The scope is a generated value, so for testing reliability we just replace it with a known
      # value to assert against.
      assert file_contents ==
               ~s|@scope ([phx-css-SCOPE_HERE]) to ([phx-r] > *) { \n  .sample-class { background-color: #FFFFFF; }\n }|

      # now write the manifest manually as we are in a test
      Phoenix.LiveView.ColocatedAssets.compile()

      assert manifest =
               File.read!(
                 Path.join(
                   Mix.Project.build_path(),
                   "phoenix-colocated/phoenix_live_view/colocated.css"
                 )
               )

      path =
        Path.relative_to(
          style,
          Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view/")
        )

      # style is in manifest
      assert manifest =~ ~s[@import "./#{path}";\n]
    after
      :code.delete(__MODULE__.TestScopedInclusiveComponent)
      :code.purge(__MODULE__.TestScopedInclusiveComponent)
    end

    test "raises for invalid lower-bound attribute value" do
      message =
        ~r/expected "inclusive" or "exclusive" for the `lower-bound` attribute of colocated css, got: "unknown"/

      assert_raise ParseError,
                   message,
                   fn ->
                     defmodule TestBadLowerBoundAttrComponent do
                       use Phoenix.Component

                       def fun(assigns) do
                         ~H"""
                         <style :type={Phoenix.LiveView.ColocatedCSS} lower-bound="unknown">
                           .sample-class { background-color: #FFFFFF; }
                         </style>
                         """
                       end
                     end
                   end
    after
      :code.delete(__MODULE__.TestBadLowerBoundAttrComponent)
      :code.purge(__MODULE__.TestBadLowerBoundAttrComponent)
    end
  end

  test "writes empty manifest when no colocated styles exist" do
    manifest =
      Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view/colocated.css")

    Phoenix.LiveView.ColocatedAssets.compile()
    assert File.exists?(manifest)
    assert File.read!(manifest) == ""
  end
end
