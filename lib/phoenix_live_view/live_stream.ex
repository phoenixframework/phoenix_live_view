defmodule Phoenix.LiveView.LiveStream do
  @moduledoc false

  defstruct name: nil,
            dom_id: nil,
            ref: nil,
            inserts: [],
            deletes: [],
            reset?: false,
            consumable?: false

  alias Phoenix.LiveView.LiveStream

  def new(name, ref, items, opts) when is_list(opts) do
    dom_prefix = to_string(name)
    dom_id = Keyword.get_lazy(opts, :dom_id, fn -> &default_id(dom_prefix, &1) end)

    if not is_function(dom_id, 1) do
      raise ArgumentError,
            "stream :dom_id must return a function which accepts each item, got: #{inspect(dom_id)}"
    end

    items_list = for item <- items, do: {dom_id.(item), -1, item, opts[:limit]}

    %LiveStream{
      ref: ref,
      name: name,
      dom_id: dom_id,
      inserts: items_list,
      deletes: [],
      reset?: false
    }
  end

  defp default_id(dom_prefix, %{id: id} = _struct_or_map), do: dom_prefix <> "-#{to_string(id)}"

  defp default_id(dom_prefix, other) do
    raise ArgumentError, """
    expected stream :#{dom_prefix} to be a struct or map with :id key, got: #{inspect(other)}

    If you would like to generate custom DOM id's based on other keys, use stream_configure/3 with the :dom_id option beforehand.
    """
  end

  def reset(%LiveStream{} = stream) do
    %LiveStream{stream | reset?: true}
  end

  def prune(%LiveStream{} = stream) do
    %LiveStream{stream | inserts: [], deletes: [], reset?: false}
  end

  def delete_item(%LiveStream{} = stream, item) do
    delete_item_by_dom_id(stream, stream.dom_id.(item))
  end

  def delete_item_by_dom_id(%LiveStream{} = stream, dom_id) do
    %LiveStream{stream | deletes: [dom_id | stream.deletes]}
  end

  def insert_item(%LiveStream{} = stream, item, at, limit) do
    item_id = stream.dom_id.(item)

    %LiveStream{stream | inserts: stream.inserts ++ [{item_id, at, item, limit}]}
  end

  defimpl Enumerable, for: LiveStream do
    def count(%LiveStream{inserts: inserts}), do: {:ok, length(inserts)}

    def member?(%LiveStream{}, _item), do: raise(RuntimeError, "not implemented")

    def reduce(%LiveStream{inserts: inserts} = stream, acc, fun) do
      if stream.consumable? do
        do_reduce(inserts, acc, fun)
      else
        raise ArgumentError, """
        streams can only be consumed directly by a for comprehension.
        If you are attempting to consume the stream ahead of time, such as with
        `Enum.with_index(@streams.#{stream.name})`, you need to place the relevant information
        within the stream items instead.
        """
      end
    end

    defp do_reduce(_list, {:halt, acc}, _fun), do: {:halted, acc}
    defp do_reduce(list, {:suspend, acc}, fun), do: {:suspended, acc, &do_reduce(list, &1, fun)}
    defp do_reduce([], {:cont, acc}, _fun), do: {:done, acc}

    defp do_reduce([{dom_id, _at, item, _limit} | tail], {:cont, acc}, fun) do
      do_reduce(tail, fun.({dom_id, item}, acc), fun)
    end

    # Returns a function that slices the data structure contiguously.
    def slice(%LiveStream{}), do: raise(RuntimeError, "not implemented")
  end
end
