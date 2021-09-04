defmodule Phoenix.LiveView.HookTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Lifecycle

  defp build_socket() do
    %LiveView.Socket{private: %{lifecycle: %Lifecycle{}}}
  end

  describe "attach_hook/3" do
    test "raises on invalid lifecycle event" do
      assert_raise ArgumentError, ~r/invalid lifecycle event/, fn ->
        LiveView.attach_hook(build_socket(), :id, nil, &noop/3)
      end

      assert_raise ArgumentError, ~r/invalid lifecycle event/, fn ->
        LiveView.attach_hook(build_socket(), :id, :info, &noop/2)
      end

      assert_raise ArgumentError, ~r/invalid lifecycle event/, fn ->
        LiveView.attach_hook(build_socket(), :id, :handle_call, &noop/3)
      end

      assert_raise ArgumentError, ~r/invalid lifecycle event/, fn ->
        LiveView.attach_hook(build_socket(), :id, :handle_cast, &noop/2)
      end
    end

    test "supports handle_event/3" do
      assert %Lifecycle{handle_event: [%{id: :noop}]} =
               build_socket()
               |> LiveView.attach_hook(:noop, :handle_event, &noop/3)
               |> lifecycle()
    end

    test "supports handle_params/3" do
      assert %Lifecycle{handle_params: [%{id: :noop}]} =
               build_socket()
               |> LiveView.attach_hook(:noop, :handle_params, &noop/3)
               |> lifecycle()
    end

    test "supports handle_info/2" do
      assert %Lifecycle{handle_info: [%{id: :noop}]} =
               build_socket()
               |> LiveView.attach_hook(:noop, :handle_info, &noop/2)
               |> lifecycle()
    end

    test "raises when hook with :name is already attached to the same lifecycle event" do
      socket = LiveView.attach_hook(build_socket(), :noop, :handle_event, &noop/3)

      assert_raise ArgumentError, ~r/existing hook :noop already attached on :handle_event/, fn ->
        LiveView.attach_hook(socket, :noop, :handle_event, &noop/3)
      end
    end

    test "supports named hooks for multiple lifecycle events" do
      socket =
        build_socket()
        |> LiveView.attach_hook(:noop, :handle_params, &noop/3)
        |> LiveView.attach_hook(:noop, :handle_event, &noop/3)
        |> LiveView.attach_hook(:noop, :handle_info, &noop/2)

      assert %Lifecycle{
               handle_info: [%{id: :noop, stage: :handle_info}],
               handle_event: [%{id: :noop, stage: :handle_event}],
               handle_params: [%{id: :noop, stage: :handle_params}]
             } = lifecycle(socket)
    end
  end

  describe "detach_hook" do
    test "raises on invalid lifecycle event" do
      assert_raise ArgumentError, ~r/invalid lifecycle event/, fn ->
        LiveView.detach_hook(build_socket(), :id, nil)
      end

      assert_raise ArgumentError, ~r/invalid lifecycle event/, fn ->
        LiveView.detach_hook(build_socket(), :id, :info)
      end

      assert_raise ArgumentError, ~r/invalid lifecycle event/, fn ->
        LiveView.detach_hook(build_socket(), :id, :handle_call)
      end

      assert_raise ArgumentError, ~r/invalid lifecycle event/, fn ->
        LiveView.detach_hook(build_socket(), :id, :handle_cast)
      end
    end

    test "removes the hook by a given stage" do
      socket =
        build_socket()
        |> LiveView.attach_hook(:a, :handle_event, &noop/3)
        |> LiveView.attach_hook(:b, :handle_event, &noop/3)
        |> LiveView.attach_hook(:c, :handle_event, &noop/3)
        |> LiveView.attach_hook(:b, :handle_params, &noop/3)

      assert %Lifecycle{
               handle_event: [
                 %{id: :a, stage: :handle_event},
                 %{id: :b, stage: :handle_event},
                 %{id: :c, stage: :handle_event}
               ],
               handle_params: [
                 %{id: :b, stage: :handle_params}
               ]
             } = lifecycle(socket)

      socket = LiveView.detach_hook(socket, :b, :handle_event)

      assert %Lifecycle{
               handle_event: [
                 %{id: :a, stage: :handle_event},
                 %{id: :c, stage: :handle_event}
               ],
               handle_params: [
                 %{id: :b, stage: :handle_params}
               ]
             } = lifecycle(socket)
    end

    test "when no hook is registered detach_hook is a no-op" do
      socket = LiveView.attach_hook(build_socket(), :foo, :handle_event, &noop/3)
      assert LiveView.detach_hook(socket, :bar, :handle_event) == socket
    end
  end

  test "callbacks?/2" do
    socket = build_socket()
    refute Lifecycle.callbacks?(socket, :mount)
    refute Lifecycle.callbacks?(socket, :handle_event)
    refute Lifecycle.callbacks?(socket, :handle_info)
    refute Lifecycle.callbacks?(socket, :handle_params)

    # In lieu of calling the on_mount macro, we can do a gnarly
    # update to get a mount hook inside the Lifecycle (:
    socket = update_in(socket.private.lifecycle, fn lifecycle ->
      hook = Lifecycle.on_mount(Phoenix.LiveViewTest.HooksLive, {__MODULE__, :noop})
      %{lifecycle | mount: [hook]}
    end)

    assert Lifecycle.callbacks?(socket, :mount)

    socket = LiveView.attach_hook(socket, :foo, :handle_event, &noop/3)
    assert Lifecycle.callbacks?(socket, :handle_event)

    socket = LiveView.attach_hook(socket, :foo, :handle_info, &noop/2)
    assert Lifecycle.callbacks?(socket, :handle_info)

    socket = LiveView.attach_hook(socket, :foo, :handle_params, &noop/3)
    assert Lifecycle.callbacks?(socket, :handle_params)
  end

  defp lifecycle(%LiveView.Socket{private: %{lifecycle: struct}}), do: struct
  defp lifecycle(%LiveView.Socket{}), do: nil

  defp noop(_, socket), do: {:cont, socket}
  defp noop(_, _, socket), do: {:cont, socket}
end
