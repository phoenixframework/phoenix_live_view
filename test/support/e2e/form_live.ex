defmodule Phoenix.LiveViewTest.E2E.FormLive do
  use Phoenix.LiveView

  alias Phoenix.LiveView.JS

  @impl Phoenix.LiveView
  def mount(params, session, socket) do
    params =
      case params do
        :not_mounted_at_router -> session
        _ -> params
      end

    {:ok,
     socket
     |> assign(
       :params,
       Enum.into(params, %{
         "a" => "foo",
         "b" => "bar",
         "id" => "test-form",
         "phx-change" => "validate"
       })
     )
     |> update_params(params)
     |> assign(:submitted, false)}
  end

  def update_params(socket, %{"no-id" => _}) do
    update(socket, :params, &Map.delete(&1, "id"))
  end

  def update_params(socket, %{"no-change-event" => _}) do
    update(socket, :params, &Map.delete(&1, "phx-change"))
  end

  def update_params(socket, _), do: socket

  @impl Phoenix.LiveView
  def handle_event("validate", params, socket) do
    {:noreply, assign(socket, :params, Map.merge(socket.assigns.params, params))}
  end

  def handle_event("save", _params, socket) do
    {:noreply, assign(socket, :submitted, true)}
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
      <button type="submit" phx-disable-with="Submitting" phx-click={JS.dispatch("test")}>
        Submit with JS
      </button>
      <button id="submit" type="submit" phx-disable-with="Submitting">Submit</button>
      <button type="button" phx-click="button-test" phx-disable-with="Loading">
        Non-form Button
      </button>
    </form>

    <p :if={@submitted}>Form was submitted!</p>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.NestedFormLive do
  use Phoenix.LiveView

  def mount(params, _session, socket) do
    {:ok, assign(socket, :params, params)}
  end

  def render(assigns) do
    ~H"""
    <%= live_render(@socket, Phoenix.LiveViewTest.E2E.FormLive,
      id: "nested",
      layout: nil,
      session: @params
    ) %>
    """
  end
end
