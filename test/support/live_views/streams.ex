defmodule Phoenix.LiveViewTest.StreamLive do
  use Phoenix.LiveView

  def run(lv, func) do
    GenServer.call(lv.pid, {:run, func})
  end

  def render(%{invalid_consume: true} = assigns) do
    ~H"""
    <div :for={{id, _user} <- Enum.map(@streams.users, &(&1))} id={id} />
    """
  end
  def render(assigns) do
    ~H"""
    <div id="users" phx-update="stream">
      <div :for={{id, user} <- @streams.users} id={id}>
        <%= user.name %>
        <button phx-click="delete" phx-value-id={id}>delete</button>
        <button phx-click="update" phx-value-id={id}>update</button>
        <button phx-click="move-to-first" phx-value-id={id}>make first</button>
        <button phx-click="move-to-last" phx-value-id={id}>make last</button>
        <button phx-click="move" phx-value-id={id} phx-value-name="moved" phx-value-at="1">move</button>
      </div>
    </div>
    <div id="admins" phx-update="stream">
      <div :for={{id, user} <- @streams.admins} id={id}>
        <%= user.name %>
        <button phx-click="admin-delete" phx-value-id={id}>delete</button>
        <button phx-click="admin-update" phx-value-id={id}>update</button>
        <button phx-click="admin-move-to-first" phx-value-id={id}>make first</button>
        <button phx-click="admin-move-to-last" phx-value-id={id}>make last</button>
      </div>
    </div>
    <.live_component id="stream-component" module={Phoenix.LiveViewTest.StreamComponent} />
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:invalid_consume, false)
     |> stream(:users, [user(1, "chris"), user(2, "callan")])
     |> stream(:admins, [user(1, "chris-admin"), user(2, "callan-admin")])}
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

  def handle_event("move", %{"id" => "users-" <> id = dom_id, "name" => name, "at" => at}, socket) do
    at = String.to_integer(at)
    user = user(id, name)

    {:noreply,
     socket
     |> stream_delete_by_dom_id(:users, dom_id)
     |> stream_insert(:users, user, at: at)}
  end

  def handle_event("admin-delete", %{"id" => dom_id}, socket) do
    {:noreply, stream_delete_by_dom_id(socket, :admins, dom_id)}
  end

  def handle_event("admin-update", %{"id" => "admins-" <> id}, socket) do
    {:noreply, stream_insert(socket, :admins, user(id, "updated"))}
  end

  def handle_event("admin-move-to-first", %{"id" => "admins-" <> id}, socket) do
    {:noreply, stream_insert(socket, :admins, user(id, "updated"), at: 0)}
  end

  def handle_event("admin-move-to-last", %{"id" => "admins-" <> id = dom_id}, socket) do
    user = user(id, "updated")

    {:noreply,
     socket
     |> stream_delete_by_dom_id(:admins, dom_id)
     |> stream_insert(:admins, user, at: -1)}
  end

  def handle_event("consume-stream-invalid", _, socket) do
    {:noreply, assign(socket, :invalid_consume, true)}
  end

  def handle_call({:run, func}, _, socket), do: func.(socket)

  defp user(id, name) do
    %{id: id, name: name}
  end
end

defmodule Phoenix.LiveViewTest.StreamComponent do
  use Phoenix.LiveComponent

  def run(lv, func) do
    GenServer.call(lv.pid, {:run, func})
  end

  def render(assigns) do
    ~H"""
    <div id="c_users" phx-update="stream">
      <div :for={{id, user} <- @streams.c_users} id={id}>
        <%= user.name %>
        <button phx-click="delete" phx-value-id={id} phx-target={@myself}>delete</button>
        <button phx-click="update" phx-value-id={id} phx-target={@myself}>update</button>
        <button phx-click="move-to-first" phx-value-id={id} phx-target={@myself}>make first</button>
        <button phx-click="move-to-last" phx-value-id={id} phx-target={@myself}>make last</button>
      </div>
    </div>
    """
  end

  def update(%{reset: {stream, collection}}, socket) do
    {:ok, stream(socket, stream, collection, reset: true)}
  end

  def update(%{send_assigns_to: test_pid}, socket) when is_pid(test_pid) do
    send(test_pid, {:assigns, socket.assigns})
    {:ok, socket}
  end

  def update(_assigns, socket) do
    users = [user(1, "chris"), user(2, "callan")]
    {:ok, stream(socket, :c_users, users)}
  end

  def handle_event("reset", %{}, socket) do
    {:noreply, stream(socket, :c_users, [], reset: true)}
  end

  def handle_event("delete", %{"id" => dom_id}, socket) do
    {:noreply, stream_delete_by_dom_id(socket, :c_users, dom_id)}
  end

  def handle_event("update", %{"id" => "c_users-" <> id}, socket) do
    {:noreply, stream_insert(socket, :c_users, user(id, "updated"))}
  end

  def handle_event("move-to-first", %{"id" => "c_users-" <> id}, socket) do
    {:noreply, stream_insert(socket, :c_users, user(id, "updated"), at: 0)}
  end

  def handle_event("move-to-last", %{"id" => "c_users-" <> id = dom_id}, socket) do
    user = user(id, "updated")

    {:noreply,
     socket
     |> stream_delete_by_dom_id(:c_users, dom_id)
     |> stream_insert(:c_users, user, at: -1)}
  end

  defp user(id, name) do
    %{id: id, name: name}
  end
end

defmodule Phoenix.LiveViewTest.HealthyLive do
  use Phoenix.LiveView

  @healthy_stuff %{
    "fruits" => [
      %{id: 1, name: "Apples"},
      %{id: 2, name: "Oranges"}
    ],
    "veggies" => [
      %{id: 3, name: "Carrots"},
      %{id: 4, name: "Tomatoes"}
    ]
  }

  def render(assigns) do
    ~H"""
    <p>
      <.link patch={other(@category)}>Switch</.link>
    </p>

    <h1><%= String.capitalize(@category) %></h1>

    <ul id="items" phx-update="stream">
      <li :for={{dom_id, item} <- @streams.items} id={dom_id}>
        <%= item.name %>
      </li>
    </ul>
    """
  end

  defp other("fruits" = _current_category) do
    "/healthy/veggies"
  end

  defp other("veggies" = _current_category) do
    "/healthy/fruits"
  end

  def mount(%{"category" => category} = _params, _session, socket) do
    socket =
      socket
      |> assign(:category, category)

    {:ok, socket}
  end

  def handle_params(%{"category" => category} = _params, _url, socket) do
    socket =
      socket
      |> assign(:category, category)
      |> stream(:items, Map.fetch!(@healthy_stuff, category), reset: true)

    {:noreply, socket}
  end
end
