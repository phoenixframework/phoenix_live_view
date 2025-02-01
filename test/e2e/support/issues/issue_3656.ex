defmodule Phoenix.LiveViewTest.E2E.Issue3656Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/3656

  use Phoenix.LiveView

  alias Phoenix.LiveView.JS

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <style>
      * { font-size: 1.1em }
      nav { margin-top: 1em }
      nav a { padding: 8px 16px; border: 1px solid black; text-decoration: none }
      nav a:visited { color: inherit }
      nav a.active { border: 3px solid green }
      nav a.phx-click-loading { animation: pulsate 2s infinite }
      @keyframes pulsate {
        0% {
          background-color: white;
        }
        50% {
          background-color: red;
        }
        100% {
          background-color: white;
        }
      }
    </style>

    {live_render(@socket, Phoenix.LiveViewTest.E2E.Issue3656Live.Sticky,
      id: "sticky",
      sticky: true
    )}
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3656Live.Sticky do
  use Phoenix.LiveView

  def mount(:not_mounted_at_router, _session, socket) do
    {:ok, socket, layout: false}
  end

  def render(assigns) do
    ~H"""
    <nav>
      <.link navigate="/issues/3656?navigated=true">Link 1</.link>
    </nav>
    """
  end
end
