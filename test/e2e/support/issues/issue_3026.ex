defmodule Phoenix.LiveViewTest.E2E.Issue3026Live do
  use Phoenix.LiveView

  # https://github.com/phoenixframework/phoenix_live_view/issues/3026

  defmodule Form do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <div>
        Example form

        <.form for={to_form(%{})} phx-change="validate" phx-submit="submit">
          <input label="Name" name="name" type="text" value={@name} />
          <input label="Email" name="email" type="text" value={@email} />
          <button type="submit">Submit</button>
        </.form>
      </div>
      """
    end
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      send(self(), :load)
    end

    status = if connected?(socket), do: :loading, else: :connecting

    {:ok, assign(socket, :status, status)}
  end

  @impl Phoenix.LiveView
  def handle_info(:load, socket) do
    Process.sleep(200)

    {:noreply, assign(socket, %{status: :loaded, name: "John", email: ""})}
  end

  @impl Phoenix.LiveView
  def handle_event("change_status", %{"status" => status}, socket) do
    {:noreply, assign(socket, :status, String.to_existing_atom(status))}
  end

  def handle_event("validate", params, socket) do
    {:noreply, assign(socket, %{name: params["name"], email: params["email"]})}
  end

  def handle_event("submit", _params, socket) do
    send(self(), :load)
    {:noreply, assign(socket, %{status: :loading})}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.form for={to_form(%{})} phx-change="change_status">
      <select name="status" type="select">
        <%= Phoenix.HTML.Form.options_for_select(options(), @status) %>
      </select>
    </.form>

    <%= case @status do %>
      <% :connecting -> %>
        <.status status={@status} />
      <% :loading -> %>
        <.status status={@status} />
      <% :connected -> %>
        <.status status={@status} />
      <% :loaded -> %>
        <.live_component module={__MODULE__.Form} id="my-form" name={@name} email={@email} />
    <% end %>
    """
  end

  defp status(assigns) do
    ~H"""
    <div class="p-8 bg-gray-200 mb-4">
      <%= @status %>
    </div>
    """
  end

  defp options do
    ~w(connecting loading connected loaded)
    |> Enum.map(fn status -> {String.capitalize(status), status} end)
  end
end
