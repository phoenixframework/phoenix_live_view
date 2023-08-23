defmodule Phoenix.LiveView.AsyncResult do
  @moduledoc ~S'''
  Provides a datastructure for tracking the state of an async assign.

  See the `Async Operations` section of the `Phoenix.LiveView` docs for more information.

  ## Fields

    * `:ok?` - When true, indicates the `:result` has been set successfully at least once.
    * `:loading` - The current loading state
    * `:failed` - The current failed state
    * `:result` - The successful result of the async task
  '''

  defstruct ok?: false,
            loading: nil,
            failed: nil,
            result: nil

  alias Phoenix.LiveView.AsyncResult

  @doc """
  Updates the loading state.

  When loading, the failed state will be reset to `nil`.

  ## Examples

      AsyncResult.loading()
      AsyncResult.loading(my_async)
      AsyncResult.loading(my_async, %{my: :loading_state})
  """
  def loading do
    %AsyncResult{loading: true}
  end

  def loading(%AsyncResult{} = result) do
    %AsyncResult{result | loading: true, failed: nil}
  end

  def loading(loading_state) do
    %AsyncResult{loading: loading_state, failed: nil}
  end

  def loading(%AsyncResult{} = result, loading_state) do
    %AsyncResult{result | loading: loading_state, failed: nil}
  end


  @doc """
  Updates the failed state.

  When failed, the loading state will be reset to `nil`.

  ## Examples

      AsyncResult.failed(my_async, {:exit, :boom})
      AsyncResult.failed(my_async, {:error, reason})
  """
  def failed(%AsyncResult{} = result, reason) do
    %AsyncResult{result | failed: reason, loading: nil}
  end

  @doc """
  Updates the successful result.

  The `:ok?` field will also be set to `true` to indicate this result has
  completed successfully at least once, regardless of future state changes.

  When ok'd, the loading and failed state will be reset to `nil`.

  ## Examples

      AsyncResult.ok(my_async, my_result)
  """
  def ok(%AsyncResult{} = result, value) do
    %AsyncResult{result | failed: nil, loading: nil, ok?: true, result: value}
  end

  defimpl Enumerable, for: Phoenix.LiveView.AsyncResult do
    alias Phoenix.LiveView.AsyncResult

    def count(%AsyncResult{result: result, ok?: true}),
      do: Enum.count(result)

    def count(%AsyncResult{}), do: 0

    def member?(%AsyncResult{result: result, ok?: true}, item) do
      do: Enumerable.member?(result, item)
    end

    def member?(%AsyncResult{}, _item) do
      raise RuntimeError, "cannot lookup member? without an ok result"
    end

    def reduce(
          %AsyncResult{result: result, ok?: true},
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

    def slice(%AsyncResult{result: result, ok?: true}) do
      Enumerable.slice(result)
    end

    def slice(%AsyncResult{}) do
      fn _start, _length, _step -> [] end
    end
  end
end
