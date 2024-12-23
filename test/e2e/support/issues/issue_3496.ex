defmodule Phoenix.LiveViewTest.E2E.Issue3496.ALive do
  # https://github.com/phoenixframework/phoenix_live_view/issues/3496

  use Phoenix.LiveView

  alias Phoenix.LiveView.JS

  def base(assigns) do
    ~H"""
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <script src="/assets/phoenix/phoenix.min.js">
    </script>
    <script type="module">
      import {LiveSocket} from "/assets/phoenix_live_view/phoenix_live_view.esm.js"

      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
      let liveSocket = new LiveSocket("/live", window.Phoenix.Socket, {params: {_csrf_token: csrfToken}, hooks: {
        MyHook: {
          mounted() {
            console.log("Hook mounted!")
          }
        }
      }})
      liveSocket.connect()
      window.liveSocket = liveSocket
    </script>
    <style>
      * { font-size: 1.1em; }
    </style>
    """
  end

  def with_sticky(assigns) do
    ~H"""
    <.base />

    <div>
      {@inner_content}
    </div>

    {live_render(@socket, Phoenix.LiveViewTest.E2E.Issue3496.StickyLive,
      id: "sticky",
      sticky: true
    )}
    """
  end

  def without_sticky(assigns) do
    ~H"""
    <.base />

    <div>
      {@inner_content}
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket, layout: {__MODULE__, :with_sticky}}
  end

  def render(assigns) do
    ~H"""
    <h1>Page A</h1>
    <.link navigate="/issues/3496/b">Go to page B</.link>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3496.BLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket, layout: {Phoenix.LiveViewTest.E2E.Issue3496.ALive, :without_sticky}}
  end

  def render(assigns) do
    ~H"""
    <h1>Page B</h1>
    <Phoenix.LiveViewTest.E2E.Issue3496.MyComponent.my_component />
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3496.StickyLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket, layout: false}
  end

  def render(assigns) do
    ~H"""
    <div>
      <Phoenix.LiveViewTest.E2E.Issue3496.MyComponent.my_component />
    </div>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3496.MyComponent do
  use Phoenix.Component

  def my_component(assigns) do
    ~H"""
    <div id="my-component" phx-hook="MyHook"></div>
    """
  end
end
