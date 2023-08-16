defmodule Phoenix.LiveView.AsyncResult do
  @moduledoc ~S'''
  Adds async functionality to LiveViews and LiveComponents.

  Performing asynchronous work is common in LiveViews and LiveComponents.
  It allows the user to get a working UI quicky while the system fetches some
  data in the background or talks to an external service. For async work,
  you also typically need to handle the different states of the async operation,
  such as loading, error, and the successful result. You also want to catch any
  errors or exits and translate it to a meaningful update in the UI rather than
  crashing the user experience.

  ## Async assigns

  The `assign_async/3` function takes a name, a list of keys which will be assigned
  asynchronously, and a function that returns the result of the async operation.
  For example, let's say we want to async fetch a user's organization from the database,
  as well as their profile and rank:

      def mount(%{"slug" => slug}, _, socket) do
        {:ok,
         socket
         |> assign(:foo, "bar")
         |> assign_async(:org, fn -> {:ok, %{org: fetch_org!(slug)} end)
         |> assign_async([:profile, :rank], fn -> {:ok, %{profile: ..., rank: ...}} end)}
      end

  Here we are assigning `:org` and `[:profile, :rank]` asynchronously. The async function
  must return a `{:ok, assigns}` or `{:error, reason}` tuple, where `assigns` is a map of
  the keys passed to `assign_async`. If the function returns other keys or a different
  set of keys, an error is raised.

  The state of the async operation is stored in the socket assigns within an
  `%AsyncResult{}`. It carries the loading and error states, as well as the result.
  For example, if we wanted to show the loading states in the UI for the `:org`,
  our template could conditionally render the states:

  ```heex
  <div :if={@org.state == :loading}>Loading organization...</div>
  <div :if={org = @org.ok? && @org.result}}><%= org.name %> loaded!</div>
  ```

  The `with_state` function component can also be used to declaratively
  render the different states using slots:

  ```heex
  <AsyncResult.with_state :let={org} assign={@org}>
    <:loading>Loading organization...</:loading>
    <:empty>You don't have an organization yet</:error>
    <:error :let={{_kind, _reason}}>there was an error loading the organization</:error>
    <:canceled :let={_reason}>loading canceled</:canceled>
    <%= org.name %>
  <AsyncResult.with_state>
  ```

  Additionally, for async assigns which result in a list of items, you
  can consume the assign directly. It will only enumerate
  the results once the results are loaded. For example:

  ```heex
  <div :for={orgs <- @orgs}><%= org.name %></div>
  ```

  ## Arbitrary async operations

  Sometimes you need lower level control of asynchronous operations, while
  still receiving process isolation and error handling. For this, you can use
  `start_async/3` and the `AsyncResult` module directly:

      def mount(%{"id" => id}, _, socket) do
        {:ok,
        socket
        |> assign(:org, AsyncResult.new(:org))
        |> start_async(:my_task, fn -> fetch_org!(id) end)
      end

      def handle_async(:org, {:ok, fetched_org}, socket) do
        %{org: org} = socket.assigns
        {:noreply, assign(socket, :org, AsyncResult.ok(org, fetched_org))}
      end

      def handle_async(:org, {:exit, reason}, socket) do
        %{org: org} = socket.assigns
        {:noreply, assign(socket, :org, AsyncResult.exit(org, reason))}
      end

  `start_async/3` is used to fetch the organization asynchronously. The
  `handle_async/3` callback is called when the task completes or exists,
  with the results wrapped in either `{:ok, result}` or `{:exit, reason}`.
  The `AsyncResult` module is used to direclty to update the state of the
  async operation, but you can also assign any value directly to the socket
  if you want to handle the state yourself.
  '''
  use Phoenix.Component

  defstruct name: nil,
            keys: [],
            ok?: false,
            state: :loading,
            result: nil

  alias Phoenix.LiveView.AsyncResult

  @doc """
  Defines a new async result.

  By default, the state will be `:loading`.
  """
  def new(name) do
    new(name, [name])
  end

  def new(name, keys) do
    loading(%AsyncResult{name: name, keys: keys, result: nil, ok?: false})
  end

  @doc """
  Updates the state of the result to `:loading`
  """
  def loading(%AsyncResult{} = result) do
    %AsyncResult{result | state: :loading}
  end

  @doc """
  Updates the state of the result to `{:error, {:canceled, reason}}`.
  """
  def canceled(%AsyncResult{} = result, reason) do
    error(result, {:canceled, reason})
  end

  @doc """
  Updates the state of the result to `{:error, reason}`.
  """
  def error(%AsyncResult{} = result, reason) do
    %AsyncResult{result | state: {:error, reason}}
  end

  @doc """
  Updates the state of the result to `{:exit, reason}`.
  """
  def exit(%AsyncResult{} = result, reason) do
    %AsyncResult{result | state: {:exit, reason}}
  end

  @doc """
  Updates the state of the result to `:ok` and sets the result.

  The `:ok?` field will also be set to `true` to indicate this result has
  completed successfully at least once, regardless of future state changes.
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
    <:error :let={{_kind, _reason}}>there was an error loading the organization</:error>
    <:canceled :let={_reason}>loading canceled</:canceled>
    <%= org.name %>
  <AsyncResult.with_state>
  ```
  """
  attr :assign, :any, required: true
  slot(:loading)

  # TODO decide if we want an canceled slot
  slot(:canceled)

  # TODO decide if we want an empty slot
  slot(:empty,
    doc:
      "rendered when the result is loaded and is either nil or an empty list. Receives the result as a :let."
  )

  slot(:failed,
    doc:
      "rendered when an error or exit is caught or assign_async returns `{:error, reason}`. Receives the error as a :let."
  )

  def with_state(assigns) do
    case assigns.assign do
      %AsyncResult{state: state, ok?: once_ok?, result: result} when state == :ok or once_ok? ->
        if assigns.empty != [] && result in [nil, []] do
          ~H|<%= render_slot(@empty, @assign.result) %>|
        else
          ~H|<%= render_slot(@inner_block, @assign.result) %>|
        end

      %AsyncResult{state: :loading} ->
        ~H|<%= render_slot(@loading) %>|

      %AsyncResult{state: {:error, {:canceled, reason}}} ->
        if assigns.canceled != [] do
          assigns = Phoenix.Component.assign(assigns, reason: reason)
          ~H|<%= render_slot(@canceled, @reason) %>|
        else
          ~H|<%= render_slot(@failed, @assign.state) %>|
        end

      %AsyncResult{state: {kind, _reason}} when kind in [:error, :exit] ->
        ~H|<%= render_slot(@failed, @assign.state) %>|
    end
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
