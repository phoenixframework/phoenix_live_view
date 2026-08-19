defmodule Phoenix.LiveViewTest.E2E.Issue4369Live do
  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.sleep(1_000)

    {:ok, allow_upload(socket, :file, accept: :any)}
  end

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <form id="upload-form" phx-change="validate">
      <label for={@uploads.file.ref}>Choose a file</label>
      <.live_file_input upload={@uploads.file} />
    </form>

    <article :for={entry <- @uploads.file.entries} class="upload-entry">
      {entry.client_name}
    </article>
    """
  end
end
