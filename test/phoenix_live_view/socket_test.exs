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

  test "use forwards options to Phoenix.Socket" do
    defmodule MyOptions do
      use Phoenix.LiveView.Socket, max_channels_per_transport: 1
    end

    assert {:ok, {state, %Phoenix.Socket{}}} =
             MyOptions.connect(%{
               endpoint: Phoenix.LiveViewTest.Support.Endpoint,
               options: [serializer: [{Phoenix.Socket.V2.JSONSerializer, "~> 2.0.0"}]],
               transport: :websocket,
               params: %{"vsn" => "2.0.0"},
               connect_info: %{}
             })

    assert state.max_channels_per_transport == 1
  end

  describe "resume/3" do
    defp connect_info(session), do: %{session: session, peer_data: %{}}

    defp connected(socket \\ Phoenix.LiveView.Socket, session) do
      info = connect_info(session)
      {:ok, socket} = socket.connect(%{}, %Phoenix.Socket{handler: socket}, info)
      %{socket | id: socket.handler.id(socket)}
    end

    test "accepts the same session and stores the new connect_info" do
      socket = connected(%{"live_socket_id" => "users:1"})
      info = connect_info(%{"live_socket_id" => "users:1", "flash" => %{"info" => "hi"}})

      assert {:ok, %Phoenix.Socket{} = socket} =
               Phoenix.LiveView.Socket.resume(%{}, socket, info)

      assert socket.private.connect_info == info
    end

    test "rejects a different or missing live_socket_id" do
      socket = connected(%{"live_socket_id" => "users:1"})
      resume = &Phoenix.LiveView.Socket.resume(%{}, socket, &1)

      assert resume.(connect_info(%{"live_socket_id" => "users:2"})) == :error
      assert resume.(connect_info(%{})) == :error
      # the session is nil when the CSRF token of the new connection does not match
      assert resume.(connect_info(nil)) == :error
      assert resume.(%{peer_data: %{}}) == :error
    end

    test "without live_socket_id, accepts only sessions without live_socket_id" do
      socket = connected(%{})
      info = connect_info(%{"flash" => %{}})

      assert {:ok, new_socket} = Phoenix.LiveView.Socket.resume(%{}, socket, info)
      assert new_socket.private.connect_info == info
      assert {:ok, _socket} = Phoenix.LiveView.Socket.resume(%{}, socket, connect_info(nil))

      # the user logged in, so the socket needs the live_socket_id as its id
      info = connect_info(%{"live_socket_id" => "users:1"})
      assert Phoenix.LiveView.Socket.resume(%{}, socket, info) == :error

      # the session is not configured
      socket = connected(Phoenix.LiveView.Socket, nil)
      assert {:ok, _socket} = Phoenix.LiveView.Socket.resume(%{}, socket, %{peer_data: %{}})
    end

    test "use with no override checks the session" do
      defmodule MyResumeSocket do
        use Phoenix.LiveView.Socket
      end

      socket = connected(MyResumeSocket, %{"live_socket_id" => "users:1"})
      info = connect_info(%{"live_socket_id" => "users:1"})
      assert {:ok, socket} = MyResumeSocket.resume(%{}, socket, info)
      assert socket.private.connect_info == info

      assert MyResumeSocket.resume(%{}, socket, connect_info(%{})) == :error
    end

    test "use with overrides checks the session before the override" do
      defmodule MyResumeOverrides do
        use Phoenix.LiveView.Socket

        # no @impl, as Phoenix 1.8 does not define resume/3
        def connect(_params, socket, _info), do: {:ok, assign(socket, :resumed, false)}

        def resume(%{"error" => reason}, _socket, _info), do: {:error, reason}

        def resume(params, socket, info) do
          send(self(), {:resume, params, socket.private.connect_info, info})
          {:ok, assign(socket, :resumed, true)}
        end

        def id(_socket), do: "my-id"
      end

      socket = connected(MyResumeOverrides, %{"live_socket_id" => "users:1"})
      assert socket.id == "my-id"
      info = connect_info(%{"live_socket_id" => "users:1"})

      assert {:ok, socket} = MyResumeOverrides.resume(%{"a" => "b"}, socket, info)
      assert_received {:resume, %{"a" => "b"}, ^info, ^info}
      assert socket.assigns.resumed
      assert socket.private.connect_info == info

      assert MyResumeOverrides.resume(%{"error" => "denied"}, socket, info) ==
               {:error, "denied"}

      assert MyResumeOverrides.resume(%{}, socket, connect_info(%{})) == :error
      refute_received {:resume, _, _, _}
    end

    # Phoenix.Socket invokes resume/3 since Phoenix 1.9
    if function_exported?(Phoenix.LiveView.Socket, :handle_resume, 2) do
      test "Phoenix.Socket resumes with the session check" do
        session = %{"live_socket_id" => "users:1"}

        assert {:ok, {_state, socket} = state} =
                 Phoenix.LiveView.Socket.connect(%{
                   endpoint: Phoenix.LiveViewTest.Support.Endpoint,
                   options: [serializer: [{Phoenix.Socket.V2.JSONSerializer, "~> 2.0.0"}]],
                   transport: :websocket,
                   params: %{"vsn" => "2.0.0"},
                   connect_info: connect_info(session)
                 })

        assert socket.id == "users:1"

        resume = fn session ->
          Phoenix.LiveView.Socket.handle_resume(
            %{transport: :longpoll, params: %{}, connect_info: connect_info(session)},
            state
          )
        end

        assert {:ok, {_state, socket}} = resume.(Map.put(session, "flash", %{}))
        assert socket.transport == :longpoll
        assert socket.private.connect_info.session["flash"] == %{}

        assert {:error, _} = resume.(%{"live_socket_id" => "users:2"})
      end
    end
  end
end
