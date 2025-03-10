defmodule Phoenix.LiveView.LiveStreamTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.LiveStream

  test "new raises on invalid options" do
    msg = ~r/stream :dom_id must return a function which accepts each item, got: false/

    assert_raise ArgumentError, msg, fn ->
      LiveStream.new(:numbers, 0, [1, 2, 3], dom_id: false)
    end
  end

  test "default dom_id" do
    stream = LiveStream.new(:users, 0, [%{id: 1}, %{id: 2}], [])

    assert stream.inserts == [
             {"users-2", -1, %{id: 2}, nil, nil},
             {"users-1", -1, %{id: 1}, nil, nil}
           ]
  end

  test "custom dom_id" do
    stream = LiveStream.new(:users, 0, [%{name: "u1"}, %{name: "u2"}], dom_id: &"u-#{&1.name}")

    assert stream.inserts == [
             {"u-u2", -1, %{name: "u2"}, nil, nil},
             {"u-u1", -1, %{name: "u1"}, nil, nil}
           ]
  end

  test "default dom_id without struct or map with :id" do
    msg = ~r/expected stream :users to be a struct or map with :id key/

    assert_raise ArgumentError, msg, fn ->
      LiveStream.new(:users, 0, [%{user_id: 1}, %{user_id: 2}], [])
    end
  end

  test "inserts are deduplicated (last insert wins)" do
    assert stream = LiveStream.new(:users, 0, [%{id: 1}, %{id: 2}], [])
    stream = LiveStream.insert_item(stream, %{id: 2, updated: true}, -1, nil)
    stream = %{stream | consumable?: true}
    assert Enum.to_list(stream) == [{"users-1", %{id: 1}}, {"users-2", %{id: 2, updated: true}}]
  end
end
