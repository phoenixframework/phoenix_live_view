defmodule Phoenix.LiveViewTest do
  use ExUnit.Case
  doctest PhoenixLiveView

  test "greets the world" do
    assert PhoenixLiveView.hello() == :world
  end
end
