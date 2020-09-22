defmodule Phoenix.LiveViewTest.TZLive do
  use Phoenix.LiveView

  def render(%{name: "NestedAppend"} = assigns) do
    ~L"""
    time: <%= @time %> <%= @name %>
    <div id="append-<%= @name %>" phx-update="append"><%= for item <- @items do %>
      <!-- example -->
      <div id="item-<%= item %>"><%= item %></div>
    <% end %></div>
    """
  end

  def render(assigns) do
    ~L"""
    time: <%= @time %> <%= @name %>
    """
  end

  def mount(:not_mounted_at_router, session, socket) do
    {:ok, assign(socket, time: "12:00", items: [], name: session["name"] || "NY")}
  end

  def handle_call({:append, items}, _, socket), do: {:reply, :ok, assign(socket, items: items)}
end

defmodule Phoenix.LiveViewTest.AppendLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div <%= @id && {:safe, "id=#{inspect(@id)}"} %> phx-update="<%= @update_type %>">
      <%= for %{id: id, name: name} <- @time_zones do %>
        <h1 <%= id && {:safe, "id=title-#{id}"} %>><%= name %></h1>
        <%= live_render(@socket, Phoenix.LiveViewTest.TZLive, id: "tz-#{id}", session: %{"name" => name}) %>
      <% end %>
    </div>
    """
  end

  def mount(_params, %{"time_zones" => {update_type, time_zones}}, socket) do
    {:ok, assign(socket, update_type: update_type, time_zones: time_zones, id: "times"),
     temporary_assigns: [time_zones: []]}
  end

  def handle_event("remove-id", _, socket) do
    {:noreply, assign(socket, :id, nil)}
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
      <div id="score-<%= zone["id"] %>">
        <%= live_render(@socket, Phoenix.LiveViewTest.TZLive, id: "tz-#{zone["id"]}", session: %{"name" => zone["name"]}) %>
      </div>
    <% end %>
    """
  end

  def mount(_params, %{"time_zones" => time_zones}, socket) do
    {:ok, assign(socket, time_zones: time_zones)}
  end

  def handle_event("reverse", _, socket) do
    {:noreply, assign(socket, :time_zones, Enum.reverse(socket.assigns.time_zones))}
  end
end
