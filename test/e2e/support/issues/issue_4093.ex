defmodule Phoenix.LiveViewTest.E2E.Issue4093Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/4093
  # Verifies that JS.patch updates window.location BEFORE hooks' updated() is called.
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, counter: 0)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_event("patch", _params, socket) do
    {:noreply,
     socket
     |> assign(counter: socket.assigns.counter + 1)
     |> push_patch(to: "/issues/4093?patched=true")}
  end

  def render(assigns) do
    ~H"""
    <script :type={Phoenix.LiveView.ColocatedHook} name=".UrlTracker">
      export default {
        updated() {
          this.el.setAttribute("data-url-in-updated", window.location.href);
        }
      }
    </script>
    <div id="tracker" phx-hook=".UrlTracker" data-counter={@counter}></div>
    <button phx-click="patch">Patch</button>
    """
  end
end
