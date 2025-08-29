defmodule Phoenix.LiveViewTest.Support.PortalLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :count, 0)}
  end

  def render(assigns) do
    ~H"""
    <div id="main-content">
      <h1>Portal Test</h1>
      <p>Count: {@count}</p>
      <button phx-click="increment">Increment</button>

      <.portal id="test-portal" target="#fakebody">
        <div id="portal-content" class="modal">
          <h2>Portal Content</h2>
          <p>This content is teleported to body</p>
          <p>Current count: {@count}</p>
        </div>
      </.portal>

      <.portal id="footer-portal" target="#footer-target">
        <div id="footer-content">
          Footer content here (count: {@count})
        </div>
      </.portal>
    </div>

    <div id="fakebody"></div>
    <div id="footer-target"></div>
    """
  end

  def handle_event("increment", _params, socket) do
    {:noreply, update(socket, :count, &(&1 + 1))}
  end
end
