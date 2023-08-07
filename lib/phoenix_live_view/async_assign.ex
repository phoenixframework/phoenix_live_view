defmodule Phoenix.LiveView.AsyncAssign do
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
            ref: nil,
            pid: nil,
            keys: [],
            loading?: false,
            error: nil,
            result: nil,
            canceled?: false

  alias Phoenix.LiveView.AsyncAssign

  @doc """
  Renders an async assign with slots for the different loading states.

  ## Examples

  ```heex
  <.async_result :let={org} assign={@async.org}>
    <:loading>Loading organization...</:loading>
    <:empty>You don't have an organization yet</:error>
    <:error :let={_reason}>there was an error loading the organization</:error>
    <:canceled :let={_reason}>loading cancled</:canceled>
    <%= org.name %>
  <.async_result>
  ```
  """
  attr :assign, :any, required: true
  slot :loading
  slot :canceled

  slot :empty,
    doc:
      "rendered when the result is loaded and is either nil or an empty enumerable. Receives the result as a :let."

  slot :error,
    doc:
      "rendered when an error is caught or the function return `{:error, reason}`. Receives the error as a :let."

  def async_result(assigns) do
    case assigns.assign do
      %AsyncAssign{result: result, loading?: false, error: nil, canceled?: false} ->
        if assigns.empty != [] && (is_nil(result) or Enum.empty?(result)) do
          ~H|<%= render_slot(@empty, @assign.result) %>|
        else
          ~H|<%= render_slot(@inner_block, @assign.result) %>|
        end

      %AsyncAssign{loading?: true} ->
        ~H|<%= render_slot(@loading) %>|

      %AsyncAssign{loading?: false, error: error} when not is_nil(error) ->
        ~H|<%= render_slot(@error, @assign.error) %>|

      %AsyncAssign{loading?: false, canceled?: true} ->
        ~H|<%= render_slot(@canceled) %>|
    end
  end

  @doc """
  Assigns keys ansynchronously.

  See the module docs for more and exmaple usage.
  """
  def assign_async(%Phoenix.LiveView.Socket{} = socket, name, func) do
    assign_async(socket, name, [name], func)
  end

  def assign_async(%Phoenix.LiveView.Socket{} = socket, name, keys, func)
      when is_atom(name) and is_list(keys) and is_function(func, 0) do
    socket = cancel_existing(socket, name)
    base_async = %AsyncAssign{name: name, keys: keys, loading?: true}

    async_assign =
      if Phoenix.LiveView.connected?(socket) do
        lv_pid = self()
        ref = make_ref()
        cid = if myself = socket.assigns[:myself], do: myself.cid

        {:ok, pid} =
          Task.start_link(fn ->
            do_async(lv_pid, cid, %AsyncAssign{base_async | pid: self(), ref: ref}, func)
          end)

        %AsyncAssign{base_async | pid: pid, ref: ref}
      else
        base_async
      end

    Enum.reduce(keys, socket, fn key, acc -> update_async(acc, key, async_assign) end)
  end

  @doc """
  Cancels an async assign.

  ## Examples

      def handle_event("cancel_preview", _, socket) do
        {:noreply, cancel_async(socket, :preview)}
      end
  """
  def cancel_async(%Phoenix.LiveView.Socket{} = socket, name) do
    case get(socket, name) do
      %AsyncAssign{loading?: false} ->
        socket

      %AsyncAssign{canceled?: false, pid: pid} = existing ->
        Process.unlink(pid)
        Process.exit(pid, :kill)
        async = %AsyncAssign{existing | loading?: false, error: nil, canceled?: true}
        update_async(socket, name, async)

      nil ->
        raise ArgumentError,
              "no async assign #{inspect(name)} previously assigned with assign_async"
    end
  end

  defp do_async(lv_pid, cid, %AsyncAssign{} = async_assign, func) do
    %AsyncAssign{keys: known_keys, name: name, ref: ref} = async_assign

    try do
      case func.() do
        {:ok, %{} = results} ->
          if Map.keys(results) -- known_keys == [] do
            Phoenix.LiveView.Channel.write_socket(lv_pid, cid, fn socket ->
              write_current_async(socket, name, ref, fn %AsyncAssign{} = current ->
                Enum.reduce(results, socket, fn {key, result}, acc ->
                  async = %AsyncAssign{current | result: result, loading?: false}
                  update_async(acc, key, async)
                end)
              end)
            end)
          else
            raise ArgumentError, """
            expected assign_async to return map of
            assigns for all keys in #{inspect(known_keys)}, but got: #{inspect(results)}
            """
          end

        {:error, reason} ->
          Phoenix.LiveView.Channel.write_socket(lv_pid, cid, fn socket ->
            write_current_async(socket, name, ref, fn %AsyncAssign{} = current ->
              Enum.reduce(known_keys, socket, fn key, acc ->
                async = %AsyncAssign{current | result: nil, loading?: false, error: reason}
                update_async(acc, key, async)
              end)
            end)
          end)

        other ->
          raise ArgumentError, """
          expected assign_async to return {:ok, map} of
          assigns for #{inspect(known_keys)} or {:error, reason}, got: #{inspect(other)}
          """
      end
    catch
      kind, reason ->
        Process.unlink(lv_pid)

        Phoenix.LiveView.Channel.write_socket(lv_pid, cid, fn socket ->
          write_current_async(socket, name, ref, fn %AsyncAssign{} = current ->
            Enum.reduce(known_keys, socket, fn key, acc ->
              async = %AsyncAssign{current | loading?: false, error: {kind, reason}}
              update_async(acc, key, async)
            end)
          end)
        end)

        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end

  defp update_async(socket, key, %AsyncAssign{} = new_async) do
    socket
    |> ensure_async()
    |> Phoenix.Component.update(:async, fn async_map ->
      Map.put(async_map, key, new_async)
    end)
  end

  defp ensure_async(socket) do
    Phoenix.Component.assign_new(socket, :async, fn -> %{} end)
  end

  defp get(%Phoenix.LiveView.Socket{} = socket, name) do
    socket.assigns[:async] && Map.get(socket.assigns.async, name)
  end

  # handle race of async being canceled and then reassigned
  defp write_current_async(socket, name, ref, func) do
    case get(socket, name) do
      %AsyncAssign{ref: ^ref} = async_assign -> func.(async_assign)
      %AsyncAssign{ref: _ref} -> socket
    end
  end

  defp cancel_existing(socket, name) do
    if get(socket, name) do
      cancel_async(socket, name)
    else
      socket
    end
  end

  defimpl Enumerable, for: Phoenix.LiveView.AsyncAssign do
    alias Phoenix.LiveView.AsyncAssign

    def count(%AsyncAssign{result: result, loading?: false, error: nil, canceled?: false}),
      do: Enum.count(result)

    def count(%AsyncAssign{}), do: 0

    def member?(%AsyncAssign{result: result, loading?: false, error: nil, canceled?: false}, item) do
      Enum.member?(result, item)
    end

    def member?(%AsyncAssign{}, _item) do
      raise RuntimeError, "cannot lookup member? while loading"
    end

    def reduce(
          %AsyncAssign{result: result, loading?: false, error: nil, canceled?: false},
          acc,
          fun
        ) do
      do_reduce(result, acc, fun)
    end

    def reduce(%AsyncAssign{}, acc, _fun), do: acc

    defp do_reduce(_list, {:halt, acc}, _fun), do: {:halted, acc}
    defp do_reduce(list, {:suspend, acc}, fun), do: {:suspended, acc, &do_reduce(list, &1, fun)}
    defp do_reduce([], {:cont, acc}, _fun), do: {:done, acc}

    defp do_reduce([item | tail], {:cont, acc}, fun) do
      do_reduce(tail, fun.(item, acc), fun)
    end

    def slice(%AsyncAssign{result: result, loading?: false, error: nil, canceled?: false}) do
      fn start, length, step -> Enum.slice(result, start..(start + length - 1)//step) end
    end

    def slice(%AsyncAssign{}) do
      fn _start, _length, _step -> [] end
    end
  end
end
