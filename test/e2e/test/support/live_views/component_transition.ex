defmodule Phoenix.LiveViewTest.Support.ComponentTransitionLive do
  use Phoenix.LiveView
  alias Phoenix.LiveView.JS

  def mount(_params, _session, socket) do
    {:ok, assign(socket, show_components: true)}
  end

  def render(assigns) do
    ~H"""
    <div class="container">
      <button phx-click="remove_components">Remove Components</button>

      <!-- Single-root component that should transition properly -->
      <div
        :if={@show_components}
        id="single-root-component"
        phx-remove={JS.hide(transition: "fade-out-scale", time: 500)}
      >
        <.single_root_component />
      </div>

      <!-- Multi-root component that should transition properly -->
      <div
        :if={@show_components}
        id="multi-root-component"
        phx-remove={JS.hide(transition: "fade-out-scale", time: 500)}
      >
        <.multi_root_component />
      </div>

      <!-- Content that appears after removal -->
      <div :if={not @show_components} id="components-removed">
        Components have been removed
      </div>
    </div>
    """
  end

  # Single root component - should behave same as multi-root during transitions
  def single_root_component(assigns) do
    ~H"""
    <div class="single-root-content bg-blue-200 p-4 rounded">
      Single root component content
    </div>
    """
  end

  # Multi root component - reference behavior for transitions
  def multi_root_component(assigns) do
    ~H"""
    <div class="multi-root-header bg-green-200 p-2 rounded-t">Header</div>
    <div class="multi-root-content bg-green-100 p-4 rounded-b">
      Multi root component content
    </div>
    """
  end

  def handle_event("remove_components", _params, socket) do
    {:noreply, assign(socket, show_components: false)}
  end
end
|}
