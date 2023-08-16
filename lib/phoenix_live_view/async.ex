defmodule Phoenix.LiveView.Async do
  @moduledoc false

  alias Phoenix.LiveView.{AsyncResult, Socket, Channel}

  @doc false
  def start_async(%Socket{} = socket, name, func)
      when is_atom(name) and is_function(func, 0) do
    run_async_task(socket, name, func, :start)
  end

  @doc false
  def assign_async(%Socket{} = socket, key_or_keys, func)
      when (is_atom(key_or_keys) or is_list(key_or_keys)) and
             is_function(func, 0) do
    keys = List.wrap(key_or_keys)

    # verifies result inside task
    wrapped_func = fn ->
      case func.() do
        {:ok, %{} = assigns} ->
          if Map.keys(assigns) -- keys == [] do
            {:ok, assigns}
          else
            raise ArgumentError, """
            expected assign_async to return map of assigns for all keys
            in #{inspect(keys)}, but got: #{inspect(assigns)}
            """
          end

        {:error, reason} ->
          {:error, reason}

        other ->
          raise ArgumentError, """
          expected assign_async to return {:ok, map} of
          assigns for #{inspect(keys)} or {:error, reason}, got: #{inspect(other)}
          """
      end
    end

    keys
    |> Enum.reduce(socket, fn key, acc ->
      async_result =
        case acc.assigns do
          %{^key => %AsyncResult{ok?: true} = existing} -> existing
          %{} -> AsyncResult.new(key, keys)
        end

      Phoenix.Component.assign(acc, key, async_result)
    end)
    |> run_async_task(keys, wrapped_func, :assign)
  end

  defp run_async_task(%Socket{} = socket, keys, func, kind) do
    if Phoenix.LiveView.connected?(socket) do
      socket = cancel_existing(socket, keys)
      lv_pid = self()
      cid = cid(socket)
      ref = make_ref()
      {:ok, pid} = Task.start_link(fn -> do_async(lv_pid, cid, ref, keys, func, kind) end)
      update_private_async(socket, &Map.put(&1, keys, {ref, pid, kind}))
    else
      socket
    end
  end

  defp do_async(lv_pid, cid, ref, keys, func, async_kind) do
    try do
      result = func.()
      Channel.report_async_result(lv_pid, async_kind, ref, cid, keys, {:ok, result})
    catch
      catch_kind, reason ->
        Process.unlink(lv_pid)
        caught_result = {:catch, catch_kind, reason, __STACKTRACE__}
        Channel.report_async_result(lv_pid, async_kind, ref, cid, keys, caught_result)
        :erlang.raise(catch_kind, reason, __STACKTRACE__)
    end
  end

  @doc false
  def cancel_async(%Socket{} = socket, %AsyncResult{} = result, reason) do
    result.keys
    |> Enum.reduce(socket, fn key, acc ->
      Phoenix.Component.assign(acc, key, AsyncResult.canceled(result, reason))
    end)
    |> cancel_async(result.keys, reason)
  end

  def cancel_async(%Socket{} = socket, key, reason) when is_atom(key) do
    cancel_async(socket, [key], reason)
  end

  def cancel_async(%Socket{} = socket, keys, _reason) when is_list(keys) do
    case get_private_async(socket, keys) do
      {_ref, pid, _kind} when is_pid(pid) ->
        Process.unlink(pid)
        Process.exit(pid, :kill)
        update_private_async(socket, &Map.delete(&1, keys))

      nil ->
        raise ArgumentError, "uknown async assign #{inspect(keys)}"
    end
  end

  @doc false
  def handle_async(socket, maybe_component, kind, keys, ref, result) do
    case prune_current_async(socket, keys, ref) do
      {:ok, pruned_socket} ->
        handle_kind(pruned_socket, maybe_component, kind, keys, result)

      :error ->
        socket
    end
  end

  @doc false
  def handle_trap_exit(socket, maybe_component, kind, keys, ref, reason) do
    {:current_stacktrace, stack} = Process.info(self(), :current_stacktrace)
    trapped_result = {:catch, :exit, reason, stack}
    handle_async(socket, maybe_component, kind, keys, ref, trapped_result)
  end

  defp handle_kind(socket, maybe_component, :start, keys, result) do
    callback_mod = maybe_component || socket.view

    normalized_result =
      case result do
        {:ok, result} -> {:ok, result}
        {:catch, kind, reason, stack} -> {:exit, to_exit(kind, reason, stack)}
      end

    case callback_mod.handle_async(keys, normalized_result, socket) do
      {:noreply, %Socket{} = new_socket} ->
        new_socket

      other ->
        raise ArgumentError, """
        expected #{inspect(callback_mod)}.handle_async/3 to return {:noreply, socket}, got:

            #{inspect(other)}
        """
    end
  end

  defp handle_kind(socket, _maybe_component, :assign, keys, result) do
    case result do
      {:ok, {:ok, %{} = assigns}} ->
        Enum.reduce(assigns, socket, fn {key, val}, acc ->
          current_async = get_current_async!(acc, key)
          Phoenix.Component.assign(acc, key, AsyncResult.ok(current_async, val))
        end)

      {:ok, {:error, reason}} ->
        Enum.reduce(keys, socket, fn key, acc ->
          current_async = get_current_async!(acc, key)
          Phoenix.Component.assign(acc, key, AsyncResult.error(current_async, reason))
        end)

      {:catch, kind, reason, stack} ->
        normalized_exit = to_exit(kind, reason, stack)

        Enum.reduce(keys, socket, fn key, acc ->
          current_async = get_current_async!(acc, key)
          Phoenix.Component.assign(acc, key, AsyncResult.exit(current_async, normalized_exit))
        end)
    end
  end

  # handle race of async being canceled and then reassigned
  defp prune_current_async(socket, keys, ref) do
    case get_private_async(socket, keys) do
      {^ref, _pid, _kind} -> {:ok, update_private_async(socket, &Map.delete(&1, keys))}
      {_ref, _pid, _kind} -> :error
      nil -> :error
    end
  end

  defp update_private_async(socket, func) do
    existing = socket.private[:phoenix_async] || %{}
    Phoenix.LiveView.put_private(socket, :phoenix_async, func.(existing))
  end

  defp get_private_async(%Socket{} = socket, keys) do
    socket.private[:phoenix_async][keys]
  end

  defp get_current_async!(socket, key) do
    # handle case where assign is temporary and needs to be rebuilt
    case socket.assigns do
      %{^key => %AsyncResult{} = current_async} -> current_async
      %{^key => _other} -> AsyncResult.new(key, key)
      %{} -> raise ArgumentError, "missing async assign #{inspect(key)}"
    end
  end

  defp to_exit(:throw, reason, stack), do: {{:nocatch, reason}, stack}
  defp to_exit(:error, reason, stack), do: {reason, stack}
  defp to_exit(:exit, reason, _stack), do: reason

  defp cancel_existing(%Socket{} = socket, keys) when is_list(keys) do
    if get_private_async(socket, keys) do
      Phoenix.LiveView.cancel_async(socket, keys)
    else
      socket
    end
  end

  defp cid(%Socket{} = socket) do
    if myself = socket.assigns[:myself], do: myself.cid
  end
end
