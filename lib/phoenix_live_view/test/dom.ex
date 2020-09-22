defmodule Phoenix.LiveViewTest.DOM do
  @moduledoc false

  @phx_static "data-phx-static"
  @phx_component "data-phx-component"
  @static :s
  @components :c

  def ensure_loaded! do
    unless Code.ensure_loaded?(Floki) do
      raise """
      Phoenix LiveView requires Floki as a test dependency.
      Please add to your mix.exs:

      {:floki, ">= 0.27.0", only: :test}
      """
    end
  end

  def parse(html) do
    {:ok, parsed} = Floki.parse_document(html)
    parsed
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

  def to_text(html_tree), do: Floki.text(html_tree)

  def by_id!(html_tree, id) do
    case maybe_one(html_tree, "#" <> id) do
      {:ok, node} -> node
      {:error, _, message} -> raise message
    end
  end

  def child_nodes({_, _, nodes}), do: nodes

  def attrs({_, attrs, _}), do: attrs

  def inner_html!(html, id), do: html |> by_id!(id) |> child_nodes()

  def component_id(html_tree), do: Floki.attribute(html_tree, @phx_component) |> List.first()

  def find_static_views(html) do
    html
    |> all("[#{@phx_static}]")
    |> Enum.into(%{}, fn node ->
      {attribute(node, "id"), attribute(node, @phx_static)}
    end)
  end

  def find_live_views(html) do
    html
    |> all("[data-phx-session]")
    |> Enum.reduce([], fn node, acc ->
      id = attribute(node, "id")
      static = attribute(node, "data-phx-static")
      session = attribute(node, "data-phx-session")
      main = attribute(node, "data-phx-main")

      static = if static in [nil, ""], do: nil, else: static
      found = {id, session, static}

      if main == "true" do
        acc ++ [found]
      else
        [found | acc]
      end
    end)
    |> Enum.reverse()
  end

  def deep_merge(target, source) do
    Map.merge(target, source, fn
      _, %{} = target, %{} = source -> deep_merge(target, source)
      _, _target, source -> source
    end)
  end

  def filter(node, fun) do
    node |> reverse_filter(fun) |> Enum.reverse()
  end

  def reverse_filter(node, fun) do
    node
    |> Floki.traverse_and_update([], fn node, acc ->
      if fun.(node), do: {node, [node | acc]}, else: {node, acc}
    end)
    |> elem(1)
  end

  # Diff merging

  def merge_diff(rendered, diff) do
    {new, diff} = Map.pop(diff, @components)
    rendered = deep_merge(rendered, diff)

    # If we have any component, we need to get the components
    # sent by the diff and remove any link between components
    # statics. We cannot let those links reside in the diff
    # as components can be removed at any time.
    if new do
      old = Map.get(rendered, @components, %{})

      acc =
        Enum.reduce(new, old, fn {cid, cdiff}, acc ->
          value =
            case cdiff do
              %{@static => pointer} when is_integer(pointer) ->
                deep_merge(find_component(cdiff, old, new), Map.delete(cdiff, @static))

              %{} ->
                deep_merge(Map.get(old, cid, %{}), cdiff)
            end

          Map.put(acc, cid, value)
        end)

      Map.put(rendered, @components, acc)
    else
      rendered
    end
  end

  defp find_component(%{@static => cid}, old, new) when is_integer(cid) and cid > 0,
    do: find_component(new[cid], old, new)

  defp find_component(%{@static => cid}, old, new) when is_integer(cid) and cid < 0,
    do: find_component(old[-cid], old, new)

  defp find_component(%{} = component, _old, _new),
    do: component

  def drop_cids(rendered, cids) do
    update_in(rendered[@components], &Map.drop(&1, cids))
  end

  # Diff rendering

  def render_diff(rendered) do
    rendered
    |> Phoenix.LiveView.Diff.to_iodata(fn cid, contents ->
      contents
      |> IO.iodata_to_binary()
      |> parse()
      |> List.wrap()
      |> Enum.map(walk_fun(&inject_cid_attr(&1, cid)))
      |> to_html()
    end)
    |> IO.iodata_to_binary()
    |> parse()
    |> List.wrap()
  end

  defp inject_cid_attr({tag, attrs, children}, cid) do
    {tag, [{@phx_component, to_string(cid)}] ++ attrs, children}
  end

  # Patching

  def patch_id(id, html, inner_html) do
    cids_before = component_ids(id, html)

    phx_update_tree =
      walk(inner_html, fn node ->
        apply_phx_update(attribute(node, "phx-update"), html, node)
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
    deleted_cids = for cid <- cids_before -- cids_after, do: String.to_integer(cid)
    {new_html, deleted_cids}
  end

  defp component_ids(id, html) do
    by_id!(html, id)
    |> Floki.children()
    |> Enum.reduce([], &traverse_component_ids/2)
  end

  defp traverse_component_ids(current, acc) do
    acc =
      if id = attribute(current, @phx_component) do
        [id | acc]
      else
        acc
      end

    cond do
      attribute(current, @phx_static) ->
        acc

      children = Floki.children(current) ->
        Enum.reduce(children, [], &traverse_component_ids/2)

      true ->
        acc
    end
  end

  defp apply_phx_update(type, html, {tag, attrs, appended_children} = node)
       when type in ["append", "prepend"] do
    id = attribute(node, "id")
    verify_phx_update_id!(type, id, node)
    children_before = apply_phx_update_children(html, id)
    existing_ids = apply_phx_update_children_id(type, children_before)
    new_ids = apply_phx_update_children_id(type, appended_children)
    content_changed? = new_ids != existing_ids

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

  defp apply_phx_update("ignore", _state, node) do
    verify_phx_update_id!("ignore", attribute(node, "id"), node)
    node
  end

  defp apply_phx_update(type, _state, node) when type in [nil, "replace"] do
    node
  end

  defp apply_phx_update(other, _state, _node) do
    raise ArgumentError,
          "invalid phx-update value #{inspect(other)}, " <>
            "expected one of \"replace\", \"append\", \"prepend\", \"ignore\""
  end

  defp verify_phx_update_id!(type, id, node) when id in ["", nil] do
    raise ArgumentError,
          "setting phx-update to #{inspect(type)} requires setting an ID on the container, " <>
            "got: \n\n #{inspect_html(node)}"
  end

  defp verify_phx_update_id!(_type, _id, _node) do
    :ok
  end

  defp apply_phx_update_children(html, id) do
    case by_id(html, id) do
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
    html_tree |> Floki.find("##{id}") |> List.first()
  end
end
