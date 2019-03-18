defmodule Phoenix.LiveView.StoreTest do
  use ExUnit.Case, async: true
  doctest Phoenix.LiveView.Store

  alias Phoenix.LiveView.Store

  setup do
    {:ok, store} = Store.start_link(__MODULE__)
    {:ok, store: store}
  end

  describe ".set/2" do
    test "sets a single key/value pair", %{store: store} do
      :ok = Store.set(store, key: "value")
      assert "value" == Store.get!(store, :key)
    end

    test "sets multiple key/value pairs", %{store: store} do
      :ok = Store.set(store, foo: "bar", baz: "quux")
      assert "bar" == Store.get!(store, :foo)
      assert "quux" == Store.get!(store, :baz)
    end
  end

  describe ".get/2" do
    test "returns an :ok tuple when a value is found", %{store: store} do
      :ok = Store.set(store, foo: "bar")
      assert {:ok, "bar"} == Store.get(store, :foo)
    end

    test "returns an :error tuple when a value is found", %{store: store} do
      assert {:error, :not_found} == Store.get(store, :foo)
    end
  end

  describe ".get!/2" do
    test "returns a value when a value is found", %{store: store} do
      :ok = Store.set(store, foo: "bar")
      assert "bar" == Store.get!(store, :foo)
    end

    test "raises a NoSuchKeyError when no value is found", %{store: store} do
      assert_raise KeyError, fn ->
        Store.get!(store, :foo)
      end
    end
  end

  describe ".update/4" do
    test "updates an existing value", %{store: store} do
      :ok = Store.set(store, key: 1)
      :ok = Store.update(store, :key, 0, &(&1 + 1))
      assert Store.get!(store, :key) == 2
    end

    test "sets an initial value if value is present", %{store: store} do
      :ok = Store.update(store, :key, 0, &(&1 + 1))
      assert Store.get!(store, :key) == 0
    end
  end

  describe ".update!/3" do
    test "updates an existing value", %{store: store} do
      :ok = Store.set(store, key: 1)
      :ok = Store.update!(store, :key, &(&1 + 1))
      assert Store.get!(store, :key) == 2
    end

    test "raises if a value is not present", %{store: store} do
      assert_raise KeyError, fn ->
        Store.update!(store, :key, &(&1 + 1))
      end
    end
  end

  describe ".subscribe/1" do
    test "subscribes to any changes in the store", %{store: store} do
      Store.subscribe(store)
      Store.set(store, foo: "bar")
      assert_received {:store_update, ^store, [foo: "bar"]}
    end

    test "unsubscribes when a process goes down", %{store: store} do
      task =
        Task.async(fn ->
          Store.subscribe(store)
        end)

      Task.await(task)

      assert %{} == Store.get_state(store).subscribers
    end
  end

  describe ".subscribe/2" do
    test "subscribes to any changes in the store for a given key", %{store: store} do
      Store.subscribe(store, :baz)
      Store.set(store, foo: "bar")
      refute_received _
      Store.set(store, baz: "quux")
      assert_received {:store_update, ^store, [baz: "quux"]}
    end
  end

  describe ".unsubscribe/1" do
    test "unsubscribes from any store changes", %{store: store} do
      Store.subscribe(store)
      Store.set(store, foo: "bar")
      assert_received {:store_update, ^store, [foo: "bar"]}
      Store.unsubscribe(store)
      Store.set(store, foo: "bar")
      refute_received _
    end
  end

  describe ".unsubscribe/2" do
    test "unsubscribes from any changes in the store for a given key", %{store: store} do
      Store.subscribe(store, :foo)
      Store.set(store, foo: "bar")
      assert_received {:store_update, ^store, [foo: "bar"]}
      Store.unsubscribe(store, :foo)
      Store.set(store, foo: "bar")
      refute_received {:store_update, ^store, [foo: "bar"]}
    end
  end
end
