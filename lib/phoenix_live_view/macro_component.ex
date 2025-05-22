defmodule Phoenix.LiveView.MacroComponent do
  @type tag :: binary()
  @type attributes :: %{atom() => term()}
  @type children :: [heex_ast()]
  @type heex_ast :: {tag(), attributes(), children()} | binary()

  @callback transform(heex_ast :: heex_ast(), meta :: map()) :: heex_ast()
end

defmodule Phoenix.LiveView.MacroComponent.AST do
  @moduledoc """
  An HTML AST for macro components.
  """

  @doc false
  def build_ast([{:tag, name, attrs, _tag_meta} | rest]) do
    build_ast(rest, [], [{name, token_attrs_to_ast(attrs)}])
  end

  # recursive case: build_ast(tokens, acc, stack)

  # closing for final stack element -> done!
  defp build_ast([{:close, :tag, _, _} | rest], acc, [{tag_name, attrs}]) do
    {:ok, {tag_name, attrs, Enum.reverse(acc)}, rest}
  end

  # tag open (self closing or void)
  defp build_ast([{:tag, name, attrs, %{closing: type}} | rest], acc, stack)
       when type in [:self, :void] do
    build_ast(rest, [{name, token_attrs_to_ast(attrs), []} | acc], stack)
  end

  # tag open
  defp build_ast([{:tag, name, attrs, _tag_meta} | rest], acc, stack) do
    build_ast(rest, [], [{name, token_attrs_to_ast(attrs), acc} | stack])
  end

  # tag close
  defp build_ast([{:close, :tag, name, _tag_meta} | tokens], acc, [
         {name, attrs, prev_acc} | stack
       ]) do
    build_ast(tokens, [{name, attrs, Enum.reverse(acc)} | prev_acc], stack)
  end

  # text
  defp build_ast([{:text, text, _meta} | rest], acc, stack) do
    build_ast(rest, [text | acc], stack)
  end

  # unsupported token
  defp build_ast([{type, _name, _attrs, meta} | _tokens], _acc, _stack)
       when type in [:local_component, :remote_component] do
    {:error, "function components cannot be nested inside a macro component", meta}
  end

  defp build_ast([{:eex, _, _, meta} | _], _acc, _stack) do
    {:error, "interpolation is not currently supported in macro components", meta}
  end

  defp token_attrs_to_ast(attrs) do
    Enum.map(attrs, fn {name, value, _meta} ->
      # TODO: decide how we want to treat expressions
      #       for now we just do binary / Elixir AST
      case value do
        {:string, binary, _meta} ->
          {name, binary}

        {:expr, code, _meta} ->
          ast = Code.string_to_quoted!(code)
          {name, ast}
      end
    end)
  end

  @doc """
  Turns an AST into a string.
  """
  def to_string(ast) do
    IO.iodata_to_binary(ast_to_string(ast))
  end

  defp ast_to_string(list) when is_list(list) do
    Enum.map(list, &ast_to_string/1)
  end

  defp ast_to_string({name, attrs, children}) do
    [
      "<",
      name,
      attrs_to_string(attrs),
      ">",
      Enum.map(children, &ast_to_string/1),
      "</",
      name,
      ">"
    ]
  end

  defp ast_to_string(bin) when is_binary(bin), do: bin

  defp attrs_to_string([]), do: []

  defp attrs_to_string(attrs) do
    [
      " ",
      Enum.map_join(attrs, " ", fn {key, value} when is_binary(value) ->
        {:safe, escaped} = Phoenix.HTML.html_escape(value)
        <<key::binary, "=", "\"", escaped::binary, "\"">>
      end)
    ]
  end

  @doc false
  def to_tokens(ast) do
    ast_to_tokens(ast)
  end

  defp ast_to_tokens({name, attrs, children}) do
    [
      {:tag, name, ast_attrs_to_token_attrs(attrs), %{line: 0, column: 0}}
      | Enum.flat_map(children, &ast_to_tokens/1)
    ] ++ [{:close, :tag, name, %{line: 0, column: 0, tag_name: name}}]
  end

  defp ast_to_tokens(bin) when is_binary(bin) do
    [{:text, bin, %{line_end: 0, column_end: 0}}]
  end

  defp ast_attrs_to_token_attrs(attrs) do
    Enum.map(attrs, fn {key, value} ->
      {key,
       case value do
         bin when is_binary(bin) -> {:string, value, %{delimiter: ?"}}
         ast -> {:expr, Macro.to_string(ast), %{line: 0, column: 0}}
       end, %{line: 0, column: 0}}
    end)
  end
end
