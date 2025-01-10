defmodule Phoenix.LiveViewTest.E2E.Issue3529Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/3529

  use Phoenix.LiveView

  alias Phoenix.LiveView.JS

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :mounted, DateTime.utc_now())}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :next, :rand.uniform())}
  end

  def render(assigns) do
    ~H"""
    <h1>Mounted at {@mounted}</h1>
    <.link navigate={"/issues/3529?param=#{@next}"}>Navigate</.link>
    <.link patch={"/issues/3529?param=#{@next}"}>Patch</.link>
    """
  end
end
