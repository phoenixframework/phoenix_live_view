defmodule Phoenix.LiveViewTest.E2E.Issue4212Live do
  use Phoenix.LiveView

  @items [
    %{id: "a", name: "A"},
    %{id: "b", name: "B"},
    %{id: "c", name: "C"}
  ]

  def mount(_params, _session, socket) do
    socket =
      socket
      |> stream(:items, @items)
      |> assign(:counter, 0)
      |> assign(:render_in_root, fn assigns ->
        ~H"""
        <script>
          window.__lvCustomElLog = [];
          class LvCustomEl extends HTMLElement {
            connectedCallback() {
              window.__lvCustomElLog.push({ type: "connected", id: this.id });
            }
            disconnectedCallback() {
              window.__lvCustomElLog.push({ type: "disconnected", id: this.id });
            }
            connectedMoveCallback() {
              window.__lvCustomElLog.push({ type: "moved", id: this.id });
            }
          }
          customElements.define("lv-custom-el", LvCustomEl);
        </script>
        """
      end)

    {:ok, socket}
  end

  def handle_event("insert_at_1", _params, socket) do
    n = socket.assigns.counter + 1
    item = %{id: "new#{n}", name: "New #{n}"}

    {:noreply,
     socket
     |> assign(:counter, n)
     |> stream_insert(:items, item, at: 1)}
  end

  def render(assigns) do
    ~H"""
    <button id="insert-at-1" phx-click="insert_at_1">Insert at 1</button>
    <ul id="items" phx-update="stream">
      <li :for={{dom_id, item} <- @streams.items} id={dom_id}>
        <lv-custom-el id={"el-#{item.id}"}>{item.name}</lv-custom-el>
      </li>
    </ul>
    """
  end
end
