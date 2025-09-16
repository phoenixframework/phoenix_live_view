defmodule Phoenix.LiveViewTest.Support.StreamLive do
  use Phoenix.LiveView

  def run(lv, func) do
    GenServer.call(lv.pid, {:run, func})
  end

  def render(%{invalid_consume: true} = assigns) do
    ~H"""
    <div :for={{id, _user} <- Enum.map(@streams.users, & &1)} id={id} />
    """
  end

  def render(%{no_id: true} = assigns) do
    ~H"""
    <div id="users" phx-update="stream">
      <div only-child>Empty!</div>
      <div :for={{id, _user} <- @streams.users} id={id} />
    </div>

    <style>
      [only-child] {
        display: none;
      }
      [only-child]:only-child {
        display: block;
      }
    </style>
    """
  end

  def render(%{extra_item_with_id: true} = assigns) do
    ~H"""
    <div id="users" phx-update="stream">
      <div :for={{id, user} <- @streams.users} id={id}>{user.name}</div>
      <div id="users-empty" only-child>Empty!</div>
    </div>

    <style>
      [only-child] {
        display: none;
      }
      [only-child]:only-child {
        display: block;
      }
    </style>
    """
  end

  def render(assigns) do
    ~H"""
    <div id="users" phx-update="stream">
      <div :for={{id, user} <- @streams.users} id={id} data-count={@count}>
        {user.name}
        <button phx-click="delete" phx-value-id={id}>delete</button>
        <button phx-click="update" phx-value-id={id}>update</button>
        <button phx-click="move-to-first" phx-value-id={id}>make first</button>
        <button phx-click="move-to-last" phx-value-id={id}>make last</button>
        <button phx-click="move" phx-value-id={id} phx-value-name="moved" phx-value-at="1">
          move
        </button>
        <button phx-click={Phoenix.LiveView.JS.hide(to: "##{id}")}>JS Hide</button>
      </div>
    </div>
    <div id="admins" phx-update="stream">
      <div :for={{id, user} <- @streams.admins} id={id} data-count={@count}>
        {user.name}
        <button phx-click="admin-delete" phx-value-id={id}>delete</button>
        <button phx-click="admin-update" phx-value-id={id}>update</button>
        <button phx-click="admin-move-to-first" phx-value-id={id}>make first</button>
        <button phx-click="admin-move-to-last" phx-value-id={id}>make last</button>
      </div>
    </div>
    <.live_component id="stream-component" module={Phoenix.LiveViewTest.Support.StreamComponent} />

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

  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:invalid_consume, false)
     |> assign(:no_id, false)
     |> assign(:extra_item_with_id, Map.has_key?(params, "empty_item"))
     |> assign(:count, 0)
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
    {:noreply, socket |> update(:count, &(&1 + 1)) |> stream(:users, [], reset: true)}
  end

  def handle_event("reset-users-reorder", %{}, socket) do
    {:noreply,
     socket
     |> update(:count, &(&1 + 1))
     |> stream(:users, [user(3, "peter"), user(1, "chris"), user(4, "mona")], reset: true)}
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

  def handle_event("stream-no-id", _, socket) do
    {:noreply, assign(socket, :no_id, true) |> stream(:users, @users)}
  end

  def handle_event("stream-extra-with-id", _, socket) do
    {:noreply, assign(socket, :extra_item_with_id, true) |> stream(:users, @users)}
  end

  def handle_call({:run, func}, _, socket), do: func.(socket)

  defp user(id, name) do
    %{id: id, name: name}
  end
end

defmodule Phoenix.LiveViewTest.Support.StreamComponent do
  use Phoenix.LiveComponent

  def run(lv, func) do
    GenServer.call(lv.pid, {:run, func})
  end

  def render(assigns) do
    ~H"""
    <div id="c_users" phx-update="stream">
      <div :for={{id, user} <- @streams.c_users} id={id}>
        {user.name}
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

