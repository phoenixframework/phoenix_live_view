# Note this file is intentionally a .exs file because it is loaded
# in the test helper with debug_heex_annotations turned on.
defmodule Phoenix.LiveViewTest.Support.DebugAnno do
  use Phoenix.Component

  def remote(assigns) do
    ~H"REMOTE COMPONENT: Value: {@value}"
  end

  def remote_with_tags(assigns) do
    ~H"<div>REMOTE COMPONENT: Value: {@value}</div>"
  end

  def local(assigns) do
    ~H"LOCAL COMPONENT: Value: {@value}"
  end

  def local_with_tags(assigns) do
    ~H"<div>LOCAL COMPONENT: Value: {@value}</div>"
  end

  def nested(assigns) do
    ~H"""
    <div>
      <.local_with_tags value="local" />
    </div>
    """
  end

  def slot(assigns) do
    ~H"""
    <.intersperse :let={num} enum={[1, 2]}>
      <:separator>,</:separator>
      {num}
    </.intersperse>
    """
  end

  def slot_with_tags(assigns) do
    ~H"""
    <.intersperse :let={num} enum={[1, 2]}>
      <:separator><hr /></:separator>
      <div>{num}</div>
    </.intersperse>
    """
  end
end
