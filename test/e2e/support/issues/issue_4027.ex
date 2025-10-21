defmodule Phoenix.LiveViewTest.E2E.Issue4027Live do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  alias Phoenix.LiveViewTest.E2E.Issue4027Live
  alias Phoenix.LiveView.JS
  alias Phoenix.LiveView.AsyncResult

  def mount(params, _session, socket) do
    {:ok, socket |> assign(:data, AsyncResult.ok([])) |> assign(:case, params["case"] || "first")}
  end

  def render(assigns) do
    ~H"""
    <div class="p-4">
      <p class="my-4">
        Click Load Data. 3 items should be displayed. Then click Remove First entry. The expected result is 2 items displayed.
      </p>
      <div>
        <.async_result :let={data} :if={@case == "first"} assign={@data}>
          <.live_component module={Issue4027Live.ReproLiveComponent} id="repro" data={data} />
        </.async_result>
        <%= if @case == "second" do %>
          <div style="margin: 10px; height: 1px; background-color: black;"></div>
          <.live_component
            module={Issue4027Live.ReproLiveComponentWithAsyncResult}
            id="repro_async"
            data={@data}
          />
        <% end %>
      </div>
      <div>
        <button phx-click="load">Load data</button>
        <button phx-click="remove">Remove first entry</button>
      </div>
    </div>
    """
  end

  def handle_event("load", _, socket) do
    socket =
      assign_async(socket, :data, fn ->
        Process.sleep(100)

        {:ok,
         %{data: [%{id: 1, value: "First"}, %{id: 2, value: "Second"}, %{id: 3, value: "Third"}]}}
      end)

    {:noreply, socket}
  end

  def handle_event("remove", _, socket) do
    socket =
      assign_async(socket, :data, fn ->
        Process.sleep(100)
        {:ok, %{data: [%{id: 2, value: "Second"}, %{id: 3, value: "Third"}]}}
      end)

    {:noreply, socket}
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue4027Live.ReproLiveComponentWithAsyncResult do
  use Phoenix.LiveComponent

  def mount(socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div id="result">
      <.async_result :let={data} assign={@data}>
        <p :for={item <- data} :key={item.id}>{item.value}</p>
      </.async_result>
    </div>
    """
  end

  def handle_event(_, _, socket) do
    {:noreply, socket}
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue4027Live.ReproLiveComponent do
  use Phoenix.LiveComponent

  def mount(socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div id="result">
      <p :for={item <- @data} :key={item.id}>{item.value}</p>
    </div>
    """
  end

  def handle_event(_, _, socket) do
    {:noreply, socket}
  end
end
