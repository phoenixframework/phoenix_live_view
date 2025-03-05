defmodule Phoenix.LiveViewTest.E2E.Issue3658Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/3658

  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.link navigate="/issues/3658?navigated=true">Link 1</.link>

    {live_render(@socket, Phoenix.LiveViewTest.E2E.Issue3658Live.Sticky,
      id: "sticky",
      sticky: true
    )}
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3658Live.Sticky do
  use Phoenix.LiveView

  def mount(:not_mounted_at_router, _session, socket) do
    {:ok, socket, layout: false}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div id="foo" phx-remove={Phoenix.LiveView.JS.dispatch("my-event")}>Hi</div>
    </div>
    """
  end
end
