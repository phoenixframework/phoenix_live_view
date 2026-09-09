defmodule Phoenix.LiveViewTest.E2E.MultiSocketLive do
  use Phoenix.LiveView, container: {:div, "data-app": "main"}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(clicks: 0, keys: 0, text: nil)
     |> assign(:render_in_root, fn assigns ->
       ~H"""
       {live_render(@conn, Phoenix.LiveViewTest.E2E.MultiSocketLive.EmbeddedLive,
         session: %{"label" => "outside"}
       )}
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
    <div id="embed-slot" phx-update="ignore"></div>
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

defmodule Phoenix.LiveViewTest.E2E.MultiSocketLive.EmbedController do
  use Phoenix.Controller, formats: [:html]

  import Phoenix.LiveView.Controller

  def show(conn, %{"label" => label}) do
    conn
    |> put_root_layout(false)
    |> put_layout(false)
    |> live_render(Phoenix.LiveViewTest.E2E.MultiSocketLive.EmbeddedLive,
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
end

defmodule Phoenix.LiveViewTest.E2E.MultiSocketLive.Layout do
  use Phoenix.Component

  # Boots two scoped LiveSockets instead of the default page-wide one.
  def render("live.html", assigns) do
    ~H"""
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <script src="/assets/phoenix/phoenix.min.js">
    </script>
    <script type="module">
      import { LiveSocket } from "/assets/phoenix_live_view/phoenix_live_view.esm.js";
      // the outside embedded root is dead-rendered with this same layout,
      // duplicating this script in the page — boot the sockets only once
      if (!window.mainLiveSocket) {
        const csrfToken = document
          .querySelector("meta[name='csrf-token']")
          .getAttribute("content");
        const opts = { params: { _csrf_token: csrfToken } };
        window.mainLiveSocket = new LiveSocket("/live", window.Phoenix.Socket, {
          ...opts,
          viewSelector: "[data-app=main]",
        });
        window.embeddedLiveSocket = new LiveSocket("/live", window.Phoenix.Socket, {
          ...opts,
          viewSelector: "[data-app=embedded]",
        });
        window.mainLiveSocket.connect();
        // model a real embedder: fetch the embedded app's disconnected
        // render, inject it into the slot the host never patches, and only
        // then boot the embedded socket so it discovers both of its roots
        const res = await fetch("/multi-socket/embed?label=nested");
        const doc = new DOMParser().parseFromString(await res.text(), "text/html");
        const container = doc.querySelector("[data-app=embedded]");
        document.getElementById("embed-slot").innerHTML = container.outerHTML;
        window.embeddedLiveSocket.connect();
      }
    </script>
    {@inner_content}
    """
  end
end
