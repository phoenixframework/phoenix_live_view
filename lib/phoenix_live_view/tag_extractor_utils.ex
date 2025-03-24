defmodule Phoenix.LiveView.TagExtractorUtils do
  # TODO: make public for attribute helper?
  @moduledoc false

  def attribute(key, value) when is_binary(value) do
    {key, {:string, value, %{delimiter: ?", line: 0, column: 0}}, %{line: 0, column: 0}}
  end

  def process_extracts(tokens, opts) do
    file = Keyword.fetch!(opts, :file)
    caller = Keyword.fetch!(opts, :caller)
    module = caller.module

    {extracts, tokens} =
      process_extracts(tokens, %{module: module, file: file, env: caller}, {[], []})

    tokens = Enum.reverse(tokens)

    if extracts == %{} do
      tokens
    else
      maybe_apply_rewrites(extracts, tokens)
    end
  end

  defp process_extracts(
         [
           {:tag, name, attrs, %{extract: extract} = start_meta} = _start,
           {:text, text, text_meta} = _content,
           {:close, :tag, name, _} = end_ | rest
         ],
         meta,
         {extracts, tokens_acc}
       )
       when not is_nil(extract) do
    {data, _} = Code.eval_string(extract, [], meta.env)
    %{line: line, column: column} = start_meta
    new_meta = Map.merge(meta, %{line: line, column: column})

    case Phoenix.LiveView.TagExtractor.extract(data, attrs_to_map(attrs), text, new_meta) do
      {:keep, attributes, new_content, state} ->
        Module.put_attribute(meta.module, :__extracts__, {data, state})

        process_extracts(
          rest,
          meta,
          {[{data, state} | extracts],
           [
             end_,
             {:text, new_content, text_meta},
             {:tag, name, map_to_attrs(attributes), start_meta} | tokens_acc
           ]}
        )

      {:drop, state} ->
        Module.put_attribute(meta.module, :__extracts__, {data, state})
        process_extracts(rest, meta, {[{data, state} | extracts], tokens_acc})

      other ->
        raise ArgumentError,
              "extract must return either {:keep, attributes, new_content, any} or {:drop, any}, got:\n\n#{inspect(other)}"
    end
  end

  # if the first clause did not match (tag open, text, close),
  # this means that there is interpolation inside the tag, which is not supported
  defp process_extracts(
         [{:tag, _name, attrs, %{extract: extract} = _meta} = start | rest],
         meta,
         {extracts, tokens_acc}
       )
       when not is_nil(extract) do
    if Enum.find(attrs, &match?({"type", {:string, "text/phx-hook", _}, _}, &1)) do
      # TODO: nice error message
      raise ArgumentError,
            "interpolation inside a tag with :extract attribute is not supported"
    else
      process_extracts(rest, meta, {extracts, [start | tokens_acc]})
    end
  end

  defp process_extracts([token | rest], meta, {extracts, tokens_acc}),
    do: process_extracts(rest, meta, {extracts, [token | tokens_acc]})

  defp process_extracts([], _meta, acc), do: acc

  # TODO: in postprocess_tokens we expose the attributes from the tokenizer directly
  #       either we do this here as well, or we find a better way for postprocess_tokens
  defp attrs_to_map(attrs) do
    for {name, {type, value, _}, _} <- attrs, into: %{}, do: {name, {type, value}}
  end

  defp map_to_attrs(map) do
    for {name, {type, value}} <- map,
        into: [],
        do: {name, {type, value, %{delimiter: ?", line: 0, column: 0}}, %{line: 0, column: 0}}
  end

  defp maybe_apply_rewrites(extracts, tokens) do
    for {data, state} <- extracts, reduce: tokens do
      acc -> Phoenix.LiveView.TagExtractor.postprocess_tokens(data, state, acc)
    end
  end
end
