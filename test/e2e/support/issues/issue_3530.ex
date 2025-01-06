defmodule Phoenix.LiveViewTest.E2E.Issue3530Live do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  defmodule NestedLive do
    use Phoenix.LiveView

    def mount(_params, session, socket) do
      {:ok, assign(socket, :item_id, session["item_id"])}
    end

    def render(assigns) do
      ~H"""
      <div id={"item-outer-#{@item_id}"}>
        test hook with nested liveview
        <div id={"test-hook-#{@item_id}"} phx-hook="test"></div>
      </div>
      """
    end
  end

  def render("live.html", assigns) do
    ~H"""
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <script src="/assets/phoenix/phoenix.min.js">
    </script>
    <script type="module">
      import {LiveSocket} from "/assets/phoenix_live_view/phoenix_live_view.esm.js"

      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
      let liveSocket = new LiveSocket("/live", window.Phoenix.Socket, {params: {_csrf_token: csrfToken}, hooks: {
        test: {
          mounted() { console.log(this.__view().id, "mounted hook!") }
        }
      }})
      liveSocket.connect()
      window.liveSocket = liveSocket
    </script>

    {@inner_content}
    """
  end

  def render(assigns) do
    ~H"""
    <ul id="stream-list" phx-update="stream">
      <%= for {dom_id, item} <- @streams.items do %>
        {live_render(@socket, NestedLive, id: dom_id, session: %{"item_id" => item.id})}
      <% end %>
    </ul>
    <.link patch="/issues/3530?q=a">patch a</.link>
    <.link patch="/issues/3530?q=b">patch b</.link>
    <div phx-click="inc">+</div>
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:count, 3)
      |> stream_configure(:items, dom_id: &"item-#{&1.id}")

    {:ok, socket}
  end

  def handle_params(%{"q" => "a"}, _uri, socket) do
    socket =
      socket
      |> stream(:items, [%{id: 1}, %{id: 3}], reset: true)

    {:noreply, socket}
  end

  def handle_params(%{"q" => "b"}, _uri, socket) do
    socket =
      socket
      |> stream(:items, [%{id: 2}, %{id: 3}], reset: true)

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    socket =
      socket
      |> stream(:items, [%{id: 1}, %{id: 2}, %{id: 3}], reset: true)

    {:noreply, socket}
  end

  def handle_event("inc", _params, socket) do
    socket =
      socket
      |> update(:count, &(&1 + 1))
      |> then(&stream_insert(&1, :items, %{id: &1.assigns.count}))

    {:noreply, socket}
  end
end
