defmodule Phoenix.LiveViewTest.E2E.Issue3979Live do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  alias Phoenix.LiveView.JS

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:counter, 1)
     |> assign(:components, for(i <- 1..10, do: %{id: i, counter: 0}))}
  end

  def handle_event("bump", _params, socket) do
    Process.send_after(self(), {:update, socket.assigns.counter}, 100)

    new_components =
      for {component, i} <- Enum.with_index(socket.assigns.components, 1) do
        if i == socket.assigns.counter do
          %{component | counter: component.counter + 1}
        else
          component
        end
      end

    {:noreply,
     socket
     |> assign(:components, new_components)
     |> assign(:counter, socket.assigns.counter + 1)}
  end

  def handle_info({:update, i}, socket) do
    send_update(Phoenix.LiveViewTest.E2E.Issue3979Live.Component, id: "comp-#{i}", counter: 10)

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      :for={component <- @components}
      module={Phoenix.LiveViewTest.E2E.Issue3979Live.Component}
      id={"comp-#{component.id}"}
      dom_id={"hello-#{component.id}-#{component.counter}"}
      counter={component.counter}
    />
    <button phx-click="bump">Bump ID (and counter)</button>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3979Live.Component do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div id={@dom_id}>
      {@counter}
    </div>
    """
  end
end
