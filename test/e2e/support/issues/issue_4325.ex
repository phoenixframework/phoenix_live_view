defmodule Phoenix.LiveViewTest.E2E.Issue4325Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/4325
  use Phoenix.LiveView

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    assigns = %{}

    pre_script =
      ~H"""
      <script>
        window.issue4325Lifecycle = { mounted: 0, updated: 0, destroyed: 0 };
        window.hooks.IdPassthrough = {
          mounted() {
            window.issue4325Lifecycle.mounted++;
            this.js().setAttribute(this.el, "id", this.el.id);
          },
          updated() {
            window.issue4325Lifecycle.updated++;
          },
          destroyed() {
            window.issue4325Lifecycle.destroyed++;
          },
        };
      </script>
      """

    {:ok, assign(socket, count: 0, pre_script: pre_script)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <button phx-click="increment">Increment</button>
    <div id="hooked" phx-hook="IdPassthrough">count is {@count}</div>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("increment", _params, socket) do
    {:noreply, update(socket, :count, &(&1 + 1))}
  end
end
