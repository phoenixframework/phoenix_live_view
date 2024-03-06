defmodule Phoenix.LiveViewTest.WarnOnExpensiveAssignsLive do
  use Phoenix.LiveView

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :bar, "bar")}
  end

  defp do_something_with(x), do: x

  @impl Phoenix.LiveView
  def handle_event("expensive_assigns", _params, socket) do
    socket
    |> assign(:my_fun, fn -> do_something_with(socket.assigns.bar) end)
    |> assign(:nested, %{
      fun: fn x ->
        do_something_with(x)
        do_something_with(socket.assigns.bar)
      end
    })
    |> assign(:nested_socket, socket)
    |> then(&{:noreply, &1})
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h1>Hello!</h1>
    """
  end
end
