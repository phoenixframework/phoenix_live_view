# Note this file is intentionally a .exs file because it is loaded
# in the test helper with debug_heex_annotations turned on.
defmodule Phoenix.LiveViewTest.DebugAnno do
  use Phoenix.Component

  def remote(assigns) do
    ~H"REMOTE COMPONENT: Value: <%= @value %>"
  end

  def remote_with_root(assigns) do
    ~H"<div>REMOTE COMPONENT: Value: <%= @value %></div>"
  end

  def local(assigns) do
    ~H"LOCAL COMPONENT: Value: <%= @value %>"
  end

  def local_with_root(assigns) do
    ~H"<div>LOCAL COMPONENT: Value: <%= @value %></div>"
  end

  def nested(assigns) do
    ~H"""
    <div>
      <.local_with_root value="local" />
    </div>
    """
  end
end
