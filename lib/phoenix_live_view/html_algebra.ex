defmodule Phoenix.LiveView.HTMLAlgebra do
  @moduledoc false

  import Inspect.Algebra, except: [format: 2]

  # TODO: Remove it after versions before Elixir 1.13 are no longer supported.
  @compile {:no_warn_undefined, Code}

  # Reference for all inline elements so that we can tell the formatter to not
  # force a line break. This list has been taken from here:
  #
  # https://developer.mozilla.org/en-US/docs/Web/HTML/Inline_elements#list_of_inline_elements
  @inline_elements ~w(a abbr acronym audio b bdi bdo big br button canvas cite
  code data datalist del dfn em embed i iframe img input ins kbd label map
  mark meter noscript object output picture progress q ruby s samp select slot
  small span strong sub sup svg template textarea time u tt var video wbr)

  @languages ~w(style script)

  # The formatter has two modes:
  #
  # * :normal
  # * :preserve - for preserving text in <pre>, <script>, <style> and HTML Comment tags
  #
  def build(tree, opts) when is_list(tree) do
    tree
    |> block_to_algebra(%{mode: :normal, opts: opts})
    |> group()
  end

  defp block_to_algebra([], _opts), do: empty()

  defp block_to_algebra(block, %{mode: :preserve} = context) do
    block
    |> Enum.reduce(empty(), fn node, doc ->
      {_type, next_doc} = to_algebra(node, context)
      concat(doc, next_doc)
    end)
    |> force_unfit()
    |> group()
  end

  defp block_to_algebra([head | tail], context) do
    {type, doc} =
      head
      |> to_algebra(context)
      |> maybe_force_unfit()

    Enum.reduce(tail, {head, type, doc}, fn next_node, {prev_node, prev_type, prev_doc} ->
      {next_type, next_doc} =
        next_node
        |> to_algebra(context)
        |> maybe_force_unfit()

      cond do
        prev_type == :inline and next_type == :inline ->
          on_break =
            if next_doc != empty() and
                 (text_ends_with_space?(prev_node) or text_starts_with_space?(next_node)) do
              " "
            else
              ""
            end

          {next_node, next_type, concat([prev_doc, flex_break(on_break), next_doc])}

        prev_type == :newline and next_type == :inline ->
          {next_node, next_type, concat([prev_doc, line(), next_doc])}

        next_type == :newline ->
          {:text, _text, %{newlines: newlines}} = next_node

          if newlines > 1 do
            {next_node, next_type, concat([prev_doc, nest(line(), :reset), next_doc])}
          else
            {next_node, next_type, concat([prev_doc, next_doc])}
          end

        true ->
          {next_node, next_type, concat([prev_doc, break(""), next_doc])}
      end
    end)
    |> elem(2)
    |> group()
  end

  @codepoints '\s\n\r\t'

  defp text_starts_with_space?({:text, text, _meta}) when text != "",
    do: :binary.first(text) in @codepoints

  defp text_starts_with_space?(_node), do: false

  defp text_ends_with_space?({:text, text, _meta}) when text != "",
    do: :binary.last(text) in @codepoints

  defp text_ends_with_space?(_node), do: false

  defp to_algebra({:html_comment, block}, context) do
    children = block_to_algebra(block, %{context | mode: :preserve})
    {:block, group(nest(children, :reset))}
  end

  defp to_algebra({:tag_block, "pre", attrs, block}, context) do
    children = block_to_algebra(block, %{context | mode: :preserve})

    tag =
      concat([
        "<pre",
        build_attrs(attrs, "", context.opts),
        ">",
        nest(children, :reset),
        "</pre>"
      ])
      |> group()

    {:block, tag}
  end

  defp to_algebra({:tag_block, name, attrs, block}, %{mode: :preserve} = context) do
    children = block_to_algebra(block, context)

    {:inline,
     concat(["<#{name}", build_attrs(attrs, "", context.opts), ">", children, "</#{name}>"])}
  end

  defp to_algebra({:tag_block, name, attrs, block}, context) when name in @languages do
    children = block_to_algebra(block, %{context | mode: :preserve})

    # Convert the whole block to text as there are no
    # tags inside script/style, only text and EEx blocks.
    lines =
      children
      |> Inspect.Algebra.format(:infinity)
      |> IO.iodata_to_binary()
      |> String.split(["\r\n", "\n"])
      |> Enum.drop_while(&(String.trim_leading(&1) == ""))

    indentation =
      lines
      |> Enum.map(&count_indentation(&1, 0))
      |> Enum.min(fn -> :infinity end)
      |> case do
        :infinity -> 0
        min -> min
      end

    doc =
      case lines do
        [] ->
          empty()

        _ ->
          text =
            lines
            |> Enum.map(&remove_indentation(&1, indentation))
            |> text_to_algebra(0, [])

          nest(concat(line(), text), 2)
      end

    group =
      concat([
        "<#{name}",
        build_attrs(attrs, "", context.opts),
        ">",
        doc,
        line(),
        "</#{name}>"
      ])
      |> group()

    {:block, group}
  end

  defp to_algebra({:tag_block, name, attrs, block}, context) do
    {block, force_newline?} = trim_block_newlines(block)

    children =
      case block do
        [] -> empty()
        _ -> nest(concat(break(""), block_to_algebra(block, context)), 2)
      end

    children = if force_newline?, do: force_unfit(children), else: children

    tag_open =
      case attrs do
        [attr] ->
          concat(["<#{name} ", render_attribute(attr, context.opts), ">"])

        attrs ->
          concat(["<#{name}", build_attrs(attrs, "", context.opts), ">"])
      end

    doc =
      concat([
        tag_open,
        children,
        break(""),
        "</#{name}>"
      ])
      |> group()

    if !force_newline? and name in @inline_elements do
      {:inline, doc}
    else
      {:block, doc}
    end
  end

  defp to_algebra({:tag_self_close, name, attrs}, context) do
    doc =
      case attrs do
        [attr] ->
          concat(["<#{name} ", render_attribute(attr, context.opts), " />"])

        attrs ->
          concat(["<#{name}", build_attrs(attrs, " ", context.opts), "/>"])
      end

    {:block, group(doc)}
  end

  # Handle EEX blocks within `pre` tag
  defp to_algebra({:eex_block, expr, block}, %{mode: :preserve} = context) do
    doc =
      Enum.reduce(block, empty(), fn {block, expr}, doc ->
        children = block_to_algebra(block, context)
        expr = "<% #{expr} %>"
        concat([doc, children, expr])
      end)

    {:block, group(concat("<%= #{expr} %>", doc))}
  end

  # Handle EEX blocks
  defp to_algebra({:eex_block, expr, block}, context) do
    {doc, _stab} =
      Enum.reduce(block, {empty(), false}, fn {block, expr}, {doc, stab?} ->
        {block, _force_newline?} = trim_block_newlines(block)
        {next_doc, stab?} = eex_block_to_algebra(expr, block, stab?, context)
        {concat(doc, force_unfit(next_doc)), stab?}
      end)

    {:block, group(concat("<%= #{expr} %>", doc))}
  end

  defp to_algebra({:eex_comment, text}, _context) do
    {:inline, concat(["<%!--", text, "--%>"])}
  end

  defp to_algebra({:eex, text, %{opt: opt} = meta}, context) do
    doc = expr_to_code_algebra(text, meta, context.opts)
    {:inline, concat(["<%#{opt} ", doc, " %>"])}
  end

  # Handle text within <pre>/<script>/<style>/comment tags.
  defp to_algebra({:text, text, _meta}, %{mode: :preserve}) when is_binary(text) do
    {:inline, string(text)}
  end

  # Handle text within other tags.
  defp to_algebra({:text, text, _meta}, _context) when is_binary(text) do
    case classify_leading(text) do
      :spaces ->
        {:inline, empty()}

      :newline ->
        {:newline, empty()}

      :other ->
        {:inline,
         text
         |> String.split(["\r\n", "\n"])
         |> Enum.map(&String.trim/1)
         |> Enum.drop_while(&(&1 == ""))
         |> text_to_algebra(0, [])}
    end
  end

  # Handle comment start and end in the same line: <!-- comment -->
  defp to_algebra({:comment, text}, _context) when is_binary(text) do
    {:block, text |> String.trim() |> string()}
  end

  # Empty newline
  defp text_to_algebra(["" | lines], newlines, acc),
    do: text_to_algebra(lines, newlines + 1, acc)

  # Text
  # Text
  defp text_to_algebra([line | lines], 0, acc),
    do: text_to_algebra(lines, 0, [string(line), line() | acc])

  # Text
  #
  # Text
  defp text_to_algebra([line | lines], _newlines, acc),
    do: text_to_algebra(lines, 0, [string(line), line(), nest(line(), :reset) | acc])

  # Final clause: single line
  defp text_to_algebra([], _, [doc, _line]),
    do: doc

  defp text_to_algebra([], _, []),
    do: empty()

  # Final clause: multiple lines
  defp text_to_algebra([], _, acc),
    do: acc |> Enum.reverse() |> tl() |> concat() |> force_unfit()

  defp build_attrs([], on_break, _opts), do: on_break

  defp build_attrs(attrs, on_break, opts) do
    attrs
    |> Enum.reduce(empty(), &concat([&2, break(" "), render_attribute(&1, opts)]))
    |> nest(2)
    |> concat(break(on_break))
    |> group()
  end

  defp render_attribute({:root, {:expr, expr, _}}, _opts), do: ~s({#{expr}})
  defp render_attribute({attr, {:string, value, _meta}}, _opts), do: ~s(#{attr}="#{value}")

  defp render_attribute({attr, {:expr, value, meta}}, opts) do
    case Code.string_to_quoted(value) do
      {:ok, string} when is_binary(string) ->
        ~s(#{attr}="#{string}")

      _ ->
        expr =
          break("")
          |> concat(expr_to_code_algebra(value, meta, opts))
          |> nest(2)

        group(concat(["#{attr}={", expr, concat(break(""), "}")]))
    end
  end

  defp render_attribute({attr, {_, value, _meta}}, _opts), do: ~s(#{attr}=#{value})
  defp render_attribute({attr, nil}, _opts), do: ~s(#{attr})

  # Handle EEx clauses
  #
  # {[], "something ->"}
  # {[{:tag_block, "p", [], [text: "do something"]}], "else"}
  defp eex_block_to_algebra(expr, block, stab?, context) when is_list(block) do
    indent = if stab?, do: 4, else: 2

    document =
      if block == [] do
        # The first clause in cond/case and general empty clauses.
        empty()
      else
        line()
        |> concat(block_to_algebra(block, context))
        |> nest(indent)
      end

    stab? = String.ends_with?(expr, "->")
    indent = if stab?, do: 2, else: 0

    next =
      line()
      |> concat("<% #{expr} %>")
      |> nest(indent)

    {concat(document, next), stab?}
  end

  defp expr_to_code_algebra(expr, meta, opts) do
    string_to_quoted_opts = [
      literal_encoder: &{:ok, {:__block__, &2, [&1]}},
      token_metadata: true,
      unescape: false,
      line: meta.line,
      column: meta.column
    ]

    {quoted, comments} = Code.string_to_quoted_with_comments!(expr, string_to_quoted_opts)
    Code.quoted_to_algebra(quoted, Keyword.merge(opts, escape: false, comments: comments))
  end

  def classify_leading(text), do: classify_leading(text, :spaces)

  def classify_leading(<<char, rest::binary>>, mode) when char in [?\s, ?\t],
    do: classify_leading(rest, mode)

  def classify_leading(<<?\n, rest::binary>>, _), do: classify_leading(rest, :newline)
  def classify_leading(<<>>, mode), do: mode
  def classify_leading(_rest, _), do: :other

  defp maybe_force_unfit({:block, doc}), do: {:block, force_unfit(doc)}
  defp maybe_force_unfit(doc), do: doc

  defp trim_block_newlines(block) do
    {tail, force?} = pop_head_if_only_spaces_or_newlines(block)

    {block, _} =
      tail
      |> Enum.reverse()
      |> pop_head_if_only_spaces_or_newlines()

    force? = if Enum.empty?(block), do: false, else: force?

    {Enum.reverse(block), force?}
  end

  defp pop_head_if_only_spaces_or_newlines([{:text, text, meta} | tail] = block) do
    force? = meta.newlines > 0
    if String.trim_leading(text) == "", do: {tail, force?}, else: {block, force?}
  end

  defp pop_head_if_only_spaces_or_newlines(block), do: {block, false}

  defp count_indentation(<<?\t, rest::binary>>, indent), do: count_indentation(rest, indent + 2)
  defp count_indentation(<<?\s, rest::binary>>, indent), do: count_indentation(rest, indent + 1)
  defp count_indentation(<<>>, _indent), do: :infinity
  defp count_indentation(_, indent), do: indent

  defp remove_indentation(rest, 0), do: rest
  defp remove_indentation(<<?\t, rest::binary>>, indent), do: remove_indentation(rest, indent - 2)
  defp remove_indentation(<<?\s, rest::binary>>, indent), do: remove_indentation(rest, indent - 1)
  defp remove_indentation(rest, _indent), do: rest
end
