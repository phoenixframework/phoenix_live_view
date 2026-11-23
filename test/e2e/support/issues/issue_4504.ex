defmodule Phoenix.LiveViewTest.E2E.Issue4504Live do
  use Phoenix.LiveView

  def mount(params, _session, socket) do
    {:ok, assign(socket, q: "", patch_focused: Map.get(params, "patch_focused", "empty"))}
  end

  def render(assigns) do
    ~H"""
    <form id="search" phx-change="q">
      <input
        id="q"
        name="q"
        value={@q}
        phx-patch-focused={@patch_focused == "always" or (@patch_focused == "empty" and @q == "")}
        autocomplete="off"
      />
    </form>
    <p>server: <span id="server">{@q}</span></p>
    """
  end

  def handle_event("q", %{"q" => q}, socket) do
    {:noreply, assign(socket, :q, q)}
  end
end
