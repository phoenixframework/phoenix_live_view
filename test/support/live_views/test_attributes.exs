# Note this file is intentionally a .exs file because it is loaded
# in the test helper with strip_test_attributes turned on.
defmodule Phoenix.LiveViewTest.Support.TestAttributes do
  use Phoenix.Component

  def with_value(assigns) do
    ~H"<div data-test-id={@test_id}></div>"
  end

  def with_static_value(assigns) do
    ~H"""
    <div data-test-name="foo"></div>
    """
  end

  def without_value(assigns) do
    ~H"<div data-test-attr></div>"
  end
end
