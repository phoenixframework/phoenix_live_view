defmodule Phoenix.LiveViewTest.E2E.Issue3199Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/3199

  use Phoenix.LiveView

  alias Phoenix.LiveView.JS

  def remove_view do
    JS.transition("view-removing", time: 100)
  end

  def mount(_params, _session, socket) do
    {:ok,
     stream(socket, :items, [
       %{id: 1, name: "Item 1"},
       %{id: 2, name: "Item 2"}
     ])}
  end

  def render(assigns) do
    ~H"""
    <h1>Items</h1>

    <.link navigate="/issues/3199/away">Navigate away</.link>

    <ul id="items" phx-update="stream">
      <li
        :for={{dom_id, item} <- @streams.items}
        id={dom_id}
        phx-remove={JS.transition("item-removing", time: 1_000)}
      >
        {item.name}
        <button phx-click="delete" phx-value-id={dom_id}>Delete</button>
      </li>
    </ul>
    """
  end

  def handle_event("delete", %{"id" => dom_id}, socket) do
    {:noreply, stream_delete_by_dom_id(socket, :items, dom_id)}
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3199Live.Away do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <h1>Away</h1>
    """
  end
end
