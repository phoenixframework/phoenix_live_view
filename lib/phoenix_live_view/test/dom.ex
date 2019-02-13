defmodule Phoenix.LiveViewTest.DOM do
  @moduledoc false

  def render(nil), do: ""
  def render(%{static: statics} = rendered) do
    for {static, i} <- Enum.with_index(statics), into: "",
      do: static <> to_string(rendered[i])
  end

  def render_diff(rendered) do
    rendered
    |> to_output_buffer([])
    |> Enum.reverse()
    |> Enum.join("")
  end
  defp to_output_buffer(%{dynamics: dynamics, static: statics}, acc) do
    Enum.reduce(dynamics, acc, fn {_dynamic, index}, acc ->
      Enum.reduce(tl(statics), [Enum.at(statics, 0) | acc], fn static, acc ->
        [static | dynamic_to_buffer(dynamics[index - 1], acc)]
      end)
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
  defp dynamic_to_buffer(str, acc), do: [str | acc]

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
