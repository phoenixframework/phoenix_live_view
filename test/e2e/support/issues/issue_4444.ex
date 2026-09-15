defmodule Phoenix.LiveViewTest.E2E.Issue4444Live do
  use Phoenix.LiveView

  alias __MODULE__.{ChildLive, LabelComponent}

  def mount(params, _session, socket) do
    {:ok,
     assign(socket,
       variant: Map.get(params, "variant", "skip"),
       outside_count: 0,
       child_pid: nil
     )}
  end

  def handle_info({:child_pid, pid}, socket) do
    {:noreply, assign(socket, child_pid: pid)}
  end

  def handle_event("prepare", _params, socket) do
    {:noreply, update(socket, :outside_count, &(&1 + 1))}
  end

  def handle_event("hold", _params, socket) do
    send(socket.assigns.child_pid, :update_component)
    Process.sleep(500)
    {:noreply, socket}
  end

  def handle_event("update-parent-component", _params, socket) do
    send_update(LabelComponent, id: "parent-component", label: "parent 1")
    {:noreply, socket}
  end

  def render(%{variant: "root"} = assigns) do
    ~H"""
    <div id="locked" phx-hook=".HoldLock">
      <div id="outside-count">{@outside_count}</div>
      <button id="run" type="button">Run</button>
      {live_render(@socket, ChildLive, id: "child-lv", session: %{"parent" => self()})}
    </div>
    <.hook_script />
    """
  end

  def render(assigns) do
    ~H"""
    <div id="outside-count">{@outside_count}</div>
    <button id="update-parent" phx-click="update-parent-component">Update parent component</button>
    <.wrapper socket={@socket} collision={@variant == "collision"} />
    <.hook_script />
    """
  end

  defp wrapper(assigns) do
    ~H"""
    <div id="locked" phx-hook=".HoldLock">
      <.live_component
        :if={@collision}
        module={LabelComponent}
        id="parent-component"
        label="parent 0"
      />
      <button id="run" type="button">Run</button>
      {live_render(@socket, ChildLive, id: "child-lv", session: %{"parent" => self()})}
    </div>
    """
  end

  defp hook_script(assigns) do
    ~H"""
    <script :type={Phoenix.LiveView.ColocatedHook} name=".HoldLock">
      export default {
        mounted() {
          this.el.querySelector("#run").addEventListener("click", () => {
            // ref 0: its reply patches the parent while ref 1 still holds the lock
            this.pushEvent("prepare", {});
            // ref 1: the server triggers the child component update, then sleeps
            this.pushEvent("hold", {});
          });
        },
      };
    </script>
    """
  end

  defmodule LabelComponent do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <div id={@id}>
        <span id={"#{@id}-label"}>{@label}</span>
      </div>
      """
    end
  end

  defmodule ChildLive do
    use Phoenix.LiveView

    def mount(_params, %{"parent" => parent}, socket) do
      if connected?(socket), do: send(parent, {:child_pid, self()})
      {:ok, socket}
    end

    def handle_info(:update_component, socket) do
      send_update(LabelComponent, id: "child-component", label: "child 1")
      {:noreply, socket}
    end

    def render(assigns) do
      ~H"""
      <div id="child-root">
        <.live_component module={LabelComponent} id="child-component" label="child 0" />
      </div>
      """
    end
  end
end
