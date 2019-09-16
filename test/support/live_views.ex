alias Phoenix.LiveViewTest.{ClockLive, ClockControlsLive}

defmodule Phoenix.LiveViewTest.ThermostatLive do
  use Phoenix.LiveView, container: {:article, class: "thermo"}, namespace: Phoenix.LiveViewTest

  def render(assigns) do
    ~L"""
    The temp is: <%= @val %><%= @greeting %>
    <button phx-click="dec">-</button>
    <button phx-click="inc">+</button><%= if @nest do %>
      <%= live_render(@socket, ClockLive, [id: :clock] ++ @nest) %>
      <%= for user <- @users do %>
        <i><%= user.name %> <%= user.email %></i>
      <% end %>
    <% end %>
    """
  end

  def mount(session, socket) do
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

  def handle_event("save", %{"temp" => new_temp} = params, socket) do
    {:noreply, assign(socket, val: new_temp, greeting: inspect(params["_target"]))}
  end

  def handle_event("save", new_temp, socket) do
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
  use Phoenix.LiveView, container: {:section, class: "clock"}

  def render(assigns) do
    ~L"""
    time: <%= @time %> <%= @name %>
    <%= live_render(@socket, ClockControlsLive, id: :"#{String.replace(@name, " ", "-")}-controls") %>
    """
  end

  def mount(session, socket) do
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
    send(socket.parent_pid, :snooze)
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
      <%= live_render(@socket, ClockLive, id: :dup, session: %{name: name}) %>
    <% end %>
    """
  end

  def render(%{dup: false} = assigns) do
    ~L"""
    <%= for name <- @names do %>
      <%= live_render(@socket, ClockLive, session: %{name: name, count: @count}, id: name) %>
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
    <%= live_render(@socket, ChildLive, id: :static, session: %{child: :static, user_id: @current_user.id}) %>
    <%= if @dynamic_child do %>
      <%= live_render(@socket, ChildLive, id: :dynamic, session: %{child: :dynamic, user_id: @current_user.id}, id: :dyn) %>
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
    child <%= @id %> name: <%= @current_user.name %>
    """
  end

  def mount(%{user_id: user_id, child: id}, socket) do
    {:ok,
     socket
     |> assign(:id, id)
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
    <%= if map_size(@params) > 0, do: inspect(@params) %>
    connect: <%= inspect(@connect_params) %>
    """
  end

  def mount(session, socket) do
    on_handle_params = session[:on_handle_params]

    {:ok,
     assign(
       socket,
       val: 1,
       connect_params: get_connect_params(socket) || %{},
       test_pid: session[:test_pid],
       on_handle_params: on_handle_params && :erlang.binary_to_term(on_handle_params)
     )}
  end

  def handle_params(%{"from" => "handle_params"} = params, uri, socket) do
    send(socket.assigns.test_pid, {:handle_params, uri, socket.assigns, params})
    socket.assigns.on_handle_params.(assign(socket, :params, params))
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

  def handle_call({:live_redirect, func}, _from, socket) do
    func.(socket)
  end

  def handle_cast({:live_redirect, to}, socket) do
    {:noreply, live_redirect(socket, to: to)}
  end
end

defmodule Phoenix.LiveViewTest.OptsLive do
  use Phoenix.LiveView

  def render(assigns), do: ~L|<%= @description %>. <%= @canary %>|

  def mount(%{opts: opts}, socket) do
    {:ok, assign(socket, description: "long description", canary: "canary"), opts}
  end

  def handle_call({:exec, func}, _from, socket) do
    func.(socket)
  end
end

defmodule Phoenix.LiveViewTest.AppendLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div id="times" phx-update="<%= @update_type %>">
      <%= for %{id: id, name: name} <- @time_zones do %>
        <h1 id="title-<%= id %>"><%= name %></h1>
        <%= live_render(@socket, Phoenix.LiveViewTest.ClockLive, id: "tz-#{id}", session: %{name: name}) %>
      <% end %>
    </div>
    """
  end

  def mount(%{time_zones: {update_type, time_zones}}, socket) do
    {:ok, assign(socket, update_type: update_type, time_zones: time_zones), temporary_assigns: [:time_zones]}
  end

  def handle_event("add-tz", %{"id" => id, "name" => name}, socket) do
    {:noreply, assign(socket, :time_zones, [%{id: id, name: name}])}
  end
end

defmodule Phoenix.LiveViewTest.ShuffleLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <%= for zone <- @time_zones do %>
      <div id="score-<%= zone.id %>">
        <%= live_render(@socket, Phoenix.LiveViewTest.ClockLive, id: "tz-#{zone.id}", session: %{name: zone.name}) %>
      </div>
    <% end %>
    """
  end

  def mount(%{time_zones: time_zones}, socket) do
    {:ok, assign(socket, time_zones: time_zones)}
  end

  def handle_event("reverse", _, socket) do
    {:noreply, assign(socket, :time_zones, Enum.reverse(socket.assigns.time_zones))}
  end
end

defmodule Phoenix.LiveViewTest.ComponentLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <%= for name <- @names do %>
      <div id="<%= name %>" data-phx-compontent="<%= name %>">
        <%= name %>
      </div>
    <% end %>
    """
  end

  def mount(%{data: %{names: names}}, socket) do
    {:ok, assign(socket, names: names)}
  end

  def handle_event("delete-name", %{"name" => name}, socket) do
    {:noreply, assign(socket, :names, Enum.reject(socket.assigns.names, &(&1 == name)))}
  end
end

