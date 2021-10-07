defmodule Phoenix.LiveViewTest.InnerCounter do
  use Phoenix.LiveComponent

  def mount(socket) do
    {:ok, assign(socket, :value, 0)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <button id="inner" phx-click="inc" phx-target={@myself}>+</button>
      <p><%= render_slot(@default_slot, @value) %></p>
    </div>
    """
  end

  def handle_event("inc", _, socket) do
    {:noreply, update(socket, :value, &(&1 + 1))}
  end
end

defmodule Phoenix.LiveViewTest.InnerLive do
  use Phoenix.LiveView

  def mount(_params, %{"test_process" => test_process}, socket) do
    {:ok, assign(socket, test_process: test_process, outer: 0)}
  end

  def render(assigns) do
    ~H"""
    <button id="outer" phx-click="inc">+</button>

    <.live_component let={value} module={Phoenix.LiveViewTest.InnerCounter} id="counter">
      Outer: <%= send(@test_process, @outer) %>
      Inner: <%= value %>
    </.live_component>
    """
  end

  def handle_event("inc", _, socket) do
    {:noreply, update(socket, :outer, &(&1 + 1))}
  end
end
