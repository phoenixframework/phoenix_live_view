defmodule Phoenix.LiveViewTest.Support.InitAssigns do
  alias Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> Component.assign(:init_assigns_mount, true)
     |> Component.assign(:last_on_mount, :init_assigns_mount)}
  end

  def on_mount(:other, _params, _session, socket) do
    {:cont,
     socket
     |> Component.assign(:init_assigns_other_mount, true)
     |> Component.assign(:last_on_mount, :init_assigns_other_mount)}
  end
end

defmodule Phoenix.LiveViewTest.Support.MountArgs do
  import Phoenix.LiveView

  def on_mount(:inlined, _params, _session, socket) do
    qs = URI.encode_query(%{called: true, inlined: true})
    {:halt, push_navigate(socket, to: "/lifecycle?#{qs}")}
  end
end

defmodule Phoenix.LiveViewTest.Support.OnMount do
  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end

  def on_mount(:other, _params, _session, socket) do
    {:cont, socket}
  end
end

defmodule Phoenix.LiveViewTest.Support.OtherOnMount do
  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end

  def on_mount(:other, _params, _session, socket) do
    {:cont, socket}
  end
end

defmodule Phoenix.LiveViewTest.Support.HooksLive do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.Support.InitAssigns

  on_mount InitAssigns
  on_mount {InitAssigns, :other}

  def render(assigns) do
    ~H"""
    <p>last_on_mount:{inspect(assigns[:last_on_mount])}</p>
    <p>params_hook:{assigns[:params_hook_ref]}</p>
    <p>count:{@count}</p>
    <p>task:{@task}</p>
    <button id="dec" phx-click="dec">-</button>
    <button id="inc" phx-click="inc">+</button>
    <button id="patch" phx-click="patch">?</button>
    <button id="async" phx-click="async">=</button>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0, task: "")}
  end

  def handle_event("inc", _, socket), do: {:noreply, update(socket, :count, &(&1 + 1))}
  def handle_event("dec", _, socket), do: {:noreply, update(socket, :count, &(&1 - 1))}

  def handle_event("patch", _, socket) do
    ref = socket.assigns[:params_hook_ref] || 0
    {:noreply, push_patch(socket, to: "/lifecycle?ref=#{ref}")}
  end

  def handle_event("async", _, socket) do
    {:noreply, start_async(socket, :task, fn -> true end)}
  end

  def handle_async(:task, {:ok, true}, socket) do
    {:noreply, update(socket, :task, &(&1 <> "."))}
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

  def unlink_and_monitor(lv) do
    Process.unlink(proxy_pid(lv))
    Process.monitor(proxy_pid(lv))
  end

  def run(lv, func) do
    GenServer.call(lv.pid, {:run, func})
  end

  def proxy_pid(%{proxy: {_ref, _topic, pid}}), do: pid
end

defmodule Phoenix.LiveViewTest.Support.HooksLive.BadMount do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  on_mount __MODULE__

  def on_mount(:default, _params, _session, _socket), do: :boom

  def mount(_params, _session, _socket) do
    raise "expected to exit before #{__MODULE__}.mount/3"
  end

  def render(assigns), do: ~H"<div></div>"
end

defmodule Phoenix.LiveViewTest.Support.HooksLive.HaltMount do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  on_mount {__MODULE__, :hook}

  def on_mount(:hook, _, _, socket), do: {:halt, socket}
  def render(assigns), do: ~H"<div></div>"
end

defmodule Phoenix.LiveViewTest.Support.HooksLive.RedirectMount do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  def mount(_, _, socket) do
    case socket.assigns.live_action do
      :halt -> raise "mount should not have been called"
      _ -> {:ok, socket}
    end
  end

  on_mount __MODULE__

  def on_mount(:default, _, _, %{assigns: %{live_action: action}} = socket) do
    {action, push_navigate(socket, to: "/lifecycle")}
  end

  def render(assigns), do: ~H"<div></div>"
end

defmodule Phoenix.LiveViewTest.Support.HooksLive.Noop do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  def render(assigns) do
    ~H"""
    <h1>Noop</h1>
    last_on_mount:{inspect(assigns[:last_on_mount])}
    """
  end
end

defmodule Phoenix.LiveViewTest.Support.HaltConnectedMount do
  alias Phoenix.{Component, LiveView}

  def on_mount(_arg, _params, _session, socket) do
    if LiveView.connected?(socket) do
      {:halt, LiveView.push_navigate(socket, to: "/lifecycle")}
    else
      {:cont, Component.assign(socket, :last_on_mount, __MODULE__)}
    end
  end
end

defmodule Phoenix.LiveViewTest.Support.HooksAttachInfoComponent do
  use Phoenix.LiveComponent
  alias Phoenix.LiveView

  def mount(socket) do
    {:ok, LiveView.attach_hook(socket, :live_component_hook, :handle_info, &__MODULE__.hook/3)}
  end

  def hook(_, _, _socket) do
    raise "expected to exit before #{__MODULE__}.hook/3"
  end

  def render(assigns), do: ~H"<div></div>"
end

defmodule Phoenix.LiveViewTest.Support.HooksDetachInfoComponent do
  use Phoenix.LiveComponent
  alias Phoenix.LiveView

  def mount(socket) do
    {:ok, LiveView.detach_hook(socket, :live_view_hook, :handle_info)}
  end

  def render(assigns), do: ~H"<div></div>"
end

defmodule Phoenix.LiveViewTest.Support.HooksEventComponent do
  use Phoenix.LiveComponent
  alias Phoenix.LiveView

  def mount(socket) do
    {:ok, assign(socket, :counter, 0)}
  end

  def update(assigns, socket) do
    socket = assign(socket, assigns)
    hook = if assigns.reply?, do: &__MODULE__.hook_reply/3, else: &__MODULE__.hook/3
    {:ok, LiveView.attach_hook(socket, :live_component_hook, :handle_event, hook)}
  end

  def hook("detach", _, socket),
    do: {:halt, LiveView.detach_hook(socket, :live_component_hook, :handle_event)}

  def hook(_, _, socket), do: {:halt, assign(socket, :counter, socket.assigns.counter + 1)}

  def hook_reply("detach", _, socket),
    do: {:halt, LiveView.detach_hook(socket, :live_component_hook, :handle_event)}

  def hook_reply(_, _, socket) do
    counter = socket.assigns.counter + 1
    {:halt, %{counter: counter}, assign(socket, :counter, counter)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div id="detach-component-hook" phx-click="detach" phx-target={@myself}>Detach</div>
      <div id="hook" phx-click="event" phx-target={@myself}>counter: {@counter}</div>
    </div>
    """
  end
