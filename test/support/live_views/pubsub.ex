defmodule Phoenix.LiveViewTest.Support.PubSubFlashLive do
  use Phoenix.LiveView

  defmodule Child do
    use Phoenix.LiveComponent

    alias Phoenix.LiveView

    @pubsub Phoenix.LiveViewTest.PubSubTest.PubSub

    def mount(socket) do
      LiveView.subscribe(socket, @pubsub, "lv-pubsub-test", &receive_message/2)
      {:ok, socket}
    end

    def receive_message({:patch, to}, socket) do
      socket
      |> put_flash(:info, "patched")
      |> push_patch(to: to)
    end

    def render(assigns) do
      ~H"""
      <div id="child">child flash: {inspect(@flash)}</div>
      """
    end
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div id="root">root flash: {inspect(@flash)}</div>
    <.live_component module={Child} id="child" />
    """
  end
end
