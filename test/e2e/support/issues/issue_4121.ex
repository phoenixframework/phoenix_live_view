defmodule Phoenix.LiveViewTest.E2E.Issue4121Live do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    socket
    |> stream(:items, [%{id: 1, name: "Item 1"}, %{id: 2, name: "Item 2"}])
    |> then(&{:ok, &1})
  end

  def handle_event("reset-stream", _params, socket) do
    id = System.unique_integer()

    {:noreply, stream(socket, :items, [%{id: id, name: "Item #{id}"}], reset: true)}
  end

  def render(assigns) do
    ~H"""
    <button phx-click="reset-stream">Reset teleported stream</button>

    <.portal id="teleported-stream" target="body">
      <ul id="stream-in-lv" phx-update="stream">
        <li :for={{id, item} <- @streams.items} id={id}>
          {item.name}
        </li>
      </ul>
    </.portal>
    """
  end
end
