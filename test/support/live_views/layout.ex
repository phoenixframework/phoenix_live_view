defmodule Phoenix.LiveViewTest.Support.ParentLayoutLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    {live_render(@socket, Phoenix.LiveViewTest.Support.LayoutLive, session: @session, id: "layout")}
    """
  end

  def mount(_params, session, socket) do
    {:ok, assign(socket, session: session)}
  end
end

defmodule Phoenix.LiveViewTest.Support.LayoutLive do
  use Phoenix.LiveView, layout: {Phoenix.LiveViewTest.Support.LayoutView, :live}

  def render(assigns), do: ~H|The value is: {@val}|

  def mount(_params, session, socket) do
    socket
    |> assign(val: 123)
    |> maybe_put_layout(session)
  end

  def handle_event("double", _, socket) do
    {:noreply, update(socket, :val, &(&1 * 2))}
  end

  defp maybe_put_layout(socket, %{"live_layout" => value}) do
    {:ok, socket, layout: value}
  end

  defp maybe_put_layout(socket, _session), do: {:ok, socket}
end
