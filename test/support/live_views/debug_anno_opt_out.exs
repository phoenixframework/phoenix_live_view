# Note this file is intentionally a .exs file because it is loaded
# in the test helper with debug_heex_annotations turned on.
defmodule Phoenix.LiveViewTest.Support.DebugAnnoOptOut do
  use Phoenix.Component

  @debug_heex_annotations false
  @debug_attributes false

  def slot_with_tags(assigns) do
    ~H"""
    <.intersperse :let={num} enum={[1, 2]}>
      <:separator><hr /></:separator>
      <div>{num}</div>
    </.intersperse>
    """
  end
end
