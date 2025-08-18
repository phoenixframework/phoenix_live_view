defmodule Phoenix.LiveViewTest.E2E.Issue3953Live do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  alias Phoenix.LiveView.JS

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :show, false)}
  end

  def handle_event("toggle", _params, socket) do
    {:noreply, assign(socket, :show, !socket.assigns.show)}
  end

  def render(assigns) do
    ~H"""
    <.live_component module={Phoenix.LiveViewTest.E2E.Issue3953Live.Component} id="comp" />
    <button phx-click="toggle">Show</button>
    <%= if @show do %>
      {live_render(@socket, Phoenix.LiveViewTest.E2E.Issue3953Live.NestedViewLive,
        id: "nested_view",
        session: %{}
      )}
    <% end %>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3953Live.NestedViewLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    Nested Content
    <.live_component module={Phoenix.LiveViewTest.E2E.Issue3953Live.Component} id="comp2" />
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3953Live.Component do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div>
      Component
    </div>
    """
  end
end
