defmodule Phoenix.LiveViewTest.E2E.Issue4465Live do
  use Phoenix.LiveView

  # https://github.com/phoenixframework/phoenix_live_view/pull/4465
  #
  # Query params:
  #   * uploader=external|channel (default channel)
  #   * auto=true|false (default false)
  #
  # Files whose content is "error" fail in the writer and external entries
  # named "bad*" call entry.error() in the client uploader.

  defmodule Writer do
    @behaviour Phoenix.LiveView.UploadWriter

    @impl true
    def init(name), do: {:ok, name}

    @impl true
    def meta(name), do: %{name: name}

    @impl true
    def write_chunk("error", name), do: {:error, :boom, name}
    def write_chunk(_chunk, name), do: {:ok, name}

    @impl true
    def close(name, _reason), do: {:ok, name}
  end

  @impl true
  def mount(params, _session, socket) do
    assigns = %{}

    pre_script = ~H"""
    <script>
      window.uploaders = {
        Issue4465(entries) {
          entries.forEach((entry) => {
            setTimeout(() => {
              if (entry.file.name.startsWith("bad")) {
                entry.error("boom");
              } else {
                entry.progress(100);
              }
            }, 300);
          });
        },
      };
    </script>
    """

    opts = [
      accept: :any,
      max_entries: 2,
      chunk_size: 5,
      auto_upload: params["auto"] == "true"
    ]

    opts =
      case params["uploader"] do
        "external" ->
          Keyword.put(opts, :external, fn _entry, socket ->
            {:ok, %{uploader: "Issue4465"}, socket}
          end)

        _ ->
          Keyword.put(opts, :writer, fn _name, entry, _socket -> {Writer, entry.client_name} end)
      end

    {:ok,
     socket
     |> assign(submitted: nil, pre_script: pre_script)
     |> allow_upload(:files, opts)}
  end

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :files, ref)}
  end

  def handle_event("submit", _params, socket) do
    {completed, _in_progress} = uploaded_entries(socket, :files)
    {:noreply, assign(socket, submitted: Enum.map(completed, & &1.client_name))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form id="upload-form" phx-change="validate" phx-submit="submit">
      <.live_file_input upload={@uploads.files} />
      <button type="submit">Submit</button>
    </form>

    <p id="submitted">submitted: {inspect(@submitted)}</p>
    <p id="pid">{inspect(self())}</p>

    <article
      :for={entry <- @uploads.files.entries}
      class="upload-entry"
      data-name={entry.client_name}
    >
      <span>{entry.client_name}: {entry.progress}%</span>
      <button type="button" phx-click="cancel" phx-value-ref={entry.ref}>Cancel</button>
      <p :for={error <- upload_errors(@uploads.files, entry)} class="upload-error">
        {inspect(error)}
      </p>
    </article>
    """
  end
end
