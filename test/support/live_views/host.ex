defmodule Phoenix.LiveViewTest.HostLive do
  use Phoenix.LiveView
  alias Phoenix.LiveViewTest.Router.Helpers, as: Routes

  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :uri, uri)}
  end

  def render(assigns) do
    ~H"""
    URI: <%= @uri %>
    LiveAction: <%= @live_action %>
    <%= live_patch "Path", id: "path", to: Routes.host_path(@socket, :path) %>
    <%= live_patch "Full", id: "full", to: "https://app.example.com" <> Routes.host_path(@socket, :full) %>
    """
  end
end
