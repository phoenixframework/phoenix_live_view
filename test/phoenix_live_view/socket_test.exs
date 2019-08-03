defmodule Phoenix.LiveView.SocketTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView
  alias Phoenix.LiveView.View
  alias Phoenix.LiveViewTest.{Endpoint, Router}

  describe "get_connect_params" do
    test "raises when not in mounting state and connected" do
      socket =
        Endpoint
        |> View.build_socket(Router, %{connected?: true})
        |> View.post_mount_prune()

      assert_raise RuntimeError, ~r/attempted to read connect_params/, fn ->
        LiveView.get_connect_params(socket)
      end
    end

    test "raises when not in mounting state and disconnected" do
      socket =
        Endpoint
        |> View.build_socket(Router, %{connected?: false})
        |> View.post_mount_prune()

      assert_raise RuntimeError, ~r/attempted to read connect_params/, fn ->
        LiveView.get_connect_params(socket)
      end
    end

    test "returns nil when disconnected" do
      socket = View.build_socket(Endpoint, Router, %{connected?: false})
      assert LiveView.get_connect_params(socket) == nil
    end

    test "returns params connected and mounting" do
      socket = View.build_socket(Endpoint, Router, %{connected?: true})
      assert LiveView.get_connect_params(socket) == %{}
    end
  end
end
