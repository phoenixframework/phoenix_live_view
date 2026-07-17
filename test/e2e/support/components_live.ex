defmodule Phoenix.LiveViewTest.E2E.ComponentsLive do
  use Phoenix.LiveView

  alias Phoenix.LiveView.JS

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :tailwind, true)}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    active_tab = params["tab"] || "focus_wrap"
    {:noreply, assign(socket, active_tab: active_tab)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <h1 class="text-2xl font-bold mb-6">Phoenix Components Demo</h1>

      <!-- Tab Navigation -->
      <div class="border-b border-gray-200 mb-6">
        <nav class="-mb-px flex space-x-8">
          <.tab_link tab="focus_wrap" active_tab={@active_tab} patch="/components?tab=focus_wrap">
            Focus Wrap
          </.tab_link>
        </nav>
      </div>

      <!-- Tab Content -->
      <div class="mt-6">
        <div :if={@active_tab == "focus_wrap"}>
          <.focus_wrap_demo />
        </div>
      </div>
    </div>
    """
  end

  defp tab_link(assigns) do
    ~H"""
    <.link
      patch={@patch}
      class={[
        "whitespace-nowrap py-2 px-1 border-b-2 font-medium text-sm transition-colors",
        if(@tab == @active_tab,
          do: "border-blue-500 text-blue-600",
          else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
        )
      ]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  defp focus_wrap_demo(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h2 class="text-xl font-semibold mb-4">Phoenix.Component.focus_wrap Demo</h2>
        <p class="text-gray-600 mb-6">
          The focus_wrap component wraps tab focus around a container for accessibility.
          This is essential for modals, dialogs, and menus.
        </p>
      </div>

      <%!-- Dropdown Menu Example --%>
      <div class="space-y-4">
        <h3 class="text-lg font-medium">Dropdown Menu Example</h3>
        <p class="text-sm text-gray-600">
          Click the button to open a dropdown menu with focus wrapping.
        </p>

        <div class="relative inline-block">
          <button
            id="dropdown-button"
            phx-click={JS.toggle(to: "#dropdown-menu") |> JS.focus_first(to: "#dropdown-content")}
            class="px-4 py-2 bg-gray-600 text-white rounded hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-gray-500"
          >
            Options ▼
          </button>

          <div
            id="dropdown-menu"
            class="hidden absolute left-0 mt-2 bg-white border border-gray-300 rounded shadow-lg z-10"
          >
            <.focus_wrap id="dropdown-content" class="py-1">
              <button
                phx-click={JS.hide(to: "#dropdown-menu")}
                class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 focus:bg-gray-100 focus:outline-none"
              >
                Edit Profile
              </button>
              <button
                phx-click={JS.hide(to: "#dropdown-menu")}
                class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 focus:bg-gray-100 focus:outline-none"
              >
                Settings
              </button>
              <button
                phx-click={JS.hide(to: "#dropdown-menu")}
                class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 focus:bg-gray-100 focus:outline-none"
              >
                Sign Out
              </button>
            </.focus_wrap>
          </div>
        </div>
      </div>

      <%!-- Simple Container Example --%>
      <div class="space-y-4">
        <h3 class="text-lg font-medium">Simple Focus Container</h3>
        <p class="text-sm text-gray-600">
          A simple container that wraps focus. Notice how Tab navigation cycles within this box.
        </p>

        <.focus_wrap
          id="simple-focus-container"
          class="border-2 border-dashed border-gray-300 p-4 rounded"
        >
          <div class="space-y-3">
            <h4 class="font-medium">Focus Trapped Container</h4>
            <p class="text-sm text-gray-600">
              Tab through these elements and notice how focus cycles within this container.
            </p>

            <div class="grid grid-cols-2 gap-3">
              <button class="px-3 py-2 bg-green-600 text-white rounded hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500">
                Button 1
              </button>
              <button class="px-3 py-2 bg-green-600 text-white rounded hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500">
                Button 2
              </button>
            </div>

            <input
              type="text"
              placeholder="Input within container"
              class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-green-500"
            />
          </div>
        </.focus_wrap>
      </div>
    </div>
    """
  end
end
