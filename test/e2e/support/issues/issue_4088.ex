defmodule Phoenix.LiveViewTest.E2E.Issue4088Live do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.live_component module={__MODULE__.LC} id="lc" />
    """
  end

  defmodule LC do
    use Phoenix.LiveComponent

    def mount(socket) do
      {:ok, assign(socket, :test, "value")}
    end

    def render(assigns) do
      ~H"""
      <script :type={Phoenix.LiveView.ColocatedHook} name=".MyHook">
        export default {
          mounted() {
            this.pushEventTo(this.el, 'my_update', {})
            this.pushEventTo(this.el, 'my_update', {})
            this.pushEventTo(this.el, 'my_update', {})
          }
        }
      </script>
      <div id="foo" phx-hook=".MyHook" phx-target={@myself}>
        {@test}
      </div>
      """
    end

    def handle_event("my_update", _params, socket) do
      {:noreply, assign(socket, :test, :rand.uniform())}
    end
  end
end
