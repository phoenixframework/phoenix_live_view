defmodule Phoenix.LiveViewTest.E2E.Issue4094Live do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    if params["foo"] == "bar" do
      {:noreply, redirect(socket, to: "/navigation/a")}
    else
      {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <.link patch="/issues/4094?foo=bar">Patch</.link>
    """
  end
end
