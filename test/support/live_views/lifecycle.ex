defmodule Phoenix.LiveViewTest.InitAssigns do
  alias Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:cont,
     socket
     |> LiveView.assign(:init_assigns_mount, true)
     |> LiveView.assign(:last_at_mount, :init_assigns_mount)}
  end

  def other_mount(_params, _session, socket) do
    {:cont,
     socket
     |> LiveView.assign(:init_assigns_other_mount, true)
     |> LiveView.assign(:last_at_mount, :init_assigns_other_mount)}
  end
end

defmodule Phoenix.LiveViewTest.HooksLive do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.InitAssigns

  on_mount InitAssigns
  on_mount {InitAssigns, :other_mount}

  def render(assigns) do
    ~L"""
    last_at_mount:<%= inspect(assigns[:last_at_mount]) %>
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
      {:reply, Map.fetch(socket.private, :lifecycle), socket}
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

defmodule Phoenix.LiveViewTest.HooksLive.BadMount do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  on_mount {__MODULE__, :bad_mount}

  @spec mount(any, any, any) :: none
  def mount(_params, _session, _socket) do
    raise "expected to exit before #{__MODULE__}.mount/3"
  end

  def bad_mount(_params, _session, _socket), do: :boom

  def render(assigns), do: ~L""
end

defmodule Phoenix.LiveViewTest.HooksLive.OwnMount do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  on_mount __MODULE__

  def mount(_params, _session, _socket) do
    raise "expected to exit before #{__MODULE__}.mount/3"
  end

  def render(assigns), do: ~L""
end

defmodule Phoenix.LiveViewTest.HooksLive.HaltMount do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  on_mount {__MODULE__, :hook}

  def hook(_, _, socket), do: {:halt, socket}
  def render(assigns), do: ~L""
end

defmodule Phoenix.LiveViewTest.HooksLive.RedirectMount do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  on_mount {__MODULE__, :hook}

  def hook(_, _, %{assigns: %{live_action: action}} = socket) do
    {action, push_redirect(socket, to: "/lifecycle")}
  end

  def render(assigns), do: ~L""
end
