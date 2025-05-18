defmodule Phoenix.LiveViewTest.E2E.CustomEventsLive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  @impl Phoenix.LiveView
  def render("live.html", assigns) do
    ~H"""
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <script src="/assets/phoenix/phoenix.min.js">
    </script>
    <script type="module">
      class MyButton extends HTMLElement {
        connectedCallback() {
          this.attachShadow({mode: 'open'});
          this.shadowRoot.innerHTML = `<button>Do it!</button>`;
          this.shadowRoot.querySelector('button').addEventListener('click', () => {
            this.dispatchEvent(new CustomEvent('my_event', {detail: {foo: 'bar'}}));
          });
        }
      }
      window.customElements.define('my-button', MyButton);

      import {LiveSocket} from "/assets/phoenix_live_view/phoenix_live_view.esm.js"

      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
      let liveSocket = new LiveSocket("/live", window.Phoenix.Socket, {params: {_csrf_token: csrfToken}})
      liveSocket.connect()
      window.liveSocket = liveSocket
    </script>
    {@inner_content}
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:foo, nil)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <my-button id="mybutton" phx-custom-events="my_event"></my-button>
    <div id="foo">{@foo}</div>
    """
  end

  def handle_event("my_event", %{"foo" => foo}, socket) do
    {:noreply, socket |> assign(:foo, foo)}
  end
end
