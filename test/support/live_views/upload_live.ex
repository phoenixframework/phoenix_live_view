defmodule Phoenix.LiveViewTest.UploadLive do
  use Phoenix.LiveView

  def render(%{uploads: _} = assigns) do
    ~L"""
    <form phx-change="validate" phx-submit="save">
      <%= for entry <- @uploads.avatar.entries do %>
        <%= entry.progress %>%
        channel:<%= inspect(Phoenix.LiveView.UploadConfig.entry_pid(@uploads.avatar, entry)) %>
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
    {:ok, socket}
  end

  def handle_call({:run, setup_func}, _from, socket) do
    {:reply, :ok, setup_func.(socket)}
  end
end
