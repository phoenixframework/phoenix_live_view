defmodule Phoenix.LiveViewTest.E2E.Issue4442Live do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, stream(socket, :items, [%{id: 1, preview?: false}])}
  end

  def handle_event("reset", _params, socket) do
    {:noreply, stream(socket, :items, [%{id: 1, preview?: true}], reset: true)}
  end

  def handle_event("insert", _params, socket) do
    {:noreply, stream_insert(socket, :items, %{id: 1, preview?: true})}
  end

  def render(assigns) do
    ~H"""
    <button id="reset" phx-click="reset">Add preview with stream reset</button>
    <button id="insert" phx-click="insert">Add preview with stream_insert</button>

    <div id="items" phx-update="stream">
      <div :for={{dom_id, item} <- @streams.items} id={dom_id}>
        <span>Row {item.id}</span>
        <.portal :if={item.preview?} id={"preview-#{item.id}"} target="#portal-target">
          <p id={"preview-content-#{item.id}"}>Ticket details</p>
        </.portal>
      </div>
    </div>

    <div id="portal-target"></div>
    """
  end
end