end

defmodule Phoenix.LiveViewTest.Support.HooksLive.WithComponent do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.Support.{HooksAttachInfoComponent, HooksDetachInfoComponent}
  alias Phoenix.LiveViewTest.Support.HooksEventComponent

  def mount(params, _session, socket) do
    type = String.to_existing_atom(params["type"])
    reply? = Map.get(params, "reply", "false") |> String.to_existing_atom()

    {:ok,
     socket
     |> assign(:component, nil)
     |> assign(:type, type)
     |> assign(:reply?, reply?)
     |> attach_hook(:live_view_hook, :handle_event, fn _, _, socket ->
       {:cont, socket}
     end)}
  end

  def handle_event("load", %{"val" => val}, socket) do
    component =
      case {val, socket.assigns.type} do
        {"attach", :handle_info} -> HooksAttachInfoComponent
        {"detach", :handle_info} -> HooksDetachInfoComponent
        {"attach", :handle_event} -> HooksEventComponent
      end

    {:noreply, assign(socket, :component, component)}
  end

  def render(assigns) do
    ~H"""
    <button id="attach" phx-click="load" phx-value-val="attach">Load/Attach</button>
    <button id="detach" phx-click="load" phx-value-val="detach">Load/Detach</button>
    <%= if @component do %>
      <.live_component module={@component} id={:hook} type={@type} reply?={@reply?} />
    <% end %>
    """
  end
end

defmodule Phoenix.LiveViewTest.Support.HooksLive.HandleParamsNotDefined do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  def mount(_, _, socket) do
    {:ok,
     attach_hook(socket, :assign_url, :handle_params, fn _, url, socket ->
       {:cont, assign(socket, :url, url)}
     end)}
  end

  def render(assigns), do: ~H"url={assigns[:url]}"
end

defmodule Phoenix.LiveViewTest.Support.HooksLive.HandleInfoNotDefined do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  def mount(_, _, socket) do
    send(self(), {:data, "somedata"})

    {:ok,
     attach_hook(socket, :assign_url, :handle_info, fn message, socket ->
       {:data, data} = message
       {:cont, assign(socket, :data, data)}
     end)}
  end

  def render(assigns), do: ~H"data={assigns[:data]}"
end

defmodule Phoenix.LiveViewTest.Support.HooksLive.OnMountOptions do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  on_mount {__MODULE__, :temporary_assigns}
  on_mount {__MODULE__, :layout}

  def on_mount(:temporary_assigns, _params, _session, socket) do
    {:cont, socket, temporary_assigns: [data: "Phoenix"]}
  end

  def on_mount(:layout, _params, _session, socket) do
    {:cont, socket, layout: {Phoenix.LiveViewTest.Support.LayoutView, :on_mount_layout}}
  end

  def render(assigns), do: ~H"data-{@data}"
end
