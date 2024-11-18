defmodule Phoenix.LiveViewTest.E2E.Issue3448Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/3448

  use Phoenix.LiveView

  alias Phoenix.LiveView.JS

  def mount(_params, _session, socket) do
    form = to_form(%{"a" => []})

    {:ok, assign_new(socket, :form, fn -> form end)}
  end

  def render(assigns) do
    ~H"""
    <.form for={@form} id="my_form" phx-change="validate" class="flex flex-col gap-2">
      <.my_component>
        <:left_content :for={value <- @form[:a].value || []}>
          <div>{value}</div>
        </:left_content>
      </.my_component>

      <div class="flex gap-2">
        <input
          type="checkbox"
          name={@form[:a].name <> "[]"}
          value="settings"
          checked={"settings" in (@form[:a].value || [])}
          phx-click={JS.dispatch("input") |> JS.focus(to: "#search")}
        />

        <input
          type="checkbox"
          name={@form[:a].name <> "[]"}
          value="content"
          checked={"content" in (@form[:a].value || [])}
          phx-click={JS.dispatch("input") |> JS.focus(to: "#search")}
        />
      </div>
    </.form>
    """
  end

  def handle_event("validate", params, socket) do
    {:noreply, assign(socket, form: to_form(params))}
  end

  def handle_event("search", _params, socket) do
    {:noreply, socket}
  end

  slot :left_content

  defp my_component(assigns) do
    ~H"""
    <div>
      <div :for={left_content <- @left_content}>
        {render_slot(left_content)}
      </div>

      <input id="search" type="search" name="value" phx-change="search" />
    </div>
    """
  end
end
