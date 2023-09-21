defmodule Phoenix.LiveViewTest.HTML do
  defmacro sigil_X({:<<>>, _, [binary]}, []) when is_binary(binary) do
    Macro.escape(parse_sorted!(binary))
  end

  defmacro sigil_x(term, []) do
    quote bind_quoted: [term: term] do
      parse_sorted!(term)
    end
  end

  def t2h(template) do
    template
    |> Phoenix.LiveViewTest.rendered_to_string()
    |> parse_sorted!()
  end

  @doc """
  This function will parse a binary into a list of in the format
  of floki, however the attributes of any node are in sorted
  order.

  ```
  {"node_name", [{"attribute_name", "attribute_value"}], [content]}
  ```

  or

  ```
  "string contents with no html/xml nodes"
  ```

  While soting the html attributes does mean we can't detect
  differences in behavior, it also keeps the order of map
  key/value from failing tests.

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
