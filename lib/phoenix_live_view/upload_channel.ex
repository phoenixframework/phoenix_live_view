defmodule Phoenix.LiveView.UploadChannel do
  @moduledoc false
  use Phoenix.Channel

  require Logger

  alias Phoenix.LiveView.Static

  @impl true
  def join(_topic, auth_payload, socket) do
    %{"token" => token} = auth_payload

    with {:ok, %{pid: pid, ref: ref}} <- Static.verify_token(socket.endpoint, token),
         {:ok, %{file_size_limit: file_size_limit, chunk_size: chunk_size}} <-
           GenServer.call(pid, {:phoenix, :register_file_upload, %{pid: self(), ref: ref}}),
         {:ok, path} <- Plug.Upload.random_file("live_view_upload"),
         {:ok, handle} <- File.open(path, [:binary, :write]) do
      Process.monitor(pid)

      socket = Phoenix.Socket.assign(socket, %{
        path: path,
        handle: handle,
        live_view_pid: pid,
        file_size_limit: file_size_limit,
        uploaded_size: 0
      })

      {:ok, %{"chunkSize" => chunk_size}, socket}
    else
      {:error, :limit_exceeded} -> {:error, %{reason: :limit_exceeded}}
      _ -> {:error, %{reason: :invalid_token}}
    end
  end

  @impl true
  def handle_in(
        "event",
        {:frame, payload},
        %{assigns: %{uploaded_size: uploaded_size, file_size_limit: file_size_limit}} = socket
      )
      when byte_size(payload) + uploaded_size > file_size_limit do
    reply = %{message: "file size limit exceeded", limit: file_size_limit}
    {:stop, :normal, {:error, reply}, socket}
  end

  def handle_in("event", {:frame, payload}, socket) do
    IO.binwrite(socket.assigns.handle, payload)
    socket = assign(socket, :uploaded_size, socket.assigns.uploaded_size + byte_size(payload))
    {:reply, {:ok, %{file_ref: socket.join_ref}}, socket}
  end

  @impl true
  def handle_call({:get_file, _ref}, _reply, socket) do
    File.close(socket.assigns.handle)
    {:reply, {:ok, socket.assigns.path}, socket}
  end

  @impl true
  def handle_cast(:stop, socket) do
    {:stop, :normal, socket}
  end

  @impl true
  def handle_info(
        {:DOWN, _, _, live_view_pid, reason},
        %{assigns: %{live_view_pid: live_view_pid}} = socket
      ) do
    reason = if reason == :normal, do: {:shutdown, :closed}, else: reason
    # {:stop, reason, :live_view_down, socket}
    # TODO: stop the socket here
    {:noreply, socket}
  end
end
