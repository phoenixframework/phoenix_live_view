defmodule Phoenix.LiveView.PubSub do
  @moduledoc false

  @behavior Phoenix.PubSub.Sender

  @impl true
  def send(pid, ref, message, _state) do
    send(pid, {__MODULE__, ref, message})
    :ok
  end

  def subscribe(%Phoenix.LiveView.Socket{} = socket, pubsub, topic, callback) do
    verify_called_from_liveview!()

    case socket do
      %{assigns: %{myself: %Phoenix.LiveComponent.CID{} = cid}} ->
        send(self(), {__MODULE__, :subscribe, pubsub, topic, cid, callback})

      _ ->
        send(self(), {__MODULE__, :subscribe, pubsub, topic, :root, callback})
    end

    socket
  end

  def unsubscribe(%Phoenix.LiveView.Socket{} = socket, pubsub, topic) do
    verify_called_from_liveview!()

    case socket do
      %{assigns: %{myself: %Phoenix.LiveComponent.CID{} = cid}} ->
        send(self(), {__MODULE__, :unsubscribe, pubsub, topic, cid})

      _ ->
        send(self(), {__MODULE__, :unsubscribe, pubsub, topic, :root})
    end

    socket
  end

  defp verify_called_from_liveview! do
    # we use send(self(), ...) so to prevent cases where a user calls
    # subscribe in assign_async or a custom Task, we check and raise
    # if this process is not demonstrably a LiveView
    case Process.get(:"$process_label") do
      {Phoenix.LiveView, view, topic} when is_atom(view) and is_binary(topic) ->
        :ok

      _ ->
        raise ArgumentError,
              "Phoenix.LiveView.subscribe can only be called from the LiveView process itself"
    end
  end
end
