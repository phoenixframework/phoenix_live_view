defmodule Phoenix.LiveViewTest.E2E.Issue3378.NotificationsLive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream(:notifications, [%{id: 1, message: "Hello"}])}
  end

  def render(assigns) do
    ~H"""
    <div>
      <ul id="notifications_list" phx-update="stream">
        <div :for={{dom_id, _notification} <- @streams.notifications} id={dom_id}>
          <p>big!</p>
        </div>
      </ul>
    </div>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3378.AppBarLive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      {live_render(
        @socket,
        Phoenix.LiveViewTest.E2E.Issue3378.NotificationsLive,
        session: %{},
        id: :notifications
      )}
    </div>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3378.HomeLive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    {live_render(
      @socket,
      Phoenix.LiveViewTest.E2E.Issue3378.AppBarLive,
      session: %{},
      id: :appbar
    )}
    """
  end
end
