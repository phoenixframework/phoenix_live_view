defmodule Phoenix.LiveViewTest.ParamCounterLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    The value is: <%= @val %>
    connect: <%= inspect(@connect_params) %>
    info: <%= inspect(@connect_info) %>
    mount: <%= inspect(@mount_params) %>
    params: <%= inspect(@params) %>
    """
  end

  def mount(params, session, socket) do
    on_handle_params = session["on_handle_params"]

    {:ok,
     assign(
       socket,
       val: 1,
       mount_params: params,
       connect_params: get_connect_params(socket) || %{},
       connect_info: get_connect_info(socket) || %{},
       test_pid: session["test_pid"],
       connected?: connected?(socket),
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

  def handle_info({:set, var, val}, socket), do: {:noreply, assign(socket, var, val)}

  def handle_info({:push_patch, to}, socket) do
    {:noreply, push_patch(socket, to: to)}
  end

  def handle_info({:push_redirect, to}, socket) do
    {:noreply, push_redirect(socket, to: to)}
  end

  def handle_call({:push_patch, func}, _from, socket) do
    func.(socket)
  end

  def handle_call({:push_redirect, func}, _from, socket) do
    func.(socket)
  end

  def handle_cast({:push_patch, to}, socket) do
    {:noreply, push_patch(socket, to: to)}
  end

  def handle_cast({:push_redirect, to}, socket) do
    {:noreply, push_redirect(socket, to: to)}
  end

  def handle_event("push_patch", %{"to" => to}, socket) do
    {:noreply, push_patch(socket, to: to)}
  end

  def handle_event("push_redirect", %{"to" => to}, socket) do
    {:noreply, push_redirect(socket, to: to)}
  end
end

defmodule Phoenix.LiveViewTest.ActionLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    Live action: <%= inspect @live_action %>
    Mount action: <%= inspect @mount_action %>
    Params: <%= inspect @params %>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, mount_action: socket.assigns.live_action)}
  end

  def handle_params(params, _url, socket) do
    {:noreply, assign(socket, params: params)}
  end

  def handle_event("push_patch", to, socket) do
    {:noreply, push_patch(socket, to: to)}
  end
end

defmodule Phoenix.LiveViewTest.ErrorInHandleParamsLive do
  use Phoenix.LiveView

  def render(assigns), do: ~L|<div>I crash in handle_params</div>|
  def mount(_params, _session, socket), do: {:ok, socket}
  def handle_params(_params, _uri, _socket), do: raise("boom")
end
