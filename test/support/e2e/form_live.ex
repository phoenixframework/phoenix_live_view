defmodule Phoenix.LiveViewTest.E2E.FormLive do
  use Phoenix.LiveView

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("button-test", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <form id="test-form" phx-submit="save" phx-change="validate">
      <input type="text" name="a" readonly value="foo" />
      <input type="text" name="b" value="bar" />
      <button type="submit" phx-disable-with="Submitting">Submit</button>
      <button type="button" phx-click="button-test" phx-disable-with="Loading">Non-form Button</button>
    </form>
    """
  end
end
