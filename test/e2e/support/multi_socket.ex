defmodule Phoenix.LiveViewTest.E2E.MultiSocketLive do
  use Phoenix.LiveView, container: {:div, "data-app": "main"}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(clicks: 0, keys: 0, text: nil)
     |> assign(:render_in_root, fn assigns ->
       ~H"""
       <div id="outside-slot" phx-update="ignore"></div>
       """
     end)}
  end

  def render(assigns) do
    ~H"""
    <h1>Main</h1>
    <button id="main-click" phx-click="inc">main-click</button>
    <span id="main-clicks">{@clicks}</span>
    <div phx-window-keydown="key"></div>
    <span id="main-keys">{@keys}</span>
    <form id="main-form" phx-change="text">
      <input id="main-input" type="text" name="text" phx-debounce="50" />
    </form>
    <span id="main-text">{@text}</span>
    <div id="embed-slot" phx-update="ignore" phx-hook="EmbeddedApp" data-label="nested"></div>
    <.link id="to-other" navigate="/multi-socket/other">other</.link>
    """
  end

  def handle_event("inc", _params, socket) do
    {:noreply, update(socket, :clicks, &(&1 + 1))}
  end

  # typing into the inputs never produces Escape, so it never bumps the counter
  def handle_event("key", %{"key" => "Escape"}, socket) do
    {:noreply, update(socket, :keys, &(&1 + 1))}
  end

  def handle_event("key", _params, socket), do: {:noreply, socket}

  def handle_event("text", %{"text" => text}, socket) do
    {:noreply, assign(socket, :text, text)}
  end
end

# A second page to live-navigate to, embedding the nested app the same way.
defmodule Phoenix.LiveViewTest.E2E.MultiSocketLive.OtherLive do
  use Phoenix.LiveView, container: {:div, "data-app": "main"}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, clicks: 0)}
  end

  def render(assigns) do
    ~H"""
    <h1>Other</h1>
    <button id="other-click" phx-click="inc">other-click</button>
    <span id="other-clicks">{@clicks}</span>
    <div id="embed-slot" phx-update="ignore" phx-hook="EmbeddedApp" data-label="nested"></div>
    <.link id="to-main" navigate="/multi-socket">main</.link>
    """
  end

  def handle_event("inc", _params, socket) do
    {:noreply, update(socket, :clicks, &(&1 + 1))}
  end
end

defmodule Phoenix.LiveViewTest.E2E.MultiSocketLive.EmbedController do
  use Phoenix.Controller, formats: [:html]

  import Phoenix.LiveView.Controller

  def show(conn, %{"label" => label}) do
    live_embed(conn, Phoenix.LiveViewTest.E2E.MultiSocketLive.EmbeddedLive,
      session: %{"label" => label}
    )
  end
end

defmodule Phoenix.LiveViewTest.E2E.MultiSocketLive.EmbeddedLive do
  use Phoenix.LiveView, container: {:div, "data-app": "embedded"}

  def mount(_params, %{"label" => label}, socket) do
    {:ok, assign(socket, clicks: 0, keys: 0, text: nil, label: label)}
  end

  def render(assigns) do
    ~H"""
    <h2>Embedded {@label}</h2>
    <button data-role="click" phx-click="inc">emb-click</button>
    <span data-role="clicks">{@clicks}</span>
    <div phx-window-keydown="key"></div>
    <span data-role="keys">{@keys}</span>
    <form phx-change="text">
      <input type="text" name="text" phx-debounce="50" />
    </form>
    <span data-role="text">{@text}</span>
    <button data-role="navigate" phx-click="navigate">emb-navigate</button>
    <.link data-role="navigate-link" navigate="/multi-socket/other">emb-link</.link>
    {live_render(@socket, Phoenix.LiveViewTest.E2E.MultiSocketLive.StickyLive,
      id: "sticky-#{@label}",
      sticky: true,
      container: {:div, "data-app": "sticky"}
    )}
    """
  end

  def handle_event("inc", _params, socket) do
    {:noreply, update(socket, :clicks, &(&1 + 1))}
  end

  def handle_event("key", %{"key" => "Escape"}, socket) do
    {:noreply, update(socket, :keys, &(&1 + 1))}
  end

  def handle_event("key", _params, socket), do: {:noreply, socket}

  def handle_event("text", %{"text" => text}, socket) do
    {:noreply, assign(socket, :text, text)}
  end

  # an embedded view asking to navigate the page: refused by its socket
  def handle_event("navigate", _params, socket) do
    {:noreply, push_navigate(socket, to: "/multi-socket/other")}
  end
end

# A sticky root of the embedded app: a root of the embedded LiveSocket that
# the page's navigation must leave where it is.
defmodule Phoenix.LiveViewTest.E2E.MultiSocketLive.StickyLive do
  use Phoenix.LiveView

  def mount(:not_mounted_at_router, _session, socket) do
    {:ok, assign(socket, clicks: 0), layout: false}
  end

  def render(assigns) do
    ~H"""
    <button data-role="sticky-click" phx-click="inc">sticky-click</button>
    <span data-role="sticky-clicks">{@clicks}</span>
    """
  end

  def handle_event("inc", _params, socket) do
    {:noreply, update(socket, :clicks, &(&1 + 1))}
  end
end

defmodule Phoenix.LiveViewTest.E2E.MultiSocketLive.Layout do
  use Phoenix.Component

  # Boots the page's LiveSocket plus one LiveSocket per embedded copy of the
  # app: one embedded in the host view's ignored slot by the EmbeddedApp hook
  # (and re-embedded into each page's slot across live navigation), one in
  # the ignored slot of the root layout. Both fetch their roots from the
  # embed endpoint, which also hands them their csrf token, and connect to
  # the embedded application's own socket.
  def render("live.html", assigns) do
    ~H"""
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <script src="/assets/phoenix/phoenix.min.js">
    </script>
    <script type="module">
      import { LiveSocket } from "/assets/phoenix_live_view/phoenix_live_view.esm.js";
      const csrfToken = document
        .querySelector("meta[name='csrf-token']")
        .getAttribute("content");
      window.embeddedLiveSockets = {
        nested: new LiveSocket("/embedded/live", window.Phoenix.Socket),
        outside: new LiveSocket("/embedded/live", window.Phoenix.Socket),
      };
      const embedUrl = (label) => `/multi-socket/embed?label=${label}`;
      const hooks = {
        EmbeddedApp: {
          mounted() {
            window.embeddedLiveSockets.nested.embed(
              this.el,
              embedUrl(this.el.dataset.label),
            );
          },
          // nothing to do on destroyed(): the next page's slot re-embeds the
          // same LiveSocket, which leaves the roots held so far
        },
      };
      window.mainLiveSocket = new LiveSocket("/live", window.Phoenix.Socket, {
        params: { _csrf_token: csrfToken },
        hooks,
      });
      window.mainLiveSocket.connect();
      const outsideSlot = document.getElementById("outside-slot");
      if (outsideSlot) {
        window.embeddedLiveSockets.outside.embed(outsideSlot, embedUrl("outside"));
      }
    </script>
    {@inner_content}
    """
  end
end
