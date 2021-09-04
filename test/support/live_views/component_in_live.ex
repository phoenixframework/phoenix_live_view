defmodule Phoenix.LiveViewTest.ComponentInLive.Root do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :enabled, true)}
  end

  def render(assigns) do
    ~H"<%= @enabled && live_render @socket, Phoenix.LiveViewTest.ComponentInLive.Live, id: :nested_live %>"
  end

  def handle_info(:disable, socket) do
    {:noreply, assign(socket, :enabled, false)}
  end
end

defmodule Phoenix.LiveViewTest.ComponentInLive.Live do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"<%= live_component Phoenix.LiveViewTest.ComponentInLive.Component, id: :nested_component %>"
  end

  def handle_event("disable", _params, socket) do
    send(socket.parent_pid, :disable)
    {:noreply, socket}
  end
end

defmodule Phoenix.LiveViewTest.ComponentInLive.Component do
  use Phoenix.LiveComponent

  # Make sure mount is calling by setting assigns in them.
  def mount(socket) do
    {:ok, assign(socket, world: "World")}
  end

  def update(_assigns, socket) do
    {:ok, assign(socket, hello: "Hello")}
  end

  def render(assigns) do
    ~H"<div><%= @hello %> <%= @world %></div>"
  end
end
