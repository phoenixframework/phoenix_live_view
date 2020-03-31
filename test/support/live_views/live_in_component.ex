defmodule Phoenix.LiveViewTest.NestedLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~L"<%= live_component @socket, Phoenix.LiveViewTest.NestedComponent, id: :nested_component %>"
  end
end

defmodule Phoenix.LiveViewTest.NestedComponent do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"<%= live_render @socket, Phoenix.LiveViewTest.LiveInComponent, id: :live_in_component %>"
  end
end

defmodule Phoenix.LiveViewTest.LiveInComponent do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~L""
  end
end
