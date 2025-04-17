defmodule Phoenix.LiveViewTest.E2E.Issue3612.ALive do
  # https://github.com/phoenixframework/phoenix_live_view/issues/3612

  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    {live_render(@socket, Phoenix.LiveViewTest.E2E.Issue3612.StickyLive,
      id: "sticky",
      sticky: true
    )}

    <h1>Page A</h1>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3612.BLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    {live_render(@socket, Phoenix.LiveViewTest.E2E.Issue3612.StickyLive,
      id: "sticky",
      sticky: true
    )}

    <h1>Page B</h1>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3612.StickyLive do
  use Phoenix.LiveView

  def mount(:not_mounted_at_router, _session, socket) do
    {:ok, socket, layout: false}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.link phx-click="navigate_to_a">Go to page A</.link>
      <.link phx-click="navigate_to_b">Go to page B</.link>
    </div>
    """
  end

  def handle_event("navigate_to_a", _params, socket) do
    {:noreply, push_navigate(socket, to: "/issues/3612/a")}
  end

  def handle_event("navigate_to_b", _params, socket) do
    {:noreply, push_navigate(socket, to: "/issues/3612/b")}
  end
end
