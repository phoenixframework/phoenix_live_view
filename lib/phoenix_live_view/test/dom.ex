defmodule Phoenix.LiveViewTest.DOM do
  @moduledoc false

  @phx_component "data-phx-component"

  def render_diff(rendered) do
    rendered
    |> to_output_buffer([])
    |> Enum.reverse()
    |> Enum.join("")
  end

  # for comprehension
  defp to_output_buffer(%{dynamics: for_dynamics, static: statics}, acc) do
    Enum.reduce(for_dynamics, acc, fn dynamics, acc ->
      dynamics
      |> Enum.with_index()
      |> Enum.into(%{static: statics}, fn {val, key} -> {key, val} end)
      |> to_output_buffer(acc)
    end)
  end

  defp to_output_buffer(%{static: statics} = rendered, acc) do
    statics
    |> Enum.with_index()
    |> tl()
    |> Enum.reduce([Enum.at(statics, 0) | acc], fn {static, index}, acc ->
      [static | dynamic_to_buffer(rendered[index - 1], acc)]
    end)
  end

  defp dynamic_to_buffer(%{} = rendered, acc), do: to_output_buffer(rendered, []) ++ acc
  defp dynamic_to_buffer(str, acc) when is_binary(str), do: [str | acc]

  def find_static_views(html) do
    html
    |> all("[data-phx-static]")
    |> Enum.into(%{}, fn node ->
      attrs = attrs(node)
      {attrs["id"], attrs["data-phx-static"]}
    end)
  end

  def find_views(html) do
    html
    |> all("[data-phx-session]")
    |> Enum.map(fn node ->
      attrs = attrs(node)

      static =
        cond do
          attrs["data-phx-static"] in [nil, ""] -> nil
          true -> attrs["data-phx-static"]
        end

      {attrs["id"], attrs["data-phx-session"], static}
    end)
  end

  def deep_merge(target, source) do
    Map.merge(target, source, fn
      _, %{} = target, %{} = source -> deep_merge(target, source)
      _, _target, source -> source
    end)
  end

  def by_id(html_tree, id) do
    case Floki.find(html_tree, "##{id}") do
      [node | _] -> node
      [] -> nil
    end
  end

  def all(html_tree, selector), do: Floki.find(html_tree, selector)

  def parse(html), do: Floki.parse(html)

  def attrs({_tag, attrs, _children}), do: Enum.into(attrs, %{})
  def attrs({_tag, attrs, _children}, key), do: Enum.into(attrs, %{})[key]

  def all_attributes(html_tree, name), do: Floki.attribute(html_tree, name)

  def to_html(html_tree, opts \\ []), do: Floki.raw_html(html_tree, opts)

  def walk(html, func) when is_binary(html) and is_function(func, 1) do
    html
    |> parse()
    |> Floki.traverse_and_update(fn
      {:pi, _, _} = xml -> xml
      {:comment, _children} = comment -> comment
      {:doctype, _, _, _} = doctype -> doctype
      {_tag, _attrs, _children} = node -> func.(node)
    end)
  end

  def walk(html_tree, func) when is_function(func, 1) do
    Floki.traverse_and_update(html_tree, fn node -> func.(node) end)
  end

  def filter_out(html_tree, selector), do: Floki.filter_out(html_tree, selector)

  def patch_id(id, html, inner_html) do
    cids_before = find_component_ids(id, html)

    phx_update_tree =
      walk(inner_html, fn node -> apply_phx_update(attrs(node, "phx-update"), html, node) end)

    new_html =
      html
      |> walk(fn {tag, attrs, children} = node ->
        cond do
          attrs(node, "id") == id -> {tag, attrs, phx_update_tree}
          true -> {tag, attrs, children}
        end
      end)
      |> to_html()

    cids_after = find_component_ids(id, new_html)
    deleted_cids = cids_before -- cids_after

    {new_html, deleted_cids}
  end

  def inner_html(html, id) do
    {_container, _attrs, children} = by_id(html, id)
    to_html(children)
  end

  defp find_component_ids(id, html) do
    html
    |> by_id(id)
    |> all("[#{@phx_component}]")
    |> all_attributes("id")
  end

  defp apply_phx_update(type, html, {tag, attrs, appended_children} = node)
       when type in ["append", "prepend"] do
    children_before = phx_update_children(html, attrs(node, "id"))
    existing_ids = all_attributes(children_before, "id")
    new_ids = all_attributes(appended_children, "id")
    content_changed? = new_ids !== existing_ids

    dup_ids =
      if content_changed? do
        Enum.filter((content_changed? && new_ids) || [], fn id -> id in existing_ids end)
      else
        []
      end

    {updated_existing_children, updated_appended} =
      Enum.reduce(dup_ids, {children_before, appended_children}, fn dup_id, {before, appended} ->
        patched_before =
          walk(before, fn {tag, attrs, _} = node ->
            cond do
              attrs(node, "id") == dup_id -> {tag, attrs, inner_html(appended, dup_id)}
              true -> node
            end
          end)

        {patched_before, filter_out(appended, "##{dup_id}")}
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

  defp apply_phx_update(type, _state, {tag, attrs, children})
       when type in [nil, "replace", "ignore"] do
    {tag, attrs, children}
  end

  defp apply_phx_update(other, _state, {_tag, _attrs, _children}) do
    raise ArgumentError, """
    invalid phx-update value #{inspect(other)}.

    Expected one of "replace", "append", "prepend", "ignore"
    """
  end

  def phx_update_children(html, id) do
    case by_id(html, id) do
      {_, _, children_before} -> children_before
      nil -> raise ArgumentError, "phx-update append/prepend containers require an ID"
    end
  end
end
