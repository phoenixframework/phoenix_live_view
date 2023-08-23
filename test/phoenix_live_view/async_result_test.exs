defmodule Phoenix.LiveView.AsyncResultTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.AsyncResult

  test "ok" do
    async = AsyncResult.loading()
    assert Enum.sum(AsyncResult.ok(async, [1, 1, 1])) == 3
    assert Enum.count(AsyncResult.ok(async, [1, 2, 3])) == 3
    assert Enum.map(AsyncResult.ok(async, [1, 2, 3]), &(&1 * 2)) == [2, 4, 6]
  end

  test "not ok" do
    async = AsyncResult.loading()

    # loading
    assert Enum.sum(async) == 0
    assert Enum.map(async, & &1) == []

    # failed
    failed = AsyncResult.failed(async, {:exit, :boom})
    assert Enum.sum(failed) == 0
    assert Enum.map(failed, & &1) == []
  end
end
