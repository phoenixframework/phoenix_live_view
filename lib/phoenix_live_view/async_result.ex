defmodule Phoenix.LiveView.AsyncResult do
  @moduledoc ~S'''
  Adds async_assign functionality to LiveViews and LiveComponents.

  Performing asynchronous work is common in LiveViews and LiveComponents.
  It allows the user to get a working UI quicky while the system fetches some
  data in the background or talks to an external service. For async work,
  you also typically need to handle the different states of the async operation,
  such as loading, error, and the successful result. You also want to catch any
  error and translate it to a meaningful update in the UI rather than crashing
  the user experience.

  ## Examples

  The `assign_async/3` function takes a name, a list of keys which will be assigned
  asynchronously, and a function that returns the result of the async operation.
  For example, let's say we want to async fetch a user's organization from the database,
  as well as their profile and rank:

      def mount(%{"slug" => slug}, _, socket) do
        {:ok,
         socket
         |> assign(:foo, "bar")
         |> assign_async(:org, fn -> {:ok, %{org: fetch_org!(slug)} end)
         |> assign_async(:profile, [:profile, :rank], fn -> {:ok, %{profile: ..., rank: ...}} end)}
      end

  Here we are assigning `:org` and `[:profile, :rank]` asynchronously. If no keys are
  given (as in the case of `:org`), the keys will default to `[:org]`. The async function
  must return a `{:ok, assigns}` or `{:error, reason}` tuple where `assigns` is a map of
  the keys passed to `assign_async`. If the function returns other keys or a different
  set of keys, an error is raised.

  The state of the async operation is stored in the socket assigns under the `@async` assign
  on the socket with the name given to `assign_async/3`. It carries the `:loading?`,
  `:error`, and `:result` keys. For example, if we wanted to show the loading states
  in the UI for the `:org`, our template could conditionally render the states:

  ```heex
  <div :if={@async.org.loading?}>Loading organization...</div>
  <div :if={@async.org.error}>there was an error loading the organization</div>
  <div :if={@async.org.result == nil}}>You don't have an org yet</div>
  <div :if={org = @async.org.result}}><%= org.name%> loaded!</div>
  ```

  The `async_result` function component can also be used to declaratively
  render the different states using slots:

  ```heex
  <.async_result :let={org} assign={@async.org}>
    <:loading>Loading organization...</:loading>
    <:empty>You don't have an organization yet</:error>
    <:error>there was an error loading the organization</:error>
    <%= org.name %>
  <.async_result>
  ```

  Additionally, for async assigns which result in a list of items, you
  can consume the `@async.<name>` directly, and it will only enumerate
  the results once the results are loaded. For example:

  ```heex
  <div :for={orgs <- @async.orgs}><%= org.name %></div>
  ```
  '''
  use Phoenix.Component

  defstruct name: nil,
            keys: [],
            ok?: false,
            state: :loading,
            result: nil

  alias Phoenix.LiveView.{AsyncResult, Socket}

  @doc """
  TODO
  """
  def new(name, keys) do
    loading(%AsyncResult{name: name, keys: keys, result: nil, ok?: false})
  end

  @doc """
  TODO
  """
  def loading(%AsyncResult{} = result) do
    %AsyncResult{result | state: :loading}
  end

  @doc """
  TODO
  """
  def canceled(%AsyncResult{} = result) do
    %AsyncResult{result | state: :canceled}
  end

  @doc """
  TODO
  """
  def error(%AsyncResult{} = result, reason) do
    %AsyncResult{result | state: {:error, reason}}
  end

  @doc """
  TODO
  """
  def exit(%AsyncResult{} = result, reason) do
    %AsyncResult{result | state: {:exit, reason}}
  end

  @doc """
  TODO
  """
  def throw(%AsyncResult{} = result, value) do
    %AsyncResult{result | state: {:throw, value}}
  end

  @doc """
  TODO
  """
  def ok(%AsyncResult{} = result, value) do
    %AsyncResult{result | state: :ok, ok?: true, result: value}
  end

  @doc """
  Renders an async assign with slots for the different loading states.

  ## Examples

  ```heex
  <AsyncResult.with_state :let={org} assign={@org}>
    <:loading>Loading organization...</:loading>
    <:empty>You don't have an organization yet</:error>
    <:error :let={_reason}>there was an error loading the organization</:error>
    <:canceled :let={_reason}>loading cancled</:canceled>
    <%= org.name %>
  <AsyncResult.with_state>
  ```
  """
  attr :assign, :any, required: true
  slot :loading
  slot :canceled

  slot :empty,
    doc:
      "rendered when the result is loaded and is either nil or an empty list. Receives the result as a :let."

  slot :error,
    doc:
      "rendered when an error is caught or the function return `{:error, reason}`. Receives the error as a :let."

  def with_state(assigns) do
    case assigns.assign do
      %AsyncResult{state: :ok, result: result} ->
        if assigns.empty != [] && result in [nil, []] do
          ~H|<%= render_slot(@empty, @assign.result) %>|
        else
          ~H|<%= render_slot(@inner_block, @assign.result) %>|
        end

      %AsyncResult{state: :loading} ->
        ~H|<%= render_slot(@loading) %>|

      %AsyncResult{state: :canceled} ->
        ~H|<%= render_slot(@canceled) %>|

      %AsyncResult{state: {kind, _value}} when kind in [:error, :exit, :throw] ->
        ~H|<%= render_slot(@error, @assign.state) %>|
    end
  end

  @doc """
  Assigns keys asynchronously.

  The task is linked to the caller and errors are wrapped.
  Each key passed to `assign_async/3` will be assigned to
  an `%AsyncResult{}` struct holding the status of the operation
  and the result when completed.
  """
  def assign_async(%Socket{} = socket, key_or_keys, func)
      when (is_atom(key_or_keys) or is_list(key_or_keys)) and
             is_function(func, 0) do
    keys = List.wrap(key_or_keys)

    keys
    |> Enum.reduce(socket, fn key, acc ->
      Phoenix.Component.assign(acc, key, AsyncResult.new(key, keys))
    end)
    |> run_async_task(keys, func, fn new_socket, _component_mod, result ->
      assign_result(new_socket, keys, result)
    end)
  end

  defp assign_result(socket, keys, result) do
    case result do
      {:ok, %{} = values} ->
        if Map.keys(values) -- keys == [] do
          Enum.reduce(values, socket, fn {key, val}, acc ->
            current_async = get_current_async!(acc, key)
            Phoenix.Component.assign(acc, key, AsyncResult.ok(current_async, val))
          end)
        else
          raise ArgumentError, """
          expected assign_async to return map of assigns for all keys
          in #{inspect(keys)}, but got: #{inspect(values)}
          """
        end

      {:error, reason} ->
        Enum.reduce(keys, socket, fn key, acc ->
          current_async = get_current_async!(acc, key)
          Phoenix.Component.assign(acc, key, AsyncResult.error(current_async, reason))
        end)

      {:exit, reason} ->
        Enum.reduce(keys, socket, fn key, acc ->
          current_async = get_current_async!(acc, key)
          Phoenix.Component.assign(acc, key, AsyncResult.exit(current_async, reason))
        end)

      {:throw, value} ->
        Enum.reduce(keys, socket, fn key, acc ->
          current_async = get_current_async!(acc, key)
          Phoenix.Component.assign(acc, key, AsyncResult.throw(current_async, value))
        end)

      other ->
        raise ArgumentError, """
        expected assign_async to return {:ok, map} of
        assigns for #{inspect(keys)} or {:error, reason}, got: #{inspect(other)}
        """
    end
  end

  defp get_current_async!(socket, key) do
    # handle case where assign is temporary and needs to be rebuilt
    case socket.assigns do
      %{^key => %AsynResult{} = current_async} -> current_async
      %{^key => _other} -> AsyncResult.new(key, keys)
      %{} -> raise ArgumentError, "missing async assign #{inspect(key)}"
    end
  end

  @doc """
  Starts an ansynchronous task.

  The task is linked to the caller and errors are wrapped.
  The result of the task is sent to the `handle_async/3` callback
  of the caller LiveView or LiveComponent.

  ## Examples


  """
  def start_async(%Socket{} = socket, name, func)
      when is_atom(name) and is_function(func, 0) do
    run_async_task(socket, [name], func, fn new_socket, component_mod, result ->
      callback_mod = component_mod || new_socket.view

      case result do
        {tag, value} when tag in [:ok, :error, :exit, :throw] ->
          :ok

        other ->
          raise ArgumentError, """
          expected start_async for #{inspect(name)} in #{inspect(callback_mod)}
          to return {:ok, result} | {:error, reason}, got:

              #{inspect(other)}
          """
      end

      case callback_mod.handle_async(name, result, new_socket) do
        {:noreply, %Socket{} = new_socket} ->
          new_socket

        other ->
          raise ArgumentError, """
          expected #{inspect(callback_mod)}.handle_async/3 to return {:noreply, socket}, got:

              #{inspect(other)}
          """
      end
    end)
  end

  defp run_async_task(%Socket{} = socket, keys, func, result_func)
       when is_list(keys) and is_function(result_func, 3) do
    if Phoenix.LiveView.connected?(socket) do
      socket = cancel_existing(socket, keys)
      lv_pid = self()
      cid = cid(socket)
      ref = make_ref()
      {:ok, pid} = Task.start_link(fn -> do_async(lv_pid, cid, ref, keys, func, result_func) end)
      update_private_async(socket, keys, {ref, pid})
    else
      socket
    end
  end

  defp do_async(lv_pid, cid, ref, keys, func, result_func) do
    try do
      result = func.()

      Phoenix.LiveView.Channel.write_socket(lv_pid, cid, fn socket, component_mod ->
        handle_current_async(socket, keys, ref, component_mod, result, result_func)
      end)
    catch
      kind, reason ->
        Process.unlink(lv_pid)

        Phoenix.LiveView.Channel.write_socket(lv_pid, cid, fn socket, component_mod ->
          handle_current_async(socket, keys, ref, component_mod, {kind, reason}, result_func)
        end)

        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end

  # handle race of async being canceled and then reassigned
  defp handle_current_async(socket, keys, ref, component_mod, result, result_func)
       when is_function(result_func, 3) do
    get_private_async(socket, keys) do
      {^ref, pid} ->
        new_socket = delete_private_async(socket, keys)
        result_func.(new_socket, component_mod, result)

      {_ref, _pid} ->
        socket

      nil ->
        socket
    end
  end

  @doc """
  Cancels an async assign.

  ## Examples

      TODO fix docs
      def handle_event("cancel_preview", _, socket) do
        {:noreply, cancel_async(socket, :preview)}
      end
  """
  def cancel_async(%Socket{} = socket, %AsyncResult{} = result) do
    result.keys
    |> Enum.reduce(socket, fn key, acc ->
      Phoenix.Component.assign(acc, key, AsyncResult.canceled(result))
    end)
    |> cancel_async(result.keys)
  end

  def cancel_async(%Socket{} = socket, key) when is_atom(key) do
    cancel_async(socket, [key])
  end

  def cancel_async(%Socket{} = socket, keys) when is_list(keys) do
    case get_private_async(socket, keys) do
      {ref, pid} when is_pid(pid) ->
        Process.unlink(pid)
        Process.exit(pid, :kill)
        delete_private_async(socket, keys)

      nil ->
        raise ArgumentError, "uknown async assign #{inspect(keys)}"
    end
  end

  defp update_private_async(socket, keys, {ref, pid}) do
    socket
    |> ensure_private_async()
    |> Phoenix.Component.update(:async, fn async_map ->
      Map.put(async_map, keys, {ref, pid})
    end)
  end

  defp delete_private_async(socket, keys) do
    socket
    |> ensure_private_async()
    |> Phoenix.Component.update(:async, fn async_map -> Map.delete(async_map, keys) end)
  end

  defp ensure_private_async(socket) do
    case socket.private do
      %{phoenix_async: _} -> socket
      %{} -> Phoenix.LiveView.put_private(socket, :phoenix_async, %{})
    end
  end

  defp get_private_async(%Socket{} = socket, keys) do
    socket.private[:phoenix_async][keys]
  end

  defp cancel_existing(socket, keys) when is_list(keys) do
    if get_private_async(acc, keys) do
      cancel_async(acc, keys)
    else
      acc
    end
  end

  defp cid(%Socket{} = socket) do
    if myself = socket.assigns[:myself], do: myself.cid
  end

  defimpl Enumerable, for: Phoenix.LiveView.AsyncResult do
    alias Phoenix.LiveView.AsyncResult

    def count(%AsyncResult{result: result, state: :ok}),
      do: Enum.count(result)

    def count(%AsyncResult{}), do: 0

    def member?(%AsyncResult{result: result, state: :ok}, item) do
      Enum.member?(result, item)
    end

    def member?(%AsyncResult{}, _item) do
      raise RuntimeError, "cannot lookup member? without an ok result"
    end

    def reduce(
          %AsyncResult{result: result, state: :ok},
          acc,
          fun
        ) do
      do_reduce(result, acc, fun)
    end

    def reduce(%AsyncResult{}, acc, _fun), do: acc

    defp do_reduce(_list, {:halt, acc}, _fun), do: {:halted, acc}
    defp do_reduce(list, {:suspend, acc}, fun), do: {:suspended, acc, &do_reduce(list, &1, fun)}
    defp do_reduce([], {:cont, acc}, _fun), do: {:done, acc}

    defp do_reduce([item | tail], {:cont, acc}, fun) do
      do_reduce(tail, fun.(item, acc), fun)
    end

    def slice(%AsyncResult{result: result, state: :ok}) do
      fn start, length, step -> Enum.slice(result, start..(start + length - 1)//step) end
    end

    def slice(%AsyncResult{}) do
      fn _start, _length, _step -> [] end
    end
  end
end
