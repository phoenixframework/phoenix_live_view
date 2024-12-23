defmodule Phoenix.LiveViewTest.E2E.Navigation.Layout do
  use Phoenix.LiveView

  def render("live.html", assigns) do
    ~H"""
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <script src="/assets/phoenix/phoenix.min.js">
    </script>
    <script type="module">
      import {LiveSocket} from "/assets/phoenix_live_view/phoenix_live_view.esm.js"
      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
      let liveSocket = new LiveSocket("/live", window.Phoenix.Socket, {params: {_csrf_token: csrfToken}})
      liveSocket.connect()
      window.liveSocket = liveSocket

      window.addEventListener("phx:navigate", (e) => {
        console.log("navigate event", JSON.stringify(e.detail))
      })
    </script>

    <style>
      html, body {
        margin: 0;
        padding: 0;

        font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Ubuntu, "Helvetica Neue", sans-serif;
        font-size: 1rem;
      }
    </style>

    <div style="display: flex; width: 100%; height: 100vh;">
      <div style="position: fixed; height: 100vh; background-color: #f8fafc; border-right: 1px solid; width: 20rem; display: flex; flex-direction: column; padding: 1rem; gap: 0.5rem;">
        <h1 style="margin-bottom: 1rem; font-size: 1.125rem; line-height: 1.75rem;">Navigation</h1>

        <.link navigate="/navigation/a" style="background-color: #f1f5f9; padding: 0.5rem;">
          LiveView A
        </.link>

        <.link navigate="/navigation/b" style="background-color: #f1f5f9; padding: 0.5rem;">
          LiveView B
        </.link>

        <.link navigate="/stream" style="background-color: #f1f5f9; padding: 0.5rem;">
          LiveView (other session)
        </.link>

        <.link navigate="/navigation/dead" style="background-color: #f1f5f9; padding: 0.5rem;">
          Dead View
        </.link>
      </div>

      <div style="margin-left: 22rem; flex: 1; padding: 2rem;">
        {@inner_content}
      </div>
    </div>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Navigation.ALive do
  use Phoenix.LiveView

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket
    |> assign(:param_current, nil)
    |> then(&{:ok, &1})
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    param = Map.get(params, "param")

    socket
    |> assign(:param_current, param)
    |> assign(:param_next, System.unique_integer())
    |> then(&{:noreply, &1})
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h1>This is page A</h1>

    <p>Current param: {@param_current}</p>

    <.styled_link patch={"/navigation/a?param=#{@param_next}"}>Patch this LiveView</.styled_link>
    <.styled_link patch={"/navigation/a?param=#{@param_next}"} replace>Patch (Replace)</.styled_link>
    <.styled_link navigate="/navigation/b#items-item-42">Navigate to 42</.styled_link>
    """
  end

  defp styled_link(assigns) do
    ~H"""
    <.link
      style="padding-left: 1rem; padding-right: 1rem; padding-top: 0.5rem; padding-bottom: 0.5rem; background-color: #e2e8f0; display: inline-flex; align-items: center; border-radius: 0.375rem; cursor: pointer;"
      {Map.delete(assigns, [:inner_block])}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Navigation.BLive do
  use Phoenix.LiveView

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket
    |> then(&{:ok, &1})
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    socket
    |> assign(:container, not is_nil(params["container"]))
    |> apply_action(socket.assigns.live_action, params)
    |> then(&{:noreply, &1})
  end

  def apply_action(socket, :index, _params) do
    items =
      for i <- 1..100 do
        %{id: "item-#{i}", name: i}
      end

    stream(socket, :items, items)
  end

  def apply_action(socket, :show, %{"id" => id}) do
    assign(socket, :id, id)
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h1>This is page B</h1>

    <a
      href="#items-item-42"
      style="margin-bottom: 8px; padding-left: 1rem; padding-right: 1rem; padding-top: 0.5rem; padding-bottom: 0.5rem; background-color: #e2e8f0; display: inline-flex; align-items: center; border-radius: 0.375rem; cursor: pointer;"
    >
      Go to 42.
    </a>

    <div
      :if={@live_action == :index}
      id="my-scroll-container"
      style={"#{if @container, do: "height: 85vh; overflow-y: scroll; "}width: 100%; border: 1px solid #e2e8f0; border-radius: 0.375rem; position: relative;"}
    >
      <ul id="items" style="padding: 1rem; list-style: none;" phx-update="stream">
        <%= for {id, item} <- @streams.items do %>
          <li id={id} style="padding: 0.5rem; border-bottom: 1px solid #e2e8f0;">
            <.link
              patch={"/navigation/b/#{item.id}"}
              style="display: inline-flex; align-items: center; gap: 0.5rem;"
            >
              Item {item.name}
            </.link>
          </li>
        <% end %>
      </ul>
    </div>

    <div :if={@live_action == :show}>
      <p>Item {@id}</p>
    </div>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Navigation.Dead do
  use Phoenix.Controller,
    formats: [:html],
    layouts: [html: {Phoenix.LiveViewTest.E2E.Navigation.Layout, :live}]

  import Phoenix.Component, only: [sigil_H: 2]

  def index(conn, _params) do
    render(conn, :index)
  end
end

defmodule Phoenix.LiveViewTest.E2E.Navigation.DeadHTML do
  use Phoenix.Component

  def index(assigns) do
    ~H"""
    <h1>Dead view</h1>
    """
  end
end
