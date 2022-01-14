defmodule Phoenix.LiveViewTest.ComponentAndNestedInLive do
  use Phoenix.LiveView

  defmodule NestedLive do
    use Phoenix.LiveView

    def mount(_params, _session, socket) do
      {:ok, assign(socket, :hello, "hello")}
    end

    def render(assigns) do
      ~H"<div><%= @hello %></div>"
    end

    def handle_event("disable", _params, socket) do
      send(socket.parent_pid, :disable)
      {:noreply, socket}
    end
  end

  defmodule NestedComponent do
    use Phoenix.LiveComponent

    def mount(socket) do
      {:ok, assign(socket, :world, "world")}
    end

    def render(assigns) do
      ~H"<div><%= @world %></div>"
    end
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :enabled, true)}
  end

  def render(assigns) do
    ~H"""
      <%= if @enabled do %>
        <%= live_render @socket, NestedLive, id: :nested_live %>
        <%= live_component NestedComponent, id: :_component %>
      <% end %>
    """
  end

  def handle_event("disable", _, socket) do
    {:noreply, assign(socket, :enabled, false)}
  end
end

