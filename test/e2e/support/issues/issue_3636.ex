defmodule Phoenix.LiveViewTest.E2E.Issue3636Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/3636
  use Phoenix.LiveView

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <style>
      .space-x-8 > :not([hidden]) ~ :not([hidden]) {
        margin-left: 2rem;
      }
    </style>

    <div class="container mx-auto p-8">
      <button>Outside 1</button>
      <.focus_wrap id="focus-wrap" class="space-x-8">
        <button id="first" class="border rounded py-2 px-4">One</button>
        <button id="second" class="border rounded py-2 px-4">Two</button>
        <button id="third" class="border rounded py-2 px-4">Three</button>
      </.focus_wrap>
      <button>Outside 2</button>
    </div>
    """
  end
end
