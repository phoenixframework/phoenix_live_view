defmodule Phoenix.LiveViewTest.E2E.JsLive do
  use Phoenix.LiveView

  alias Phoenix.LiveView.JS

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div id="my-modal" aria-expanded="false" style="display: none;">Test</div>

    <button phx-click={
      JS.show(to: "#my-modal", transition: "fade-in", time: 50)
      |> JS.set_attribute({"aria-expanded", "true"}, to: "#my-modal")
      |> JS.set_attribute({"open", "true"}, to: "#my-modal")
    }>
      show modal
    </button>

    <button phx-click={
      JS.hide(to: "#my-modal", transition: "fade-out", time: 50)
      |> JS.set_attribute({"aria-expanded", "false"}, to: "#my-modal")
      |> JS.remove_attribute("open", to: "#my-modal")
    }>
      hide modal
    </button>

    <button phx-click={
      JS.toggle(to: "#my-modal", in: "fade-in", out: "fade-out", time: 50)
      |> JS.toggle_attribute({"aria-expanded", "true", "false"}, to: "#my-modal")
      |> JS.toggle_attribute({"open", "true"}, to: "#my-modal")
    }>
      toggle modal
    </button>
    """
  end
end
