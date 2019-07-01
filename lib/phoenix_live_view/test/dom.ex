defmodule Phoenix.LiveViewTest.DOM do
  @moduledoc false

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
    ~r/<[^>]+data-phx-static="([^"]+)[^>]+id="([^"]+)/
    |> Regex.scan(html, capture: :all_but_first)
    |> Enum.into(%{}, fn
      [static, id] -> {id, static}
    end)
  end

  def find_sessions(html) do
    ~r/<[^>]+data-phx-session="([^"]++)[^>]+data-phx-static="([^"]+)[^>]+id="([^"]+)|<[^>]+data-phx-session="([^"]++)[^>]+id="([^"]+)/
    |> Regex.scan(html, capture: :all_but_first)
    |> Enum.map(fn
      ["", "", "", session, id] -> {session, nil, id}
      [session, static, id] -> {session, static, id}
    end)
  end

  def insert_attr(root_html, attr, value, child_html) do
    attr_value = "#{attr}=\"#{value}\""
    [left, right] = :binary.split(root_html, attr_value)
    [[tag] | _] = Regex.scan(~r/<\/([^>]+)/, right, capture: :all_but_first)
    [middle, right] = :binary.split(right, "</#{tag}>")
    Enum.join([left, attr_value, middle, child_html, "</#{tag}>", right], "")
  end

  def deep_merge(target, source) do
    Map.merge(target, source, fn
      _, %{} = target, %{} = source -> deep_merge(target, source)
      _, _target, source -> source
    end)
  end
end
