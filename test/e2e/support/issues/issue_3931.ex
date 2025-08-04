defmodule Phoenix.LiveViewTest.E2E.Issue3931Live do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_async(:slow_data, fn ->
        Process.sleep(100)
        {:ok, %{slow_data: "This was loaded asynchronously!"}}
      end)

    {:ok, socket}
  end

  def layout(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-8">
      {render_slot(@inner_block)}
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <.layout {assigns}>
      <.async_result :let={data} assign={@slow_data}>
        <:loading>
          <div id="async" class="flex items-center space-x-3">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
            <p class="text-gray-600">Loading data...</p>
          </div>
        </:loading>

        <div id="async" class="space-y-3">
          {data}
        </div>
      </.async_result>
    </.layout>
    """
  end
end
