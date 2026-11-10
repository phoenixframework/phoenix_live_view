defmodule Phoenix.LiveViewTest.E2E.AdoptLive do
  # An adoptable LiveView, see adopt.spec.js. The request mounts it, and the
  # client adopts it, so its mount id stays the same.
  use Phoenix.LiveView, adoptable: true

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    # the client receives the update after it attached
    if connected?(socket), do: send(self(), :tick)

    {:ok,
     assign(socket,
       mount_id: System.unique_integer([:positive]),
       connected: connected?(socket),
       clicks: 0,
       ticks: 0
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("click", _params, socket) do
    {:noreply, update(socket, :clicks, &(&1 + 1))}
  end

  @impl Phoenix.LiveView
  def handle_info(:tick, socket) do
    {:noreply, update(socket, :ticks, &(&1 + 1))}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <p>mount: <span id="mount-id">{@mount_id}</span></p>
    <p>connected: <span id="connected">{@connected}</span></p>
    <p>clicks: <span id="clicks">{@clicks}</span></p>
    <p>ticks: <span id="ticks">{@ticks}</span></p>
    <button id="click" phx-click="click">click</button>
    """
  end
end
