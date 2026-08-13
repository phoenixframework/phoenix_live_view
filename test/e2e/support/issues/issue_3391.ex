defmodule Phoenix.LiveViewTest.E2E.Issue3391Live do
  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(submitted?: false, uploaded?: false)
     |> allow_upload(:document,
       accept: ~w(.txt),
       auto_upload: true,
       max_entries: 1,
       progress: &__MODULE__.handle_progress/3
     )}
  end

  def handle_progress(:document, %{done?: true} = entry, socket) do
    :ok = consume_uploaded_entry(socket, entry, fn _meta -> {:ok, :ok} end)
    {:noreply, assign(socket, :uploaded?, true)}
  end

  def handle_progress(:document, _entry, socket), do: {:noreply, socket}

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :document, ref)}
  end

  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, :submitted?, true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form id="upload-form" phx-change="validate" phx-submit="submit">
      <.live_file_input upload={@uploads.document} />
      <button type="submit">Submit</button>

      <article :for={entry <- @uploads.document.entries} class="upload-entry">
        <span>{entry.client_name}: {entry.progress}%</span>
        <button type="button" phx-click="cancel" phx-value-ref={entry.ref}>Cancel</button>
        <p :for={error <- upload_errors(@uploads.document, entry)} class="upload-error">
          {inspect(error)}
        </p>
      </article>
    </form>

    <p id="uploaded">uploaded: {@uploaded?}</p>
    <p id="submitted">submitted: {@submitted?}</p>
    """
  end
end
