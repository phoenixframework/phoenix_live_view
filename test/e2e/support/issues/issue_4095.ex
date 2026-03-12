defmodule Phoenix.LiveViewTest.E2E.Issue4095Live do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  def render(assigns) do
    ~H"""
    <.form :let={f} for={@form} phx-change="validate">
      <input type="text" name={f[:show?].name} id={f[:show?].id} value={f[:show?].value} />

      <.portal id="portal" target="#portal_target">
        <div>
          <.button :if={!!f[:show?].value}>Show?</.button>
        </div>
      </.portal>
    </.form>

    <div id="portal_target"></div>
    """
  end

  def mount(_, _, socket) do
    form = %{"show?" => true} |> to_form

    {:ok, assign(socket, form: form)}
  end

  def handle_event("validate", params, socket) do
    form = params |> to_form

    {:noreply, assign(socket, form: form)}
  end

  attr :rest, :global

  defp button(assigns) do
    ~H"""
    <button {@rest}>{render_slot(@inner_block)}</button>
    """
  end
end
