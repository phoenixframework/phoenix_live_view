defmodule Phoenix.LiveView.Serializer do
  @moduledoc false
  @behaviour Phoenix.Socket.Serializer
  @short 0
  @file_part 1

  alias Phoenix.Socket.Message
  defdelegate fastlane!(msg), to: Phoenix.Socket.V2.JSONSerializer
  defdelegate encode!(msg), to: Phoenix.Socket.V2.JSONSerializer


  def decode!(<<0::size(8), rest :: binary>> = raw_message, _opts) do
    decode_binary(rest)
  end

  def decode!(raw_message, opts) do
    Phoenix.Socket.V2.JSONSerializer.decode!(raw_message, opts)
  end

  @doc false

  def decode_binary(<< 1 :: size(8), rest :: binary>>) do
    case decode_frame(rest) do
      %Phoenix.Socket.Message{} = message -> message
      other -> other
    end
  end

  def decode_binary(<<vsn::size(8), _rest::binary>>) when vsn != 1 do
    {:error, :invalid_version}
  end

  def decode_binary(_) do
    {:error, :invalid_binary}
  end

  defp decode_frame(<<join_ref_size :: size(8), ref_size :: size(8), topic_size :: size(8), join_ref :: binary-size(join_ref_size), ref :: binary-size(ref_size), topic :: binary-size(topic_size), data :: binary>>) do

    %Phoenix.Socket.Message{
        topic: topic,
        event: "event",
        ref: ref,
        payload: {:frame, data},
        join_ref: join_ref
    }
  end


  defp decode_frame(_) do
    {:error, :invalid_frame}
  end
end
