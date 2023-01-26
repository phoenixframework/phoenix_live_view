defmodule Phoenix.LiveView.LiveStream do
  alias Phoenix.LiveView.LiveStream
  defstruct id: nil, name: nil, count: 0, dom_id: nil, inserts: [], deletes: []

  # TODO
  # dom_id – optional
  #

  def new(items, opts) when is_list(opts) do
    name = Keyword.fetch!(opts, :name)
    stream_id = Keyword.get_lazy(opts, :id, fn -> to_string(name) end)
    dom_id = Keyword.get_lazy(opts, :dom_id, fn -> &default_id(stream_id, &1) end)

    unless is_function(dom_id, 1) do
      raise ArgumentError,
            "stream :dom_id's must return a function which accepts each item, got: #{inspect(dom_id)}"
    end

    %LiveStream{
      id: stream_id,
      name: name,
      dom_id: dom_id,
      inserts: to_list(items, dom_id),
      deletes: [],
      count: Enum.count(items)
    }
  end

  defp default_id(stream_id, %{id: id} = _struct_or_map), do: stream_id <> "-#{to_string(id)}"

  defp default_id(stream_id, other) do
    raise ArgumentError, """
    expected stream \"#{stream_id}\" to be a struct or map with :id key, got #{inspect(other)}

    if you would like to generate custom DOM id's based on other keys, use the :dom_id option.
    """
  end

  def prune(%LiveStream{} = stream) do
    %LiveStream{stream | inserts: [], deletes: []}
  end

  # todo remove count
  def insert_item(%LiveStream{} = stream, item, at) do
    item_id = stream.dom_id.(item)

    %LiveStream{
      stream
      | inserts: stream.inserts ++ [{item_id, at, item}],
        count: stream.count + 1
    }
  end

  defp to_list(items, item_id_func) do
    for item <- Enum.to_list(items), do: {item_id_func.(item), -1, item}
  end

  defimpl Enumerable, for: LiveStream do
    # TODO count should be only what we have in appends/prepends
    def count(%LiveStream{count: count}), do: count

    def member?(%LiveStream{}, _item), do: raise(RuntimeError, "not implemented")

    def reduce(%LiveStream{inserts: inserts}, acc, fun) do
      do_reduce(inserts, acc, fun)
    end

    defp do_reduce(_list, {:halt, acc}, _fun), do: {:halted, acc}
    defp do_reduce(list, {:suspend, acc}, fun), do: {:suspended, acc, &do_reduce(list, &1, fun)}
    defp do_reduce([], {:cont, acc}, _fun), do: {:done, acc}
    defp do_reduce([{dom_id, _at, item} | tail], {:cont, acc}, fun) do
      do_reduce(tail, fun.({dom_id, item}, acc), fun)
    end

    # Returns a function that slices the data structure contiguously.
    def slice(%LiveStream{}), do: raise(RuntimeError, "not implemented")
  end
end
