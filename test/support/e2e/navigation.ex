defmodule Phoenix.LiveViewTest.E2E.Navigation.Layout do
  use Phoenix.LiveView

  alias Phoenix.LiveView.JS

  def render("live.html", assigns) do
    ~H"""
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <script src="/assets/phoenix/phoenix.min.js">
    </script>
    <script src="/assets/phoenix_live_view/phoenix_live_view.js">
    </script>
    <script>
      window.navigationEvents = []
      let customScrollPosition = null;

      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
      let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket, {
        params: {_csrf_token: csrfToken},
        navigation: {
          async beforeEach(to, from) {
            console.log(to, from)
            window.navigationEvents.push({ type: "before", to, from });

            // remember custom scroll position
            if (document.querySelector("#my-scroll-container")) {
              customScrollPosition = document.querySelector("#my-scroll-container").scrollTop
            }

            // prevent navigating when form submit is pending
            if (document.querySelector("form[data-submit-pending]")) {
              return confirm("Do you really want to leave the page?")
            }

            if(document.startViewTransition) {
              document.startViewTransition();
            }
          },
          async afterEach(to, from) {
            window.navigationEvents.push({ type: "after", to, from });

            // restore custom scroll position
            if (document.querySelector("#my-scroll-container") && customScrollPosition) {
              document.querySelector("#my-scroll-container").scrollTop = customScrollPosition
            }
          }
        }
      })
      liveSocket.connect()

      window.onbeforeunload = function(e) {
        if(document.querySelector("form[data-submit-pending]")) {
          return "Do you really want to leave the page?"
        }
      };
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

        <.link navigate="/navigation/c" style="background-color: #f1f5f9; padding: 0.5rem;">
          LiveView C
        </.link>

        <.link navigate="/stream" style="background-color: #f1f5f9; padding: 0.5rem;">
          LiveView (other session)
        </.link>
      </div>

      <div style="margin-left: 22rem; flex: 1; padding: 2rem;">
        <%= @inner_content %>
      </div>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  defp flash_group(assigns) do
    ~H"""
    <div id="flash-group">
      <.flash kind={:info} title="Success!" flash={@flash} />
      <.flash kind={:error} title="Error!" flash={@flash} />
    </div>
    """
  end

  attr :id, :string
  attr :flash, :map, default: %{}
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error]
  attr :rest, :global

  slot(:inner_block, required: false)

  defp flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || @flash[to_string(@kind)]}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> JS.hide(to: "##{@id}")}
      role="alert"
      style={"position: fixed; top: 0.5rem; right: 0.5rem; margin-right: 0.5rem; width: 20rem; z-index: 50; border-radius: 0.375rem; padding: 0.75rem; box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05); background-color: #{(@kind == :info && "#ECFDF5") || (@kind == :error && "#FEF2F2")}; color: #{(@kind == :info && "#065F46") || (@kind == :error && "#991B1B")}; ring-width: 1px; ring-color: #{(@kind == :info && "#10B981") || (@kind == :error && "#F43F5E")};"}
      {@rest}
    >
      <p
        :if={@title}
        style="display: flex; align-items: center; gap: 0.375rem; font-size: 0.875rem; font-weight: 600; line-height: 1.5;"
      >
        <%= @title %>
      </p>
      <p style="margin-top: 0.5rem; font-size: 0.875rem; line-height: 1.25;"><%= msg %></p>
      <button
        type="button"
        style="position: absolute; top: 0.25rem; right: 0.25rem; padding: 0.5rem;"
        aria-label="close"
      >
        x
      </button>
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

    <p>Current param: <%= @param_current %></p>

    <.link
      patch={"/navigation/a?param=#{@param_next}"}
      style="padding-left: 1rem; padding-right: 1rem; padding-top: 0.5rem; padding-bottom: 0.5rem; background-color: #e2e8f0; display: inline-flex; align-items: center; border-radius: 0.375rem; cursor: pointer;"
    >
      Patch this LiveView
    </.link>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Navigation.BLive do
  use Phoenix.LiveView

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket
    |> assign(:form, to_form(%{}))
    |> assign(:form_dirty, false)
    |> then(&{:ok, &1})
  end

  @impl Phoenix.LiveView
  def handle_event("validate", params, socket) do
    socket
    |> assign(:form, to_form(params))
    |> assign(:form_dirty, true)
    |> then(&{:noreply, &1})
  end

  def handle_event("submit", _params, socket) do
    socket
    |> assign(:form, %{})
    |> assign(:form_dirty, false)
    |> put_flash(:info, "Submitted successfully!")
    |> then(&{:noreply, &1})
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h1>This is page C</h1>

    <form id="my-form" data-submit-pending={@form_dirty} phx-change="validate" phx-submit="submit">
      <label style="font-size: 0.875rem; color: #334155;">
        Email
      </label>
      <input
        type="text"
        name="email"
        style="height: 2.5rem; width: 12rem; border: 1px solid #e2e8f0; border-radius: 0.375rem; padding: 1rem;"
      />

      <button style="padding-left: 1rem; padding-right: 1rem; padding-top: 0.5rem; padding-bottom: 0.5rem; background-color: #e2e8f0; display: inline-flex; align-items: center; border-radius: 0.375rem; cursor: pointer;">
        Submit
      </button>
    </form>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Navigation.CLive do
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
    <h1>This is page D</h1>

    <div
      :if={@live_action == :index}
      id="my-scroll-container"
      style={"#{if @container, do: "height: 85vh; overflow-y: scroll; "}width: 100%; border: 1px solid #e2e8f0; border-radius: 0.375rem;"}
    >
      <ul id="items" style="padding: 1rem; list-style: none;" phx-update="stream">
        <%= for {id, item} <- @streams.items do %>
          <li id={id} style="padding: 0.5rem; border-bottom: 1px solid #e2e8f0;">
            <.link
              patch={"/navigation/c/#{item.id}"}
              style="display: inline-flex; align-items: center; gap: 0.5rem;"
            >
              Item <%= item.name %>
            </.link>
          </li>
        <% end %>
      </ul>
    </div>

    <div :if={@live_action == :show}>
      <p>Item <%= @id %></p>
    </div>
    """
  end
end
