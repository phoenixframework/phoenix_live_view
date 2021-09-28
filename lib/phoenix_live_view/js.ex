defmodule Phoenix.LiveView.JS do
  @moduledoc """
  TODO
  """
  alias Phoenix.LiveView.JS

  defstruct ops: []

  @default_transition_time 200

  defimpl Phoenix.HTML.Safe, for: Phoenix.LiveView.JS  do
    def to_iodata(%Phoenix.LiveView.JS{} = cmd) do
      Phoenix.HTML.Engine.html_escape(Phoenix.json_library().encode!(cmd.ops))
    end
  end

  def push(cmd \\ %JS{}, event, opts \\ []) do
    put_op(cmd, "push", Enum.into(opts, %{event: event}))
  end

  def dispatch(cmd \\ %JS{}, event, opts) do
    args = %{event: event, to: Keyword.fetch!(opts, :to)}
    args =
      case Keyword.fetch(opts, :detail) do
        {:ok, detail} -> Map.put(args, :detail, detail)
        :error -> args
      end

    put_op(cmd, "dispatch", args)
  end

  def toggle(cmd \\ %JS{}, to, opts \\ []) do
    in_classes = opts[:in] && List.wrap(opts[:in])
    out_classes = opts[:out] && List.wrap(opts[:out])
    time = opts[:time] || @default_transition_time
    put_op(cmd, "toggle", %{to: to, ins: in_classes, outs: out_classes, time: time})
  end

  def add_class(cmd \\ %JS{}, names, opts) do
    put_op(cmd, "add_class", %{to: Keyword.fetch!(opts, :to), names: List.wrap(names)})
  end

  def remove_class(cmd \\ %JS{}, names, opts \\ []) do
    put_op(cmd, "remove_class", %{to: opts[:to], names: List.wrap(names)})
  end

  def transition(cmd \\ %JS{}, names, opts) when is_list(opts) and (is_binary(names) or is_list(names)) do
    time = opts[:time] || @default_transition_time
    put_op(cmd, "transition", %{time: time, to: opts[:to], names: List.wrap(names)})
  end

  defp put_op(%JS{ops: ops} = cmd, kind, %{} = args) do
    %JS{cmd | ops: ops ++ [[kind, args]]}
  end
end
