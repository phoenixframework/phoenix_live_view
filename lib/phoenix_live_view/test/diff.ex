defmodule Phoenix.LiveViewTest.Diff do
  @moduledoc false

  alias Phoenix.LiveViewTest.DOM

  @components :c
  @static :s
  @keyed :k
  @keyed_count :kc
  @stream_id :stream
  @template :p
  @phx_component "data-phx-component"

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

  defp deep_merge_diff(target, %{@template => template} = source),
    do: deep_merge_diff(target, resolve_templates(Map.delete(source, @template), template))

  defp deep_merge_diff(target, %{@keyed => source_keyed} = source) when is_map(target) do
    target_keyed = target[@keyed]

    merged_keyed =
      case source_keyed[@keyed_count] do
        0 ->
          %{@keyed_count => 0}

        count ->
          for pos <- 0..(count - 1), into: %{@keyed_count => count} do
            value =
              case source_keyed[pos] do
                nil -> target_keyed[pos]
                value when is_number(value) -> target_keyed[value]
                value when is_map(value) -> deep_merge_diff(target_keyed[pos], value)
                [old_pos, value] -> deep_merge_diff(target_keyed[old_pos], value)
              end

            {pos, value}
          end
      end

    merged = deep_merge_diff(Map.delete(target, @keyed), Map.delete(source, @keyed))
    Map.put(merged, @keyed, merged_keyed)
  end

  defp deep_merge_diff(_target, %{@static => _} = source),
    do: source

  defp deep_merge_diff(%{} = target, %{} = source),
    do: Map.merge(target, source, fn _, t, s -> deep_merge_diff(t, s) end)

  defp deep_merge_diff(_target, source),
    do: source

  # we resolve any templates when merging, because subsequent patches can
  # contain more templates that are not compatible with previous diffs
  defp resolve_templates(%{@template => template} = rendered, nil) do
    resolve_templates(Map.delete(rendered, @template), template)
  end

  defp resolve_templates(%{@static => static} = rendered, template) when is_integer(static) do
    resolve_templates(Map.put(rendered, @static, Map.fetch!(template, static)), template)
  end

  defp resolve_templates(rendered, template) when is_map(rendered) and not is_struct(rendered) do
    Map.new(rendered, fn {k, v} -> {k, resolve_templates(v, template)} end)
  end

  defp resolve_templates(other, _template), do: other

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
    |> DOM.parse_fragment()
    |> elem(1)
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
end
