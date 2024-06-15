defmodule Phoenix.LiveViewTest.E2E.Issue3194Live do
  use Phoenix.LiveView

  # https://github.com/phoenixframework/phoenix_live_view/issues/3194

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :form, to_form(%{}, as: :foo))}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.form
      for={@form}
      phx-change="validate"
      phx-submit="submit"
    >
      <input
        id={@form[:store_number].id}
        name={@form[:store_number].name}
        value={@form[:store_number].value}
        type="text"
        phx-debounce="blur"
      />
    </.form>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("submit", _params, socket) do
    {:noreply, push_navigate(socket, to: "/issues/3194/other")}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  defmodule OtherLive do
    use Phoenix.LiveView

    @impl Phoenix.LiveView
    def render(assigns) do
      ~H"""
      <h2>Another LiveView</h2>
      """
    end
  end
end
