defmodule Phoenix.LiveViewTest.E2E.Issue4209Live do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, outside_count: 0)}
  end

  def handle_info(:bump_outside, socket) do
    {:noreply, update(socket, :outside_count, &(&1 + 1))}
  end

  def handle_info(:update_child, socket) do
    send_update(__MODULE__.ChildComponent, id: "locked-child", label: "child 1")
    {:noreply, socket}
  end

  defp locked_panel(assigns) do
    ~H"""
    <div id="locked-panel" phx-hook=".LockedPanel">
      <.live_component module={__MODULE__.ChildComponent} id="locked-child" label="child 0" />
      <button id="start-locked-update" type="button">Start locked update</button>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".LockedPanel">
      export default {
        mounted() {
          this.el
            .querySelector("#start-locked-update")
            .addEventListener("click", () => {
              this.pushEventTo("#slow-target-child", "hold-lock", {});
            });
        },
      };
    </script>
    """
  end

  def render(assigns) do
    ~H"""
    <div id="outside-count">{@outside_count}</div>
    <.locked_panel />
    <div id="slow-target">
      {live_render(@socket, __MODULE__.SlowTargetLive,
        id: "slow-target-live",
        session: %{"parent" => self()}
      )}
    </div>
    """
  end

  defmodule ChildComponent do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <div id="locked-child-content">
        <span id="locked-child-label">{@label}</span>
      </div>
      """
    end
  end

  defmodule SlowTargetLive do
    use Phoenix.LiveView

    def mount(_params, %{"parent" => parent}, socket) do
      {:ok, assign(socket, parent: parent)}
    end

    def handle_event("hold-lock", _params, socket) do
      send(socket.assigns.parent, :bump_outside)
      send(socket.assigns.parent, :update_child)
      Process.sleep(800)
      {:noreply, socket}
    end

    def render(assigns) do
      ~H"""
      <div id="slow-target-child">slow target</div>
      """
    end
  end
end
