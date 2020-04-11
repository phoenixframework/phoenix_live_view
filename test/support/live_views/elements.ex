defmodule Phoenix.LiveViewTest.ElementsLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div id="last-event"><%= @event %></div>
    <div id="scoped-render"><span>This</span> is a div</div>
    <div>This</div>
    <span id="span-no-attr">This is a span</span>
    <span id="span-click-no-value" phx-click="span-click">This is a span</span>
    <span id="span-click-value" phx-click="span-click" phx-value-foo="123" phx-value-bar="456">This is a span</span>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :event, nil)}
  end

  def handle_event(event, value, socket) do
    {:noreply, assign(socket, :event, "#{event}: #{inspect(value)}")}
  end
end
