defmodule Phoenix.LiveViewTest.E2E.PortalLive do
  use Phoenix.LiveView

  alias Phoenix.LiveView.JS

  def render("root.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <head>
      <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
      <script src="https://cdn.tailwindcss.com/3.4.3">
      </script>
      <script src="/assets/phoenix/phoenix.min.js">
      </script>
      <script type="module">
        import {LiveSocket} from "/assets/phoenix_live_view/phoenix_live_view.esm.js"
        let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
        let liveSocket = new LiveSocket("/live", window.Phoenix.Socket, {params: {_csrf_token: csrfToken}})
        liveSocket.connect()
        window.liveSocket = liveSocket
      </script>
    </head>

    <body>
      <main style="flex: 1; padding: 2rem;">
        {@inner_content}
      </main>
      <div id="root-portal"></div>
    </body>
    """
  end

  def render("live.html", assigns) do
    ~H"""
    {@inner_content}

    <div id="portal-target"></div>
    """
  end

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    case params do
      %{"tick" => "false"} -> :ok
      _ -> :timer.send_interval(1000, self(), :tick)
    end

    socket
    |> assign(:param_current, nil)
    |> assign(:count, 0)
    |> assign(:render_modal, true)
    |> then(&{:ok, &1, layout: {__MODULE__, :live}})
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
  def handle_info(:tick, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count + 1)}
  end

  @impl Phoenix.LiveView
  def handle_event("tick", _params, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count + 1)}
  end

  def handle_event("toggle_modal", _params, socket) do
    {:noreply, assign(socket, :render_modal, !socket.assigns.render_modal)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h1>Modal example</h1>

    <p>Current param: {@param_current}</p>

    <.button phx-click={JS.patch("/portal?param=#{@param_next}")}>Patch this LiveView</.button>

    <.button phx-click={show_modal("my-modal")}>Open modal</.button>
    <.button phx-click="toggle_modal">Toggle modal render</.button>
    <.button phx-click={show_modal("my-modal-2")}>Open second modal</.button>
    <.button phx-click={JS.push("tick")}>Tick</.button>

    <.button phx-click={JS.navigate("/form")}>Live navigate</.button>

    <template :if={@render_modal} id="portal-source" phx-portal="root-portal">
      <.modal id="my-modal">
        This is a modal.
        <p>DOM patching works as expected: {@count}</p>
        <.button phx-click={JS.patch("/portal?param=#{@param_next}")}>Patch this LiveView</.button>
      </.modal>
    </template>

    <template id="portal-source-2" phx-portal="portal-target">
      <.modal id="my-modal-2">
        This is a second modal.
      </.modal>
    </template>

    <template id="portal-with-live-component" phx-portal="root-portal">
      <.live_component module={Phoenix.LiveViewTest.E2E.PortalLive.LC} id="lc" />
    </template>

    {live_render(@socket, Phoenix.LiveViewTest.E2E.PortalLive.NestedLive, id: "nested")}
    """
  end

  attr :type, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "phx-submit-loading:opacity-75 rounded-lg bg-zinc-900 hover:bg-zinc-700 py-2 px-3",
        "text-sm font-semibold leading-6 text-white active:text-white/80",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div id={"#{@id}-bg"} class="bg-zinc-50/90 fixed inset-0 transition-opacity" aria-hidden="true" />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class="w-full max-w-3xl p-4 sm:p-6 lg:py-8">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="shadow-zinc-700/10 ring-zinc-700/10 relative hidden rounded-2xl bg-white p-14 shadow-lg ring-1 transition"
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="-m-3 flex-none p-3 opacity-20 hover:opacity-40"
                  aria-label="close"
                >
                  x
                </button>
              </div>
              <div id={"#{@id}-content"}>
                {render_slot(@inner_block)}
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 300,
      transition: {"transition-all ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end
end

defmodule Phoenix.LiveViewTest.E2E.PortalLive.NestedLive do
  use Phoenix.LiveView

  def handle_event("event", _params, socket) do
    IO.puts("Nested LV got event!")
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="border border-orange-200">
      <h1>Nested LiveView</h1>

      <button phx-click="event">Toggle event in nested LV</button>

      <template id="nested-tpl" phx-portal="portal-target">
        <div id="button-from-nested-lv">
          <button phx-click="event">Toggle event in nested LV (from teleported button)</button>
        </div>
      </template>

      <template id="teleported-nested-lv" phx-portal="portal-target">
        <div id="nested-lv-container">
          {live_render(@socket, Phoenix.LiveViewTest.E2E.PortalLive.NestedTeleportedLive,
            id: "nested-teleported"
          )}
        </div>
      </template>
    </div>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.PortalLive.NestedTeleportedLive do
  use Phoenix.LiveView

  def handle_event("event", _params, socket) do
    IO.puts("Nested teleported LV got event!")
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="border border-green-200">
      <h1>Nested teleport LiveView</h1>
      <button phx-click="event">Toggle event in teleported LV</button>
    </div>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.PortalLive.LC do
  use Phoenix.LiveComponent

  def update(assigns, socket) do
    {:ok, stream(socket, :items, [%{id: 1, name: "Item 1"}, %{id: 2, name: "Item 2"}])}
  end

  def handle_event("prepend", _params, socket) do
    rand = 1000 + floor(:rand.uniform() * 1000)
    {:noreply, stream_insert(socket, :items, %{id: rand, name: "Item #{rand}"}, at: 0)}
  end

  def render(assigns) do
    ~H"""
    <div id="teleported-lc" class="border border-red-200">
      <h1>LiveComponent</h1>

      <ul id="stream-in-lc" phx-update="stream">
        <li :for={{id, item} <- @streams.items} id={id}>
          {item.name}
        </li>
      </ul>

      <button phx-click="prepend" phx-target={@myself}>Prepend item</button>
    </div>
    """
  end
end
