defmodule Phoenix.LiveViewTest.E2E.ErrorLive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  # TODO: find a way to silence the raise "boom" crashes

  defmodule ChildLive do
    use Phoenix.LiveView

    @impl Phoenix.LiveView
    def mount(_params, _session, socket) do
      if connected?(socket) do
        send(socket.parent_pid, {:child_mounted, self()})

        receive do
          :boom ->
            raise "boom"

          :boom_link ->
            Process.link(socket.parent_pid)
            raise "boom"

          :ok_link ->
            Process.link(socket.parent_pid)
            :ok

          _ ->
            :ok
        end
      end

      {:ok, socket}
    end

    @impl Phoenix.LiveView
    def handle_event("boom", _params, _socket) do
      raise "boom"
    end

    @impl Phoenix.LiveView
    def render(assigns) do
      ~H"""
      <%= if connected?(@socket), do: "Child connected", else: "Child rendered (dead)" %>
      <p id="child-render-time">child rendered at: <%= DateTime.utc_now() %></p>

      <button phx-click="boom">Crash child</button>

      <p class="if-phx-error">Error</p>
      <p class="if-phx-client-error">Client Error</p>
      <p class="if-phx-server-error">Server Error</p>
      <p class="if-phx-disconnected">Disconnected</p>
      <p class="if-phx-loading">Loading</p>
      """
    end
  end

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
        reloadJitterMax: 50,
        reloadJitterMin: 50,
        maxReloads: 5,
        failsafeJitter: 30000,
        maxChildJoinTries: 3,
        // override Phoenix.Socket channel join backoff
        rejoinAfterMs: (_tries) => 50
      })
      liveSocket.connect()
      window.liveSocket = liveSocket
    </script>

    <%= @inner_content %>
    """
  end

  @impl Phoenix.LiveView
  def mount(%{"dead-mount" => "raise"}, _session, _socket), do: raise("boom")

  def mount(%{"connected-mount" => "raise"}, _session, socket) do
    if connected?(socket) do
      raise "boom"
    end

    {:ok, socket}
  end

  def mount(%{"connected-child-mount-raise" => "link"}, _session, socket) do
    # prevent infinite reconnect loop, as the parent always mounts successfully
    # and therefore the clientside failsafe never triggers;
    # therefore we only crash once
    case get_connect_params(socket) do
      %{"_mounts" => 0} ->
        {:ok, assign(socket, child: true, want_fails: 1, have_fails: 0, link: true)}

      _ ->
        {:ok, assign(socket, child: true, want_fails: 1, have_fails: 1, link: true)}
    end
  end

  def mount(%{"connected-child-mount-raise" => want_fails}, _session, socket) do
    # we send the number of times the child mount should fail
    # to test that the page is not reloaded, but the child rejoins successfully
    # up to a certain number of times
    want_fails = String.to_integer(want_fails)
    {:ok, assign(socket, child: true, want_fails: want_fails, have_fails: 0)}
  end

  def mount(%{"child" => _}, _session, socket) do
    {:ok, assign(socket, child: true, want_fails: 0, have_fails: 0)}
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:child_mounted, pid}, socket) do
    if socket.assigns[:have_fails] < socket.assigns[:want_fails] do
      send(pid, (socket.assigns[:link] && :boom_link) || :boom)
      {:noreply, assign(socket, have_fails: socket.assigns[:have_fails] + 1)}
    else
      send(pid, (socket.assigns[:link] && :ok_link) || :ok)
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("boom", _params, _socket) do
    raise "boom"
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <p id="render-time">main rendered at: <%= DateTime.utc_now() %></p>

    <button phx-click="boom">Crash main</button>

    <p class="if-phx-error">Error</p>
    <p class="if-phx-client-error">Client Error</p>
    <p class="if-phx-server-error">Server Error</p>
    <p class="if-phx-disconnected">Disconnected</p>
    <p class="if-phx-loading">Loading</p>

    <div style="border: 1px solid lightgray; padding: 4px; margin-top: 16px;">
      <%= if assigns[:child] do %>
        <%= live_render(@socket, ChildLive, id: "child") %>
      <% end %>
    </div>

    <style>
      [data-phx-session] .if-phx-error {
        display: none;
      }

      [data-phx-session].phx-error > .if-phx-error {
        display: block;
      }

      [data-phx-session] .if-phx-client-error {
        display: none;
      }

      [data-phx-session].phx-client-error > .if-phx-client-error {
        display: block;
      }

      [data-phx-session] .if-phx-server-error {
        display: none;
      }

      [data-phx-session].phx-server-error > .if-phx-server-error {
        display: block;
      }

      [data-phx-session] .if-phx-disconnected {
        display: none;
      }

      [data-phx-session].phx-disconnected > .if-phx-disconnected {
        display: block;
      }

      [data-phx-session] .if-phx-loading {
        display: none;
      }

      [data-phx-session].phx-loading > .if-phx-loading {
        display: block;
      }
    </style>
    """
  end
end
