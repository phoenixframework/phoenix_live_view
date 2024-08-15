defmodule Phoenix.LiveViewTest.E2E.Issue3083Live do
  use Phoenix.LiveView

  # https://github.com/phoenixframework/phoenix_live_view/issues/3083

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    if connected?(socket) and not (params["auto"] == "false") do
      :timer.send_interval(1000, self(), :tick)
    end

    {:ok, socket |> assign(options: [1, 2, 3, 4, 5], form: to_form(%{"ids" => []}))}
  end

  @impl Phoenix.LiveView
  def handle_info(:tick, socket) do
    selected = Enum.take_random([1, 2, 3, 4, 5], 2)
    params = %{"ids" => selected}

    {:noreply, socket |> assign(form: to_form(params))}
  end

  def handle_info({:select, values}, socket) do
    params = %{"ids" => values}

    {:noreply, socket |> assign(form: to_form(params))}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.form id="form" for={@form} phx-change="validate">
      <select id={@form[:ids].id} name={@form[:ids].name <> "[]"} multiple={true}>
        <%= Phoenix.HTML.Form.options_for_select(@options, @form[:ids].value) %>
      </select>
      <input type="text" placeholder="focus me!" />
    </.form>
    """
  end
end
