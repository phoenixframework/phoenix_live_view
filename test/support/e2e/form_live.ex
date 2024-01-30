defmodule Phoenix.LiveViewTest.E2E.FormLive do
  use Phoenix.LiveView

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, :params, %{
       "a" => "foo",
       "b" => "bar",
       "id" => "test-form",
       "phx-change" => "validate"
     })}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"no-id" => _}, _uri, socket) do
    {:noreply, update(socket, :params, &Map.delete(&1, "id"))}
  end

  def handle_params(%{"no-change-event" => _}, _uri, socket) do
    {:noreply, update(socket, :params, &Map.delete(&1, "phx-change"))}
  end

  def handle_params(%{"phx-auto-recover" => event}, _uri, socket) do
    {:noreply, update(socket, :params, &Map.put(&1, "phx-auto-recover", event))}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", params, socket) do
    {:noreply, assign(socket, :params, Map.merge(socket.assigns.params, params))}
  end

  def handle_event("save", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("custom-recovery", _params, socket) do
    {:noreply,
     assign(
       socket,
       :params,
       Map.merge(socket.assigns.params, %{"b" => "custom value from server"})
     )}
  end

  def handle_event("button-test", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <form
      id={@params["id"]}
      phx-submit="save"
      phx-change={@params["phx-change"]}
      phx-auto-recover={@params["phx-auto-recover"]}
    >
      <input type="text" name="a" readonly value={@params["a"]} />
      <input type="text" name="b" value={@params["b"]} />
      <button type="submit" phx-disable-with="Submitting">Submit</button>
      <button type="button" phx-click="button-test" phx-disable-with="Loading">
        Non-form Button
      </button>
    </form>
    """
  end
end
