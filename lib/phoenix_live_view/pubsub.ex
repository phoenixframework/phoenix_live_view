defmodule Phoenix.LiveView.PubSub do
  @moduledoc false

  @behaviour Phoenix.PubSub.Sender

  # We use the process dictionary because pubsub subscriptions
  # are side effects by design.
  #
  # If someone does
  #
  #   def mount(...) do
  #     socket
  #     |> subscribe("items", ...)
  #     |> assign(..., load_items(...))
  #
  # the expectation is that the subscription happens before loading
  # items. Otherwise there is a gap where updates can be missed.
  #
  # If this implementation deferred subscriptions by looking at the
  # socket after mount returns (or used the process mailbox), this
  # immediate subscription behavior could not be achieved.
  @key {__MODULE__, :__subscriptions__}

  @impl true
  def send(pid, ref, message, _state) do
    send(pid, {__MODULE__, ref, message})
    :ok
  end

  def subscribe(%Phoenix.LiveView.Socket{} = socket, pubsub, topic, callback) do
    if Phoenix.LiveView.connected?(socket) do
      verify_called_from_liveview!()
      do_subscribe(pubsub, topic, subscriber(socket), callback)
    end

    socket
  end

  defp do_subscribe(pubsub, topic, cid_or_root, callback) do
    pubsub_subscriptions = pubsub_subscriptions()

    updated_subscriptions =
      case pubsub_subscriptions do
        %{{^pubsub, ^topic} => {ref, subscribers}} ->
          Map.put(
            pubsub_subscriptions,
            {pubsub, topic},
            {ref, Map.put(subscribers, cid_or_root, callback)}
          )

        %{} ->
          ref = make_ref()
          Phoenix.PubSub.subscribe(pubsub, topic, sender: {Phoenix.LiveView.PubSub, ref})

          pubsub_subscriptions
          |> Map.put({pubsub, topic}, {ref, %{cid_or_root => callback}})
          |> Map.put(ref, {pubsub, topic})
      end

    Process.put(@key, updated_subscriptions)
  end

  def unsubscribe(%Phoenix.LiveView.Socket{} = socket, pubsub, topic) do
    if Phoenix.LiveView.connected?(socket) do
      verify_called_from_liveview!()
      do_unsubscribe(pubsub, topic, subscriber(socket))
    end

    socket
  end

  defp do_unsubscribe(pubsub, topic, cid_or_root) do
    pubsub_subscriptions = pubsub_subscriptions()

    updated_subscriptions =
      case pubsub_subscriptions do
        %{{^pubsub, ^topic} => {ref, subscribers}} when is_map_key(subscribers, cid_or_root) ->
          case Map.delete(subscribers, cid_or_root) do
            empty when map_size(empty) == 0 ->
              # unsubscribe/2 would also drop subscriptions the user made on the same topic
              Phoenix.PubSub.unsubscribe_match(pubsub, topic, [__MODULE__ | ref])

              pubsub_subscriptions
              |> Map.delete({pubsub, topic})
              |> Map.delete(ref)

            subscribers ->
              Map.put(pubsub_subscriptions, {pubsub, topic}, {ref, subscribers})
          end

        %{} ->
          pubsub_subscriptions
      end

    Process.put(@key, updated_subscriptions)
  end

  defp pubsub_subscriptions do
    Process.get(@key, %{})
  end

  def subscribers(ref) do
    case pubsub_subscriptions() do
      %{^ref => key} = subscriptions ->
        {^ref, subscribers} = Map.fetch!(subscriptions, key)
        subscribers

      %{} ->
        # we might still have stale messages in the mailbox
        # so we ignore those silently
        []
    end
  end

  def unsubscribe_cid(cid) do
    for {{pubsub, topic}, {_ref, subscribers}} <- pubsub_subscriptions(),
        Map.has_key?(subscribers, cid) do
      do_unsubscribe(pubsub, topic, cid)
    end
  end

  defp subscriber(%{assigns: %{myself: %Phoenix.LiveComponent.CID{cid: cid}}}), do: cid
  defp subscriber(_socket), do: :root

  defp verify_called_from_liveview! do
    # we use the process dicationary so to prevent cases where a user calls
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
