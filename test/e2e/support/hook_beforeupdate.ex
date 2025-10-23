defmodule Phoenix.LiveViewTest.E2E.HookBeforeupdateLive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(counter: 0)}
  end

  def handle_event("inc", _params, socket) do
    {:noreply, socket |> assign(counter: socket.assigns.counter + 1)}
  end

  def render("live.html", assigns) do
    ~H"""
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <script src="/assets/phoenix/phoenix.min.js">
    </script>
    <script type="module">
      import {LiveSocket} from "/assets/phoenix_live_view/phoenix_live_view.esm.js"
      import {default as colocated, hooks} from "/assets/colocated/index.js";
      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
      let liveSocket = new LiveSocket("/live", window.Phoenix.Socket, {
        params: {_csrf_token: csrfToken},
        reloadJitterMin: 50,
        reloadJitterMax: 500,
        hooks
      })
      liveSocket.connect()
      window.liveSocket = liveSocket
      // initialize js exec handler from colocated js
      colocated.js_exec(liveSocket)
    </script>

    {@inner_content}
    """
  end

  def render(assigns) do
    ~H"""
    <div id="hook-beforeupdate" phx-hook=".LocalHook">
      <button phx-click="inc">
        Inc {@counter}
      </button>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".LocalHook">
      export default {
        mounted() {
          this.el.setAttribute("aria-hidden", false)
        },

        beforeUpdate(from, to) {
          const before = from.getAttribute("aria-hidden");
          const after = to.getAttribute("aria-hidden");

          if (before !== after) {
            console.log("before update", {before, after})
            to.setAttribute("aria-hidden", before)
          }
        },
      }
    </script>
    """
  end
end
