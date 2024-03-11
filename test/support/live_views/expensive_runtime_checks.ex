defmodule Phoenix.LiveViewTest.ExpensiveRuntimeChecksLive do
  use Phoenix.LiveView

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :bar, "bar")}
  end

  @impl Phoenix.LiveView
  def handle_event("expensive_assign_async_socket", _params, socket) do
    socket
    |> assign_async(:test, bad_assign_async_function_socket(socket))
    |> then(&{:noreply, &1})
  end

  def handle_event("expensive_assign_async_assigns", _params, socket) do
    socket
    |> assign_async(:test, bad_assign_async_function_assigns(socket))
    |> then(&{:noreply, &1})
  end

  def handle_event("good_assign_async", _params, socket) do
    socket
    |> assign_async(:test, good_assign_async_function(socket))
    |> then(&{:noreply, &1})
  end

  def handle_event("expensive_start_async_socket", _params, socket) do
    socket
    |> start_async(:test, bad_start_async_function_socket(socket))
    |> then(&{:noreply, &1})
  end

  def handle_event("expensive_start_async_assigns", _params, socket) do
    socket
    |> start_async(:test, bad_start_async_function_assigns(socket))
    |> then(&{:noreply, &1})
  end

  def handle_event("good_start_async", _params, socket) do
    socket
    |> start_async(:test, good_start_async_function(socket))
    |> then(&{:noreply, &1})
  end

  defp bad_assign_async_function_socket(socket) do
    fn ->
      {:ok, %{test: do_something_with(socket.assigns.bar)}}
    end
  end

  defp bad_assign_async_function_assigns(socket) do
    assigns = socket.assigns

    fn ->
      {:ok, %{test: do_something_with(assigns.bar)}}
    end
  end

  defp good_assign_async_function(socket) do
    bar = socket.assigns.bar

    fn ->
      {:ok, %{test: do_something_with(bar)}}
    end
  end

  defp bad_start_async_function_socket(socket) do
    fn -> do_something_with(socket.assigns.bar) end
  end

  defp bad_start_async_function_assigns(socket) do
    assigns = socket.assigns

    fn -> do_something_with(assigns.bar) end
  end

  defp good_start_async_function(socket) do
    bar = socket.assigns.bar

    fn -> do_something_with(bar) end
  end

  defp do_something_with(x), do: x

  @impl Phoenix.LiveView
  def handle_async(:test, {:ok, _val}, socket), do: {:noreply, socket}

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h1>Hello!</h1>
    """
  end
end
