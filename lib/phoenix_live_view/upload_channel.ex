defmodule Phoenix.LiveView.UploadChannel do
  @moduledoc false
  use Phoenix.Channel, log_handle_in: false
  @timeout :infinity

  require Logger

  alias Phoenix.LiveView.{Static, Channel}

  def cancel(pid) do
    GenServer.call(pid, :cancel, @timeout)
  end

  def consume(pid, entry, func) when is_function(func, 1) or is_function(func, 2) do
    case GenServer.call(pid, :consume_start, @timeout) do
      {:ok, file_meta} ->
        try do
          result =
            cond do
              is_function(func, 1) -> func.(file_meta)
              is_function(func, 2) -> func.(file_meta, entry)
            end

          case result do
            {:ok, return} ->
              GenServer.call(pid, :consume_done, @timeout)
              return

            {:postpone, return} ->
              return

            return ->
              IO.warn """
              consuming uploads requires a return signature matching:

                  {:ok, value} | {:postpone, value}

              got:

                  #{inspect(return)}
              """
              GenServer.call(pid, :consume_done, @timeout)
              return
          end
        rescue
          exception ->
            GenServer.call(pid, :consume_done, @timeout)
            reraise(exception, __STACKTRACE__)
        end

      {:error, :in_progress} ->
        raise RuntimeError, "cannot consume uploaded file that is still in progress"
    end
  end

  @impl true
  def join(_topic, auth_payload, socket) do
    %{"token" => token} = auth_payload

    with {:ok, %{pid: pid, ref: ref, cid: cid}} <- Static.verify_token(socket.endpoint, token),
         {:ok, config} <- Channel.register_upload(pid, ref, cid),
         %{max_file_size: max_file_size, chunk_timeout: chunk_timeout} = config,
         {:ok, path} <- Plug.Upload.random_file("live_view_upload"),
         {:ok, handle} <- File.open(path, [:binary, :write]) do
      Process.monitor(pid)

      socket =
        assign(socket, %{
          path: path,
          handle: handle,
          live_view_pid: pid,
          max_file_size: max_file_size,
          chunk_timeout: chunk_timeout,
          chunk_timer: nil,
          done?: false,
          uploaded_size: 0
        })

      {:ok, socket}
    else
      {:error, reason} when reason in [:expired, :invalid] ->
        {:error, %{reason: :invalid_token}}

      {:error, reason} when reason in [:already_registered, :disallowed] ->
        {:error, %{reason: reason}}
    end
  end

  @impl true
  def handle_in("chunk", {:binary, payload}, socket) do
    %{uploaded_size: uploaded_size, max_file_size: max_file_size} = socket.assigns
    socket = reschedule_chunk_timer(socket)

    if byte_size(payload) + uploaded_size <= max_file_size do
      {:reply, :ok, write_bytes(socket, payload)}
    else
      reply = %{reason: :file_size_limit_exceeded, limit: max_file_size}
      {:stop, {:shutdown, :closed}, {:error, reply}, socket}
    end
  end

  @impl true
  def handle_info(
        {:DOWN, _, _, live_view_pid, reason},
        %{assigns: %{live_view_pid: live_view_pid}} = socket
      ) do
    reason = if reason == :normal, do: {:shutdown, :closed}, else: reason
    {:stop, reason, socket}
  end

  def handle_info(:chunk_timeout, socket) do
    {:stop, {:shutdown, :closed}, socket}
  end

  @impl true
  def handle_call(:consume_start, _from, socket) do
    if socket.assigns.done? do
      {:reply, {:ok, file_meta(socket)}, socket}
    else
      {:reply, {:error, :in_progress}, socket}
    end
  end

  @impl true
  def handle_call(:consume_done, from, socket) do
    GenServer.reply(from, :ok)
    {:stop, {:shutdown, :closed}, socket}
  end

  def handle_call(:cancel, from, socket) do
    new_socket = close_file(socket)
    GenServer.reply(from, :ok)
    {:stop, {:shutdown, :closed}, new_socket}
  end

  defp reschedule_chunk_timer(socket) do
    cancel_timer(socket.assigns.chunk_timer, :chunk_timeout)
    new_timer = Process.send_after(self(), :chunk_timeout, socket.assigns.chunk_timeout)
    assign(socket, :chunk_timer, new_timer)
  end

  defp cancel_timer(nil = _timer, _msg), do: :ok

  defp cancel_timer(timer, msg) do
    if Process.cancel_timer(timer) do
      :ok
    else
      receive do
        ^msg -> :ok
      after
        0 -> :ok
      end
    end
  end

  defp write_bytes(socket, payload) do
    IO.binwrite(socket.assigns.handle, payload)
    socket = assign(socket, :uploaded_size, socket.assigns.uploaded_size + byte_size(payload))

    if socket.assigns.uploaded_size == socket.assigns.max_file_size do
      socket
      |> close_file()
      |> assign(:done?, true)
    else
      socket
    end
  end

  defp close_file(socket) do
    File.close(socket.assigns.handle)
    cancel_timer(socket.assigns.chunk_timer, :chunk_timeout)

    socket
    |> assign(:chunk_timer, nil)
    |> garbage_collect()
  end

  defp garbage_collect(socket) do
    send(socket.transport_pid, :garbage_collect)
    :erlang.garbage_collect(self())

    socket
  end

  defp file_meta(socket), do: %{path: socket.assigns.path}
end
