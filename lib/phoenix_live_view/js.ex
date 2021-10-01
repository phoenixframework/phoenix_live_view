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

  @doc """
  ## TODO
  [ ] documnet all JS interfaces
  [ ] document phx-click-away
  [ ] documnet phx-handle-nav (going away)
  [ ] document custom execJS dispatch on push_event
  [ ] figure out what to deprecate (phx-page-loading binding?)
  [ ] phx-remove
  [ ] phx-updated

  ## push
  [x] page_loading: boolean,
  [ ] loading: dom_selector,
  [ ] value: map (value merges on top of phx-value)
  [x] target: ...,
  """
  def push(event) when is_binary(event) do
    push(%JS{}, event, [])
  end

  def push(event, opts) when is_binary(event) and is_list(opts) do
    push(%JS{}, event, opts)
  end

  def push(%JS{} = cmd, event) when is_binary(event) do
    push(cmd, event, [])
  end

  def push(%JS{} = cmd, event, opts) when is_binary(event) and is_list(opts) do
    opts = put_target(opts)
    put_op(cmd, "push", Enum.into(opts, %{event: event}))
  end

  defp put_target(opts) do
    case Keyword.fetch(opts, :target) do
      {:ok, %Phoenix.LiveComponent.CID{cid: cid}} -> Keyword.put(opts, :target, cid)
      {:ok, selector} -> Keyword.put(opts, :target, selector)
      :error -> opts
    end
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

  def add_class(cmd \\ %JS{}, names, opts) when is_binary(names) do
    put_op(cmd, "add_class", %{to: Keyword.fetch!(opts, :to), names: class_names(names)})
  end

  def remove_class(cmd \\ %JS{}, names, opts \\ []) do
    put_op(cmd, "remove_class", %{to: opts[:to], names: class_names(names)})
  end

  def transition(names) when is_binary(names) do
    transition(%JS{}, names, [])
  end

  def transition(names, opts) when is_binary(names) and is_list(opts) do
    transition(%JS{}, names, opts)
  end

  def transition(%JS{} = cmd, names) when is_binary(names) do
    transition(cmd, names, [])
  end

  def transition(%JS{} = cmd, names, opts) when is_binary(names) and is_list(opts) do
    time = opts[:time] || @default_transition_time
    put_op(cmd, "transition", %{time: time, to: opts[:to], names: class_names(names)})
  end

  defp put_op(%JS{ops: ops} = cmd, kind, %{} = args) do
    %JS{cmd | ops: ops ++ [[kind, args]]}
  end

  defp class_names(names) do
    String.split(names, " ")
  end
end
