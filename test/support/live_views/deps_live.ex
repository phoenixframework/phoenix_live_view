defmodule Phoenix.LiveViewTest.Support.DepsLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <div>
      <div>counter: <%= @counter %></div>
      <div>user_id: <%= @user_id %></div>
      <div>user_name: <%= @user_name %></div>
      <button phx-click="increment">Increment Counter</button>
      <button phx-click="change_user_id">Change User ID</button>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:counter, 0)
      |> assign(:user_id, 123)
      |> assign_new(:user_name, [:user_id], fn %{user_id: user_id} ->
        # In a real app, this would be a database query
        "User #{user_id}"
      end)

    {:ok, socket}
  end

  def handle_event("increment", _, socket) do
    {:noreply, update(socket, :counter, &(&1 + 1))}
  end

  def handle_event("change_user_id", _, socket) do
    socket =
      socket
      |> assign(:user_id, 456)
      |> assign_new(:user_name, [:user_id], fn %{user_id: user_id} ->
        # In a real app, this would be a database query
        "User #{user_id}"
      end)

    {:noreply, socket}
  end
end
