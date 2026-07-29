defmodule Phoenix.LiveViewTest.E2E.Issue4350Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/4350
  #
  # A LiveComponent that is destroyed and then used again before the client's
  # cids_destroyed arrives must revive its whole subtree, including children that
  # change tracking would otherwise skip.

  defmodule Leaf do
    use Phoenix.LiveComponent

    def mount(socket), do: {:ok, assign(socket, count: 0)}

    def handle_event("bump", _params, socket) do
      {:noreply, update(socket, :count, &(&1 + 1))}
    end

    def render(assigns) do
      ~H"""
      <div id="leaf">
        count: <span id="leaf-count">{@count}</span>
        <button id="bump" phx-click="bump" phx-target={@myself}>bump</button>
      </div>
      """
    end
  end

  defmodule Branch do
    use Phoenix.LiveComponent

    # @tick changes, the live_component below does not, so change tracking skips
    # the dynamic holding the leaf on every re-render after the first.
    def render(assigns) do
      ~H"""
      <div id="branch">
        tick: {@tick}
        <.live_component module={Leaf} id="leaf" />
      </div>
      """
    end
  end

  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, show: true, tick: 0)}
  end

  def render(assigns) do
    ~H"""
    <button id="tick" phx-click="tick">tick</button>
    <button id="hide" phx-click="hide">hide</button>
    <button id="show" phx-click="show">show</button>

    <div :if={@show} id="wrapper">
      <.live_component module={Branch} id="branch" tick={@tick} />
    </div>
    """
  end

  def handle_event("tick", _params, socket), do: {:noreply, update(socket, :tick, &(&1 + 1))}
  def handle_event("hide", _params, socket), do: {:noreply, assign(socket, show: false)}
  def handle_event("show", _params, socket), do: {:noreply, assign(socket, show: true)}
end
