defmodule Phoenix.LiveView.JS do
  @moduledoc """
  TODO docs
  TODO validate args
  """
  alias Phoenix.LiveView.JS

  defstruct ops: []

  @default_transition_time 200

  defimpl Phoenix.HTML.Safe, for: Phoenix.LiveView.JS do
    def to_iodata(%Phoenix.LiveView.JS{} = cmd) do
      Phoenix.HTML.Engine.html_escape(Phoenix.json_library().encode!(cmd.ops))
    end
  end

  # TODO
  #   page_loading: boolean,
  #   loading: dom_selector,
  #   value: map (value merges on top of phx-value)
  #   target: ...,
  #   disable_with:
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

  def toggle(cmd \\ %JS{}, opts) when is_list(opts) do
    in_classes = class_names(opts[:in] || [])
    out_classes = class_names(opts[:out] || [])
    time = opts[:time] || @default_transition_time

    put_op(cmd, "toggle", %{
      to: opts[:to],
      display: opts[:display],
      ins: in_classes,
      outs: out_classes,
      time: time
    })
  end

  def add_class(cmd \\ %JS{}, names, opts) when is_binary(names) or is_list(names) do
    put_op(cmd, "add_class", %{to: Keyword.fetch!(opts, :to), names: class_names(names)})
  end

  def remove_class(cmd \\ %JS{}, names, opts \\ []) do
    put_op(cmd, "remove_class", %{to: opts[:to], names: class_names(names)})
  end

  def transition(cmd \\ %JS{}, names, opts)
      when is_list(opts) and (is_binary(names) or is_list(names)) do
    time = opts[:time] || @default_transition_time
    put_op(cmd, "transition", %{time: time, to: opts[:to], names: class_names(names)})
  end

  defp put_op(%JS{ops: ops} = cmd, kind, %{} = args) do
    %JS{cmd | ops: ops ++ [[kind, args]]}
  end

  defp class_names(names) do
    names
    |> List.wrap()
    |> Enum.flat_map(&String.split(&1, " "))
  end
end
