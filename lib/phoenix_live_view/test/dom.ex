defmodule Phoenix.LiveViewTest.DOM do
  @moduledoc false

  @phx_static "data-phx-static"
  @phx_component "data-phx-component"
  @static :s
  @components :c
  @stream_id :stream

  def ensure_loaded! do
    if not Code.ensure_loaded?(Floki) do
      raise """
      Phoenix LiveView requires Floki as a test dependency.
      Please add to your mix.exs:

      {:floki, ">= 0.30.0", only: :test}
      """
    end
  end

  @spec parse(binary) :: [
          {:comment, binary}
          | {:pi | binary, binary | list, list}
          | {:doctype, binary, binary, binary}
        ]
  def parse(html, error_reporter \\ nil) do
    {:ok, parsed} = Floki.parse_document(html)

    if is_function(error_reporter, 1) do
      detect_duplicate_ids(parsed, error_reporter)
    end

    parsed
  end

  defp detect_duplicate_ids(tree, error_reporter),
    do: detect_duplicate_ids(tree, tree, MapSet.new(), error_reporter)

  defp detect_duplicate_ids(tree, [node | rest], ids, error_reporter) do
    ids = detect_duplicate_ids(tree, node, ids, error_reporter)
    detect_duplicate_ids(tree, rest, ids, error_reporter)
  end

  # ignore declarations
  defp detect_duplicate_ids(_tree, {:pi, _type, _attrs}, seen_ids, _error_reporter), do: seen_ids

  defp detect_duplicate_ids(tree, {_tag_name, _attrs, children} = node, ids, error_reporter) do
    case Floki.attribute(node, "id") do
      [id] ->
        if MapSet.member?(ids, id) do
          error_reporter.("""
          Duplicate id found while testing LiveView: #{id}

          #{inspect_html(all(tree, "[id=#{id}]"))}

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

  defp detect_duplicate_components(tree, cids, error_reporter) do
    cids
    |> Enum.frequencies()
    |> Enum.each(fn {cid, count} ->
      if count > 1 do
        error_reporter.("""
        Duplicate live component found while testing LiveView:

        #{inspect_html(all(tree, "[#{@phx_component}=#{cid}]"))}

        This most likely means that you are conditionally rendering the same
        LiveComponent multiple times with the same ID in the same LiveView.
        This is not supported and will lead to broken behavior on the client.
        """)
      end
    end)
  end

  def all(html_tree, selector), do: Floki.find(html_tree, selector)

  def maybe_one(html_tree, selector, type \\ :selector) do
    case all(html_tree, selector) do
      [node] ->
        {:ok, node}

      [] ->
        {:error, :none,
         "expected #{type} #{inspect(selector)} to return a single element, but got none " <>
           "within: \n\n" <> inspect_html(html_tree)}

      many ->
        {:error, :many,
         "expected #{type} #{inspect(selector)} to return a single element, " <>
           "but got #{length(many)}: \n\n" <> inspect_html(many)}
    end
  end

  def targets_from_node(tree, node) do
    case node && all_attributes(node, "phx-target") do
      nil -> [nil]
      [] -> [nil]
      [selector] -> targets_from_selector(tree, selector)
    end
  end

  def targets_from_selector(tree, selector)

  def targets_from_selector(_tree, nil), do: [nil]

  def targets_from_selector(_tree, cid) when is_integer(cid), do: [cid]

  def targets_from_selector(tree, selector) when is_binary(selector) do
    case Integer.parse(selector) do
      {cid, ""} ->
        [cid]

      _ ->
        case all(tree, selector) do
          [] ->
            [nil]

          elements ->
            for element <- elements do
              if cid = component_id(element) do
                String.to_integer(cid)
              end
            end
        end
    end
  end

  def all_attributes(html_tree, name), do: Floki.attribute(html_tree, name)

  def all_values({_, attributes, _}) do
    for {attr, value} <- attributes, key = value_key(attr), do: {key, value}, into: %{}
  end

  def inspect_html(nodes) when is_list(nodes) do
    for dom_node <- nodes, into: "", do: inspect_html(dom_node)
  end

  def inspect_html(dom_node),
    do: "    " <> String.replace(to_html(dom_node), "\n", "\n   ") <> "\n"

  defp value_key("phx-value-" <> key), do: key
  defp value_key("value"), do: "value"
  defp value_key(_), do: nil

  def tag(node), do: elem(node, 0)

  def attribute(node, key) do
    with {tag, attrs, _children} when is_binary(tag) <- node,
         {_, value} <- List.keyfind(attrs, key, 0) do
      value
    else
      _ -> nil
    end
  end

  def to_html(html_tree), do: Floki.raw_html(html_tree)

  def to_text(html_tree) do
    html_tree
    |> Floki.text()
    |> String.replace(~r/[\s]+/, " ")
    |> String.trim()
  end

  # TODO: rewrite to use Floki.get_by_id/2
  # currently it does not raise when multiple elements are found
  def by_id!(html_tree, id) do
    case maybe_one(html_tree, "#" <> id) do
      {:ok, node} -> node
      {:error, _, message} -> raise message
    end
  end

  def child_nodes({_, _, nodes}), do: nodes

  def attrs({_, attrs, _}), do: attrs

  def inner_html!(html_tree, id), do: html_tree |> by_id!(id) |> child_nodes()

  def component_id(html_tree), do: Floki.attribute(html_tree, @phx_component) |> List.first()

  @doc """
  Find static information in the given HTML tree.
  """
  def find_static_views(html_tree) do
    html_tree
    |> all("[#{@phx_static}]")
    |> Enum.into(%{}, fn node ->
      {attribute(node, "id"), attribute(node, @phx_static)}
    end)
  end

  @doc """
  Find live views in the given HTML tree.
  """
  def find_live_views(html_tree) do
    html_tree
    |> all("[data-phx-session]")
    |> Enum.reduce([], fn node, acc ->
      id = attribute(node, "id")
      static = attribute(node, "data-phx-static")
      session = attribute(node, "data-phx-session")
      main = attribute(node, "data-phx-main")

      static = if static in [nil, ""], do: nil, else: static
      found = {id, session, static}

      if main not in [nil, "", "false"] do
        acc ++ [found]
      else
        [found | acc]
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Deep merges two maps.
  """
  def deep_merge(%{} = target, %{} = source),
    do: Map.merge(target, source, fn _, t, s -> deep_merge(t, s) end)

  def deep_merge(_target, source),
    do: source

  @doc """
  Filters nodes according to `fun`.
  """
  def filter(node, fun) do
    node |> reverse_filter(fun) |> Enum.reverse()
  end

  @doc """
  Filters nodes and returns them in reverse order.
  """
  def reverse_filter(node, fun) do
    node
    |> Floki.traverse_and_update([], fn node, acc ->
      if fun.(node), do: {node, [node | acc]}, else: {node, acc}
    end)
    |> elem(1)
  end

  # Diff merging

  def merge_diff(rendered, diff) do
    old = Map.get(rendered, @components, %{})
    # must extract streams from diff before we pop components
    streams = extract_streams(diff, [])
    {new, diff} = Map.pop(diff, @components)
    rendered = deep_merge_diff(rendered, diff)

    # If we have any component, we need to get the components
    # sent by the diff and remove any link between components
    # statics. We cannot let those links reside in the diff
    # as components can be removed at any time.
    rendered =
      cond do
        new ->
          {acc, _} =
            Enum.reduce(new, {old, %{}}, fn {cid, cdiff}, {acc, cache} ->
              {value, cache} = find_component(cid, cdiff, old, new, cache)
              {Map.put(acc, cid, value), cache}
            end)

          Map.put(rendered, @components, acc)

        old != %{} ->
          Map.put(rendered, @components, old)

        true ->
          rendered
      end

    Map.put(rendered, :streams, streams)
  end

  defp find_component(cid, cdiff, old, new, cache) do
    case cache do
      %{^cid => cached} ->
        {cached, cache}

      %{} ->
        {res, cache} =
          case cdiff do
            %{@static => cid} when is_integer(cid) and cid > 0 ->
              {res, cache} = find_component(cid, new[cid], old, new, cache)
              {deep_merge_diff(res, Map.delete(cdiff, @static)), cache}

            %{@static => cid} when is_integer(cid) and cid < 0 ->
              {deep_merge_diff(old[-cid], Map.delete(cdiff, @static)), cache}

            %{} ->
              {deep_merge_diff(Map.get(old, cid, %{}), cdiff), cache}
          end

        {res, Map.put(cache, cid, res)}
    end
  end

  def drop_cids(rendered, cids) do
    update_in(rendered[@components], &Map.drop(&1, cids))
  end

  defp deep_merge_diff(_target, %{@static => _} = source),
    do: source

  defp deep_merge_diff(%{} = target, %{} = source),
    do: Map.merge(target, source, fn _, t, s -> deep_merge_diff(t, s) end)

  defp deep_merge_diff(_target, source),
    do: source

  def extract_streams(%{} = source, streams) when not is_struct(source) do
    Enum.reduce(source, streams, fn
      {@stream_id, stream}, acc -> [stream | acc]
      {_key, value}, acc -> extract_streams(value, acc)
    end)
  end

  # streams can also be in the dynamic part of the diff
  def extract_streams(source, streams) when is_list(source) do
    Enum.reduce(source, streams, fn el, acc -> extract_streams(el, acc) end)
  end

  def extract_streams(_value, acc), do: acc

  # Diff rendering

  def render_diff(rendered) do
    rendered
    |> Phoenix.LiveView.Diff.to_iodata(&add_cid_attr/2)
    |> IO.iodata_to_binary()
    |> parse()
    |> List.wrap()
  end

  defp add_cid_attr(cid, [head | tail]) do
    head_with_cid =
      Regex.replace(
        ~r/^(\s*(?:<!--.*?-->\s*)*)<([^\s\/>]+)/,
        IO.iodata_to_binary(head),
        "\\0 #{@phx_component}=\"#{to_string(cid)}\"",
        global: false
      )

    [head_with_cid | tail]
  end

  # Patching

  def patch_id(id, html_tree, inner_html, streams, error_reporter \\ nil) do
    cids_before = component_ids(id, html_tree)

    phx_update_tree =
      walk(inner_html, fn node ->
        apply_phx_update(attribute(node, "phx-update"), html_tree, node, streams)
      end)

    new_html =
      walk(html_tree, fn {tag, attrs, children} = node ->
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

  def component_ids(id, html_tree) do
    by_id!(html_tree, id)
    |> Floki.children()
    |> Enum.reduce([], &traverse_component_ids/2)
  end

  def replace_root_container(container_html, new_tag, attrs) do
    reserved_attrs = ~w(id data-phx-session data-phx-static data-phx-main)
    [{_container_tag, container_attrs_list, children}] = container_html
    container_attrs = Enum.into(container_attrs_list, %{})

    merged_attrs =
      attrs
      |> Enum.map(fn {attr, value} -> {String.downcase(to_string(attr)), value} end)
      |> Enum.filter(fn {attr, _value} -> attr not in reserved_attrs end)
      |> Enum.reduce(container_attrs_list, fn {attr, new_val}, acc ->
        if Map.has_key?(container_attrs, attr) do
          Enum.map(acc, fn
            {^attr, _old_val} -> {attr, new_val}
            {_, _} = other -> other
          end)
        else
          acc ++ [{attr, new_val}]
        end
      end)

    [{to_string(new_tag), merged_attrs, children}]
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

      children = Floki.children(current) ->
        Enum.reduce(children, acc, &traverse_component_ids/2)

      true ->
        acc
    end
  end

  defp apply_phx_update(type, html_tree, {tag, attrs, appended_children} = node, _streams)
       when type in ["append", "prepend"] do
    container_id = attribute(node, "id")
    verify_phx_update_id!(type, container_id, node)
    children_before = apply_phx_update_children(html_tree, container_id)
    existing_ids = apply_phx_update_children_id(type, children_before)
    new_ids = apply_phx_update_children_id(type, appended_children)

    content_changed? =
      new_ids != existing_ids

    dup_ids =
      if content_changed? && new_ids do
        Enum.filter(new_ids, fn id -> id in existing_ids end)
      else
        []
      end

    {updated_existing_children, updated_appended} =
      Enum.reduce(dup_ids, {children_before, appended_children}, fn dup_id, {before, appended} ->
        patched_before =
          walk(before, fn {tag, _, _} = node ->
            cond do
              attribute(node, "id") == dup_id ->
                new_node = by_id!(appended, dup_id)
                {tag, attrs(new_node), child_nodes(new_node)}

              true ->
                node
            end
          end)

        {patched_before, Floki.filter_out(appended, "##{dup_id}")}
      end)

    cond do
      content_changed? && type == "append" ->
        {tag, attrs, updated_existing_children ++ updated_appended}

      content_changed? && type == "prepend" ->
        {tag, attrs, updated_appended ++ updated_existing_children}

      !content_changed? ->
        {tag, attrs, updated_appended}
    end
  end

  defp apply_phx_update("stream", html_tree, {tag, attrs, appended_children} = node, streams) do
    container_id = attribute(node, "id")
    verify_phx_update_id!("stream", container_id, node)
    children_before = apply_phx_update_children(html_tree, container_id)
    appended_children = appended_children
    # to ensure correct DOM patching, all elements must have an ID
    _ = apply_phx_update_children_id("stream", children_before)
    _ = apply_phx_update_children_id("stream", appended_children)

    streams =
      Enum.map(streams, fn [ref, inserts, deleteIds | maybe_reset] ->
        %{ref: ref, inserts: inserts, deleteIds: deleteIds, reset: maybe_reset == [true]}
      end)

    streamInserts =
      Enum.reduce(streams, %{}, fn %{ref: ref, inserts: inserts}, acc ->
        # TODO: support update_only in LiveViewTest
        Enum.reduce(inserts, acc, fn [id, stream_at, limit, _update_only], acc ->
          Map.put(acc, id, %{ref: ref, stream_at: stream_at, limit: limit})
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
            "got: \n\n #{inspect_html(node)}"
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

  ## Helpers

  defp walk(html_tree, fun) when is_function(fun, 1) do
    Floki.traverse_and_update(html_tree, walk_fun(fun))
  end

  defp walk_fun(fun) when is_function(fun, 1) do
    fn
      text when is_binary(text) -> text
      {:pi, _, _} = xml -> xml
      {:comment, _children} = comment -> comment
      {:doctype, _, _, _} = doctype -> doctype
      {_tag, _attrs, _children} = node -> fun.(node)
    end
  end

  defp by_id(html_tree, id) do
    Floki.get_by_id(html_tree, id)
  end

  def parent_id(html_tree, child_id) do
    try do
      walk(html_tree, fn {tag, attrs, children} = node ->
        parent_id = attribute(node, "id")

        if parent_id && Enum.find(children, fn child -> attribute(child, "id") == child_id end) do
          throw(parent_id)
        else
          {tag, attrs, children}
        end
      end)

      nil
    catch
      :throw, parent_id -> parent_id
    end
  end

  def set_attr({tag, attrs, children} = _el, name, val) do
    new_attrs =
      attrs
      |> Enum.filter(fn {existing_name, _} -> existing_name != name end)
      |> Kernel.++([{name, val}])

    {tag, new_attrs, children}
  end

  defmacro sigil_X({:<<>>, _, [binary]}, []) when is_binary(binary) do
    Macro.escape(parse_sorted!(binary))
  end

  defmacro sigil_x(term, []) do
    quote do
      unquote(__MODULE__).parse_sorted!(unquote(term))
    end
  end

  def t2h(template) do
    template
    |> Phoenix.LiveViewTest.rendered_to_string()
    |> parse_sorted!()
  end

  @doc """
  Parses HTML into Floki format with sorted attributes.
  """
  def parse_sorted!(value) do
    value
    |> Floki.parse_fragment!()
    |> Enum.map(&normalize_attribute_order/1)
  end

  defp normalize_attribute_order({node_type, attributes, content}),
    do: {node_type, Enum.sort(attributes), Enum.map(content, &normalize_attribute_order/1)}

  defp normalize_attribute_order(values) when is_list(values),
    do: Enum.map(values, &normalize_attribute_order/1)

  defp normalize_attribute_order(value), do: value
end
