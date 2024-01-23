defmodule Phoenix.LiveViewTest.E2E.Issue3044Live do
  use Phoenix.LiveView

  @impl Phoenix.LiveView
  def mount(_, _, socket) do
    {:ok, assign(socket, :disabled, false)}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle", _, socket) do
    {:noreply, update(socket, :disabled, &(not &1))}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <input
      value={if @disabled, do: "disabled", else: "not disabled"}
      disabled={@disabled}
      phx-update="ignore"
      id="test-input"
    />
    <button phx-click="toggle">Toggle</button>
    """
  end
end
