defmodule Phoenix.LiveViewTest.LiveComponent do
  use Phoenix.LiveComponent

  @impl true
  def render(assigns) do
    {:ok, version} = Application.fetch_env(:phoenix_live_view, :vsn)
    assigns = assign(assigns, version: version)

    ~H"""
    <div>
      <div>Version <%= @version %></div>
    </div>
    """
  end
end

defmodule Phoenix.LiveViewTest.ReloadComponentLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div>
      <Phoenix.Component.live_component
        id="live-component"
        module={Phoenix.LiveViewTest.LiveComponent}
      />
    </div>
    """
  end
end
