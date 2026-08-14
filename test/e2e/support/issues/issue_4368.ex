defmodule Phoenix.LiveViewTest.E2E.Issue4368Live do
  use Phoenix.LiveView

  defmodule Writer do
    @behaviour Phoenix.LiveView.UploadWriter

    @impl true
    def init(name), do: {:ok, name}

    @impl true
    def meta(name), do: %{name: name}

    @impl true
    def write_chunk("error", name), do: {:error, :invalid_pdf, name}
    def write_chunk(_chunk, name), do: {:ok, name}

    @impl true
    def close(name, _reason), do: {:ok, name}
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(consumed: [], submitted?: false)
     |> allow_upload(:documents,
       accept: :any,
       auto_upload: true,
       chunk_size: 5,
       max_entries: 2,
       progress: &__MODULE__.handle_progress/3,
       writer: &__MODULE__.writer/3
     )}
  end

  def writer(_name, entry, _socket), do: {Writer, entry.client_name}

  def handle_progress(:documents, %{done?: true} = entry, socket) do
    name = consume_uploaded_entry(socket, entry, fn _meta -> {:ok, entry.client_name} end)
    {:noreply, update(socket, :consumed, &[name | &1])}
  end

  def handle_progress(:documents, _entry, socket), do: {:noreply, socket}

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :documents, ref)}
  end

  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, submitted?: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="issue-4368">
      <form id="upload-form" phx-change="validate" phx-submit="submit">
        <.live_file_input upload={@uploads.documents} />
        <button type="submit">Submit</button>
      </form>

      <p id="submitted">submitted: {@submitted?}</p>
      <p id="consumed">consumed: {Enum.join(@consumed, ",")}</p>

      <article
        :for={entry <- @uploads.documents.entries}
        class="upload-entry"
        data-name={entry.client_name}
      >
        <span>{entry.client_name}: {entry.progress}%</span>
        <button type="button" phx-click="cancel" phx-value-ref={entry.ref}>Cancel</button>
        <p :for={error <- upload_errors(@uploads.documents, entry)} class="upload-error">
          {inspect(error)}
        </p>
      </article>
    </div>
    """
  end
end
