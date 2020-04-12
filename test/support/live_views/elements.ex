defmodule Phoenix.LiveViewTest.ElementsLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div id="last-event"><%= @event %></div>
    <div id="scoped-render"><span>This</span> is a div</div>
    <div>This</div>
    <span id="span-no-attr">This is a span</span>
    <span id="span-click-no-value" phx-click="span-click">This is a span</span>
    <span id="span-click-value" phx-click="span-click" value="123" phx-value-extra="456">This is a span</span>
    <span id="span-click-phx-value" phx-click="span-click" phx-value-foo="123" phx-value-bar="456">This is a span</span>
    <a id="a-no-attr">No href link</a>
    <a href="/" id="click-a" phx-click="link">Regular Link</a>
    <a href="/" id="redirect-a">Regular Link</a>
    <%= live_redirect "Live redirect", to: "/example", id: "live-redirect-a" %>
    <%= live_redirect "Live redirect", to: "/example", id: "live-redirect-replace-a", replace: true %>
    <%= live_patch "Live patch", to: "/elements?from=uri", id: "live-patch-a" %>
    <section phx-hook="Example" id="hook-section" phx-value-foo="ignore">Section</section>
    <section phx-hook="Example" class="idless-hook">Section</section>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :event, nil)}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, :event, "handle_params: #{inspect(params)}")}
  end

  def handle_event(event, value, socket) do
    {:noreply, assign(socket, :event, "#{event}: #{inspect(value)}")}
  end
end
