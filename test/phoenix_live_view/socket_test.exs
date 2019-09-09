defmodule Phoenix.LiveView.SocketTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView
  alias Phoenix.LiveView.{View, Socket}
  alias Phoenix.LiveViewTest.{Endpoint, Router}

  @socket View.configure_socket(%Socket{endpoint: Endpoint, router: Router}, %{})

  describe "get_connect_params" do
    test "raises when not in mounting state and connected" do
      socket = View.post_mount_prune(%{@socket | connected?: true})

      assert_raise RuntimeError, ~r/attempted to read connect_params/, fn ->
        LiveView.get_connect_params(socket)
      end
    end

    test "raises when not in mounting state and disconnected" do
      socket = View.post_mount_prune(%{@socket | connected?: false})

      assert_raise RuntimeError, ~r/attempted to read connect_params/, fn ->
        LiveView.get_connect_params(socket)
      end
    end

    test "returns nil when disconnected" do
      socket = %{@socket | connected?: false}
      assert LiveView.get_connect_params(socket) == nil
    end

    test "returns params connected and mounting" do
      socket = %{@socket | connected?: true}
      assert LiveView.get_connect_params(socket) == %{}
    end
  end
end
