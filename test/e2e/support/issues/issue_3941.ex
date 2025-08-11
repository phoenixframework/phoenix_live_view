defmodule Phoenix.LiveViewTest.E2E.Issue3941Live do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  alias Phoenix.LiveViewTest.E2E.Issue3941Live.Item

  @all_items [
    "Item_1",
    "Item_2"
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:selected_items, @all_items)
      |> assign(:filter_options, @all_items)

    {:ok, socket}
  end

  def render("live.html", assigns) do
    ~H"""
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <script src="/assets/phoenix/phoenix.min.js">
    </script>
    <script type="module">
      import {LiveSocket} from "/assets/phoenix_live_view/phoenix_live_view.esm.js"
      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
      let liveSocket = new LiveSocket("/live", window.Phoenix.Socket, {
        params: {_csrf_token: csrfToken},
        hooks: {
          PagePositionNotifier: {
            mounted() {
              this.pushEvent("page_position_update", {});
            },
          }
        }
      })
      liveSocket.connect()
    </script>

    {@inner_content}
    """
  end

  def render(assigns) do
    ~H"""
    <.multi_select id="multi-select" items={@filter_options} selected={@selected_items} />
    <div :for={item <- @selected_items}>
      <.live_component
        module={Item}
        id={"item-#{item}"}
        item={item}
      />
    </div>
    """
  end

  def multi_select(assigns) do
    ~H"""
    <div :for={item <- @items}>
      <label for={"item-select-#{item}"}>
        <input
          type="checkbox"
          phx-click="toggle_item"
          phx-value-clicked={item}
          id={"select-#{item}"}
          name="select"
          value={item}
          checked={item in @selected}
        />
        {item}
      </label>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_item", params = %{"clicked" => clicked_id}, socket) do
    selected = socket.assigns.selected_items

    selected =
      case params["value"] do
        nil ->
          selected = List.delete(selected, clicked_id)

        value ->
          selected = selected ++ [value]
      end

    {:noreply, assign(socket, selected_items: Enum.sort(selected))}
  end

  def handle_event("page_position_update", _params, socket) do
    {:noreply, socket}
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3941Live.Item do
  use Phoenix.LiveComponent
  alias Phoenix.LiveViewTest.E2E.Issue3941Live.ItemHeader

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(:item, assigns.item)
     |> assign_unrendered_component_assigns()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"item-#{@item}"} phx-hook="PagePositionNotifier">
      <.live_component
        id={"item-header-#{@item}"}
        module={ItemHeader}
        item={@item}
      />
      <.unrendered_component :if={false} id="unrendered" any_assign={@any_assign} />
    </div>
    """
  end

  defp unrendered_component(_) do
    raise "SHOULD NOT BE CALLED"
  end

  defp assign_unrendered_component_assigns(socket) do
    socket
    |> assign(:any_assign, true)
    |> assign_async(
      :any_assign,
      fn ->
        {:ok, %{any_assign: true}}
      end
    )
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3941Live.ItemHeader do
  use Phoenix.LiveComponent

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(:item, assigns.item)
     |> assign_async(
       :async_assign,
       fn ->
         {:ok, %{async_assign: :assign}}
       end,
       reset: true
     )}
  end

  def render(assigns) do
    ~H"""
    <div id={"header-#{@item}"}>
      <.async_result assign={@async_assign}>
        <:loading>
          <div id={@item} class="border border-y-0 bg-red-500 text-white">
            {"#{@item} - I AM LOADING"}
          </div>
        </:loading>
        <div id={@item} class="border border-y-0 bg-green-500 text-white">
          {"#{@item} - I AM LOADED!"}
        </div>
      </.async_result>
      {inspect(@async_assign)}
    </div>
    """
  end
end
