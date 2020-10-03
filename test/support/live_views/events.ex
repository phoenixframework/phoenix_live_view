defmodule Phoenix.LiveViewTest.EventsLive do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  def render(assigns) do
    ~L"""
    count: <%= @count %>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, events: [], count: 0)}
  end

  def handle_event("reply", %{"count" => new_count, "reply" => reply}, socket) do
    {:reply, reply, assign(socket, :count, new_count)}
  end

  def handle_event("reply", %{"reply" => reply}, socket) do
    {:reply, reply, socket}
  end

  def handle_call({:run, func}, _, socket), do: func.(socket)

  def handle_info({:run, func}, socket), do: func.(socket)
end

defmodule Phoenix.LiveViewTest.EventsInMountLive.Root do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  def render(assigns) do
    ~L"<%= live_render @socket, Phoenix.LiveViewTest.EventsInMountLive.Child, id: :child_live %>"
  end

  def mount(_params, _session, socket) do
    socket =
      if connected?(socket),
        do: push_event(socket, "root-mount", %{root: "foo"}),
        else: socket

    {:ok, socket}
  end
end

defmodule Phoenix.LiveViewTest.EventsInMountLive.Child do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  def render(assigns) do
    ~L"hello!"
  end

  def mount(_params, _session, socket) do
    socket =
      if connected?(socket),
        do: push_event(socket, "child-mount", %{child: "bar"}),
        else: socket

    {:ok, socket}
  end
end
