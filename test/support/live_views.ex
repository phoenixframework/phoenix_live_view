alias Phoenix.LiveViewTest.{ClockLive, ClockControlsLive}

defmodule Phoenix.LiveViewTest.ThermostatLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    The temp is: <%= @val %><%= @greeting %>
    <button phx-click="dec">-</button>
    <button phx-click="inc">+</button><%= if @nest do %>
      <%= live_render(@socket, ClockLive, render_opts(@nest, session: %{redir: @redir})) %>
      <%= for user <- @users do %>
        <i><%= user.name %> <%= user.email %></i>
      <% end %>
    <% end %>
    """
  end

  defp render_opts(list, opts) when is_list(list), do: Keyword.merge(opts, list)
  defp render_opts(_, opts), do: opts

  def mount(%{redir: {:disconnected, __MODULE__}} = session, socket) do
    if connected?(socket) do
      do_mount(session, socket)
    else
      {:stop, redirect(socket, to: "/thermostat_disconnected")}
    end
  end

  def mount(%{redir: {:connected, __MODULE__}} = session, socket) do
    # Skip underlying redirect log.
    Logger.disable(self())

    if connected?(socket) do
      {:stop, redirect(socket, to: "/thermostat_connected")}
    else
      do_mount(session, socket)
    end
  end

  def mount(session, socket), do: do_mount(session, socket)

  defp do_mount(session, socket) do
    nest = Map.get(session, :nest, false)
    users = session[:users] || []
    val = if connected?(socket), do: 1, else: 0

    {:ok,
     assign(socket,
       val: val,
       nest: nest,
       redir: session[:redir],
       users: users,
       greeting: nil
     )}
  end

  @key_i 73
  @key_d 68
  def handle_event("key", @key_i, socket) do
    {:noreply, update(socket, :val, &(&1 + 1))}
  end

  def handle_event("key", @key_d, socket) do
    {:noreply, update(socket, :val, &(&1 - 1))}
  end

  def handle_event("save", %{"temp" => new_temp}, socket) do
    {:noreply, assign(socket, :val, new_temp)}
  end

  def handle_event("redir", to, socket) do
    {:stop, redirect(socket, to: to)}
  end

  def handle_event("inactive", msg, socket) do
    {:noreply, assign(socket, :greeting, "Tap to wake – #{msg}")}
  end

  def handle_event("active", msg, socket) do
    {:noreply, assign(socket, :greeting, "Waking up – #{msg}")}
  end

  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("inc", _, socket), do: {:noreply, update(socket, :val, &(&1 + 1))}

  def handle_event("dec", _, socket), do: {:noreply, update(socket, :val, &(&1 - 1))}

  def handle_info(:noop, socket), do: {:noreply, socket}

  def handle_info({:redir, to}, socket) do
    {:stop, redirect(socket, to: to)}
  end

  def handle_call({:set, var, val}, _, socket) do
    {:reply, :ok, assign(socket, var, val)}
  end
end

defmodule Phoenix.LiveViewTest.ClockLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    time: <%= @time %> <%= @name %>
    <%= live_render(@socket, ClockControlsLive) %>
    """
  end

  def mount(%{redir: {:disconnected, __MODULE__}} = session, socket) do
    if connected?(socket) do
      do_mount(session, socket)
    else
      {:stop, redirect(socket, to: "/clock_disconnected")}
    end
  end

  def mount(%{redir: {:connected, __MODULE__}} = session, socket) do
    # Skip underlying redirect log.
    Logger.disable(self())

    if connected?(socket) do
      {:stop, redirect(socket, to: "/clock_connected")}
    else
      do_mount(session, socket)
    end
  end

  def mount(session, socket), do: do_mount(session, socket)

  defp do_mount(session, socket) do
    if connected?(socket) do
      Process.register(self(), :"clock#{session[:name]}")
    end

    {:ok, assign(socket, time: "12:00", name: session[:name] || "NY")}
  end

  def handle_info(:snooze, socket) do
    {:noreply, assign(socket, :time, "12:05")}
  end

  def handle_info({:run, func}, socket) do
    func.(socket)
  end

  def handle_call({:set, new_time}, _from, socket) do
    {:reply, :ok, assign(socket, :time, new_time)}
  end
end

defmodule Phoenix.LiveViewTest.ClockControlsLive do
  use Phoenix.LiveView

  def render(assigns), do: ~L|<button phx-click="snooze">+</button>|

  def mount(_session, socket), do: {:ok, socket}

  def handle_event("snooze", _, socket) do
    send(Process.whereis(:clock), :snooze)
    {:noreply, socket}
  end
end

