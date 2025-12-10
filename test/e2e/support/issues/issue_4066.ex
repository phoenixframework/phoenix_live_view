defmodule Phoenix.LiveViewTest.E2E.Issue4066Live do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  alias Phoenix.LiveViewTest.E2E.Issue4066Live

  def mount(params, _session, socket) do
    {:ok, assign(socket, delay: params["delay"] || 3000, render_lc: true)}
  end

  def render(assigns) do
    ~H"""
    <p id="render-time">{DateTime.utc_now()}</p>
    <button phx-click="toggle">Toggle</button>
    <.live_component :if={@render_lc} id="foo" delay={@delay} module={Issue4066Live.LiveComponent} />
    """
  end

  def handle_event("toggle", _params, socket) do
    {:noreply, assign(socket, :render_lc, !socket.assigns.render_lc)}
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue4066Live.LiveComponent do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <script :type={Phoenix.LiveView.ColocatedHook} name=".MyHook">
      export default {
        mounted() {
          this.el.addEventListener("input", () => {
            setTimeout(() => {
              this.pushEventTo(this.el, "do-something", { value: 100 })
              this.liveSocket.js().setAttribute(document.body, "data-pushed", "yes");
            }, parseInt(this.el.dataset.delay));
          })
        }
      }
    </script>
    <input phx-hook=".MyHook" data-delay={@delay} target={@myself} id={@id} />
    """
  end

  def handle_event("do-something", %{"value" => value}, socket) do
    {:noreply, socket}
  end
end
