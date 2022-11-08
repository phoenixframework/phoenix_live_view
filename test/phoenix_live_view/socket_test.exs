defmodule Phoenix.LiveView.SocketTest do
  use ExUnit.Case, async: true

  test "use with no override" do
    defmodule MySocket do
      use Phoenix.LiveView.Socket
    end

    info = %{peer_data: %{}}
    assert {:ok, %Phoenix.Socket{} = socket} = MySocket.connect(%{}, %Phoenix.Socket{}, info)
    assert socket.private.connect_info == info
    assert MySocket.id(socket) == nil
  end

  test "use with overrides" do
    defmodule MyOverrides do
      use Phoenix.LiveView.Socket

      def connect(%{"error" => "true"}, _socket, _info) do
        :error
      end

      def connect(_params, socket, info) do
        {:ok, assign(socket, :info, info)}
      end

      def id(_socket), do: "my-id"
    end

    info = %{peer_data: %{}}
    assert :error = MyOverrides.connect(%{"error" => "true"}, %Phoenix.Socket{}, info)
    assert {:ok, %Phoenix.Socket{} = socket} = MyOverrides.connect(%{}, %Phoenix.Socket{}, info)
    assert socket.private.connect_info == info
    assert socket.assigns.info == info
    assert MyOverrides.id(socket) == "my-id"
  end
end
