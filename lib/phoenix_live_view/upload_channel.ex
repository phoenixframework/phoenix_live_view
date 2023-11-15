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
              IO.warn("""
              consuming uploads requires a return signature matching:

                  {:ok, value} | {:postpone, value}

              got:

                  #{inspect(return)}
              """)

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
         {writer, writer_opts} <- config.writer,
         {:ok, writer_state} <- writer.init(writer_opts) do
      Process.monitor(pid)
      Process.flag(:trap_exit, true)

      socket =
        assign(socket, %{
          writer: writer,
          writer_state: writer_state,
          live_view_pid: pid,
          max_file_size: max_file_size,
          chunk_timeout: chunk_timeout,
          chunk_timer: nil,
          writer_closed?: false,
          done?: false,
          uploaded_size: 0
        })

      {:ok, socket}
    else
      {:error, reason} when reason in [:expired, :invalid] ->
        {:error, %{reason: :invalid_token}}

      {:error, reason} when reason in [:already_registered, :disallowed] ->
        {:error, %{reason: reason}}

      # writer init error
      {:error, _reason} ->
        {:error, %{reason: :writer_error}}
    end
  end

  @impl true
  def handle_in("chunk", {:binary, payload}, socket) do
    %{uploaded_size: uploaded_size, max_file_size: max_file_size} = socket.assigns
    socket = reschedule_chunk_timer(socket)

    if !socket.assigns.writer_closed? and byte_size(payload) + uploaded_size <= max_file_size do
      case write_bytes(socket, payload) do
        {:ok, new_socket} ->
          {:reply, :ok, new_socket}

        {:error, reason, new_socket} ->
          new_socket =
            case close_writer(new_socket, {:error, reason}) do
              {:ok, new_socket} -> new_socket
              {:error, _reason, new_socket} -> new_socket
            end

          Channel.report_writer_error(socket.assigns.live_view_pid, reason)

          {:reply, {:error, %{reason: :writer_error}}, new_socket}
      end
    else
      reply = %{reason: :file_size_limit_exceeded, limit: max_file_size}
      {:stop, {:shutdown, :closed}, {:error, reply}, socket}
    end
  end

  @impl true
  def handle_info({:EXIT, _pid, reason}, socket) do
    {:stop, reason, socket}
  end

  def handle_info(
        {:DOWN, _, _, live_view_pid, reason},
        %{assigns: %{live_view_pid: live_view_pid}} = socket
      ) do
    reason = if reason == :normal, do: {:shutdown, :closed}, else: reason
    {:stop, reason, maybe_cancel_writer(socket)}
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
    if socket.assigns.writer_closed? do
      GenServer.reply(from, :ok)
      {:stop, {:shutdown, :closed}, socket}
    else
      case close_writer(socket, :cancel) do
        {:ok, new_socket} ->
          GenServer.reply(from, :ok)
          {:stop, {:shutdown, :closed}, new_socket}

        {:error, reason, new_socket} ->
          GenServer.reply(from, {:error, reason})
          {:stop, {:shutdown, :closed}, new_socket}
      end
    end
  end

  @impl true
  def terminate(_reason, socket) do
    _ = maybe_cancel_writer(socket)
    :ok
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
    case socket.assigns.writer.write_chunk(payload, socket.assigns.writer_state) do
      {:ok, writer_state} ->
        socket
        |> assign(:uploaded_size, socket.assigns.uploaded_size + byte_size(payload))
        |> assign(:writer_state, writer_state)
        |> maybe_close_completed_file()

      {:error, reason, writer_state} ->
        cancel_timer(socket.assigns.chunk_timer, :chunk_timeout)
        {:error, reason, assign(socket, writer_state: writer_state, chunk_timer: nil)}
    end
  end

  defp maybe_close_completed_file(socket) do
    if socket.assigns.uploaded_size == socket.assigns.max_file_size do
      case close_writer(socket, :done) do
        {:ok, socket} -> {:ok, assign(socket, done?: true)}
        {:error, reason, new_socket} -> {:error, reason, new_socket}
      end
    else
      {:ok, socket}
    end
  end

  # we need to handle the case where socket assigns aren't set yet because
  # we are trapping exits and may enter terminate before joining is complete
  defp maybe_cancel_writer(socket) do
    case socket.assigns do
      %{writer_closed?: false} ->
        case close_writer(socket, :cancel) do
          {:ok, new_socket} -> new_socket
          {:error, _reason, new_socket} -> new_socket
        end

      %{} ->
        socket
    end
  end

  defp close_writer(socket, reason) do
    cancel_timer(socket.assigns.chunk_timer, :chunk_timeout)
    socket = assign(socket, chunk_timer: nil, writer_closed?: true)

    case socket.assigns.writer.close(socket.assigns.writer_state, reason) do
      {:ok, writer_state} ->
        {:ok,
         socket
         |> assign(writer_state: writer_state)
         |> garbage_collect()}

      {:error, reason} ->
        {:error, reason, socket}
    end
  end

  defp garbage_collect(socket) do
    send(socket.transport_pid, :garbage_collect)
    :erlang.garbage_collect(self())

    socket
  end

  defp file_meta(socket), do: socket.assigns.writer.meta(socket.assigns.writer_state)
end
