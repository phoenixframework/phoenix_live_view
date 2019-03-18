defmodule Phoenix.LiveView.StoreTest do
  use ExUnit.Case, async: true
  doctest Phoenix.LiveView.Store

  alias Phoenix.LiveView.Store

  setup do
    store = Store.new(__MODULE__)
    {:ok, store: store}
  end

  describe ".set/2" do
    test "sets a single key/value pair", %{store: store} do
      true = Store.set(store, key: "value")
      assert "value" == Store.get!(store, :key)
    end

    test "sets multiple key/value pairs", %{store: store} do
      true = Store.set(store, foo: "bar", baz: "quux")
      assert "bar" == Store.get!(store, :foo)
      assert "quux" == Store.get!(store, :baz)
    end
  end

  describe ".get/2" do
    test "returns an :ok tuple when a value is found", %{store: store} do
      true = Store.set(store, foo: "bar")
      assert {:ok, "bar"} == Store.get(store, :foo)
    end

    test "returns an :error tuple when a value is found", %{store: store} do
      assert {:error, :not_found} == Store.get(store, :foo)
    end
  end

  describe ".get!/2" do
    test "returns a value when a value is found", %{store: store} do
      true = Store.set(store, foo: "bar")
      assert "bar" == Store.get!(store, :foo)
    end

    test "raises a NoSuchKeyError when no value is found", %{store: store} do
      assert_raise Store.NoSuchKeyError, fn ->
        Store.get!(store, :foo)
      end
    end
  end
end
