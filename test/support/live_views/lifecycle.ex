defmodule Phoenix.LiveViewTest.HooksLive do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest
  @lifecycle :__lifecycle__

  def render(assigns) do
    ~L"""
    params_hook:<%= assigns[:params_hook_ref] %>
    count:<%= @count %>
    <button id="dec" phx-click="dec">-</button>
    <button id="inc" phx-click="inc">+</button>
    <button id="patch" phx-click="patch">?</button>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0)}
  end

  def handle_event("inc", _, socket), do: {:noreply, update(socket, :count, &(&1 + 1))}
  def handle_event("dec", _, socket), do: {:noreply, update(socket, :count, &(&1 - 1))}

  def handle_event("patch", _, socket) do
    ref = socket.assigns[:params_hook_ref] || 0
    {:noreply, push_patch(socket, to: "/lifecycle?ref=#{ref}")}
  end

  def handle_call({:run, func}, _, socket), do: func.(socket)

  def handle_call({:push_patch, to}, _, socket) do
    {:reply, :ok, push_patch(socket, to: to)}
  end

  def handle_info(:noop, socket), do: {:noreply, socket}

  def handle_info({:ping, ref, pid}, socket) when is_reference(ref) and is_pid(pid) do
    send(pid, {:pong, ref})
    {:noreply, socket}
  end

  def handle_info({:run, func}, socket), do: func.(socket)

  ## test helpers

  def attach_hook(lv, name, stage, cb) do
    run(lv, fn socket ->
      {:reply, :ok, Phoenix.LiveView.attach_hook(socket, name, stage, cb)}
    end)
  end

  def detach_hook(lv, name, stage) do
    run(lv, fn socket ->
      {:reply, :ok, Phoenix.LiveView.detach_hook(socket, name, stage)}
    end)
  end

  def fetch_lifecycle(lv) do
    run(lv, fn socket ->
      {:reply, Map.fetch(socket.private, @lifecycle), socket}
    end)
  end

  def exits_with(lv, kind, func) do
    Process.unlink(proxy_pid(lv))

    try do
      func.()
      raise "expected to exit with #{inspect(kind)}"
    catch
      :exit, {{%mod{message: msg}, _}, _} when mod == kind -> msg
    end
  end

  def run(lv, func) do
    GenServer.call(lv.pid, {:run, func})
  end

  def proxy_pid(%{proxy: {_ref, _topic, pid}}), do: pid
end