defmodule Phoenix.LiveViewTest.Support.HealthyLive do
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

    <h1>{String.capitalize(@category)}</h1>

    <ul id="items" phx-update="stream">
      <li :for={{dom_id, item} <- @streams.items} id={dom_id}>
        {item.name}
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
      |> stream(:items, [])

    {:ok, socket}
  end

  def handle_params(%{"category" => category} = _params, _url, socket) do
    socket =
      socket
      |> assign(:category, category)
      |> stream(:items, Map.fetch!(@healthy_stuff, category), reset: true)

    {:noreply, socket}
  end

  def handle_event("load-more", %{}, socket) do
    new_items = [
      %{id: 5, name: "Pumpkins"},
      %{id: 6, name: "Melons"}
    ]

    {:noreply,
     socket
     |> stream(:items, new_items, at: -1)}
  end
end

defmodule Phoenix.LiveViewTest.Support.StreamResetLive do
  use Phoenix.LiveView

  # see https://github.com/phoenixframework/phoenix_live_view/issues/2994

  def mount(params, _session, socket) do
    socket
    |> stream(:items, [
      %{id: "a", name: "A"},
      %{id: "b", name: "B"},
      %{id: "c", name: "C"},
      %{id: "d", name: "D"}
    ])
    |> assign(:use_phx_remove, is_map(params) && params["phx-remove"])
    |> then(&{:ok, &1})
  end

  def render(assigns) do
    ~H"""
    <ul phx-update="stream" id="thelist">
      <li
        :for={{id, item} <- @streams.items}
        id={id}
        phx-remove={if @use_phx_remove, do: Phoenix.LiveView.JS.hide()}
      >
        {item.name}
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
    <button phx-click="new-update-only">Add E (update only)</button>
    <button phx-click="existing-update-only">Update C (update only)</button>
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

  def handle_event("new-update-only", _, socket) do
    {:noreply, stream_insert(socket, :items, %{id: "e", name: "E"}, at: -1, update_only: true)}
  end

  def handle_event("existing-update-only", _, socket) do
    {:noreply,
     stream_insert(socket, :items, %{id: "c", name: "C #{System.unique_integer()}"},
       at: -1,
       update_only: true
     )}
  end
end

defmodule Phoenix.LiveViewTest.Support.StreamResetLCLive do
  use Phoenix.LiveView

  # see https://github.com/phoenixframework/phoenix_live_view/issues/2982

  defmodule InnerComponent do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <li id={@id}>
        {@item.name}
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
      <.live_component
        :for={{id, item} <- @streams.items}
        module={InnerComponent}
        id={id}
        item={item}
      />
    </ul>

    <button phx-click="reorder">Reorder</button>
    """
  end
end

defmodule Phoenix.LiveViewTest.Support.StreamLimitLive do
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
      at: <input type="text" name="at" value={@at} /> limit:
      <input type="text" name="limit" value={@limit} />
      <button type="submit">recreate stream</button>
    </form>

    <div>configured with at: {@at}, limit: {@limit}</div>

    <button phx-click="insert_10">add 10</button>
    <button phx-click="insert_1">add 1</button>
    <button phx-click="clear">clear</button>

    <ul id="items" phx-update="stream">
      <li :for={{id, item} <- @streams.items} id={id}>{item.id}</li>
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

defmodule Phoenix.LiveViewTest.Support.StreamNestedLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    :timer.send_interval(50, self(), :tick)

    {:ok, assign(socket, :foo, 1)}
  end

  def handle_info(:tick, socket) do
    {:noreply, update(socket, :foo, &(&1 + 1))}
  end

  def render(assigns) do
    ~H"""
    <div id="nested-container">
      {@foo}
      {live_render(@socket, Phoenix.LiveViewTest.Support.StreamResetLive, id: "nested")}
    </div>
    """
  end
end

