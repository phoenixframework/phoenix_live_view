defmodule Phoenix.LiveViewTest.E2E.Issue3368Live do
  use Phoenix.LiveView

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component module={__MODULE__.UploadComponent} id="uploader" />
    """
  end

  defmodule UploadComponent do
    use Phoenix.LiveComponent

    @impl true
    def mount(socket) do
      {:ok,
       socket
       |> allow_upload(:file, accept: ~w(.jpg .jpeg .png .gif), max_entries: 1)
       |> assign(:saved_files, [])}
    end

    @impl true
    def handle_event("validate", _params, socket), do: {:noreply, socket}

    def handle_event("save", _params, socket) do
      saved_files =
        consume_uploaded_entries(socket, :file, fn _meta, entry ->
          {:ok, entry.client_name}
        end)

      {:noreply, assign(socket, :saved_files, saved_files)}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <div>
        <form id="upload-form" phx-change="validate" phx-submit="save" phx-target={@myself}>
          <div id="dropzone" phx-drop-target={@uploads.file.ref}>Drop files here</div>
          <.live_file_input upload={@uploads.file} />
          <button type="submit">Upload</button>
        </form>

        <p :for={entry <- @uploads.file.entries} class="upload-entry">{entry.client_name}</p>
        <p :for={error <- upload_errors(@uploads.file)} class="upload-error">
          {inspect(error)}
        </p>
        <p id="saved-files">{Enum.join(@saved_files, ",")}</p>
      </div>
      """
    end
  end
end
