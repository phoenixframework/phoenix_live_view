defmodule Phoenix.LiveViewTest.Support.LiveInComponent.Root do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"<.live_component
  module={Phoenix.LiveViewTest.Support.LiveInComponent.Component}
  id={:nested_component}
/>"
  end
end

defmodule Phoenix.LiveViewTest.Support.LiveInComponent.Component do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div>
      {live_render(@socket, Phoenix.LiveViewTest.Support.LiveInComponent.Live, id: :nested_live)}"
    </div>
    """
  end
end

defmodule Phoenix.LiveViewTest.Support.LiveInComponent.Live do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H""
  end
end
