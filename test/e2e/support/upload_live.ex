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

  def handle_params(%{"mixed_upload" => _}, _uri, socket) do
    socket
    |> allow_upload(:avatar,
      accept: ~w(.txt .md),
      max_entries: 2,
      external: &mixed_preflight/2
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
      consume_uploaded_entries(socket, :avatar, fn
        %{uploader: "TestExternal", path: path}, entry ->
          {:ok, %{href: path, name: entry.client_name, uploader: "external"}}

        %{path: path}, entry ->
          dir = Path.join([System.tmp_dir!(), "lvupload"])
          _ = File.mkdir_p(dir)
          dest = Path.join([dir, Path.basename(path)])
          File.cp!(path, dest)

          {:ok,
           %{
             href: "/tmp/lvupload/#{Path.basename(dest)}",
             name: entry.client_name,
             uploader: "default"
           }}
      end)

    {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_files))}
  end

  defp mixed_preflight(%{client_type: "text/plain"}, socket) do
    {:ok, :default, socket}
  end

  defp mixed_preflight(%{client_type: "text/markdown"} = entry, socket) do
    key = "#{System.unique_integer([:positive, :monotonic])}-#{Path.basename(entry.client_name)}"

    {:ok,
     %{
       uploader: "TestExternal",
       url: "/upload/external",
       key: key,
       path: "/tmp/lvupload/#{key}"
     }, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <form id="upload-form" phx-submit="save" phx-change="validate">
      <.live_file_input upload={@uploads.avatar} />
      <button type="submit">Upload</button>

      <section phx-drop-target={@uploads.avatar.ref}>
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
        <li :for={file <- @uploaded_files} data-uploader={file.uploader}>
          <a href={file.href}>{file.name}</a>
        </li>
      </ul>
    </form>
    """
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end
