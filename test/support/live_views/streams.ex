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

    <button phx-click="reset-users">Reset users</button>
    <button phx-click="reset-users-reorder">Reorder users</button>
    """
  end

  @users [
    %{id: 1, name: "chris"},
    %{id: 2, name: "callan"}
  ]

  @append_users [
    %{id: 4, name: "foo"},
    %{id: 3, name: "last_user"}
  ]

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:invalid_consume, false)
     |> stream(:users, @users)
     |> stream(:admins, [user(1, "chris-admin"), user(2, "callan-admin")])}
  end

  def handle_event("delete", %{"id" => dom_id}, socket) do
    {:noreply, stream_delete_by_dom_id(socket, :users, dom_id)}
  end

  def handle_event("update", %{"id" => "users-" <> id}, socket) do
    {:noreply, stream_insert(socket, :users, user(id, "updated"))}
  end

  def handle_event("move-to-first", %{"id" => "users-" <> id}, socket) do
    {:noreply,
     socket
     |> stream_delete_by_dom_id(:users, "users-" <> id)
     |> stream_insert(:users, user(id, "updated"), at: 0)}
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

  def handle_event("reset-users", _, socket) do
    {:noreply, stream(socket, :users, [], reset: true)}
  end

  def handle_event("reset-users-reorder", %{}, socket) do
    {:noreply,
     stream(socket, :users, [user(3, "peter"), user(1, "chris"), user(4, "mona")], reset: true)}
  end

  def handle_event("stream-users", _, socket) do
    {:noreply, stream(socket, :users, @users)}
  end

  def handle_event("append-users", _, socket) do
    {:noreply, stream(socket, :users, @append_users, at: -1)}
  end

  def handle_event("admin-delete", %{"id" => dom_id}, socket) do
    {:noreply, stream_delete_by_dom_id(socket, :admins, dom_id)}
  end

  def handle_event("admin-update", %{"id" => "admins-" <> id}, socket) do
    {:noreply, stream_insert(socket, :admins, user(id, "updated"))}
  end

  def handle_event("admin-move-to-first", %{"id" => "admins-" <> id}, socket) do
    {:noreply,
     socket
     |> stream_delete_by_dom_id(:admins, "admins-" <> id)
     |> stream_insert(:admins, user(id, "updated"), at: 0)}
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
    {:noreply,
     socket
     |> stream_delete_by_dom_id(:c_users, "c_users-" <> id)
     |> stream_insert(:c_users, user(id, "updated"), at: 0)}
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

defmodule Phoenix.LiveViewTest.StreamResetLive do
  use Phoenix.LiveView

  # see https://github.com/phoenixframework/phoenix_live_view/issues/2994

  def mount(_params, _session, socket) do
    socket
    |> stream(:items, [
      %{id: "a", name: "A"},
      %{id: "b", name: "B"},
      %{id: "c", name: "C"},
      %{id: "d", name: "D"}
    ])
    |> then(&{:ok, &1})
  end

  def render(assigns) do
    ~H"""
    <ul phx-update="stream" id="thelist">
      <li id={id} :for={{id, item} <- @streams.items}>
        <%= item.name %>
      </li>
    </ul>

    <button phx-click="filter">Filter</button>
    <button phx-click="reorder">Reorder</button>
    <button phx-click="reset">Reset</button>
    <button phx-click="prepend">Prepend</button>
    <button phx-click="append">Append</button>
    <button phx-click="bulk-insert">Bulk insert</button>
    <button phx-click="insert-at-one">Insert at 1</button>
    <button phx-click="insert-existing-at-one">Insert C at 1</button>
    <button phx-click="delete-insert-existing-at-one">Delete C and insert at 1</button>
    <button phx-click="prepend-existing">Prepend C</button>
    <button phx-click="append-existing">Append C</button>
    """
  end

  def handle_event("filter", _, socket) do
    {:noreply,
     stream(
       socket,
       :items,
       [
         %{id: "b", name: "B"},
         %{id: "c", name: "C"},
         %{id: "d", name: "D"}
       ],
       reset: true
     )}
  end

  def handle_event("reorder", _, socket) do
    {:noreply,
     stream(
       socket,
       :items,
       [
         %{id: "b", name: "B"},
         %{id: "a", name: "A"},
         %{id: "c", name: "C"},
         %{id: "d", name: "D"}
       ],
       reset: true
     )}
  end

  def handle_event("reset", _, socket) do
    {:noreply,
     stream(
       socket,
       :items,
       [
         %{id: "a", name: "A"},
         %{id: "b", name: "B"},
         %{id: "c", name: "C"},
         %{id: "d", name: "D"}
       ],
       reset: true
     )}
  end

  def handle_event("prepend", _, socket) do
    {:noreply,
     stream_insert(
       socket,
       :items,
       %{id: "a" <> "#{System.unique_integer()}", name: "#{System.unique_integer()}"},
       at: 0
     )}
  end

  def handle_event("append", _, socket) do
    {:noreply,
     stream_insert(
       socket,
       :items,
       %{id: "a" <> "#{System.unique_integer()}", name: "#{System.unique_integer()}"},
       at: -1
     )}
  end

  def handle_event("bulk-insert", _, socket) do
    {:noreply,
     stream(
       socket,
       :items,
       Enum.reverse([
         %{id: "e", name: "E"},
         %{id: "f", name: "F"},
         %{id: "g", name: "G"}
       ]),
       at: 1
     )}
  end

  def handle_event("insert-at-one", _, socket) do
    {:noreply,
     stream_insert(
       socket,
       :items,
       %{id: "a" <> "#{System.unique_integer()}", name: "#{System.unique_integer()}"},
       at: 1
     )}
  end

  def handle_event("insert-existing-at-one", _, socket) do
    {:noreply,
     stream_insert(
       socket,
       :items,
       %{id: "c", name: "C"},
       at: 1
     )}
  end

  def handle_event("delete-insert-existing-at-one", _, socket) do
    {:noreply,
     socket
     |> stream_delete_by_dom_id(:items, "items-c")
     |> stream_insert(
       :items,
       %{id: "c", name: "C"},
       at: 1
     )}
  end

  def handle_event("prepend-existing", _, socket) do
    {:noreply,
     stream_insert(
       socket,
       :items,
       %{id: "c", name: "C"},
       at: 0
     )}
  end

  def handle_event("append-existing", _, socket) do
    {:noreply,
     stream_insert(
       socket,
       :items,
       %{id: "c", name: "C"},
       at: -1
     )}
  end
end

defmodule Phoenix.LiveViewTest.StreamResetLCLive do
  use Phoenix.LiveView

  # see https://github.com/phoenixframework/phoenix_live_view/issues/2982

  defmodule InnerComponent do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <li id={@id}>
        <%= @item.name %>
      </li>
      """
    end
  end

  def mount(_params, _session, socket) do
    socket
    |> stream(:items, [
      %{id: "a", name: "A"},
      %{id: "b", name: "B"},
      %{id: "c", name: "C"},
      %{id: "d", name: "D"}
    ])
    |> then(&{:ok, &1})
  end

  def handle_event("reorder", _, socket) do
    socket =
      stream(
        socket,
        :items,
        [
          %{id: "e", name: "E"},
          %{id: "a", name: "A"},
          %{id: "f", name: "F"},
          %{id: "g", name: "G"}
        ],
        reset: true
      )

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <ul phx-update="stream" id="thelist">
      <.live_component module={InnerComponent} id={id} item={item} :for={{id, item} <- @streams.items}/>
    </ul>

    <button phx-click="reorder">Reorder</button>
    """
  end
end

defmodule Phoenix.LiveViewTest.StreamLimitLive do
  use Phoenix.LiveView

  # see https://github.com/phoenixframework/phoenix_live_view/issues/2686

  def mount(_params, _session, socket) do
    socket = stream_configure(socket, :items, [])

    {:noreply, socket} = handle_event("configure", %{"at" => "-1", "limit" => "-5"}, socket)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <form phx-submit="configure">
      at: <input type="text" name="at" value={@at}/>
      limit: <input type="text" name="limit" value={@limit}/>
      <button type="submit">recreate stream</button>
    </form>

    <div>configured with at: <%= @at %>, limit: <%= @limit %></div>

    <button phx-click="insert_10">add 10</button>
    <button phx-click="insert_1">add 1</button>
    <button phx-click="clear">clear</button>

    <ul id="items" phx-update="stream">
      <li :for={{id, item} <- @streams.items} id={id}><%= item.id %></li>
    </ul>
    """
  end

  def handle_event("configure", %{"at" => at, "limit" => limit}, socket) do
    socket =
      socket
      |> assign(limit: String.to_integer(limit), at: String.to_integer(at), last_id: 0)
      |> new_stream()

    {:noreply, socket}
  end

  def handle_event("insert_10", _params, socket) do
    %{limit: l, at: a, last_id: last_id} = socket.assigns
    items = for n <- 1..10, do: %{id: last_id + n}
    opts = [at: a, limit: l]

    socket =
      socket
      |> assign(last_id: last_id + 10)
      |> stream(:items, items, opts)

    {:noreply, socket}
  end

  def handle_event("insert_1", _params, socket) do
    %{limit: l, at: a, last_id: last_id} = socket.assigns
    item = %{id: last_id + 1}
    opts = [at: a, limit: l]

    socket =
      socket
      |> assign(last_id: last_id + 1)
      |> stream_insert(:items, item, opts)

    {:noreply, socket}
  end

  def handle_event("clear", _params, socket) do
    socket =
      socket
      |> assign(last_id: 0)
      |> stream(:items, [], reset: true)

    {:noreply, socket}
  end

  defp new_stream(socket) do
    %{limit: l, at: a} = socket.assigns
    items = for n <- 1..10, do: %{id: n}
    opts = [reset: true, at: a, limit: l]

    socket
    |> assign(last_id: 10)
    |> stream(:items, items, opts)
  end
end
