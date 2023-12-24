defmodule Phoenix.LiveViewTest.Layouts do
  use Phoenix.Component

  def on_mount(assigns) do
    ~H"""
    <div id="on-mount">
      <%= @inner_content %>
    </div>
    """
  end
end