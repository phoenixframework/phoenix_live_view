defmodule Phoenix.LiveViewTest.TreeDOM do
  @moduledoc false

  @phx_static "data-phx-static"
  @phx_component "data-phx-component"

  alias Phoenix.LiveViewTest.DOM

  @doc """
  Filters nodes according to `fun`. Walks the tree in a post-walk manner, visiting children before parents.
  """
  def filter(node, fun) do
    node |> reverse_filter(fun) |> Enum.reverse()
  end

  @doc """
  Filters nodes and returns them in reverse order.
  """
  def reverse_filter(tree, fun) do
    reduce(tree, [], fn x, acc ->
      if fun.(x), do: [x | acc], else: acc
    end)
  end

  @doc """
  Returns the tag name of the node.
  """
  def tag({name, _attrs, _children}), do: name
  def tag(_), do: nil

  @doc """
  Returns the value of the attribute `key` from the node or nil if not found.
  """
  def attribute(node, key) do
    with {tag, attrs, _children} when is_binary(tag) <- node,
         {_, value} <- List.keyfind(attrs, key, 0) do
      value
    else
      _ -> nil
    end
  end

  @doc """
  Returns the HTML representation of the node.
  """
  def to_html(text) when is_binary(text), do: text

  def to_html(html) do
    LazyHTML.Tree.to_html(List.wrap(html), skip_whitespace_nodes: true)
  end

  @doc """
  Returns the text representation of the node, removing extra whitespace.
  """
  def to_text(tree, trim \\ true) do
    text =
      tree
      |> node_to_text()
      |> Enum.join()

    if trim do
      text
      |> String.replace(~r/[\s]+/, " ")
      |> String.trim()
    else
      text
    end
  end

  defp node_to_text({_tag, _attrs, content}), do: node_to_text(content)
  defp node_to_text(list) when is_list(list), do: Enum.flat_map(list, &node_to_text/1)
  defp node_to_text(text) when is_binary(text), do: [text]
  defp node_to_text(_), do: []

  @doc """
  Returns the node with the given `id`, raises an error if not found.
  """
  def by_id!(tree, id) do
    case tree
         |> reverse_filter(fn
           {_, attributes, _} -> List.keyfind(attributes, "id", 0) == {"id", id}
           _ -> false
         end) do
      [node] ->
        node

      [] ->
        raise "expected to find one node with id #{id}, but got none within: \n\n#{inspect_html(tree)}"

      many ->
        raise "expected exactly one node with id #{id}, but got #{length(many)}: \n\n#{inspect_html(many)}"
    end
  end

  @doc """
  Returns the child nodes of the node.
  """
  def child_nodes(tree) do
    case tree do
      {_, _, children} -> children
      [{_, _, children}] -> children
      _ -> []
    end
  end

  @doc """
  Returns all attributes of the node.
  """
  def attrs(tree) do
    case tree do
      {_, attrs, _} -> attrs
      [{_, attrs, _}] -> attrs
    end
  end

  @doc """
  Returns the children of the node with the given `id`, raises an error if not found.
  """
  def inner_html!(tree, id), do: tree |> by_id!(id) |> child_nodes()

  @doc """
  Returns all values of the attribute `name` from the node.
  """
  def all_attributes(tree, name) do
    for {_, attributes, _} <- tree |> List.wrap(),
        {_, val} <- [List.keyfind(attributes, name, 0)],
        do: val
  end

  @doc """
  Returns all values of the attributes from the node.

  Handles phx-value-* attributes.
  """
  def all_values(tree) do
    attributes =
      case tree do
        {_, attributes, _} -> attributes
        [{_, attributes, _} | _] -> attributes
        _ -> []
      end

    for {attr, value} <- attributes, key = value_key(attr), do: {key, value}, into: %{}
  end

  defp value_key("phx-value-" <> key), do: key
  defp value_key("value"), do: "value"
  defp value_key(_), do: nil

  @doc """
  Reduces the tree with the given function.
  """
  def reduce(tree, acc, fun) when is_function(fun, 2) do
    do_reduce(tree, acc, fn
      text, acc when is_binary(text) -> acc
      {:comment, _children}, acc -> acc
      {_tag, _attrs, _children} = node, acc -> fun.(node, acc)
    end)
  end

  defp do_reduce([], acc, _fun), do: acc

  defp do_reduce([node | rest], acc, fun) do
    acc = do_reduce(node, acc, fun)
    do_reduce(rest, acc, fun)
  end

  defp do_reduce({tag, attrs, children}, acc, fun) do
    acc = fun.({tag, attrs, children}, acc)
    do_reduce(children, acc, fun)
  end

  defp do_reduce(node, acc, fun) do
    fun.(node, acc)
  end

  @doc """
  Walks the tree and updates nodes based on the given function.
  """
  def walk(tree, fun) when is_function(fun, 1) do
    LazyHTML.Tree.postwalk(tree, fn
      text when is_binary(text) -> text
      {:comment, _children} = comment -> comment
      {_tag, _attrs, _children} = node -> fun.(node)
    end)
  end

  defp by_id(tree, id) do
    case filter(tree, fn node -> attribute(node, "id") == id end) do
      [node] -> node
      _ -> nil
    end
  end

  @doc """
  Sets the attribute `name` to the value `val` on the node.
  """
  def set_attr({tag, attrs, children} = _el, name, val) do
    new_attrs =
      attrs
      |> Enum.filter(fn {existing_name, _} -> existing_name != name end)
      |> Kernel.++([{name, val}])

    {tag, new_attrs, children}
  end

  @doc """
  Returns an HTML representation of the nodes for showing in error messages.
  """
  def inspect_html(nodes) when is_list(nodes) do
    for dom_node <- nodes, into: "", do: inspect_html(dom_node)
  end

  def inspect_html(dom_node),
    do: "    " <> String.replace(to_html(dom_node), "\n", "\n   ") <> "\n"

  ### Functions specific for LiveView

  @doc """
  Find live views in the given HTML tree.
  """
  def find_live_views(tree) do
    tree
    |> filter(fn node -> attribute(node, "data-phx-session") end)
    |> Enum.map(fn {_, attributes, _} -> attributes end)
    |> parse_live_views_attributes()
  end

  defp parse_live_views_attributes(attributes) do
    attributes
    |> Enum.reduce([], fn node, acc ->
      id = keyfind(node, "id")
      static = keyfind(node, @phx_static)
      session = keyfind(node, "data-phx-session")
      main = List.keymember?(node, "data-phx-main", 0)

      static = if static in [nil, ""], do: nil, else: static
      found = {id, session, static}

      if main do
        acc ++ [found]
      else
        [found | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp keyfind(list, key) do
    case List.keyfind(list, key, 0) do
      {_, val} -> val
      nil -> nil
    end
  end

  @doc """
  Removes stream children from the given HTML tree.
  """
  def remove_stream_children(html_tree) do
    walk(html_tree, fn {tag, attrs, children} = node ->
      if attribute(node, "phx-update") == "stream" do
        {tag, attrs, []}
      else
        {tag, attrs, children}
      end
    end)
  end

  def patch_id(id, html, inner_html, streams, error_reporter \\ nil) do
    cids_before = component_ids(id, html)

    phx_update_tree =
      walk(inner_html, fn node ->
        apply_phx_update(attribute(node, "phx-update"), html, node, streams)
      end)

    new_html =
      walk(html, fn {tag, attrs, children} = node ->
        if attribute(node, "id") == id do
          {tag, attrs, phx_update_tree}
        else
          {tag, attrs, children}
        end
      end)

    cids_after = component_ids(id, new_html)

    if is_function(error_reporter, 1) do
      detect_duplicate_ids(new_html, error_reporter)
      detect_duplicate_components(new_html, cids_after, error_reporter)
    end

    {new_html, cids_before -- cids_after}
  end

  def detect_duplicate_ids(tree, error_reporter),
    do: detect_duplicate_ids(tree, tree, MapSet.new(), error_reporter)

  defp detect_duplicate_ids(tree, [node | rest], ids, error_reporter) do
    ids = detect_duplicate_ids(tree, node, ids, error_reporter)
    detect_duplicate_ids(tree, rest, ids, error_reporter)
  end

  defp detect_duplicate_ids(tree, {_tag_name, _attrs, children} = node, ids, error_reporter) do
    case attribute(node, "id") do
      id when not is_nil(id) ->
        if MapSet.member?(ids, id) do
          error_reporter.("""
          Duplicate id found while testing LiveView: #{id}

          #{inspect_html(filter(tree, fn node -> attribute(node, "id") == id end))}

          LiveView requires that all elements have unique ids, duplicate IDs will cause
          undefined behavior at runtime, as DOM patching will not be able to target the correct
          elements.
          """)
        end

        detect_duplicate_ids(tree, children, MapSet.put(ids, id), error_reporter)

      _ ->
        detect_duplicate_ids(tree, children, ids, error_reporter)
    end
  end

  defp detect_duplicate_ids(_tree, _non_tag, seen_ids, _error_reporter), do: seen_ids

  def detect_duplicate_components(tree, cids, error_reporter) do
    cids
    |> Enum.frequencies()
    |> Enum.each(fn {cid, count} ->
      if count > 1 do
        error_reporter.("""
        Duplicate live component found while testing LiveView:

        #{inspect_html(filter(tree, fn node -> attribute(node, @phx_component) == to_string(cid) end))}

        This most likely means that you are conditionally rendering the same
        LiveComponent multiple times with the same ID in the same LiveView.
        This is not supported and will lead to broken behavior on the client.
        """)
      end
    end)
  end

  def component_ids(id, html_tree) do
    by_id!(html_tree, id)
    |> child_nodes()
    |> Enum.reduce([], &traverse_component_ids/2)
  end

  defp traverse_component_ids(current, acc) do
    acc =
      if id = attribute(current, @phx_component) do
        [String.to_integer(id) | acc]
      else
        acc
      end

    cond do
      attribute(current, @phx_static) ->
        acc

      children = child_nodes(current) ->
        Enum.reduce(children, acc, &traverse_component_ids/2)

      true ->
        acc
    end
  end

  def replace_root_container(container_html, new_tag, attrs) do
    reserved_attrs = ~w(id data-phx-session data-phx-static data-phx-main)
    [{_container_tag, container_attrs_list, children} | _] = container_html
    container_attrs = Enum.into(container_attrs_list, %{})

    merged_attrs =
      for {attr, value} <- attrs,
          attr = String.downcase(to_string(attr)),
          attr not in reserved_attrs,
          reduce: container_attrs_list do
        acc ->
          if Map.has_key?(container_attrs, attr) do
            Enum.map(acc, fn
              {^attr, _old_val} -> {attr, value}
              {_, _} = other -> other
            end)
          else
            acc ++ [{attr, value}]
          end
      end

    [{to_string(new_tag), merged_attrs, children}]
  end

  defp apply_phx_update(type, _html_tree, _node, _streams) when type in ["append", "prepend"] do
    raise ArgumentError,
          "phx-update=#{inspect(type)} has been deprecated before v1.0 and is no longer supported in tests"
  end

  defp apply_phx_update("stream", html_tree, {tag, attrs, appended_children} = node, streams) do
    container_id = attribute(node, "id")
    verify_phx_update_id!("stream", container_id, node)
    children_before = apply_phx_update_children(html_tree, container_id)

    appended_children =
      Enum.filter(appended_children, fn node ->
        not is_binary(node) or (is_binary(node) and String.trim_leading(node) != "")
      end)

    # to ensure correct DOM patching, all elements must have an ID
    _ = apply_phx_update_children_id("stream", children_before)
    _ = apply_phx_update_children_id("stream", appended_children)

    streams =
      Enum.map(streams, fn [ref, inserts, deleteIds | maybe_reset] ->
        %{ref: ref, inserts: inserts, deleteIds: deleteIds, reset: maybe_reset == [true]}
      end)

    streamInserts =
      Enum.reduce(streams, %{}, fn %{ref: ref, inserts: inserts}, acc ->
        Enum.reduce(inserts, acc, fn [id, stream_at, limit, update_only], acc ->
          Map.put(acc, id, %{
            ref: ref,
            stream_at: stream_at,
            limit: limit,
            update_only: update_only
          })
        end)
      end)

    # for each stream, reset if necessary and apply deletes
    # (this corresponds to the this.streams.forEach loop in dom_patch.js)
    filtered_children_before =
      Enum.reduce(streams, children_before, fn stream, acc -> apply_stream(acc, stream) end)

    # now apply the DOM patching (this corresponds mainly to the appendChild in dom_patch.js)
    new_children =
      Enum.reduce(appended_children, filtered_children_before, fn node, acc ->
        id = attribute(node, "id")
        insert = streamInserts[id]
        current_index = Enum.find_index(acc, fn node -> attribute(node, "id") == id end)

        new_children =
          cond do
            is_nil(insert) and is_nil(current_index) ->
              # the element is not part of the stream inserts, so we append it at the end
              # (see dom_patch.js addChild)
              acc ++ [node]

            is_nil(insert) && current_index ->
              # not a stream item, but already in the DOM -> update in place
              List.replace_at(acc, current_index, node)

            current_index ->
              # update stream item in place
              List.replace_at(acc, current_index, set_attr(node, "data-phx-stream", insert.ref))

            insert[:update_only] ->
              # skip item if it is not already in the DOM
              acc

            true ->
              # stream item to be inserted at specific position
              List.insert_at(acc, insert.stream_at, set_attr(node, "data-phx-stream", insert.ref))
          end

        maybe_apply_stream_limit(new_children, insert)
      end)

    {tag, attrs, new_children}
  end

  defp apply_phx_update("ignore", html_tree, node, _streams) do
    container_id = attribute(node, "id")
    verify_phx_update_id!("ignore", container_id, node)

    {new_tag, new_attrs, new_children} = node

    {tag, attrs_before, children_before} =
      case by_id(html_tree, container_id) do
        {_tag, _attrs_before, _children_before} = triplet -> triplet
        nil -> {new_tag, new_attrs, new_children}
      end

    merged_attrs =
      Enum.reject(attrs_before, fn {name, _} -> String.starts_with?(name, "data-") end) ++
        Enum.filter(new_attrs, fn {name, _} -> String.starts_with?(name, "data-") end)

    {tag, merged_attrs, children_before}
  end

  defp apply_phx_update(type, _state, node, _streams) when type in [nil, "replace"] do
    node
  end

  defp apply_phx_update(other, _state, _node, _streams) do
    raise ArgumentError,
          "invalid phx-update value #{inspect(other)}, " <>
            "expected one of \"stream\", \"replace\", \"append\", \"prepend\", \"ignore\""
  end

  defp apply_stream(existing_children, stream) do
    children =
      if stream.reset do
        Enum.reject(existing_children, fn node ->
          attribute(node, "data-phx-stream") == stream.ref
        end)
      else
        existing_children
      end

    Enum.filter(children, fn node ->
      attribute(node, "id") not in stream.deleteIds
    end)
  end

  defp maybe_apply_stream_limit(children, %{limit: limit}) when is_integer(limit) do
    Enum.take(children, limit)
  end

  defp maybe_apply_stream_limit(children, _maybe_insert), do: children

  defp verify_phx_update_id!(type, id, node) when id in ["", nil] do
    raise ArgumentError,
          "setting phx-update to #{inspect(type)} requires setting an ID on the container, " <>
            "got: \n\n #{to_html(node)}"
  end

  defp verify_phx_update_id!(_type, _id, _node) do
    :ok
  end

  defp apply_phx_update_children(html_tree, id) do
    case by_id(html_tree, id) do
      {_, _, children_before} -> children_before
      nil -> []
    end
  end

  defp apply_phx_update_children_id(type, children) do
    for {tag, _, _} = child when is_binary(tag) <- children do
      attribute(child, "id") ||
        raise ArgumentError,
              "setting phx-update to #{inspect(type)} requires setting an ID on each child. " <>
                "No ID was found on:\n\n#{to_html(child)}"
    end
  end

  ## Test Helpers

  @doc """
  Normalizes the given HTML to a tree with optional sorting of attributes.
  """
  def normalize_to_tree(html, opts \\ []) do
    sort_attributes? = Keyword.get(opts, :sort_attributes, false)
    trim_whitespace? = Keyword.get(opts, :trim_whitespace, true)
    full_document? = Keyword.get(opts, :full_document, false)

    html =
      case html do
        binary when is_binary(binary) ->
          (full_document? && DOM.parse_document(binary)) || DOM.parse_fragment(binary)

        h ->
          h
      end

    tree =
      case html do
        {%{} = struct, tree} when is_struct(struct, LazyHTML) -> tree
        html when is_struct(html, LazyHTML) -> DOM.to_tree(html)
        _ -> html
      end

    normalize_tree(tree, sort_attributes?, trim_whitespace?)
  end

  defp normalize_tree({node_type, attributes, content}, sort_attributes?, trim_whitespace?) do
    {node_type, (sort_attributes? && Enum.sort(attributes)) || attributes,
     normalize_tree(content, sort_attributes?, trim_whitespace?)}
  end

  defp normalize_tree(values, sort_attributes?, true) when is_list(values) do
    for value <- values,
        not is_binary(value) or (is_binary(value) and String.trim(value) != ""),
        do: normalize_tree(value, sort_attributes?, true)
  end

  defp normalize_tree(values, sort_attributes?, false) when is_list(values) do
    Enum.map(values, &normalize_tree(&1, sort_attributes?, false))
  end

  defp normalize_tree(binary, _sort_attributes?, true) when is_binary(binary) do
    if String.trim(binary) != "" do
      binary
    else
      nil
    end
  end

  defp normalize_tree(value, _sort_attributes?, _trim_whitespace?), do: value

  defmacro sigil_X({:<<>>, _, [binary]}, []) when is_binary(binary) do
    Macro.escape(normalize_to_tree(binary, sort_attributes: true))
  end

  defmacro sigil_x(term, []) do
    quote do
      unquote(__MODULE__).normalize_to_tree(unquote(term), sort_attributes: true)
    end
  end

  def t2h(template) do
    template
    |> Phoenix.LiveViewTest.rendered_to_string()
    |> normalize_to_tree(sort_attributes: true)
  end
end
