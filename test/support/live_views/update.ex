defmodule Phoenix.LiveViewTest.TZLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    time: <%= @time %> <%= @name %>
    """
  end

  def mount(:not_mounted_at_router, session, socket) do
    {:ok, assign(socket, time: "12:00", items: [], name: session["name"] || "NY")}
  end
end

defmodule Phoenix.LiveViewTest.ShuffleLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <%= for zone <- @time_zones do %>
      <div id={"score-" <> zone["id"]}>
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
