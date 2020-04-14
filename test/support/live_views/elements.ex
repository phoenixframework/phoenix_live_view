defmodule Phoenix.LiveViewTest.ElementsLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div id="last-event"><%= @event %></div>
    <div id="scoped-render"><span>This</span> is a div</div>
    <div>This</div>

    <span id="span-no-attr">This is a span</span>

    <span id="span-blur-no-value" phx-blur="span-blur">This is a span</span>
    <span id="span-blur-value" phx-blur="span-blur" value="123" phx-value-extra="456">This is a span</span>
    <span id="span-blur-phx-value" phx-blur="span-blur" phx-value-foo="123" phx-value-bar="456">This is a span</span>

    <span id="span-focus-no-value" phx-focus="span-focus">This is a span</span>
    <span id="span-focus-value" phx-focus="span-focus" value="123" phx-value-extra="456">This is a span</span>
    <span id="span-focus-phx-value" phx-focus="span-focus" phx-value-foo="123" phx-value-bar="456">This is a span</span>

    <span id="span-keyup-no-value" phx-keyup="span-keyup">This is a span</span>
    <span id="span-keyup-value" phx-keyup="span-keyup" value="123" phx-value-extra="456">This is a span</span>
    <span id="span-keyup-phx-value" phx-keyup="span-keyup" phx-value-foo="123" phx-value-bar="456">This is a span</span>
    <span id="span-window-keyup-phx-value" phx-window-keyup="span-window-keyup" phx-value-foo="123" phx-value-bar="456">This is a span</span>

    <span id="span-keydown-no-value" phx-keydown="span-keydown">This is a span</span>
    <span id="span-keydown-value" phx-keydown="span-keydown" value="123" phx-value-extra="456">This is a span</span>
    <span id="span-keydown-phx-value" phx-keydown="span-keydown" phx-value-foo="123" phx-value-bar="456">This is a span</span>
    <span id="span-window-keydown-phx-value" phx-window-keydown="span-window-keydown" phx-value-foo="123" phx-value-bar="456">This is a span</span>

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
