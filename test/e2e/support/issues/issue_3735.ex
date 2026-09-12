defmodule Phoenix.LiveViewTest.E2E.Issue3735Live do
  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:uploaded_files, [])
     |> allow_upload(:documents,
       accept: ~w(.jpg .jpeg),
       auto_upload: :if_valid,
       max_entries: 2,
       progress: &__MODULE__.handle_progress/3
     )}
  end

  def handle_progress(:documents, %{done?: true} = entry, socket) do
    name = consume_uploaded_entry(socket, entry, fn _meta -> {:ok, entry.client_name} end)
    {:noreply, update(socket, :uploaded_files, &(&1 ++ [name]))}
  end

  def handle_progress(:documents, _entry, socket), do: {:noreply, socket}

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :documents, ref)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form id="upload-form" phx-change="validate">
      <.live_file_input upload={@uploads.documents} />

      <article
        :for={entry <- @uploads.documents.entries}
        class="upload-entry"
        data-name={entry.client_name}
        data-progress={entry.progress}
      >
        <span>{entry.client_name}: {entry.progress}%</span>
        <button type="button" phx-click="cancel" phx-value-ref={entry.ref}>cancel</button>
        <p :for={error <- upload_errors(@uploads.documents, entry)} class="entry-error">
          {inspect(error)}
        </p>
      </article>

      <p :for={error <- upload_errors(@uploads.documents)} class="upload-error">
        {inspect(error)}
      </p>
    </form>

    <ul id="uploaded-files">
      <li :for={name <- @uploaded_files}>{name}</li>
    </ul>
    """
  end
end
