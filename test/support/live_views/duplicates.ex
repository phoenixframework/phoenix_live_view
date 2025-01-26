defmodule Phoenix.LiveViewTest.Support.DuplicateIdLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <div id="a">
      <div id="b">
        <div id="a" />
      </div>
    </div>
    """
  end
end

defmodule Phoenix.LiveViewTest.Support.DynamicDuplicateComponentLive do
  use Phoenix.LiveView

  defmodule LiveComponent do
    use Phoenix.LiveComponent

    def mount(socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <div>
        <.live_component
          :if={@render_child}
          module={Phoenix.LiveViewTest.Support.DynamicDuplicateComponentLive.LiveComponent2}
          id="duplicate"
        /> Other content of LiveComponent {@id}
      </div>
      """
    end
  end

  defmodule LiveComponent2 do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <div>I am LiveComponent2</div>
      """
    end
  end

  defmodule NestedLive do
    use Phoenix.LiveView

    def render(assigns) do
      ~H"""
      <.live_component
        module={Phoenix.LiveViewTest.Support.DynamicDuplicateComponentLive.LiveComponent3}
        id="inside-nested"
      />
      """
    end
  end

  defmodule LiveComponent3 do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <div>I am a LC inside nested LV</div>
      """
    end
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, render_first: true, render_second: true, render_duplicate: false)}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      id="First"
      module={Phoenix.LiveViewTest.Support.DynamicDuplicateComponentLive.LiveComponent}
      render_child={true}
    />
    <.live_component
      id="Second"
      module={Phoenix.LiveViewTest.Support.DynamicDuplicateComponentLive.LiveComponent}
      render_child={@render_duplicate}
    />

    {live_render(@socket, Phoenix.LiveViewTest.Support.DynamicDuplicateComponentLive.NestedLive,
      id: "nested"
    )}

    <button phx-click="toggle_duplicate">Toggle duplicate LC</button>
    """
  end

  def handle_event("toggle_duplicate", _, socket) do
    {:noreply, assign(socket, :render_duplicate, !socket.assigns.render_duplicate)}
  end

  def handle_event("toggle_first", _, socket) do
    {:noreply, assign(socket, :render_first, !socket.assigns.render_first)}
  end

  def handle_event("toggle_second", _, socket) do
    {:noreply, assign(socket, :render_second, !socket.assigns.render_second)}
  end
end
