defmodule Phoenix.LiveViewTest.E2E.Issue3819Live do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", _params, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <.form id="recover" phx-change="validate" phx-submit="save">
      <button>Submit</button>
    </.form>
    """
  end
end
