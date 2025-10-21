for type <- [FormLive, FormLiveNested] do
  defmodule Module.concat(Phoenix.LiveViewTest.E2E, type) do
    use Phoenix.LiveView

    alias Phoenix.LiveView.JS

    @compile {:no_warn_undefined, Phoenix.LiveViewTest.E2E.Hooks}

    defmodule FormComponent do
      use Phoenix.LiveComponent

      @impl Phoenix.LiveComponent
      def mount(socket) do
        {:ok, assign(socket, :submitted, false)}
      end

      @impl Phoenix.LiveComponent
      def handle_event("validate", params, socket) do
        {:noreply, assign(socket, :params, Map.merge(socket.assigns.params, params))}
      end

      def handle_event("save", _params, socket) do
        {:noreply, assign(socket, :submitted, true)}
      end

      def handle_event("custom-recovery", _params, socket) do
        {:noreply,
         assign(
           socket,
           :params,
           Map.merge(socket.assigns.params, %{"b" => "custom value from server"})
         )}
      end

      def handle_event("patch-recovery", _params, socket) do
        {:noreply, push_patch(socket, to: "/form?patched=true")}
      end

      @impl Phoenix.LiveComponent
      def render(assigns) do
        ~H"""
        <div>
          <Phoenix.LiveViewTest.E2E.FormLive.my_form params={@params} phx-target={@myself} />

          <p :if={@submitted}>LC Form was submitted!</p>
        </div>
        """
      end
    end

    @impl Phoenix.LiveView
    def mount(params, session, socket) do
      # if we're nested we need to manually add the on_mount hook
      # as the live_session doesn't apply
      socket =
        if socket.parent_pid do
          {:cont, socket} =
            Phoenix.LiveViewTest.E2E.Hooks.on_mount(:default, params, session, socket)

          socket
        else
          socket
        end

      params =
        case params do
          :not_mounted_at_router -> session
          _ -> params
        end

      {:ok,
       socket
       |> assign(
         :params,
         Enum.into(params, %{
           "a" => "foo",
           "b" => "bar",
           "c" => "baz",
           "id" => "test-form",
           "phx-change" => "validate"
         })
       )
       |> update_params(params)
       |> assign(:submitted, false)}
    end

    if type === FormLive do
      def handle_params(_, _, socket), do: {:noreply, socket}
    end

    def update_params(socket, %{"no-id" => _}) do
      update(socket, :params, &Map.delete(&1, "id"))
    end

    def update_params(socket, %{"no-change-event" => _}) do
      update(socket, :params, &Map.delete(&1, "phx-change"))
    end

    def update_params(socket, %{"js-change" => _}) do
      update(socket, :params, &Map.put(&1, "phx-change", JS.push("validate")))
    end

    def update_params(socket, _), do: socket

    @impl Phoenix.LiveView
    def handle_event("validate", params, socket) do
      {:noreply, assign(socket, :params, Map.merge(socket.assigns.params, params))}
    end

    def handle_event("save", _params, socket) do
      {:noreply, assign(socket, :submitted, true)}
    end

    def handle_event("custom-recovery", _params, socket) do
      {:noreply,
       assign(
         socket,
         :params,
         Map.merge(socket.assigns.params, %{"b" => "custom value from server"})
       )}
    end

    def handle_event("patch-recovery", _params, socket) do
      {:noreply, push_patch(socket, to: "/form?patched=true")}
    end

    def handle_event("button-test", _params, socket) do
      {:noreply, socket}
    end

    @impl Phoenix.LiveView
    def render(assigns) do
      ~H"""
      <h1 :if={@params["portal"]}>Form</h1>

      <%= if @params["portal"] do %>
        <.portal id="form-portal" target="body">
          <.my_form :if={!@params["live-component"]} params={@params} />
          <.live_component
            :if={@params["live-component"]}
            id="form-component"
            module={__MODULE__.FormComponent}
            params={@params}
          />
        </.portal>
      <% else %>
        <.my_form :if={!@params["live-component"]} params={@params} />
        <.live_component
          :if={@params["live-component"]}
          id="form-component"
          module={__MODULE__.FormComponent}
          params={@params}
        />
      <% end %>

      <p :if={@submitted}>Form was submitted!</p>
      """
    end

    def my_form(assigns) do
      ~H"""
      <form
        id={@params["id"]}
        phx-submit="save"
        phx-change={@params["phx-change"]}
        phx-auto-recover={@params["phx-auto-recover"]}
        phx-no-usage-tracking={@params["phx-no-usage-tracking-form"]}
        phx-target={assigns[:"phx-target"]}
        class="myformclass"
      >
        <fieldset disabled={@params["disabled-fieldset"]}>
          <input type="text" name="a" readonly value={@params["a"]} />
          <input type="text" name="b" value={@params["b"]} />
        </fieldset>
        <input
          type="text"
          name="c"
          value={@params["c"]}
          phx-no-usage-tracking={@params["phx-no-usage-tracking-input"]}
        />
        <select name="d">
          {Phoenix.HTML.Form.options_for_select(["foo", "bar", "baz"], @params["d"])}
        </select>
        <input :if={@params["id"]} type="text" name="e" form={@params["id"]} value={@params["e"]} />
        <button type="submit" phx-disable-with="Submitting" phx-click={JS.dispatch("test")}>
          Submit with JS
        </button>
        <button id="submit" type="submit" phx-disable-with="Submitting">Submit</button>
        <button type="button" phx-click="button-test" phx-disable-with="Loading">
          Non-form Button
        </button>
      </form>

      <input :if={@params["id"]} type="text" name="f" form={@params["id"]} value={@params["f"]} />
      """
    end
  end
end

defmodule Phoenix.LiveViewTest.E2E.NestedFormLive do
  use Phoenix.LiveView

  def mount(params, _session, socket) do
    {:ok, assign(socket, :params, params)}
  end

  def render(assigns) do
    ~H"""
    {live_render(@socket, Phoenix.LiveViewTest.E2E.FormLiveNested,
      id: "nested",
      layout: nil,
      session: @params
    )}
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.FormStreamLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    {@count}
    <form id="test-form" phx-change="validate" phx-submit="save">
      <input name="myname" value={@count} />
      <input id="other" name="other" value={@count} />
      <div id="form-stream-hook" phx-hook="FormHook" phx-update="ignore"></div>
      <ul id="form-stream" phx-update="stream">
        <li :for={{id, item} <- @streams.items} id={id} phx-hook="FormStreamHook">
          *{inspect(item)}
        </li>
      </ul>
      <button id="submit" phx-disable-with="Saving...">Submit</button>
    </form>
    """
  end

  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(100, self(), :tick)
    end

    {:ok,
     socket
     |> assign(count: 0, stream_count: 3)
     |> stream(:items, [%{id: 1}, %{id: 2}, %{id: 3}])}
  end

  def handle_info(:tick, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count + 1)}
  end

  def handle_event("ping", _params, socket) do
    {:reply, %{}, socket}
  end

  def handle_event("validate", _params, socket) do
    {:noreply,
     socket
     |> inc()
     |> assign(stream_count: socket.assigns.stream_count + 1)
     |> stream_insert(:items, %{id: socket.assigns.stream_count + 1})}
  end

  def handle_event("save", _params, socket) do
    {:noreply,
     socket
     |> inc()
     |> assign(stream_count: socket.assigns.stream_count + 1)
     |> stream_insert(:items, %{id: socket.assigns.stream_count + 1})}
  end

  defp inc(socket) do
    assign(socket, count: socket.assigns.count + 1)
  end
end
