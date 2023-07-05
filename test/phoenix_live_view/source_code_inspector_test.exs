defmodule Phoenix.LiveView.SourceCodeInspectorTest do
  use ExUnit.Case, async: true

  require Phoenix.LiveView.SourceCodeInspector, as: SourceCodeInspector
  import Phoenix.Component

  # Activate the source code inspector at compile time so that
  # all templates in this module are compiled with support
  # for source code inspection
  SourceCodeInspector.activate_locally()

  defp render(template) do
    template
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  test "flat component" do
    assigns = %{class: "fancy-label", text: "Label #1"}
    template = ~H|<span class={@class}><%= @text %></span>|

    dom_without_inspector =
      SourceCodeInspector.with_source_code_inspector_disabled(fn ->
        render(template)
      end)

    dom_with_inspector =
      SourceCodeInspector.with_source_code_inspector_enabled(fn ->
        render(template)
      end)

    assert dom_without_inspector =~ ~s|<span|
    assert dom_without_inspector =~ ~s|class="fancy-label"|
    assert dom_without_inspector =~ ~s|Label #1|
    assert dom_without_inspector =~ ~s|</span>|
    # None of the inspector attributes are rendered
    refute dom_without_inspector =~ ~s|data-source-code-inspector|
    # The special attributes related to the hook are not rendered
    refute dom_without_inspector =~ ~s|id=|
    refute dom_without_inspector =~ ~s|phx-hook=|


    assert dom_with_inspector =~ ~s|<span|
    assert dom_with_inspector =~ ~s|class="fancy-label"|
    assert dom_with_inspector =~ ~s|Label #1|
    assert dom_with_inspector =~ ~s|</span>|

    assert dom_with_inspector =~ ~s|data-source-code-inspector="true"|
    assert dom_with_inspector =~ ~s|data-source-code-inspector-file=|
    assert dom_with_inspector =~ ~s|data-source-code-inspector-line=|
    assert dom_with_inspector =~ ~s|data-source-code-inspector-tooltip=|
    # The hook and the id are rendered
    assert dom_with_inspector =~ ~s|phx-hook="SourceCodeInspector"|
    assert dom_with_inspector =~ ~s|id="|
  end

  SourceCodeInspector.deactivate_locally()
end
