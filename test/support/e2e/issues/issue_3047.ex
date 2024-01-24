defmodule Phoenix.LiveViewTest.E2E.Issue3047ALive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  def render("live.html", assigns) do
    ~H"""
    <%= apply(Phoenix.LiveViewTest.E2E.Layout, :render, ["live.html", Map.put(assigns, :inner_content, [])]) %>

    <div class="flex flex-col items-center justify-center">
      <div class="flex flex-row gap-3">
        <.link class="border rounded bg-blue-700 w-fit px-2 text-white" navigate={"/issues/3047/a"}>
          Page A
        </.link>
        <.link class="border rounded bg-blue-700 w-fit px-2 text-white" navigate={"/issues/3047/b"}>
          Page B
        </.link>
      </div>

      <%= @inner_content %>

      <%= live_render(@socket, Phoenix.LiveViewTest.E2E.Issue3047.Sticky, id: "test", sticky: true) %>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <span id="page">Page A</span>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3047BLive do
  use Phoenix.LiveView, layout: {Phoenix.LiveViewTest.E2E.Issue3047ALive, :live}

  def render(assigns) do
    ~H"""
    <span id="page">Page B</span>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3047.Sticky do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    items =
      Enum.map(1..10, fn x ->
        %{id: x, name: "item-#{x}"}
      end)

    {:ok, socket |> stream(:items, items), layout: false}
  end

  def handle_event("reset", _, socket) do
    items =
      Enum.map(5..15, fn x ->
        %{id: x, name: "item-#{x}"}
      end)

    {:noreply, socket |> stream(:items, items, reset: true)}
  end

  def render(assigns) do
    ~H"""
    <div style="border: 2px solid black;">
      <h1>This is the sticky liveview</h1>
      <div id="items" phx-update="stream" style="display: flex; flex-direction: column; gap: 4px;">
        <span :for={{dom_id, item} <- @streams.items} id={dom_id}><%= item.name %></span>
      </div>

      <button phx-click="reset">Reset</button>
    </div>
    """
  end
end
