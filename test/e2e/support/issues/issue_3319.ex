defmodule Phoenix.LiveViewTest.E2E.Issue3319Live do
  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:submitted, [])
     |> allow_upload(:documents, accept: :any, max_entries: 2)}
  end

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("submit", _params, socket) do
    submitted =
      consume_uploaded_entries(socket, :documents, fn _meta, entry ->
        {:ok, entry.client_name}
      end)

    {:noreply, assign(socket, :submitted, submitted)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form id="upload-form" phx-change="validate" phx-submit="submit">
      <.live_file_input upload={@uploads.documents} required />
      <button type="submit">Submit</button>

      <p :for={entry <- @uploads.documents.entries} class="upload-entry">
        {entry.client_name}
      </p>
    </form>

    <p id="submitted">{Enum.join(@submitted, ",")}</p>
    """
  end
end
