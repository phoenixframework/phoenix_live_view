defmodule Phoenix.LiveViewTest.EventsLive do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  def render(assigns) do
    ~H"""
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

defmodule Phoenix.LiveViewTest.EventsMultiJSLive do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest
  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    count: <%= @count %>

    <button
      id="add-one-and-ten"
      phx-click={
        JS.push("inc", value: %{inc: 1})
        |> JS.push("inc", value: %{inc: 10})
      }
    >
      Add 1 and 10
    </button>

    <button
      id="reply-values"
      phx-click={
        JS.push("reply", value: %{int: 1})
        |> JS.push("reply", value: %{int: 2})
      }
    >
      Reply with 1 and 2
    </button>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, events: [], count: 0)}
  end

  def handle_event("inc", %{"inc" => v}, socket) do
    {:noreply, update(socket, :count, &(&1 + v))}
  end

  def handle_event("reply", %{"int" => i}, socket) do
    {:reply, %{value: i}, socket}
  end

  def handle_call({:run, func}, _, socket), do: func.(socket)

  def handle_info({:run, func}, socket), do: func.(socket)
end

defmodule Phoenix.LiveViewTest.EventsInComponentMultiJSLive do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest
  alias Phoenix.LiveView.JS

  defmodule Child do
    use Phoenix.LiveComponent

    def update(assigns, socket) do
      {:ok, assign(socket, id: assigns.id, count: 0)}
    end

    def handle_event("inc", %{"inc" => v}, socket) do
      {:noreply, update(socket, :count, &(&1 + v))}
    end

    def render(assigns) do
      ~H"""
      <div id={@id}>
        <button
          id="push-to-self"
          phx-click={
            JS.push("inc", target: "#child_1", value: %{inc: 1})
            |> JS.push("inc", target: "#child_1", value: %{inc: 10})}
        >
          Both to self
        </button>

        <button
          id="push-to-other-targets"
          phx-click={
            JS.push("inc", target: "#child_2", value: %{inc: 2})
            |> JS.push("inc", target: "#child_1", value: %{inc: 1})
            |> JS.push("inc", value: %{inc: -1})
          }
        >
          One to everyone
        </button>

        <%= @id %> count: <%= @count %>
      </div>
      """
    end
  end

  def render(assigns) do
    ~H"""
    <%= live_component Child, id: :child_1 %>
    <%= live_component Child, id: :child_2 %>
    root count: <%= @count %>
    """
  end

  def handle_event("inc", %{"inc" => v}, socket) do
    {:noreply, update(socket, :count, &(&1 + v))}
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, events: [], count: 0)}
  end
end

defmodule Phoenix.LiveViewTest.EventsInMountLive do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  defmodule Child do
    use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

    def render(assigns) do
      ~H"hello!"
    end

    def mount(_params, _session, socket) do
      socket =
        if connected?(socket),
          do: push_event(socket, "child-mount", %{child: "bar"}),
          else: socket

      {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"<%= live_render @socket, Child, id: :child_live %>"
  end

  def mount(_params, _session, socket) do
    socket =
      if connected?(socket),
        do: push_event(socket, "root-mount", %{root: "foo"}),
        else: socket

    {:ok, socket}
  end
end

defmodule Phoenix.LiveViewTest.EventsInComponentLive do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  defmodule Child do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <div>
        <button id="comp-reply"
                phx-click="reply"
                phx-target={@myself}>
          bump reply!
        </button>

        <button id="comp-noreply"
                phx-click="noreply"
                phx-target={@myself}>
          bump no reply!
        </button>
      </div>
      """
    end

    def update(assigns, socket) do
      socket =
        if connected?(socket),
          do: push_event(socket, "component", %{count: assigns.count}),
          else: socket

      {:ok, socket}
    end

    def handle_event("reply", reply, socket) do
      {:reply, %{"comp-reply" => reply}, socket}
    end

    def handle_event("noreply", _reply, socket) do
      {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"<%= live_component Child, id: :child_live, count: @count %>"
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :count, 1)}
  end

  def handle_event("bump", _, socket) do
    {:noreply, update(socket, :count, &(&1 + 1))}
  end
end
