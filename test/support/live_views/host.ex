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
    <.link id="path" patch={Routes.host_path(@socket, :path)}>Path</.link>
    <.link id="full" patch={"https://app.example.com" <> Routes.host_path(@socket, :full)}>Full</.link>
    """
  end
end
