defmodule Phoenix.LiveView.AsyncResult do
  @moduledoc ~S'''
  Provides a datastructure for tracking the state of an async assign.

  See the `Async Operations` section of the `Phoenix.LiveView` docs for more information.
  '''

  defstruct ok?: false,
            state: nil,
            status: nil,
            result: nil

  alias Phoenix.LiveView.AsyncResult

  @doc """
  Defines a new async result.

  By default, the state will be `{:loading, []}`.
  """
  def new(keys \\ []) do
    loading(%AsyncResult{result: nil, ok?: false}, keys)
  end

  @doc """
  Updates the status of the result to `:loading`
  """
  def loading(%AsyncResult{} = result, keys \\ []) do
    %AsyncResult{result | status: :loading, state: keys}
  end

  @doc """
  Updates the status of the result to `:error` and state to `reason`.
  """
  def error(%AsyncResult{} = result, reason) do
    %AsyncResult{result | status: :error, state: reason}
  end

  @doc """
  Updates the status of the result to `:exit` and state to `reason`.
  """
  def exit(%AsyncResult{} = result, reason) do
    %AsyncResult{result | status: :exit, state: reason}
  end

  @doc """
  Updates the status of the result to `:ok` and sets the result.

  The `:ok?` field will also be set to `true` to indicate this result has
  completed successfully at least once, regardless of future state changes.
  """
  def ok(%AsyncResult{} = result, value) do
    %AsyncResult{result | status: :ok, state: nil, ok?: true, result: value}
  end

  defimpl Enumerable, for: Phoenix.LiveView.AsyncResult do
    alias Phoenix.LiveView.AsyncResult

    def count(%AsyncResult{result: result, status: :ok}),
      do: Enum.count(result)

    def count(%AsyncResult{}), do: 0

    def member?(%AsyncResult{result: result, status: :ok}, item) do
      Enum.member?(result, item)
    end

    def member?(%AsyncResult{}, _item) do
      raise RuntimeError, "cannot lookup member? without an ok result"
    end

    def reduce(
          %AsyncResult{result: result, status: :ok},
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

    def slice(%AsyncResult{result: result, status: :ok}) do
      fn start, length, step -> Enum.slice(result, start..(start + length - 1)//step) end
    end

    def slice(%AsyncResult{}) do
      fn _start, _length, _step -> [] end
    end
  end
end
