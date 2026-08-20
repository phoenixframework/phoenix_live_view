defmodule Phoenix.LiveViewTest.E2E.UploadLive do
  use Phoenix.LiveView

  # for end-to-end testing https://phoenix-live-view.hexdocs.pm/uploads.html

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:uploaded_files, [])
     |> assign(:auto_upload, false)
     |> allow_upload(:avatar, accept: ~w(.txt .md), max_entries: 2)}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"auto_upload" => _}, _uri, socket) do
    socket
    |> allow_upload(:avatar, accept: ~w(.txt .md), max_entries: 2, auto_upload: true)
    |> then(&{:noreply, &1})
  end

  def handle_params(%{"external_upload" => _}, _uri, socket) do
    socket
    |> allow_upload(:avatar,
      accept: ~w(.txt .md),
      max_entries: 2,
      auto_upload: true,
      external: fn _entry, socket ->
        {:ok, %{uploader: "TestExternal"}, socket}
      end
    )
    |> then(&{:noreply, &1})
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
        dir = Path.join([System.tmp_dir!(), "lvupload"])
        _ = File.mkdir_p(dir)
        dest = Path.join([dir, Path.basename(path)])
        File.cp!(path, dest)
        {:ok, "/tmp/lvupload/#{Path.basename(dest)}"}
      end)

    {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_files))}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <style>
      #drop-target {
        box-sizing: border-box;
        min-height: 260px;
        margin: 1rem 0;
        padding: 2rem;
        border: 4px dashed #475569;
        background: #e2e8f0;
        transition: background 150ms ease, border-color 150ms ease;
      }

      #drop-target.phx-drop-target-active {
        border-color: #15803d;
        background: #bbf7d0;
      }

      #drop-target-inner {
        min-height: 140px;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        gap: 0.5rem;
        border: 2px solid #94a3b8;
        background: white;
      }

      #drop-target.phx-drop-target-active #drop-target-inner {
        border-color: #16a34a;
        background: #f0fdf4;
      }
    </style>

    <.link navigate="/upload?replaced=1">Replace view</.link>
    <form id="upload-form" phx-submit="save" phx-change="validate">
      <.live_file_input upload={@uploads.avatar} />
      <button type="submit">Upload</button>

      <section id="drop-target" phx-drop-target={@uploads.avatar.ref}>
        <div id="drop-target-inner">
          <strong>Inner drop target child</strong>
          <span>Drag a file across the outer padding and this inner element.</span>
        </div>

        <article :for={entry <- @uploads.avatar.entries} class="upload-entry">
          <figure>
            <.live_img_preview entry={entry} style="width: 500px" />
            <figcaption>{entry.client_name}</figcaption>
          </figure>
          <progress value={entry.progress} max="100">{entry.progress}%</progress>
          <button
            type="button"
            phx-click="cancel-upload"
            phx-value-ref={entry.ref}
            aria-label="cancel"
          >
            &times;
          </button>
          <p :for={err <- upload_errors(@uploads.avatar, entry)} class="alert alert-danger">
            {error_to_string(err)}
          </p>
        </article>
        <p :for={err <- upload_errors(@uploads.avatar)} class="alert alert-danger">
          {error_to_string(err)}
        </p>
      </section>

      <ul>
        <li :for={file <- @uploaded_files}><a href={file}>{Path.basename(file)}</a></li>
      </ul>
    </form>
    """
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end
