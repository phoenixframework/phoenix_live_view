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
    if connected?(socket) do
      {:stop, redirect(socket, to: "/thermostat_connected")}
    else
      do_mount(session, socket)
    end
  end

  def mount(session, socket), do: do_mount(session, socket)

  defp do_mount(session, socket) do
    nest = Map.get(session, :nest, false)
    users = Map.get(session, :users, [])
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
