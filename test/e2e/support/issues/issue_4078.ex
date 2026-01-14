defmodule Phoenix.LiveViewTest.E2E.Issue4078Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/4078
  #
  # live_file_input uses data-phx-update="ignore" to preserve file selection,
  # but this was blocking updates to attributes like class, disabled, and style.
  # This test verifies these attributes can now be changed dynamically.
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  def render("live.html", assigns) do
    ~H"""
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <script src="/assets/phoenix/phoenix.min.js">
    </script>
    <script type="module">
      import {LiveSocket} from "/assets/phoenix_live_view/phoenix_live_view.esm.js"
      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
      let liveSocket = new LiveSocket("/live", window.Phoenix.Socket, {
        params: {_csrf_token: csrfToken},
      })
      liveSocket.connect()
    </script>
    {@inner_content}
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:disabled?, true)
     |> assign(:custom_class, "initial-class")
     |> allow_upload(:avatar, accept: ~w(.jpg .jpeg .png .txt), max_entries: 2)}
  end

  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("toggle-disabled", _params, socket) do
    {:noreply, assign(socket, :disabled?, !socket.assigns.disabled?)}
  end

  def handle_event("toggle-class", _params, socket) do
    new_class =
      if socket.assigns.custom_class == "initial-class",
        do: "updated-class",
        else: "initial-class"

    {:noreply, assign(socket, :custom_class, new_class)}
  end

  def render(assigns) do
    ~H"""
    <form id="upload-form" phx-change="validate">
      <.live_file_input upload={@uploads.avatar} disabled={@disabled?} class={@custom_class} />
    </form>

    <button id="toggle-disabled" type="button" phx-click="toggle-disabled">Toggle Disabled</button>
    <button id="toggle-class" type="button" phx-click="toggle-class">Toggle Class</button>

    <article :for={entry <- @uploads.avatar.entries} class="upload-entry">
      <span class="entry-name">{entry.client_name}</span>
    </article>
    """
  end
end
