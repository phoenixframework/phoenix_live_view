defmodule Phoenix.LiveView.LiveStream do
  alias Phoenix.LiveView.LiveStream
  defstruct id: nil, name: nil, count: 0, item_id: nil, items: [], deletes: []

  def new(items, opts) when is_list(items) and is_list(opts) do
    name = Keyword.fetch!(opts, :name)
    id = Keyword.fetch!(opts, :id)
    item_id = Keyword.fetch!(opts, :item_id)

    %LiveStream{
      id: id,
      name: name,
      item_id: item_id,
      items: Enum.to_list(items),
      deletes: [],
      count: Enum.count(items)
    }
  end

  defimpl Enumerable, for: LiveStream do
    def count(%LiveStream{count: count}), do: count

    def member?(%LiveStream{}, _item), do: raise(RuntimeError, "not implemented")

    def reduce(%LiveStream{items: items}, acc, fun), do: do_reduce(items, acc, fun)

    defp do_reduce(_list, {:halt, acc}, _fun), do: {:halted, acc}
    defp do_reduce(list, {:suspend, acc}, fun), do: {:suspended, acc, &do_reduce(list, &1, fun)}
    defp do_reduce([], {:cont, acc}, _fun), do: {:done, acc}
    defp do_reduce([head | tail], {:cont, acc}, fun), do: do_reduce(tail, fun.(head, acc), fun)

    # Returns a function that slices the data structure contiguously.
    def slice(%LiveStream{}), do: raise(RuntimeError, "not implemented")
  end
end
