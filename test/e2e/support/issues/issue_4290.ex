defmodule Phoenix.LiveViewTest.E2E.Issue4290 do
  # https://github.com/phoenixframework/phoenix_live_view/issues/4290

  defmodule ALive do
    use Phoenix.LiveView

    alias Phoenix.LiveView.JS

    def render(assigns) do
      ~H"""
      <h1>A</h1>
      <%!-- the phx-remove transition delays the swap of the main element until well
            after the new LiveView joined, keeping the old DOM visible and interactive --%>
      <div id="slow-remove" phx-remove={JS.transition("fade-out", time: 1500)}>
        removed with transition
      </div>
      <form id="form" phx-change="validate">
        <input type="text" name="name" />
      </form>
      <button phx-click="navigate">Navigate</button>
      """
    end

    def handle_event("navigate", _params, socket) do
      {:noreply, push_navigate(socket, to: "/issues/4290/b")}
    end

    def handle_event("validate", _params, socket) do
      {:noreply, socket}
    end
  end

  defmodule BLive do
    use Phoenix.LiveView

    def mount(_params, _session, socket) do
      {:ok, assign(socket, events: [])}
    end

    def render(assigns) do
      ~H"""
      <h1>B</h1>
      <span id="event-count">{length(@events)}</span>
      <div :for={{event, idx} <- Enum.with_index(@events)} id={"event-#{idx}"}>{event}</div>
      """
    end

    def handle_event(event, _params, socket) do
      {:noreply, update(socket, :events, &(&1 ++ [event]))}
    end
  end
end
