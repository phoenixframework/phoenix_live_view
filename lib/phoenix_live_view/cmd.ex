defmodule Phoenix.LiveView.CMD do
  @moduledoc """
  TODO
  """
  alias Phoenix.LiveView.CMD

  defstruct ops: []

  defimpl Phoenix.HTML.Safe, for: Phoenix.LiveView.CMD  do
    def to_iodata(%Phoenix.LiveView.CMD{} = cmd) do
      Phoenix.HTML.Engine.html_escape(Phoenix.json_library().encode!(cmd.ops))
    end
  end

  def push(cmd \\ %CMD{}, event, opts \\ []) do
    put_op(cmd, "push", Enum.into(opts, %{event: event}))
  end

  def dispatch(cmd \\ %CMD{}, event, opts) do
    args = %{event: event, to: Keyword.fetch!(opts, :to)}
    args =
      case Keyword.fetch(opts, :detail) do
        {:ok, detail} -> Map.put(args, :detail, detail)
        :error -> args
      end

    put_op(cmd, "dispatch", args)
  end

  def toggle(cmd \\ %CMD{}, to) do
    put_op(cmd, "toggle", %{to: to})
  end

  def add_class(cmd \\ %CMD{}, names, opts) do
    put_op(cmd, "add_class", %{to: Keyword.fetch!(opts, :to), names: List.wrap(names)})
  end

  def remove_class(cmd \\ %CMD{}, names, opts) do
    put_op(cmd, "remove_class", %{to: Keyword.fetch!(opts, :to), names: List.wrap(names)})
  end

  defp put_op(%CMD{ops: ops} = cmd, kind, %{} = args) do
    %CMD{cmd | ops: ops ++ [[kind, args]]}
  end
end