defmodule Phoenix.LiveViewTest.Support.StreamInsideForLive do
  # https://github.com/phoenixframework/phoenix_live_view/issues/3129
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    socket
    |> stream(:items, [])
    |> start_async(:foo, fn ->
      Process.sleep(50)
    end)
    |> then(&{:ok, &1})
  end

  def handle_async(:foo, {:ok, _}, socket) do
    {:noreply,
     stream(socket, :items, [
       %{id: "a", name: "A"},
       %{id: "b", name: "B"},
       %{id: "c", name: "C"},
       %{id: "d", name: "D"}
     ])}
  end

  def render(assigns) do
    ~H"""
    <div :for={_i <- [1]}>
      <ul phx-update="stream" id="thelist">
        <li :for={{id, item} <- @streams.items} id={id}>
          {item.name}
        </li>
      </ul>
    </div>
    """
  end
end

defmodule Phoenix.LiveViewTest.Support.StreamNestedComponentResetLive do
  use Phoenix.LiveView

  defmodule InnerComponent do
    use Phoenix.LiveComponent

    # we already initialized the stream
    def update(assigns, %{assigns: %{id: _}} = socket) do
      {:ok, assign(socket, assigns)}
    end

    # first mount
    def update(assigns, socket) do
      items =
        if connected?(socket) do
          [
            %{id: assigns.id <> "-a", name: "N-A"},
            %{id: assigns.id <> "-b", name: "N-B"},
            %{id: assigns.id <> "-c", name: "N-C"},
            %{id: assigns.id <> "-d", name: "N-D"}
          ]
        else
          [
            %{id: assigns.id <> "-e", name: "N-E"},
            %{id: assigns.id <> "-f", name: "N-F"},
            %{id: assigns.id <> "-g", name: "N-G"},
            %{id: assigns.id <> "-h", name: "N-H"}
          ]
        end

      socket
      |> assign(assigns)
      |> stream(:nested, items, reset: true)
      |> then(&{:ok, &1})
    end

    def handle_event("reorder", _, socket) do
      socket =
        stream(
          socket,
          :nested,
          [
            %{id: socket.assigns.id <> "-e", name: "N-E"},
            %{id: socket.assigns.id <> "-a", name: "N-A"},
            %{id: socket.assigns.id <> "-f", name: "N-F"},
            %{id: socket.assigns.id <> "-g", name: "N-G"}
          ],
          reset: true
        )

      {:noreply, socket}
    end

    def render(assigns) do
      ~H"""
      <li id={@id}>
        {@item.name}
        <div id={@id <> "-nested"} phx-update="stream" style="display: flex; gap: 4px;">
          <span :for={{id, item} <- @streams.nested} id={id}>{item.name}</span>
        </div>
        <button phx-click="reorder" phx-target={@myself}>Reorder</button>
      </li>
      """
    end
  end

  def render(assigns) do
    ~H"""
    <ul phx-update="stream" id="thelist">
      <.live_component
        :for={{id, item} <- @streams.items}
        module={InnerComponent}
        id={id}
        item={item}
      />
    </ul>

    <button phx-click="reorder" id="parent-reorder">Reorder</button>
    """
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
end

defmodule Phoenix.LiveViewTest.Support.HighFrequencyStreamAndNoStreamUpdatesLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    :timer.send_interval(50, self(), :tick)

    {:ok, assign(socket, :foo, 1) |> stream(:items, [])}
  end

  def handle_info(:tick, socket) do
    {:noreply, update(socket, :foo, &(&1 + 1))}
  end

  def handle_event("insert_item", _, socket) do
    {:noreply, stream_insert(socket, :items, %{id: System.unique_integer(), name: "Item"})}
  end

  def render(assigns) do
    ~H"""
    <div id="mystream" phx-update="stream">
      <div :for={{id, item} <- @streams.items} id={id}>
        {item.name}, {item.id}
      </div>
    </div>
    <p>{@foo}</p>
    """
  end
end
