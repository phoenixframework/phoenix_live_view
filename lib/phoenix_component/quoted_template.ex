defmodule Phoenix.Component.QuotedTemplate do
  @moduledoc false

  # The value produced by `Phoenix.Component.quoted/1` once its unquote
  # fragments have been filled in: a parsed HEEx tree plus everything needed
  # to compile it later, at the use site, via
  # `Phoenix.Component.__compile_quoted__/1`.
  #
  # The node format is private to LiveView. This is fine because the struct
  # never crosses a LiveView version boundary: it is built when the macro
  # holding the template is compiled and consumed when the macro's caller is
  # compiled, both within the same project compilation and therefore with the
  # same LiveView version.

  defstruct [:nodes, :source, :file, :line, :indentation]

  @doc """
  Renders the template back to formatted HEEx source.

  Expressions in already-quoted form are rendered with `Macro.to_string/1`,
  so unquote fragments appear as the values that were spliced in. The
  resulting source is then formatted with `Phoenix.LiveView.HTMLFormatter`.
  """
  def to_source(%__MODULE__{nodes: nodes}) do
    nodes
    |> nodes_to_iodata()
    |> IO.iodata_to_binary()
    |> Phoenix.LiveView.HTMLFormatter.format(migrate_eex_to_curly_interpolation: false)
  end

  defp nodes_to_iodata(nodes), do: Enum.map(nodes, &node_to_iodata/1)

  defp node_to_iodata({:text, text, _meta}), do: text

  defp node_to_iodata({:body_expr, expr, _meta}), do: ["{", expr_to_source(expr), "}"]

  defp node_to_iodata({:eex, expr, %{opt: opt}}),
    do: ["<%", opt, " ", expr_to_source(expr), " %>"]

  defp node_to_iodata({:eex_comment, text}), do: ["<%!--", text, "--%>"]

  defp node_to_iodata({:eex_block, expr, clauses, %{opt: opt}}) do
    clauses =
      Enum.map(clauses, fn {nodes, clause_expr, _clause_meta} ->
        [nodes_to_iodata(nodes), "<% ", clause_expr, " %>"]
      end)

    [["<%", opt, " ", expr, " %>"] | clauses]
  end

  defp node_to_iodata({:self_close, _type, _name, attrs, %{closing: :void} = meta}) do
    ["<", meta.tag_name, attrs_to_iodata(attrs), ">"]
  end

  defp node_to_iodata({:self_close, _type, _name, attrs, meta}) do
    ["<", meta.tag_name, attrs_to_iodata(attrs), " />"]
  end

  defp node_to_iodata({:block, _type, _name, attrs, children, meta, _close_meta}) do
    [
      ["<", meta.tag_name, attrs_to_iodata(attrs), ">"],
      nodes_to_iodata(children),
      ["</", meta.tag_name, ">"]
    ]
  end

  defp attrs_to_iodata(attrs) do
    Enum.map(attrs, fn
      {:root, {:expr, expr, _expr_meta}, _attr_meta} ->
        [" {", expr_to_source(expr), "}"]

      {name, {:string, value, %{delimiter: ?'}}, _attr_meta} ->
        [" ", name, "='", value, "'"]

      {name, {:string, value, _str_meta}, _attr_meta} ->
        [" ", name, "=\"", value, "\""]

      {name, {:expr, expr, _expr_meta}, _attr_meta} ->
        [" ", name, "={", expr_to_source(expr), "}"]

      {name, nil, _attr_meta} ->
        [" ", name]
    end)
  end

  defp expr_to_source({:quoted, ast}), do: Macro.to_string(ast)
  defp expr_to_source(source) when is_binary(source), do: source
end
