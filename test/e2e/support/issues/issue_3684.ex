defmodule Phoenix.LiveViewTest.E2E.Issue3684Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/3684
  use Phoenix.LiveView

  defmodule BadgeForm do
    use Phoenix.LiveComponent

    def mount(socket) do
      socket =
        socket
        |> assign(:type, :huey)

      {:ok, socket}
    end

    def update(assigns, socket) do
      socket =
        socket
        |> assign(:form, assigns.form)

      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <div>
        <.form
          for={@form}
          id="foo"
          class="max-w-lg p-8 flex flex-col gap-4"
          phx-change="change"
          phx-submit="submit"
        >
          <.radios type={@type} form={@form} myself={@myself} />
        </.form>
      </div>
      """
    end

    defp radios(assigns) do
      ~H"""
      <fieldset>
        <legend>Radio example:</legend>
        <%= for type <- [:huey, :dewey] do %>
          <div phx-click="change-type" phx-value-type={type} phx-target={@myself}>
            <input type="radio" id={type} name="type" value={type} checked={@type == type} />
            <label for={type}>{type}</label>
          </div>
        <% end %>
      </fieldset>
      """
    end

    def handle_event("change-type", %{"type" => type}, socket) do
      type = String.to_existing_atom(type)
      socket = assign(socket, :type, type)
      {:noreply, socket}
    end
  end

  defp changeset(params) do
    data = %{}

    types = %{
      type: :string
    }

    {data, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> Ecto.Changeset.validate_required(:type)
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(changeset(%{}), as: :foo), payload: nil)}
  end

  def render(assigns) do
    ~H"""
    <.live_component id="badge_form" module={__MODULE__.BadgeForm} action={@live_action} form={@form} />
    """
  end

  def handle_event("change", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("submit", _params, socket) do
    {:noreply, socket}
  end
end
