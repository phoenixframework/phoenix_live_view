defmodule Phoenix.LiveViewTest.ElementsLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div id="last-event"><%= @event %></div>
    <div id="scoped-render"><span>This</span> is a div</div>
    <div>This</div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :event, nil)}
  end
end