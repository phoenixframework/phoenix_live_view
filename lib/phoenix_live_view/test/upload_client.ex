defmodule Phoenix.LiveViewTest.UploadClient do
  @moduledoc false
  use GenServer
  require Phoenix.ChannelTest

  alias Phoenix.LiveViewTest.{Upload, ClientProxy}

  def child_spec(opts) do
    %{
      id: make_ref(),
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary
    }
  end

  def channel_pids(%Upload{pid: pid}) do
    GenServer.call(pid, :channel_pids)
  end

  def allow_acknowledged?(%Upload{pid: pid}) do
    GenServer.call(pid, :allow_acknowledged)
  end

  def chunk(%Upload{pid: pid, element: element}, name, percent, proxy_pid) do
    GenServer.call(pid, {:chunk, name, percent, proxy_pid, element})
  catch
    :exit, {{:shutdown, :closed}, _} -> {:ok, :closed}
  end

  def simulate_attacker_chunk(%Upload{pid: pid}, name, chunk) do
    GenServer.call(pid, {:simulate_attacker_chunk, name, chunk})
  end

  def allowed_ack(%Upload{pid: pid, entries: entries}, ref, config, entries_resp) do
    GenServer.call(pid, {:allowed_ack, ref, config, entries, entries_resp})
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, Keyword.merge(opts, caller: self()))
  end

  def init(opts) do
    cid = Keyword.fetch!(opts, :cid)
    socket = Keyword.get(opts, :socket)
    socket = socket && put_in(socket.transport_pid, self())
    {:ok, %{socket: socket, cid: cid, upload_ref: nil, config: %{}, entries: %{}}}
  end

  def handle_call(:allow_acknowledged, _from, state) do
    {:reply, state.upload_ref != nil, state}
  end

  def handle_call({:allowed_ack, ref, config, entries, entries_resp}, _from, state) do
    entries =
      for client_entry <- entries, into: %{} do
        %{"ref" => ref, "name" => name} = client_entry
        token = Map.fetch!(entries_resp, ref)
        {name, build_and_join_entry(state, client_entry, token)}
      end

    {:reply, :ok, %{state | upload_ref: ref, config: config, entries: entries}}
  end

  def handle_call(:channel_pids, _from, state) do
    pids = Enum.into(state.entries, %{}, fn {name, entry} -> {name, entry.socket.channel_pid} end)
    {:reply, pids, state}
  end

  def handle_call({:chunk, entry_name, percent, proxy_pid, element}, from, state) do
    {:noreply, chunk_upload(state, from, entry_name, percent, proxy_pid, element)}
  end

  def handle_call({:simulate_attacker_chunk, entry_name, chunk}, _from, state) do
    Process.flag(:trap_exit, true)
    entry = get_entry!(state, entry_name)
    ref = Phoenix.ChannelTest.push(entry.socket, "chunk", {:binary, chunk})

    receive do
      %Phoenix.Socket.Reply{ref: ^ref, status: status, payload: payload} ->
        {:stop, :normal, {status, payload}, state}
    after
      get_chunk_timeout(state) -> exit(:timeout)
    end
  end

  defp build_and_join_entry(%{socket: nil} = _state, client_entry, token) do
    %{
      "name" => name,
      "content" => content,
      "size" => _,
      "type" => type,
      "ref" => ref
    } = client_entry

    %{
      name: name,
      content: content,
      size: byte_size(content),
      type: type,
      ref: ref,
      token: token,
      chunk_start: 0
    }
  end

  defp build_and_join_entry(state, client_entry, token) do
    %{
      "name" => name,
      "content" => content,
      "size" => _,
      "type" => type,
      "ref" => ref
    } = client_entry

    {:ok, _resp, entry_socket} =
      Phoenix.ChannelTest.subscribe_and_join(state.socket, "lvu:123", %{"token" => token})

    %{
      name: name,
      content: content,
      size: byte_size(content),
      type: type,
      socket: entry_socket,
      ref: ref,
      token: token,
      chunk_start: 0
    }
  end

  defp progress_stats(entry, percent) do
    chunk_size = trunc(entry.size * (percent / 100))
    start = entry.chunk_start
    new_start = start + chunk_size
    new_percent = trunc(new_start / entry.size * 100)

    %{chunk_size: chunk_size, start: start, new_start: new_start, new_percent: new_percent}
  end

  defp chunk_upload(state, from, entry_name, percent, proxy_pid, element) do
    entry = get_entry!(state, entry_name)

    if entry.chunk_start >= entry.size do
      state
    else
      do_chunk(state, from, entry, proxy_pid, element, percent)
    end
  end

  defp do_chunk(%{socket: nil, cid: cid} = state, from, entry, proxy_pid, element, percent) do
    stats = progress_stats(entry, percent)
    :ok = ClientProxy.report_upload_progress(proxy_pid, from, element, entry.ref, stats.new_percent, cid)
    update_entry_start(state, entry, stats.new_start)
  end

  defp do_chunk(state, from, entry, proxy_pid, element, percent) do
    stats = progress_stats(entry, percent)
    chunk =
      if stats.start + stats.chunk_size > entry.size do
        :binary.part(entry.content, stats.start, entry.size - stats.start)
      else
        :binary.part(entry.content, stats.start, stats.chunk_size)
      end

    ref = Phoenix.ChannelTest.push(entry.socket, "chunk", {:binary, chunk})

    receive do
      %Phoenix.Socket.Reply{ref: ^ref, status: :ok} ->
        :ok = ClientProxy.report_upload_progress(proxy_pid, from, element, entry.ref, stats.new_percent, state.cid)
        update_entry_start(state, entry, stats.new_start)
    after
      get_chunk_timeout(state) -> exit(:timeout)
    end
  end

  defp update_entry_start(state, entry, new_start) do
    new_entries = Map.update!(state.entries, entry.name, fn entry -> %{entry | chunk_start: new_start} end)
    %{state | entries: new_entries}
  end

  defp get_entry!(state, name) do
    case Map.fetch(state.entries, name) do
      {:ok, entry} -> entry
      :error ->  raise "no file input with name \"#{name}\" found in #{inspect(state.entries)}"
    end
  end

  defp get_chunk_timeout(state) do
    state.socket.assigns[:chunk_timeout] || 10_000
  end

  def handle_info(:garbage_collect, state) do
    {:noreply, state}
  end
end
