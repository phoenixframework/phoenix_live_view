defmodule Phoenix.LiveViewTest.E2E.Issue3040Live do
  use Phoenix.LiveView

  # https://github.com/phoenixframework/phoenix_live_view/issues/3040

  alias Phoenix.LiveView.JS

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, modal_open: false, submitted: false)}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"modal" => _}, _uri, socket) do
    {:noreply, socket |> assign(:modal_open, true)}
  end

  def handle_params(_unsigned_params, _uri, socket) do
    {:noreply, assign(socket, :modal_open, false)}
  end

  @impl Phoenix.LiveView
  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, :submitted, true)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <style>
      <%= style() %>
    </style>

    <.link patch={"/issues/3040?modal=true"}>Add new</.link>

    <.modal :if={@modal_open} id="my-modal" show on_cancel={JS.patch("/issues/3040")}>
      <.form for={%{}} phx-submit="submit">
        <input type="text" name="name" />

        <p :if={@submitted}>Form was submitted!</p>
      </.form>
    </.modal>
    """
  end

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot(:inner_block, required: true)

  defp modal(assigns) do
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
              class="bg-gray-200 relative hidden rounded-2xl bg-white p-14 ring-1 transition"
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
                <%= render_slot(@inner_block) %>
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  defp hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  defp show(js, selector) do
    JS.show(js,
      to: selector,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  defp hide(js, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  defp style() do
    """
    .fixed{
      position: fixed
    }

    .absolute{
      position: absolute
    }

    .relative{
      position: relative
    }

    .inset-0{
      inset: 0px
    }

    .right-5{
      right: 1.25rem
    }

    .top-6{
      top: 1.5rem
    }

    .z-50{
      z-index: 50
    }

    .-m-3{
      margin: -0.75rem
    }

    .flex{
      display: flex
    }

    .hidden{
      display: none
    }

    .min-h-full{
      min-height: 100%
    }

    .w-full{
      width: 100%
    }

    .max-w-3xl{
      max-width: 48rem
    }

    .flex-none{
      flex: none
    }

    .items-center{
      align-items: center
    }

    .justify-center{
      justify-content: center
    }

    .overflow-y-auto{
      overflow-y: auto
    }

    .rounded-2xl{
      border-radius: 1rem
    }

    .bg-white{
      background-color: rgb(255 255 255 / 1)
    }

    .bg-gray-200{
      background-color: rgb(229 231 235 / 1)
    }

    .bg-zinc-50\/90{
      background-color: rgb(250 250 250 / 0.9)
    }

    .p-14{
      padding: 3.5rem
    }

    .p-3{
      padding: 0.75rem
    }

    .p-4{
      padding: 1rem
    }

    .opacity-20{
      opacity: 0.2
    }

    .transition{
      transition-property: color, background-color, border-color, text-decoration-color, fill, stroke, opacity, box-shadow, transform, filter, backdrop-filter;
      transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
      transition-duration: 150ms
    }

    .transition-opacity{
      transition-property: opacity;
      transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
      transition-duration: 150ms
    }

    .hover\:opacity-40:hover{
      opacity: 0.4
    }

    @media (min-width: 640px){
      .sm\:p-6{
        padding: 1.5rem
      }
    }

    @media (min-width: 1024px){
      .lg\:py-8{
        padding-top: 2rem;
        padding-bottom: 2rem
      }
    }
    """
  end
end
