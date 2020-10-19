defmodule Phoenix.LiveViewTest.UploadLive do
  use Phoenix.LiveView

  def render(%{uploads: _} = assigns) do
    ~L"""
    <%= for preflight <- @preflights do %>
      preflight:<%= inspect(preflight) %>
    <% end %>
    <form phx-change="validate" phx-submit="save">
      <%= for entry <- @uploads.avatar.entries do %>
        <%= entry.client_name %>:<%= entry.progress %>%
        channel:<%= inspect(Phoenix.LiveView.UploadConfig.entry_pid(@uploads.avatar, entry)) %>
        <%= for msg <- upload_errors(@uploads.avatar, entry) do %>
          error:<%= inspect(msg) %>
        <% end %>
      <% end %>
      <%= live_file_input @uploads.avatar %>
      <button type="submit">save</button>
    </form>
    """
  end

  def render(assigns) do
    ~L"""
    loading...
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :preflights, [])}
  end

  def handle_call({:setup, setup_func}, _from, socket) do
    {:reply, :ok, setup_func.(socket)}
  end

  def handle_call({:run, func}, _from, socket), do: func.(socket)

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  ## test helpers

  def inspect_html_safe(term) do
    term
    |> inspect()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  def exits_with(lv, upload, kind, func) do
    Process.unlink(proxy_pid(lv))
    Process.unlink(upload.pid)
    try do
      func.()
      raise "expected to exit with #{inspect(kind)}"
    catch
      :exit, {{%mod{message: msg}, _}, _} when mod == kind -> msg
    end
  end

  def run(lv, func) do
    GenServer.call(lv.pid, {:run, func})
  end

  def proxy_pid(%{proxy: {_ref, _topic, pid}}), do: pid
end
