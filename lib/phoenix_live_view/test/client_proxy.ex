defmodule Phoenix.LiveViewTest.ClientProxy do
  @moduledoc false
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    {caller_ref, caller_pid} = caller = Keyword.fetch!(opts, :caller)
    view = Keyword.fetch!(opts, :view)
    timeout = Keyword.fetch!(opts, :timeout)
    socket = %Phoenix.Socket{
      transport_pid: self(),
      serializer: Phoenix.LiveViewTest,
      channel: view.module,
      endpoint: view.endpoint,
      private: %{phoenix_live_view_caller: caller, log_join: false},
      topic: view.topic,
      join_ref: 0,
    }
    ref = make_ref()

    case Phoenix.LiveView.Channel.start_link({%{"session" => view.token}, {self(), ref}, socket}) do
      {:ok, pid} ->
        receive do
          {^ref, %{rendered: rendered}} ->
            send(caller_pid, {caller_ref, :mounted, pid, render(rendered)})
            {:ok, %{caller: caller, view_pid: pid, topic: view.topic, rendered: rendered, join_ref: socket.join_ref, ref: socket.join_ref}}
        after timeout ->
          exit(:timout)
        end

      :ignore ->
        receive do
          {^ref, reason} ->
            send(caller_pid, {caller_ref, reason})
            :ignore
        end
    end
  end

  def handle_call(:render, from, state) do
    :sys.get_state(state.view_pid)
    send(self(), {:sync_render, from})
    {:noreply, state}
  end

  def handle_call({:render_event, type, event, raw_val}, _from, state) do
    ref = to_string(state.ref + 1)
    send(state.view_pid, %Phoenix.Socket.Message{
      join_ref: state.join_ref,
      topic: state.topic,
      event: "event",
      payload: %{"value" => raw_val, "event" => to_string(event), "type" => to_string(type)},
      ref: ref,
    })

    receive do
      %Phoenix.Socket.Reply{ref: ^ref, payload: diff} ->
        rendered = deep_merge(state.rendered, diff)
        html = render_diff(rendered)
        {:reply, {:ok, html}, %{state | ref: state.ref + 1, rendered: rendered}}
    end
  end

  def handle_info({:sync_render, from}, state) do
    GenServer.reply(from, {:ok, render_diff(state.rendered)})
    {:noreply, state}
  end

  def handle_info(%Phoenix.Socket.Message{
      event: "render",
      topic: topic,
      payload: diff,
    }, %{topic: topic} = state) do

    rendered = deep_merge(state.rendered, diff)
    {:noreply, %{state | rendered: rendered}}
  end

  defp render(%{static: statics} = rendered) do
    for {static, i} <- Enum.with_index(statics), into: "",
      do: static <> to_string(rendered[i])
  end

  defp render_diff(rendered) do
    rendered
    |> to_output_buffer([])
    |> Enum.reverse()
    |> Enum.join("")
  end
  defp to_output_buffer(%{dynamics: dynamics, static: statics}, acc) do
    Enum.reduce(dynamics, acc, fn {_dynamic, index}, acc ->
      Enum.reduce(tl(statics), [Enum.at(statics, 0) | acc], fn static, acc ->
        [static | dynamic_to_buffer(dynamics[index - 1], acc)]
      end)
    end)
  end
  defp to_output_buffer(%{static: statics} = rendered, acc) do
    statics
    |> Enum.with_index()
    |> tl()
    |> Enum.reduce([Enum.at(statics, 0) | acc], fn {static, index}, acc ->
        [static | dynamic_to_buffer(rendered[index - 1], acc)]
    end)
  end

  defp dynamic_to_buffer(%{} = rendered, acc), do: to_output_buffer(rendered, []) ++ acc
  defp dynamic_to_buffer(str, acc), do: [str | acc]

  defp deep_merge(target, source) do
    Map.merge(target, source, fn
      _, %{} = target, %{} = source -> deep_merge(target, source)
      _, _target, source -> source
    end)
  end
end
