defmodule Phoenix.LiveViewTest.Support.StartAsyncLive do
  use Phoenix.LiveView

  on_mount({__MODULE__, :defaults})

  def on_mount(:defaults, _params, _session, socket) do
    {:cont, assign(socket, lc: false)}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      :if={@lc}
      module={Phoenix.LiveViewTest.Support.StartAsyncLive.LC}
      test={@lc}
      id="lc"
    /> result: {inspect(@result)}
    <%= if flash = @flash["info"] do %>
      flash: {flash}
    <% end %>
    """
  end

  def mount(%{"test" => "lc_" <> lc_test}, _session, socket) do
    {:ok, assign(socket, lc: lc_test, result: :loading)}
  end

  def mount(%{"test" => "ok"}, _session, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn -> :good end)}
  end

  def mount(%{"test" => "raise"}, _session, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn -> raise("boom") end)}
  end

  def mount(%{"test" => "exit"}, _session, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn -> exit(:boom) end)}
  end

  def mount(%{"test" => "lv_exit"}, _session, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn ->
       Process.register(self(), :start_async_exit)
       send(:start_async_test_process, :async_ready)
       Process.sleep(:infinity)
     end)}
  end

  def mount(%{"test" => "cancel"}, _session, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn ->
       Process.register(self(), :start_async_cancel)
       send(:start_async_test_process, :async_ready)
       Process.sleep(:infinity)
     end)}
  end

  def mount(%{"test" => "trap_exit"}, _session, socket) do
    Process.flag(:trap_exit, true)

    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn ->
       spawn_link(fn -> exit(:boom) end)
       Process.sleep(100)
       :good
     end)}
  end

  def mount(%{"test" => "complex_key"}, _session, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async({:result_task, :foo}, fn -> :complex_key end)}
  end

  def mount(%{"test" => "navigate"}, _session, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:navigate, fn -> nil end)}
  end

  def mount(%{"test" => "patch"}, _session, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:patch, fn -> nil end)}
  end

  def mount(%{"test" => "redirect"}, _session, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:redirect, fn -> nil end)}
  end

  def mount(%{"test" => "put_flash"}, _session, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:flash, fn -> "hello" end)}
  end

  def mount(%{"test" => "socket_warning"}, _session, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, function_that_returns_the_anonymous_function(socket))}
  end

  defp function_that_returns_the_anonymous_function(socket) do
    fn ->
      Function.identity(socket)
      :ok
    end
  end

  def handle_params(_unsigned_params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_async(:result_task, {:ok, result}, socket) do
    {:noreply, assign(socket, result: result)}
  end

  def handle_async(:result_task, {:exit, {error, [_ | _] = _stack}}, socket) do
    {:noreply, assign(socket, result: {:exit, error})}
  end

  def handle_async(:result_task, {:exit, reason}, socket) do
    {:noreply, assign(socket, result: {:exit, reason})}
  end

  def handle_async({:result_task, _}, {:ok, result}, socket) do
    {:noreply, assign(socket, result: result)}
  end

  def handle_async(:navigate, {:ok, _result}, socket) do
    {:noreply, push_navigate(socket, to: "/start_async?test=ok")}
  end

  def handle_async(:patch, {:ok, _result}, socket) do
    {:noreply, push_patch(socket, to: "/start_async?test=ok")}
  end

  def handle_async(:redirect, {:ok, _result}, socket) do
    {:noreply, redirect(socket, to: "/not_found")}
  end

  def handle_async(:flash, {:ok, flash}, socket) do
    {:noreply, put_flash(socket, :info, flash)}
  end

  def handle_info(:boom, _socket), do: exit(:boom)

  def handle_info(:cancel, socket) do
    {:noreply, cancel_async(socket, :result_task)}
  end

  def handle_info(:renew_canceled, socket) do
    {:noreply,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn ->
       Process.sleep(100)
       :renewed
     end)}
  end

  def handle_info({:EXIT, pid, reason}, socket) do
    send(:start_async_trap_exit_test, {:exit, pid, reason})
    {:noreply, socket}
  end
end

defmodule Phoenix.LiveViewTest.Support.StartAsyncLive.LC do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div>
      lc: {inspect(@result)}
    </div>
    """
  end

  def update(%{test: "ok"}, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn -> :good end)}
  end

  def update(%{test: "raise"}, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn -> raise("boom") end)}
  end

  def update(%{test: "exit"}, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn -> exit(:boom) end)}
  end

  def update(%{test: "lv_exit"}, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn ->
       Process.register(self(), :start_async_exit)
       send(:start_async_test_process, :async_ready)
       Process.sleep(:infinity)
     end)}
  end

  def update(%{test: "cancel"}, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn ->
       Process.register(self(), :start_async_cancel)
       send(:start_async_test_process, :async_ready)
       Process.sleep(:infinity)
     end)}
  end

  def update(%{test: "complex_key"}, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async({:result_task, :foo}, fn -> :complex_key end)}
  end

  def update(%{test: "patch"}, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:patch, fn -> nil end)}
  end

  def update(%{test: "navigate"}, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:navigate, fn -> nil end)}
  end

  def update(%{test: "redirect"}, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:redirect, fn -> nil end)}
  end

  def update(%{test: "navigate_flash"}, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:navigate_flash, fn -> "hello" end)}
  end

  def update(%{action: :cancel}, socket) do
    {:ok, cancel_async(socket, :result_task)}
  end

  def update(%{action: :renew_canceled}, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn ->
       Process.sleep(100)
       :renewed
     end)}
  end

  def handle_async(:result_task, {:ok, result}, socket) do
    {:noreply, assign(socket, result: result)}
  end

  def handle_async(:result_task, {:exit, {error, [_ | _] = _stack}}, socket) do
    {:noreply, assign(socket, result: {:exit, error})}
  end

  def handle_async(:result_task, {:exit, reason}, socket) do
    {:noreply, assign(socket, result: {:exit, reason})}
  end

  def handle_async({:result_task, _}, {:ok, result}, socket) do
    {:noreply, assign(socket, result: result)}
  end

  def handle_async(:navigate, {:ok, _result}, socket) do
    {:noreply, push_navigate(socket, to: "/start_async?test=ok")}
  end

  def handle_async(:patch, {:ok, _result}, socket) do
    {:noreply, push_patch(socket, to: "/start_async?test=ok")}
  end

  def handle_async(:redirect, {:ok, _result}, socket) do
    {:noreply, redirect(socket, to: "/not_found")}
  end

  def handle_async(:navigate_flash, {:ok, flash}, socket) do
    {:noreply, socket |> put_flash(:info, flash) |> push_navigate(to: "/start_async?test=ok")}
  end
end
