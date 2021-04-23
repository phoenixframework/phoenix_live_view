defmodule Phoenix.LiveViewTest.InnerCounter do
  use Phoenix.LiveComponent

  def mount(socket) do
    {:ok, assign(socket, :value, 0)}
  end

  def render(assigns) do
    ~L"""
    <div>
      <button id="inner" phx-click="inc" phx-target="<%= @myself %>">+</button>
      <p><%= render_block(@inner_block, value: @value) %></p>
    </div>
    """
  end

  def handle_event("inc", _, socket) do
    {:noreply, update(socket, :value, &(&1 + 1))}
  end
end

defmodule Phoenix.LiveViewTest.InnerDoLive do
  use Phoenix.LiveView

  def mount(_params, %{"test_process" => test_process}, socket) do
    {:ok, assign(socket, test_process: test_process, outer: 0)}
  end

  def render(assigns) do
    ~L"""
    <button id="outer" phx-click="inc">+</button>

    <%= live_component Phoenix.LiveViewTest.InnerCounter, id: "counter" do %>
      Outer: <%= send(@test_process, @outer) %>
      Inner: <%= @value %>
    <% end %>
    """
  end

  def handle_event("inc", _, socket) do
    {:noreply, update(socket, :outer, &(&1 + 1))}
  end
end

defmodule Phoenix.LiveViewTest.InnerFunLive do
  use Phoenix.LiveView

  def mount(_params, %{"test_process" => test_process}, socket) do
    {:ok, assign(socket, test_process: test_process, outer: 0)}
  end

  def render(assigns) do
    ~L"""
    <button id="outer" phx-click="inc">+</button>

    <%= live_component Phoenix.LiveViewTest.InnerCounter, id: "counter" do %>
      <% [value: value] -> %>
        Outer: <%= send(@test_process, @outer) %>
        Inner: <%= value %>
    <% end %>
    """
  end

  def handle_event("inc", _, socket) do
    {:noreply, update(socket, :outer, &(&1 + 1))}
  end
end
