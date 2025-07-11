defmodule Phoenix.LiveViewTest.Support.ElementsLive do
  use Phoenix.LiveView

  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <%!-- lookups --%>
    <div id="last-event">{@event}</div>
    <div id="scoped-render"><span>This</span> is a div</div>
    <div>This</div>
    <div id="child-component">
      <.live_component module={Phoenix.LiveViewTest.Support.ElementsComponent} id={1} />
    </div>
    <span phx-no-format>
      Normalize
      <span> whitespace</span>
    </span>

    <%!-- basic render_* --%>
    <span id="span-no-attr">This is a span</span>

    <span id="span-blur-no-value" phx-blur="span-blur">This is a span</span>
    <span id="span-blur-value" phx-blur="span-blur" value="123" phx-value-extra="456">
      This is a span
    </span>
    <span id="span-blur-phx-value" phx-blur="span-blur" phx-value-foo="123" phx-value-bar="456">
      This is a span
    </span>

    <span id="span-focus-no-value" phx-focus="span-focus">This is a span</span>
    <span id="span-focus-value" phx-focus="span-focus" value="123" phx-value-extra="456">
      This is a span
    </span>
    <span id="span-focus-phx-value" phx-focus="span-focus" phx-value-foo="123" phx-value-bar="456">
      This is a span
    </span>

    <span id="span-keyup-no-value" phx-keyup="span-keyup">This is a span</span>
    <span id="span-keyup-value" phx-keyup="span-keyup" value="123" phx-value-extra="456">
      This is a span
    </span>
    <span id="span-keyup-phx-value" phx-keyup="span-keyup" phx-value-foo="123" phx-value-bar="456">
      This is a span
    </span>
    <span
      id="span-window-keyup-phx-value"
      phx-window-keyup="span-window-keyup"
      phx-value-foo="123"
      phx-value-bar="456"
    >
      This is a span
    </span>

    <span id="span-keydown-no-value" phx-keydown="span-keydown">This is a span</span>
    <span id="span-keydown-value" phx-keydown="span-keydown" value="123" phx-value-extra="456">
      This is a span
    </span>
    <span
      id="span-keydown-phx-value"
      phx-keydown="span-keydown"
      phx-value-foo="123"
      phx-value-bar="456"
    >
      This is a span
    </span>
    <span
      id="span-window-keydown-phx-value"
      phx-window-keydown="span-window-keydown"
      phx-value-foo="123"
      phx-value-bar="456"
    >
      This is a span
    </span>

    <button id="button-js-click" phx-click={JS.push("button-click")}>This is a JS button</button>
    <button id="button-js-click-value" phx-click={JS.push("button-click", value: %{one: 1})}>
      This is a JS button with a value
    </button>
    <button id="button-disabled-click" phx-click="button-click" disabled>This is a button</button>
    <span id="span-click-no-value" phx-click="span-click">This is a span</span>
    <span id="span-click-value" phx-click="span-click" value="123" phx-value-extra="&lt;456&gt;">
      This is a span
    </span>
    <span id="span-click-phx-value" phx-click="span-click" phx-value-foo="123" phx-value-bar="456">
      This is a span
    </span>

    <%!-- link handling --%>
    <a id="a-no-attr">No href link</a>
    <a href="/" id="click-a" phx-click="link">Regular Link</a>
    <a href="/" id="redirect-a">Regular Link</a>
    <.link navigate="/example" id="live-redirect-a">Live redirect</.link>
    <.link navigate="/example" id="live-redirect-replace-a" replace>Live redirect</.link>
    <%!-- unrelated phx-click does not disable patching --%>
    <.link patch="/elements?from=uri" id="live-patch-a" phx-click={JS.dispatch("noop")}>
      Live patch
    </.link>

    <button type="button" id="live-patch-button" phx-click={JS.patch("/elements?from=uri")}>
      Live patch button
    </button>
    <button
      type="button"
      id="live-push-patch-button"
      phx-click={JS.push("foo") |> JS.patch("/elements?from=uri")}
    >
      Live push patch button
    </button>
    <button type="button" id="live-redirect-push-button" phx-click={JS.navigate("/example")}>
      Live redirect
    </button>
    <button
      type="button"
      id="live-redirect-replace-button"
      phx-click={JS.navigate("/example", replace: true)}
    >
      Live redirect
    </button>
    <button
      type="button"
      id="live-redirect-patch-button"
      phx-click={JS.navigate("/example", replace: true) |> JS.patch("/elements?from=uri")}
    >
      Last one wins
    </button>

    <%!-- hooks --%>
    <section phx-hook="Example" id="hook-section" phx-value-foo="ignore">Section</section>
    <section phx-hook="Example" id="hook-section-2" class="idless-hook">Section</section>

    <ul id="posts" phx-update="stream" phx-viewport-top="prev-page" phx-viewport-bottom="next-page" />

    <%!-- forms --%>
    <a id="a-no-form" phx-change="hello" phx-submit="world">Change</a>
    <form id="empty-form" phx-change="form-change" phx-submit="form-submit"></form>
    <form
      id="phx-value-form"
      phx-change="form-change"
      phx-submit="form-submit"
      phx-value-key="val"
      phx-value-foo="bar"
    >
    </form>
    <form id="form" phx-change="form-change" phx-submit="form-submit" phx-value-key="value">
      <input value="no-name" />
      <input name="hello[disabled]" value="value" disabled />
      <input name="hello[no-type]" value="value" />
      <input name="hello[latest]" type="text" value="old" />
      <input name="hello[latest]" type="text" value="new" />
      <input name="hello[hidden]" type="hidden" value="hidden" />
      <input name="hello[hidden_or_checkbox]" type="hidden" value="false" />
      <input name="hello[hidden_or_checkbox]" type="checkbox" value="true" />
      <input name="hello[hidden_or_text]" type="hidden" value="false" />
      <input name="hello[hidden_or_text]" type="text" value="true" />
      <input name="hello[radio]" type="radio" value="1" />
      <input name="hello[radio]" type="radio" value="2" checked />
      <input name="hello[radio]" type="radio" value="3" />
      <input name="hello[not-checked-radio]" type="radio" value="1" />
      <input name="hello[disabled-radio]" type="radio" value="1" checked disabled />
      <input name="hello[checkbox]" type="checkbox" value="1" />
      <input name="hello[checkbox]" type="checkbox" value="2" checked />
      <input name="hello[checkbox]" type="checkbox" value="3" />
      <input name="hello[checkbox_no_value]" type="checkbox" />
      <input name="hello[not-checked-checkbox]" type="checkbox" value="1" />
      <input name="hello[disabled-checkbox]" type="checkbox" value="1" checked disabled />
      <input name="hello[multiple-checkbox][]" type="checkbox" value="1" />
      <input name="hello[multiple-checkbox][]" type="checkbox" value="2" checked />
      <input name="hello[multiple-checkbox][]" type="checkbox" value="3" checked />
      <select name="hello[not-selected]">
        <option value="" disabled>Disabled Prompt</option>
        <option value="blank">None</option>
        <option value="1">One</option>
        <option value="2">Two</option>
      </select>
      <select name="hello[not-selected-treeorder]">
        <option value="" disabled>Disabled Prompt</option>
        <optgroup label="Nested">
          <option value="blank">None</option>
          <option value="1">One</option>
        </optgroup>
        <option value="2">Two</option>
      </select>
      <select name="hello[not-selected-size]" size="3">
        <option value="blank">None</option>
        <option value="1">One</option>
        <option value="2">Two</option>
      </select>
      <select name="hello[selected]">
        <option value="blank">None</option>
        <option value="1" selected>One</option>
        <option value="2">Two</option>
      </select>
      <select name="hello[invalid-multiple-selected]">
        <option value="1">One</option>
        <option value="2" selected>Two</option>
        <option value="3" selected>Three</option>
      </select>
      <select name="hello[multiple-select][]" multiple>
        <option value="1">One</option>
        <option value="2" selected>Two</option>
        <option value="3" selected>Three</option>
      </select>
      <textarea name="hello[textarea]">Text</textarea>
      <textarea name="hello[textarea_empty]"></textarea>
      <!-- Mimic textarea from Phoenix.HTML -->
      <textarea name="hello[textarea_nl]">
    Text</textarea>
      <input name="hello[ignore-submit]" type="submit" value="ignored" />
      <input name="hello[ignore-image]" type="image" value="ignored" />
      <input name="hello[date_text]" type="text" />
      {PhoenixHTMLHelpers.Form.date_select(:hello, :date_select)}
      <input name="hello[time_text]" type="text" />
      {PhoenixHTMLHelpers.Form.time_select(:hello, :time_select)}
      <input name="hello[naive_text]" type="text" />
      {PhoenixHTMLHelpers.Form.datetime_select(:hello, :naive_select)}
      <input name="hello[utc_text]" type="text" />
      {PhoenixHTMLHelpers.Form.datetime_select(:hello, :utc_select, second: [])}
      <input name="hello[individual]" type="text" phx-change="individual-changed" />
    </form>

    <form id="submitter-form" phx-submit="form-submit">
      <input name="data[a]" type="hidden" value="b" />
      <input name="input" type="submit" value="yes" />
      <input name="input_disabled" type="submit" value="yes" disabled />
      <input name="data[nested]" id="data-nested" type="submit" value="yes" />
      <input id="input_no_name" type="submit" value="yes" />
      <button name="button" type="submit" value="yes">button</button>
      <button name="button_disabled" type="submit" value="yes" disabled />
      <button name="button_no_submit" type="button" value="this_value_should_never_appear">
        button_no_submit
      </button>
      <button name="button_no_type" value="yes">button_no_type</button>
      <button name="button_no_value">Button No Value</button>
    </form>

    <form
      id="trigger-form-default"
      phx-submit="form-submit-trigger"
      phx-trigger-action={@trigger_action}
    >
    </form>

    <form id="submit-form-default" action="/not_found"></form>

    <form
      id="trigger-form-value"
      action="/not_found"
      method="POST"
      phx-submit="form-submit-trigger"
      phx-trigger-action={@trigger_action}
    >
    </form>

    <form id="named" phx-submit="form-submit-named">
      <input name="child" />
    </form>
    <input form="named" name="foo" />
    <textarea form="named" name="bar" />
    <select form="named" name="baz">
      <option value="c">c</option>
    </select>
    <button form="named" name="btn" type="submit" value="x">Submit</button>

    <%!-- @page_title assign is unique --%>
    <svg>
      <title>SVG with title</title>
    </svg>
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

defmodule Phoenix.LiveViewTest.Support.ElementsComponent do
  use Phoenix.LiveComponent

  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <div>
      <div id="component-last-event">{@event}</div>

      <button
        id="component-button-js-click-target"
        phx-click={JS.push("button-click", target: @myself)}
      >
        button
      </button>
    </div>
    """
  end

  def mount(socket) do
    socket = assign(socket, :event, nil)

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, :event, "handle_params: #{inspect(params)}")}
  end

  def handle_event(event, value, socket) do
    {:noreply, assign(socket, :event, "#{event}: #{inspect(value)}")}
  end
end
