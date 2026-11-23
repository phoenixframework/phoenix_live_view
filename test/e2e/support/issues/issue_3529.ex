defmodule Phoenix.LiveViewTest.E2E.Issue3529Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/3529

  use Phoenix.LiveView

  def mount(params, _session, socket) do
    {:ok, assign(socket, mounted: DateTime.utc_now(), mounted_param: params["param"])}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, next: :rand.uniform(), current_param: params["param"])}
  end

  def render(assigns) do
    ~H"""
    <h1>Mounted at {@mounted}</h1>
    <p id="mounted-param">{@mounted_param}</p>
    <p id="current-param">{@current_param}</p>
    <.link navigate={"/issues/3529?param=#{@next}"}>Navigate</.link>
    <.link patch={"/issues/3529?param=#{@next}"}>Patch</.link>
    """
  end
end
