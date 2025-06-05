defmodule Phoenix.LiveViewTest.Support.ComponentTransitionLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :step, 1)}
  end

  def render(assigns) do
    ~H"""
    <div class="container">
      <button phx-click="next_step">Next Step</button>
      
    <!-- Element with single-root component that should transition -->
      <div
        :if={@step == 1}
        id="single-root-container"
        phx-remove={JS.hide(transition: "opacity-100", time: 300)}
      >
        <.single_root_component />
      </div>
      
    <!-- Element with multi-root component that should transition -->
      <div
        :if={@step == 1}
        id="multi-root-container"
        phx-remove={JS.hide(transition: "opacity-100", time: 300)}
      >
        <.multi_root_component />
      </div>
      
    <!-- Elements that appear in step 2 -->
      <div :if={@step == 2} id="step-2">Step 2 content</div>
    </div>
    """
  end

  # Single root component - this disappears immediately during transition
  def single_root_component(assigns) do
    ~H"""
    <div class="single-root">Single root component content</div>
    """
  end

  # Multi root component - this properly waits for transition
  def multi_root_component(assigns) do
    ~H"""
    <div></div>
    <div class="multi-root">Multi root component content</div>
    """
  end

  def handle_event("next_step", _params, socket) do
    {:noreply, assign(socket, :step, 2)}
  end
end
