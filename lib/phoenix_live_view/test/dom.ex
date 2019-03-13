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

  def find_sessions(html) do
    ~r/data-phx-session="(.*)">/
    |> Regex.scan(html, capture: :all_but_first)
    |> Enum.map(fn [session] -> session end)
  end

  def insert_session(root_html, session, child_html) do
    Regex.replace(
      ~r/data-phx-session="#{session}"><\/div>/,
      root_html,
      "data-phx-session=\"#{session}\">#{child_html}</div>"
    )
  end

  def deep_merge(target, source) do
    Map.merge(target, source, fn
      _, %{} = target, %{} = source -> deep_merge(target, source)
      _, _target, source -> source
    end)
  end
end
