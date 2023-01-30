defmodule Phoenix.LiveViewTest.StreamLive do
  use Phoenix.LiveView

  def run(lv, func) do
    GenServer.call(lv.pid, {:run, func})
  end

  def render(assigns) do
    ~H"""
    <%= @users_count %>
    <div id="users" phx-update="stream">
      <div :for={{id, user} <- @streams.users} id={id}>
        <%= user.name %>
        <button phx-click="delete" phx-value-id={id}>delete</button>
        <button phx-click="update" phx-value-id={id}>update</button>
        <button phx-click="move-to-first" phx-value-id={id}>make first</button>
        <button phx-click="move-to-last" phx-value-id={id}>make last</button>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    users = [user(1, "chris"), user(2, "callan")]
    {:ok, socket |> assign(users_count: Enum.count(users)) |> stream(:users, users)}
  end

  def handle_event("delete", %{"id" => dom_id}, socket) do
    {:noreply, stream_delete_by_dom_id(socket, :users, dom_id)}
  end

  def handle_event("update", %{"id" => "users-" <> id}, socket) do
    {:noreply, stream_insert(socket, :users, user(id, "updated"))}
  end

  def handle_event("move-to-first", %{"id" => "users-" <> id}, socket) do
    {:noreply, stream_insert(socket, :users, user(id, "updated"), at: 0)}
  end

  def handle_event("move-to-last", %{"id" => "users-" <> id = dom_id}, socket) do
    user = user(id, "updated")

    {:noreply,
     socket
     |> stream_delete_by_dom_id(:users, dom_id)
     |> stream_insert(:users, user, at: -1)}
  end

  def handle_call({:run, func}, _, socket), do: func.(socket)

  defp user(id, name) do
    %{id: id, name: name}
  end
end
