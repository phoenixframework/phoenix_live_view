defmodule Phoenix.LiveViewTest.E2E.Issue2965Live do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  defmodule NoOpWriter do
    @behaviour Phoenix.LiveView.UploadWriter

    @impl true
    def init(_opts) do
      {:ok, nil}
    end

    @impl true
    def meta(state), do: state

    @impl true
    def write_chunk(_data, state) do
      Process.sleep((:rand.uniform() * 200) |> ceil())
      {:ok, state}
    end

    def close(_state, :cancel) do
      {:ok, :aborted}
    end

    @impl true
    def close(_state, :done) do
      {:ok, %{}}
    end
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> allow_upload(:files,
        accept: :any,
        max_entries: 1500,
        # minimum 5 mb for multipart
        chunk_size: 5 * 1_024 * 1_024,
        max_file_size: 10_000_000_000,
        auto_upload: true,
        writer: &noop_writer/3,
        progress: &handle_progress/3
      )
      |> assign(:form, to_form(%{}))

    {:ok, socket}
  end

  def render("live.html", assigns) do
    ~H"""
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <script src="/assets/phoenix/phoenix.min.js">
    </script>
    <script src="/assets/phoenix_live_view/phoenix_live_view.js">
    </script>
    <script>
      const QueuedUploaderHook = {
        async mounted() {
          const maxConcurrency = this.el.dataset.maxConcurrency || 3;
          let filesRemaining = [];

          this.el.addEventListener("input", async (event) => {
            event.preventDefault()

            if (event.target instanceof HTMLInputElement) {
              const files_html = event.target.files;
              if (files_html) {

                const rawFiles = Array.from(files_html);
                const fileNames = rawFiles.map((f) => {
                  return f.name;
                });

                this.pushEvent("upload_scrub_list", { file_names: fileNames }, ({ deduped_filenames }, ref) => {
                  const files = rawFiles.filter((f) => {
                    return deduped_filenames.includes(f.name);
                  });
                  filesRemaining = files;
                  const firstFiles = files.slice(0, maxConcurrency);
                  this.upload("files", firstFiles);

                  filesRemaining.splice(0, maxConcurrency);
                });
              }
            }
          });

          this.handleEvent("upload_send_next_file", () => {
            if (filesRemaining.length > 0) {
              const nextFile = filesRemaining.shift();
              if (nextFile != undefined) {
                this.upload("files", [nextFile]);
              }
            } else {
              console.log("Done uploading, noop!");
            }
          });
        }
      };
      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
      let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket, {
        params: {_csrf_token: csrfToken},
        hooks: {QueuedUploaderHook}
      })
      liveSocket.connect()
    </script>

    <%= @inner_content %>
    """
  end

  def render(assigns) do
    ~H"""
    <main>
      <h1>Uploader reproduction</h1>
      <.form for={@form} phx-submit="save" phx-change="validate">
        <section>
          <.live_file_input upload={@uploads.files} style="display: none;" />
          <input
            id="fileinput"
            type="file"
            multiple
            phx-hook="QueuedUploaderHook"
            disabled={file_picker_disabled?(@uploads)}
          />
          <h2 :if={length(@uploads.files.entries) > 0}>Currently uploading files</h2>
          <div>
            <table>
              <!-- head -->
              <thead>
                <tr>
                  <th>File Name</th>
                  <th>Progress</th>
                  <th>Cancel</th>
                  <th>Errors</th>
                </tr>
              </thead>
              <tbody>
                <%= for entry <- uploads_in_progress(@uploads) do %>
                  <tr>
                    <td><%= entry.client_name %></td>
                    <td>
                      <progress value={entry.progress} max="100">
                        <%= entry.progress %>%
                      </progress>
                    </td>

                    <td>
                      <button
                        type="button"
                        phx-click="cancel-upload"
                        phx-value-ref={entry.ref}
                        aria-label="cancel"
                      >
                        <span>&times;</span>
                      </button>
                    </td>
                    <td>
                      <%= for err <- upload_errors(@uploads.files, entry) do %>
                        <p style="color: red;"><%= error_to_string(err) %></p>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
          <%= for err <- upload_errors(@uploads.files) do %>
            <p style="text-red"><%= error_to_string(err) %></p>
          <% end %>
        </section>
      </.form>
    </main>
    """
  end

  def handle_progress(:files, entry, socket) do
    if entry.done? do
      {:noreply, push_event(socket, "upload_send_next_file", %{})}
    else
      {:noreply, socket}
    end
  end

  # This dedupes against s3, just doing a no-op here to preserve the original uploader js code
  def handle_event(
        "upload_scrub_list",
        %{"file_names" => file_names},
        socket
      ) do
    {:reply, %{deduped_filenames: file_names}, socket}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :files, ref)}
  end

  def handle_event("save", _params, socket) do
    {:noreply, socket}
  end

  def error_to_string(:too_large), do: "Too large"
  def error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  def error_to_string(:s3_error), do: "Error on writing to cloudflare"

  def error_to_string(_unknown) do
    "unknown error"
  end

  ## Helpers

  defp file_picker_disabled?(uploads) do
    Enum.any?(uploads.files.entries, fn e -> !e.done? end)
  end

  defp noop_writer(_name, %Phoenix.LiveView.UploadEntry{} = entry, _socket) do
    {
      __MODULE__.NoOpWriter,
      provider: :r2, name: entry.client_name
    }
  end

  defp uploads_in_progress(uploads) do
    uploads.files.entries
  end
end
