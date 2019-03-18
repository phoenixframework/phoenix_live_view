defmodule Phoenix.LiveView.Store do
  @moduledoc """
  A key-value store for sharing data across Phoenix.LiveView components

  ## Example

      iex> store = Phoenix.LiveView.Store.new(App.LiveView)
      iex> Phoenix.LiveView.Store.set(store, key: "value")
      iex> Phoenix.LiveView.Store.get(store, :key)
      {:ok, "value"}

      iex> store = Phoenix.LiveView.Store.new(App.LiveView)
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
          store = Store.new(__MODULE__)
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

  @type store :: :ets.tid()

  defmodule NoSuchKeyError do
    @moduledoc """
    An error raised when an expected key is not in the LiveStore
    """
    defexception [:message]

    @impl true
    def exception(key),
      do: %__MODULE__{message: ~s(Expected key "#{key}", but no such key was found)}
  end

  @doc """
  Create a new LiveStore.
  """
  @spec new(atom) :: store
  def new(name) do
    :ets.new(name, [:set, :public])
  end

  @doc """
  Set one or more key/value pairs in the `store`.
  """
  @spec set(store, Keyword.t()) :: true
  def set(store, objects) do
    :ets.insert(store, objects)
  end

  @doc """
  Get a key from the store.
  """
  @spec get(store, atom) :: {:ok, any} | {:error, :not_found}
  def get(store, key) do
    case :ets.lookup(store, key) do
      [{^key, value}] -> {:ok, value}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Get a key from the store, but raise if it is not present.
  """
  @spec get!(store, atom) :: any | no_return
  def get!(store, key) do
    case get(store, key) do
      {:ok, value} -> value
      {:error, :not_found} -> raise NoSuchKeyError, key
    end
  end
end
