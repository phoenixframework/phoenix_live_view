defmodule Phoenix.LiveViewTest.DebugAnno do
  use Phoenix.Component, debug_heex_annotations: true

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
