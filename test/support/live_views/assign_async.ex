defmodule Phoenix.LiveViewTest.Support.AssignAsyncLive do
  use Phoenix.LiveView

  on_mount({__MODULE__, :defaults})

  def on_mount(:defaults, _params, _session, socket) do
    {:cont, assign(socket, lc: false)}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      :if={@lc}
      module={Phoenix.LiveViewTest.Support.AssignAsyncLive.LC}
      test={@lc}
      id="lc"
    />

    <div :if={@data.loading}>data loading...</div>
    <div :if={@data.ok? && @data.result == nil}>no data found</div>
    <div :if={@data.ok? && @data.result}>data: {inspect(@data.result)}</div>
    <div :if={@data.failed}>{inspect(@data.failed)}</div>
    """
  end

  def mount(%{"test" => "lc_" <> lc_test}, _session, socket) do
    {:ok,
     socket
     |> assign(lc: lc_test)
     |> assign_async(:data, fn -> {:ok, %{data: :live_component}} end)}
  end

  def mount(%{"test" => "bad_return"}, _session, socket) do
    {:ok, assign_async(socket, :data, fn -> 123 end)}
  end

  def mount(%{"test" => "bad_ok"}, _session, socket) do
    {:ok, assign_async(socket, :data, fn -> {:ok, %{bad: 123}} end)}
  end

  def mount(%{"test" => "ok"}, _session, socket) do
    {:ok, assign_async(socket, :data, fn -> {:ok, %{data: 123}} end)}
  end

  def mount(%{"test" => "sup_ok"}, _session, socket) do
    {:ok,
     assign_async(socket, :data, fn -> {:ok, data: 123} end, supervisor: TestAsyncSupervisor)}
  end

  def mount(%{"test" => "raise"}, _session, socket) do
    {:ok, assign_async(socket, :data, fn -> raise("boom") end)}
  end

  def mount(%{"test" => "sup_raise"}, _session, socket) do
    {:ok, assign_async(socket, :data, fn -> raise("boom") end, supervisor: TestAsyncSupervisor)}
  end

  def mount(%{"test" => "exit"}, _session, socket) do
    {:ok, assign_async(socket, :data, fn -> exit(:boom) end)}
  end

  def mount(%{"test" => "sup_exit"}, _session, socket) do
    {:ok, assign_async(socket, :data, fn -> exit(:boom) end, supervisor: TestAsyncSupervisor)}
  end

  def mount(%{"test" => "lv_exit"}, _session, socket) do
    {:ok,
     assign_async(socket, :data, fn ->
       Process.register(self(), :lv_exit)
       send(:assign_async_test_process, :async_ready)
       Process.sleep(:infinity)
     end)}
  end

  def mount(%{"test" => "cancel"}, _session, socket) do
    {:ok,
     assign_async(socket, :data, fn ->
       Process.register(self(), :cancel)
       send(:assign_async_test_process, :async_ready)
       Process.sleep(:infinity)
     end)}
  end

  def mount(%{"test" => "trap_exit"}, _session, socket) do
    Process.flag(:trap_exit, true)

    {:ok,
     assign_async(socket, :data, fn ->
       spawn_link(fn -> exit(:boom) end)
       Process.sleep(100)
       {:ok, %{data: 0}}
     end)}
  end

  def mount(%{"test" => "socket_warning"}, _session, socket) do
    {:ok, assign_async(socket, :data, function_that_returns_the_anonymous_function(socket))}
  end

  defp function_that_returns_the_anonymous_function(socket) do
    fn ->
      Function.identity(socket)
      {:ok, %{data: 0}}
    end
  end

  def handle_info(:boom, _socket), do: exit(:boom)

  def handle_info(:cancel, socket) do
    {:noreply, cancel_async(socket, socket.assigns.data)}
  end

  def handle_info({:EXIT, pid, reason}, socket) do
    send(:trap_exit_test, {:exit, pid, reason})
    {:noreply, socket}
  end

  def handle_info(:renew_canceled, socket) do
    {:noreply,
     assign_async(socket, :data, fn ->
       Process.sleep(100)
       {:ok, %{data: 123}}
     end)}
  end
end

defmodule Phoenix.LiveViewTest.Support.AssignAsyncLive.LC do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div>
      <.async_result :let={data} assign={@lc_data}>
        <:loading>lc_data loading...</:loading>
        <:failed :let={{kind, reason}}>{kind}: {inspect(reason)}</:failed>
        lc_data: {inspect(data)}
      </.async_result>
      <.async_result :let={data} assign={@other_data}>
        <:loading>other_data loading...</:loading>
        other_data: {inspect(data)}
      </.async_result>
    </div>
    """
  end

  def update(%{test: "bad_return"}, socket) do
    {:ok, assign_async(socket, [:lc_data, :other_data], fn -> 123 end)}
  end

  def update(%{test: "bad_ok"}, socket) do
    {:ok, assign_async(socket, [:lc_data, :other_data], fn -> {:ok, %{bad: 123}} end)}
  end

  def update(%{test: "ok"}, socket) do
    {:ok,
     assign_async(socket, [:lc_data, :other_data], fn ->
       {:ok, %{other_data: 555, lc_data: 123}}
     end)}
  end

  def update(%{test: "raise"}, socket) do
    {:ok, assign_async(socket, [:lc_data, :other_data], fn -> raise("boom") end)}
  end

  def update(%{test: "exit"}, socket) do
    {:ok, assign_async(socket, [:lc_data, :other_data], fn -> exit(:boom) end)}
  end

  def update(%{test: "lv_exit"}, socket) do
    {:ok,
     assign_async(socket, [:lc_data, :other_data], fn ->
       Process.register(self(), :lc_exit)
       send(:assign_async_test_process, :async_ready)
       Process.sleep(:infinity)
     end)}
  end

  def update(%{test: "cancel"}, socket) do
    {:ok,
     assign_async(socket, [:lc_data, :other_data], fn ->
       Process.register(self(), :lc_cancel)
       send(:assign_async_test_process, :async_ready)
       Process.sleep(:infinity)
     end)}
  end

  def update(%{action: :boom}, _socket), do: exit(:boom)

  def update(%{action: :cancel}, socket) do
    {:ok, cancel_async(socket, socket.assigns.lc_data)}
  end

  def update(%{action: :assign_async_reset, reset: reset}, socket) do
    fun = fn ->
      Process.sleep(50)
      {:ok, %{other_data: 999, lc_data: 456}}
    end

    {:ok, assign_async(socket, [:lc_data, :other_data], fun, reset: reset)}
  end

  def update(%{action: :renew_canceled}, socket) do
    {:ok,
     assign_async(socket, :lc_data, fn ->
       Process.sleep(100)
       {:ok, %{lc_data: 123}}
     end)}
  end
end
