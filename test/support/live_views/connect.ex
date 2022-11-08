defmodule Phoenix.LiveViewTest.ConnectLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    params: <%= inspect(@params) %>
    uri: <%= URI.to_string(@uri) %>
    trace: <%= inspect(@trace) %>
    peer: <%= inspect(@peer) %>
    x-headers: <%= inspect(@x_headers) %>
    user-agent: <%= inspect(@user_agent) %>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(
       socket,
       params: get_connect_params(socket),
       uri: get_connect_info(socket, :uri),
       trace: get_connect_info(socket, :trace_context_headers),
       peer: get_connect_info(socket, :peer_data),
       x_headers: get_connect_info(socket, :x_headers),
       user_agent: get_connect_info(socket, :user_agent)
     )}
  end
end
