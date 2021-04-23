defmodule Phoenix.LiveViewTest.ComponentInLive.Root do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :enabled, true)}
  end

  def render(assigns) do
    ~L"<%= @enabled && live_render @socket, Phoenix.LiveViewTest.ComponentInLive.Live, id: :nested_live %>"
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
    ~L"<%= live_component Phoenix.LiveViewTest.ComponentInLive.Component, id: :nested_component %>"
  end

  def handle_event("disable", _params, socket) do
    send(socket.parent_pid, :disable)
    {:noreply, socket}
  end
end

defmodule Phoenix.LiveViewTest.ComponentInLive.Component do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"<div>Hello World</div>"
  end
end
