defmodule Phoenix.LiveView.Serializer do
  @moduledoc false
  @behaviour Phoenix.Socket.Serializer

  @raw :__raw__

  alias Phoenix.Socket.{Broadcast, Message, Reply}

  def fastlane!(%Broadcast{} = msg) do
    encoded =
      [nil, nil, msg.topic, msg.event, take_payload(msg.payload)]
      |> encode_to_iodata!()
      |> inject_raw_payload(msg.payload)

    {:socket_push, :text, encoded}
  end

  def encode!(%Reply{} = reply) do
    data = [
      reply.join_ref,
      reply.ref,
      reply.topic,
      "phx_reply",
      %{status: reply.status, response: take_payload(reply.payload)}
    ]

    encoded =
      data
      |> encode_to_iodata!()
      |> inject_raw_payload(reply.payload)

    {:socket_push, :text, encoded}
  end

  def encode!(%Message{} = msg) do
    encoded =
      [msg.join_ref, msg.ref, msg.topic, msg.event, take_payload(msg.payload)]
      |> encode_to_iodata!()
      |> inject_raw_payload(msg.payload)

    {:socket_push, :text, encoded}
  end

  def decode!(raw_message, _opts) do
    [join_ref, ref, topic, event, payload | _] = Phoenix.json_library().decode!(raw_message)

    %Phoenix.Socket.Message{
      topic: topic,
      event: event,
      payload: payload,
      ref: ref,
      join_ref: join_ref
    }
  end

  defp encode_to_iodata!(data), do: Phoenix.json_library().encode_to_iodata!(data)

  defp inject_raw_payload(iolist, %{@raw => raw}) when is_list(raw) do
    ['#{IO.iodata_length(iolist)}', ';' | iolist] ++ raw
  end
  defp inject_raw_payload(iolist, %{@raw => raw}) do
    ['#{IO.iodata_length(iolist)}', ';' | iolist] ++ encode_to_iodata!(raw)
  end
  defp inject_raw_payload(iolist, %{} = _payload) do
    ['#{IO.iodata_length(iolist)}', ';' | iolist]
  end

  defp take_payload(payload), do: Map.delete(payload, @raw)
end
