defmodule Phoenix.LiveViewTest.Support.StreamAsyncLive do
  use Phoenix.LiveView

  on_mount({__MODULE__, :defaults})

  def on_mount(:defaults, params, _session, socket) do
    socket = socket |> assign(:lc, false)

    if params["no_init"] do
      {:cont, socket}
    else
      {:cont, stream(socket, :my_stream, [%{id: 0, name: "Initial"}])}
    end
  end

  def render(assigns) do
    ~H"""
    <.live_component
      :if={@lc}
      module={Phoenix.LiveViewTest.Support.StreamAsyncLive.LC}
      test={@lc}
      id="lc"
    />
    <.async_result assign={@my_stream}>
      <:loading>my_stream loading...</:loading>
      <:failed :let={{kind, reason}}>{kind}: {inspect(reason)}</:failed>
      stream loaded!
    </.async_result>
    <ul id="my-stream" phx-update="stream">
      <li :for={{id, item} <- @streams.my_stream} id={id}>{item.name}</li>
    </ul>
    """
  end

  def mount(%{"test" => "lc_" <> lc_test}, _session, socket) do
    {:ok,
     socket
     |> assign(lc: lc_test)
     |> stream_async(:my_stream, fn -> {:ok, [%{id: 1, name: "lc_item"}]} end)}
  end

  def mount(%{"test" => "bad_return"}, _session, socket) do
    {:ok, stream_async(socket, :my_stream, fn -> 123 end)}
  end

  def mount(%{"test" => "bad_ok"}, _session, socket) do
    {:ok, stream_async(socket, :my_stream, fn -> {:ok, "not enumerable"} end)}
  end

  def mount(%{"test" => "ok"}, _session, socket) do
    {:ok,
     socket
     |> stream_async(:my_stream, fn ->
       {:ok, [%{id: 1, name: "First"}, %{id: 2, name: "Second"}]}
     end)}
  end

  def mount(%{"test" => "ok_with_opts"}, _session, socket) do
    {:ok,
     socket
     |> stream_async(:my_stream, fn ->
       {:ok, [%{id: 1, name: "First"}, %{id: 2, name: "Second"}], at: 0}
     end)}
  end

  def mount(%{"test" => "ok_with_reset"}, _session, socket) do
    {:ok,
     socket
     |> stream_async(:my_stream, fn ->
       {:ok, [%{id: 1, name: "First"}, %{id: 2, name: "Second"}], reset: true}
     end)}
  end

  def mount(%{"test" => "error"}, _session, socket) do
    {:ok, stream_async(socket, :my_stream, fn -> {:error, :something_wrong} end)}
  end

  def mount(%{"test" => "raise"}, _session, socket) do
    {:ok, stream_async(socket, :my_stream, fn -> raise("boom") end)}
  end

  def mount(%{"test" => "exit"}, _session, socket) do
    {:ok, stream_async(socket, :my_stream, fn -> exit(:boom) end)}
  end

  def mount(%{"test" => "lv_exit"}, _session, socket) do
    {:ok,
     stream_async(socket, :my_stream, fn ->
       Process.register(self(), :stream_async_exit)
       send(:stream_async_test_process, :async_ready)
       Process.sleep(:infinity)
     end)}
  end

  def mount(%{"test" => "cancel"}, _session, socket) do
    {:ok,
     stream_async(socket, :my_stream, fn ->
       Process.register(self(), :cancel_stream)
       send(:stream_async_test_process, :async_ready)
       Process.sleep(:infinity)
     end)}
  end

  def mount(%{"test" => "reset_option"}, _session, socket) do
    {:ok,
     socket
     |> stream_async(
       :my_stream,
       fn ->
         Process.sleep(10)
         {:ok, [%{id: 1, name: "First"}]}
       end,
       reset: true
     )}
  end

  def handle_info(:boom, _socket), do: exit(:boom)

  def handle_info(:cancel, socket) do
    {:noreply, cancel_async(socket, :my_stream)}
  end

  def handle_info(:renew_canceled, socket) do
    {:noreply,
     stream_async(
       socket,
       :my_stream,
       fn ->
         Process.sleep(10)
         {:ok, [%{id: 1, name: "renewed"}]}
       end,
       reset: true
     )}
  end

  def handle_info(:add_items, socket) do
    {:noreply,
     stream_async(socket, :my_stream, fn ->
       {:ok, [%{id: 3, name: "Third"}, %{id: 4, name: "Fourth"}]}
     end)}
  end

  def handle_info(:reset_items, socket) do
    {:noreply,
     stream_async(socket, :my_stream, fn ->
       {:ok, [%{id: 5, name: "Fifth"}, %{id: 6, name: "Sixth"}], reset: true}
     end)}
  end

  def handle_info({:cancel_lc, id}, socket) do
    send_update(Phoenix.LiveViewTest.Support.StreamAsyncLive.LC, id: id, action: :cancel)
    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}
end

defmodule Phoenix.LiveViewTest.Support.StreamAsyncLive.LC do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div>
      <.async_result :let={_} assign={@lc_stream}>
        <:loading>lc_stream loading...</:loading>
        <:failed :let={{kind, reason}}>{kind}: {inspect(reason)}</:failed>
        <ul id="lc-stream" phx-update="stream">
          <li :for={{id, item} <- @streams.lc_stream} id={id}>lc: {item.name}</li>
        </ul>
      </.async_result>
    </div>
    """
  end

  def update(%{test: "bad_return"}, socket) do
    {:ok, stream_async(socket, :lc_stream, fn -> 123 end)}
  end

  def update(%{test: "bad_ok"}, socket) do
    {:ok, stream_async(socket, :lc_stream, fn -> {:ok, "not enumerable"} end)}
  end

  def update(%{test: "ok"}, socket) do
    {:ok,
     socket
     |> stream_async(:lc_stream, fn ->
       {:ok, [%{id: 1, name: "LC First"}, %{id: 2, name: "LC Second"}]}
     end)}
  end

  def update(%{test: "raise"}, socket) do
    {:ok, stream_async(socket, :lc_stream, fn -> raise("boom") end)}
  end

  def update(%{test: "exit"}, socket) do
    {:ok, stream_async(socket, :lc_stream, fn -> exit(:boom) end)}
  end

  def update(%{test: "lv_exit"}, socket) do
    {:ok,
     stream_async(socket, :lc_stream, fn ->
       Process.register(self(), :lc_stream_exit)
       send(:stream_async_test_process, :async_ready)
       Process.sleep(:infinity)
     end)}
  end

  def update(%{test: "cancel"}, socket) do
    {:ok,
     stream_async(socket, :lc_stream, fn ->
       Process.register(self(), :lc_stream_cancel)
       send(:stream_async_test_process, :async_ready)
       Process.sleep(:infinity)
     end)}
  end

  def update(%{action: :cancel}, socket) do
    {:ok, cancel_async(socket, :lc_stream)}
  end
end
