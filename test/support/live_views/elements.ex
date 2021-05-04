defmodule Phoenix.LiveViewTest.ElementsLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <%# lookups %>
    <div id="last-event"><%= @event %></div>
    <div id="scoped-render"><span>This</span> is a div</div>
    <div>This</div>

    <%# basic render_* %>
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

    <button id="button-disabled-click" phx-click="button-click" disabled>This is a button</button>
    <span id="span-click-no-value" phx-click="span-click">This is a span</span>
    <span id="span-click-value" phx-click="span-click" value="123" phx-value-extra="&lt;456&gt;">This is a span</span>
    <span id="span-click-phx-value" phx-click="span-click" phx-value-foo="123" phx-value-bar="456">This is a span</span>

    <%# link handling %>
    <a id="a-no-attr">No href link</a>
    <a href="/" id="click-a" phx-click="link">Regular Link</a>
    <a href="/" id="redirect-a">Regular Link</a>
    <%= live_redirect "Live redirect", to: "/example", id: "live-redirect-a" %>
    <%= live_redirect "Live redirect", to: "/example", id: "live-redirect-replace-a", replace: true %>
    <%= live_patch "Live patch", to: "/elements?from=uri", id: "live-patch-a" %>

    <%# hooks %>
    <section phx-hook="Example" id="hook-section" phx-value-foo="ignore">Section</section>
    <section phx-hook="Example" class="idless-hook">Section</section>

    <%# forms %>
    <a id="a-no-form" phx-change="hello" phx-submit="world">Change</a>
    <form id="empty-form" phx-change="form-change" phx-submit="form-submit" phx-value-key="value">
    </form>
    <form id="form" phx-change="form-change" phx-submit="form-submit" phx-value-key="value">
      <input value="no-name">
      <input name="hello[disabled]" value="value" disabled>
      <input name="hello[no-type]" value="value">
      <input name="hello[latest]" type="text" value="old">
      <input name="hello[latest]" type="text" value="new">
      <input name="hello[hidden]" type="hidden" value="hidden">
      <input name="hello[hidden_or_checkbox]" type="hidden" value="false">
      <input name="hello[hidden_or_checkbox]" type="checkbox" value="true">
      <input name="hello[hidden_or_text]" type="hidden" value="false">
      <input name="hello[hidden_or_text]" type="text" value="true">
      <input name="hello[radio]" type="radio" value="1">
      <input name="hello[radio]" type="radio" value="2" checked>
      <input name="hello[radio]" type="radio" value="3">
      <input name="hello[not-checked-radio]" type="radio" value="1">
      <input name="hello[disabled-radio]" type="radio" value="1" checked disabled>
      <input name="hello[checkbox]" type="checkbox" value="1">
      <input name="hello[checkbox]" type="checkbox" value="2" checked>
      <input name="hello[checkbox]" type="checkbox" value="3">
      <input name="hello[not-checked-checkbox]" type="checkbox" value="1">
      <input name="hello[disabled-checkbox]" type="checkbox" value="1" checked disabled>
      <input name="hello[multiple-checkbox][]" type="checkbox" value="1">
      <input name="hello[multiple-checkbox][]" type="checkbox" value="2" checked>
      <input name="hello[multiple-checkbox][]" type="checkbox" value="3" checked>
      <select name="hello[not-selected]">
        <option value="blank">None</option>
        <option value="1">One</option>
        <option value="2">Two</option>
      </select>
      <select name="hello[selected]">
        <option value="blank">None</option>
        <option value="1" selected>One</option>
        <option value="2">Two</option>
      </select>
      <select name="hello[multiple-select][]" multiple>
        <option value="1">One</option>
        <option value="2" selected>Two</option>
        <option value="3" selected>Three</option>
      </select>
      <textarea name="hello[textarea]">Text</textarea>
      <!-- Mimic textarea from Phoenix.HTML -->
      <textarea name="hello[textarea_nl]">
    Text</textarea>
      <input name="hello[ignore-submit]" type="submit" value="ignored">
      <input name="hello[ignore-image]" type="image" value="ignored">
      <input name="hello[date_text]" type="text">
      <%= Phoenix.HTML.Form.date_select :hello, :date_select %>
      <input name="hello[time_text]" type="text">
      <%= Phoenix.HTML.Form.time_select :hello, :time_select %>
      <input name="hello[naive_text]" type="text">
      <%= Phoenix.HTML.Form.datetime_select :hello, :naive_select %>
      <input name="hello[utc_text]" type="text">
      <%= Phoenix.HTML.Form.datetime_select :hello, :utc_select, second: [] %>
    </form>

    <form id="trigger-form-default" phx-submit="form-submit-trigger"
          <%= @trigger_action && "phx-trigger-action" %>>
    </form>

    <form id="trigger-form-value" action="/not_found" method="POST" phx-submit="form-submit-trigger"
          <%= @trigger_action && "phx-trigger-action" %>>
    </form>
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:event, nil)
      |> assign(:trigger_action, false)

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, :event, "handle_params: #{inspect(params)}")}
  end

  def handle_event("form-submit-trigger", _value, socket) do
    {:noreply, assign(socket, :trigger_action, true)}
  end

  def handle_event(event, value, socket) do
    {:noreply, assign(socket, :event, "#{event}: #{inspect(value)}")}
  end
end
