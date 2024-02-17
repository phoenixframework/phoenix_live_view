defmodule Phoenix.LiveViewTest.E2E.Issue3107Live do
  use Phoenix.LiveView

  # https://github.com/phoenixframework/phoenix_live_view/issues/3107

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
      socket
      |> assign(:form, Phoenix.Component.to_form(%{}))
      |> assign(:disabled, true)
    }
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _, socket) do
    {:noreply, assign(socket, :disabled, false)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.form for={@form} phx-change="validate" style="display: flex;">
      <select>
        <option value="ONE">ONE</option>
        <option value="TWO">TWO</option>
      </select>

      <button disabled={@disabled}>OK</button>
    </.form>
    """
  end
end