defmodule Phoenix.LiveViewTest.DashboardLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    session: <%= Phoenix.HTML.raw inspect(@router_session) %>
    """
  end

  def mount(session, socket) do
    {:ok, assign(socket, router_session: session)}
  end
end

defmodule Phoenix.LiveViewTest.SameChildLive do
  use Phoenix.LiveView

  def render(%{dup: true} = assigns) do
    ~L"""
    <%= for name <- @names do %>
      <%= live_render(@socket, ClockLive, session: %{name: name}) %>
    <% end %>
    """
  end

  def render(%{dup: false} = assigns) do
    ~L"""
    <%= for name <- @names do %>
      <%= live_render(@socket, ClockLive, session: %{name: name, count: @count}, child_id: name) %>
    <% end %>
    """
  end

  def mount(%{dup: dup}, socket) do
    {:ok, assign(socket, count: 0, dup: dup, names: ~w(Tokyo Madrid Toronto))}
  end

  def handle_event("inc", _, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count + 1)}
  end
end

defmodule Phoenix.LiveViewTest.RootLive do
  use Phoenix.LiveView
  alias Phoenix.LiveViewTest.ChildLive

  def render(assigns) do
    ~L"""
    root name: <%= @current_user.name %>
    <%= live_render(@socket, ChildLive, session: %{child: :static, user_id: @current_user.id}) %>
    <%= if @dynamic_child do %>
      <%= live_render(@socket, ChildLive, session: %{child: :dynamic, user_id: @current_user.id}, child_id: :dyn) %>
    <% end %>
    """
  end

  def mount(%{user_id: user_id}, socket) do
    {:ok,
     socket
     |> assign(:dynamic_child, false)
     |> assign_new(:current_user, fn ->
       %{name: "user-from-root", id: user_id}
     end)}
  end

  def handle_call(:show_dynamic_child, _from, socket) do
    {:reply, :ok, assign(socket, :dynamic_child, true)}
  end
end

defmodule Phoenix.LiveViewTest.ChildLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    child <%= @child_id %> name: <%= @current_user.name %>
    """
  end

  def mount(%{user_id: user_id, child: child_id}, socket) do
    {:ok,
     socket
     |> assign(:child_id, child_id)
     |> assign_new(:current_user, fn ->
       %{name: "user-from-child", id: user_id}
     end)}
  end
end

defmodule Phoenix.LiveViewTest.ParamCounterLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    The value is: <%= @val %>
    <%= if map_size(@params) > 0, do: Phoenix.HTML.raw(inspect(@params)) %>
    connect: <%= Phoenix.HTML.raw(inspect(@connect_params)) %>
    """
  end

  def mount(%{test_pid: pid} = session, socket) do
    do_mount(session, assign(socket, :test_pid, pid))
  end

  defp do_mount(%{test: %{external_disconnected_redirect: redir}}, socket) do
    %{to: to} = redir
    {:ok, live_redirect(socket, to: to)}
  end

  defp do_mount(%{test: %{external_connected_redirect: opts}, test_pid: pid}, socket) do
    %{to: to, stop: stop} = opts

    cond do
      connected?(socket) && stop -> {:stop, live_redirect(socket, to: to)}
      connected?(socket) -> {:ok, live_redirect(socket, to: to)}
      true -> {:ok, do_assign(assign(socket, pid: pid))}
    end
  end

  defp do_mount(_session, socket) do
    {:ok, do_assign(socket)}
  end

  defp do_assign(socket) do
    assign(socket, val: 1, connect_params: get_connect_params(socket) || %{})
  end

  def handle_params(%{"from" => "handle_params"} = params, uri, socket) do
    send(socket.assigns.test_pid, {:handle_params, uri, socket.assigns, params})
    socket.assigns.on_handle_params.(socket)
  end

  def handle_params(params, uri, socket) do
    send(socket.assigns.test_pid, {:handle_params, uri, socket.assigns, params})
    {:noreply, assign(socket, :params, params)}
  end

  def handle_event("live_redirect", to, socket) do
    {:noreply, live_redirect(socket, to: to)}
  end

  def handle_info({:set, var, val}, socket), do: {:noreply, assign(socket, var, val)}

  def handle_info({:live_redirect, to}, socket) do
    {:noreply, live_redirect(socket, to: to)}
  end

  def handle_call({:live_redirect, to, func}, _from, socket) do
    func.(live_redirect(socket, to: to))
  end

  def handle_cast({:live_redirect, to}, socket) do
    {:noreply, live_redirect(socket, to: to)}
  end
end

defmodule Phoenix.LiveViewTest.ConfigureLive do
  use Phoenix.LiveView

  def render(assigns), do: ~L|<%= @description %>|

  def mount(_session, socket) do
    {:ok,
     socket
     |> assign(description: "long description")
     |> configure_temporary_assigns([:description])}
  end

  def handle_call({:exec, func}, _from, socket) do
    func.(socket)
  end
end
