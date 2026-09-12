defmodule Phoenix.LiveViewTest.Support.ReloadLive do
  use Phoenix.LiveView

  alias Phoenix.LiveViewTest.Support.ReloadLive.Component

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    assigns = assign(assigns, :vsn, Application.fetch_env!(:phoenix_live_view, :vsn))

    ~H"""
    <div>Version {@vsn}</div>
    <.live_component module={Component} id="reload-component" />
    """
  end
end

defmodule Phoenix.LiveViewTest.Support.ReloadLive.Component do
  use Phoenix.LiveComponent

  def mount(socket) do
    {:ok, assign(socket, :count, 0)}
  end

  def handle_event("inc", _params, socket) do
    {:noreply, update(socket, :count, &(&1 + 1))}
  end

  def render(assigns) do
    case Application.fetch_env!(:phoenix_live_view, :vsn) do
      1 ->
        ~H"""
        <button id={@id} class="version-one" phx-click="inc" phx-target={@myself}>
          Component version 1, count {@count}
        </button>
        """

      2 ->
        ~H"""
        <button id={@id} class="version-two" phx-click="inc" phx-target={@myself}>
          Component version 2, count {@count}
        </button>
        """
    end
  end
end
