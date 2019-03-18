defmodule Phoenix.LiveView.Store do
  @moduledoc """
  A key-value store for sharing data across Phoenix.LiveView components

  ## Example

      iex> {:ok, store} = Phoenix.LiveView.Store.start_link(App.LiveView)
      iex> Phoenix.LiveView.Store.set(store, key: "value")
      iex> Phoenix.LiveView.Store.get(store, :key)
      {:ok, "value"}

      iex> {:ok, store} = Phoenix.LiveView.Store.start_link(App.LiveView)
      iex> Phoenix.LiveView.Store.set(store, key: "value")
      iex> Phoenix.LiveView.Store.get(store, :no_such_key)
      {:error, :not_found}

  ## Usage

  In order to share data across Phoenix.LiveView components, create a store in
  a component's `mount/2` callback and pass its identifier to child components.

      defmodule App.LiveView do
        use Phoenix.LiveView

        alias Phoenix.LiveView.Store

        def mount(%{user_id: user_id}, socket) do
          {:ok, store} = Store.start_link(__MODULE__)
          user = App.Users.lookup_user(user_id)
          Store.set(store, user: user)
          {:ok, assign(socket, :store, store)}
        end

        def render(assigns) do
          ~L\"""
          <%= live_render @socket, App.ChildView, session: %{store: @store} %>
          \"""
        end
      end

  Now, your child view can access data stored by its parent:

      defmodule App.ChildView do
        use Phoenix.LiveView

        alias Phoenix.LiveView.Store

        def mount(%{store: store}, socket) do
          user = Store.get!(store, :user)
          {:ok, assign(socket, :user, user)}
        end
      end
  """

  defmodule NoSuchKeyError do
    @moduledoc """
    An error raised when an expected key is not in the store
    """
    defexception [:message]

    @impl true
    def exception(key),
      do: %__MODULE__{message: ~s(Expected key "#{key}", but no such key was found)}
  end

  defmodule State do
    defstruct tid: nil, subscribers: %{}
  end

  use GenServer

  @doc """
  Start a new store.
  """
  @spec start_link(atom) :: GenServer.on_start()
  def start_link(name) do
    GenServer.start_link(__MODULE__, name)
  end

  @doc """
  Set one or more key/value pairs in the store.
  """
  @spec set(pid, Keyword.t()) :: {:ok, true}
  def set(store, objects) do
    GenServer.call(store, {:set, objects})
  end

  @doc """
  Get a key from the store.
  """
  @spec get(pid, atom) :: {:ok, any} | {:error, :not_found}
  def get(store, key) do
    GenServer.call(store, {:get, key})
  end

  @doc """
  Get a key from the store, but raise an error if it is not present.
  """
  @spec get!(pid, atom) :: any | no_return
  def get!(store, key) do
    case get(store, key) do
      {:ok, value} -> value
      {:error, :not_found} -> raise NoSuchKeyError, key
    end
  end

  @doc """
  Subscribe to changes in the store.
  """
  @spec subscribe(pid) :: :ok
  def subscribe(store) do
    GenServer.call(store, :subscribe)
  end

  @doc """
  Subscribe to changes in the store for a given key.
  """
  @spec subscribe(pid, atom) :: :ok
  def subscribe(store, key) do
    GenServer.call(store, {:subscribe, key})
  end

  @doc """
  Unsubscribe from all changes in the store.
  """
  @spec unsubscribe(pid) :: :ok
  def unsubscribe(store) do
    GenServer.call(store, :unsubscribe)
  end

  @doc """
  Unsubscribe from all changes in the store for the given key.
  """
  @spec unsubscribe(pid, atom) :: :ok
  def unsubscribe(store, key) do
    GenServer.call(store, {:unsubscribe, key})
  end

  @doc """
  Get the state of a store.

  This is for use in testing.
  """
  @spec get_state(pid) :: [pid]
  def get_state(store) do
    GenServer.call(store, :get_state)
  end

  # GenServer Callbacks

  @impl true
  def init(name) do
    tid = :ets.new(name, [:public])
    {:ok, %State{tid: tid}}
  end

  @impl true
  def handle_call({:set, objects}, _from, state) do
    :ets.insert(state.tid, objects)
    Enum.each(state.subscribers, &notify_subscriber(&1, objects))
    {:reply, true, state}
  end

  def handle_call({:get, key}, _from, state) do
    case :ets.lookup(state.tid, key) do
      [{^key, value}] -> {:reply, {:ok, value}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:subscribe, {from, _tag}, state) do
    monitor(state.subscribers, from)

    state = put_in(state, [Access.key(:subscribers), from], :all)
    {:reply, :ok, state}
  end

  def handle_call({:subscribe, key}, {from, _tag}, state) do
    monitor(state.subscribers, from)

    state =
      update_in(state, [Access.key(:subscribers), from], fn
        nil -> [key]
        keys -> [key | keys]
      end)

    {:reply, :ok, state}
  end

  def handle_call(:unsubscribe, {from, _tag}, state) do
    state = update_in(state, [Access.key(:subscribers)], &Map.delete(&1, from))
    {:reply, :ok, state}
  end

  def handle_call({:unsubscribe, key}, {from, _tag}, state) do
    state =
      update_in(state, [Access.key(:subscribers)], fn subscribers ->
        case subscribers[from] do
          # TODO: Should we be de-monitoring processes here? Or is it okay to just wait for :DOWN?
          [^key] -> Map.delete(subscribers, from)
          keys -> Map.put(subscribers, key, List.delete(keys, key))
        end
      end)

    {:reply, :ok, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, _, pid, _reason}, state) do
    state = update_in(state, [Access.key(:subscribers)], &Map.delete(&1, pid))
    {:noreply, state}
  end

  defp monitor(subscribers, pid) do
    unless pid in subscribers do
      Process.monitor(pid)
    end
  end

  defp notify_subscriber({pid, :all}, objects) do
    send(pid, {:store_update, self(), objects})
  end

  defp notify_subscriber({pid, keys}, objects) do
    Enum.each(objects, fn {key, value} ->
      if key in keys do
        send(pid, {:store_update, self(), [{key, value}]})
      end
    end)
  end
end
