defmodule Phoenix.LiveView.HTMLAlgebra do
  @moduledoc false

  import Inspect.Algebra, except: [format: 2]

  @languages ~w(style script)

  # The formatter has two modes:
  #
  # * :normal
  # * :preserve - for preserving text in <pre>, <script>, <style> and HTML Comment tags
  #
  def build(tree, opts) when is_list(tree) do
    {migrate, opts} = Keyword.pop(opts, :migrate_eex_to_curly_interpolation, true)
    {attr_formatters, opts} = Keyword.pop!(opts, :attribute_formatters)

    tree
    |> block_to_algebra(%{
      mode: :normal,
      migrate: migrate,
      attr_formatters: attr_formatters,
      opts: opts
    })
    |> group()
  end

  defp block_to_algebra([], _context), do: empty()

  defp block_to_algebra(block, %{mode: :preserve} = context) do
    concat =
      Enum.reduce(block, empty(), fn node, doc ->
        {_type, next_doc} = to_algebra(node, context)
        concat(doc, next_doc)
      end)

    {force_unfit?, meta} =
      Enum.find_value(block, fn
        {:text, text, meta} ->
          {String.contains?(text, "\n"), meta}

        _ ->
          {false, %{}}
      end)

    doc =
      if force_unfit? do
        concat |> force_unfit() |> group()
      else
        concat |> group()
      end

    newline_or_empty_before_text =
      if meta[:newlines_before_text] && meta[:newlines_before_text] > 1 do
        line()
      else
        empty()
      end

    newline_or_empty_after_text =
      if meta[:newlines_after_text] && meta[:newlines_after_text] > 1 do
        line()
      else
        empty()
      end

    concat([newline_or_empty_before_text, doc, newline_or_empty_after_text])
  end

  defp block_to_algebra([head | tail], context) do
    {type, doc} =
      head
      |> to_algebra(context)
      |> maybe_force_unfit()

    Enum.reduce(tail, {head, type, doc}, fn next_node, {prev_node, prev_type, prev_doc} ->
      context =
        if inline?(prev_node) and inline?(next_node) do
          %{context | mode: :preserve}
        else
          context
        end

      {next_type, next_doc} =
        next_node
        |> to_algebra(context)
        |> maybe_force_unfit()

      doc =
        cond do
          prev_type == :inline and next_type == :inline ->
            on_break =
              if next_doc == empty() do
                ""
              else
                inline_break(prev_node, next_node)
              end

            concat([prev_doc, on_break, next_doc])

          prev_type == :newline and next_type == :inline ->
            concat([prev_doc, line(), next_doc])

          next_type == :newline ->
            {:text, _text, %{newlines: newlines}} = next_node

            if newlines > 1 do
              concat([prev_doc, nest(line(), :reset), next_doc])
            else
              concat([prev_doc, next_doc])
            end

          true ->
            # For most cases, we do want to `break("")` here because they are
            # block tags (div, p, etc..). But, in case the previous or next token
            # is a text without whitespace, such as:
            #
            #   (<div label="application programming interface">API</div>).
            #
            # We don't want to break("") otherwise it would format it like this:
            #
            #   (
            #     <div label="application programming interface">API</div>
            #   ).
            #
            # Therefore, this check if the previous or next token is not a text
            # and, if it is a text, check if that contains whitespace.
            if (not text?(prev_node) and not text?(next_node)) or
                 (text_ends_with_space?(prev_node) or text_starts_with_space?(next_node)) do
              concat([prev_doc, break(""), next_doc])
            else
              concat([prev_doc, next_doc])
            end
        end

      {next_node, next_type, doc}
    end)
    |> elem(2)
    |> group()
  end

  defp inline_break(prev_node, next_node) do
    cond do
      block_preserve?(prev_node) or block_preserve?(next_node) ->
        cond do
          text_ends_with_line_break?(prev_node) ->
            flex_break(" ")

          text_ends_with_space?(prev_node) or text_starts_with_space?(next_node) ->
            " "

          true ->
            ""
        end

      tag_block?(prev_node) and not tag_block?(next_node) ->
        break(" ")

      text_ends_with_space?(prev_node) or text_starts_with_space?(next_node) ->
        flex_break(" ")

      true ->
        ""
    end
  end

  defp tag_block?({:tag_block, _, _, _, _}), do: true
  defp tag_block?(_node), do: false

  defp text?({:text, _text, _meta}), do: true
  defp text?(_node), do: false

  @codepoints ~c"\s\n\r\t"

  defp text_starts_with_space?({:text, text, _meta}) when text != "",
    do: :binary.first(text) in @codepoints

  defp text_starts_with_space?(_node), do: false

  defp text_ends_with_space?({:text, text, _meta}) when text != "",
    do: :binary.last(text) in @codepoints

  defp text_ends_with_space?(_node), do: false

  defp text_ends_with_line_break?({:text, text, _meta}) when text != "",
    do: :binary.last(text) in ~c"\n\r"

  defp text_ends_with_line_break?(_node), do: false

  defp block_preserve?({:tag_block, _, _, _, %{mode: :preserve}}), do: true
  defp block_preserve?({:body_expr, _, _}), do: true
  defp block_preserve?({:eex, _, _}), do: true
  defp block_preserve?(_node), do: false

  defp to_algebra({:html_comment, block}, context) do
    children = block_to_algebra(block, %{context | mode: :preserve})
    {:block, group(nest(children, :reset))}
  end

  defp to_algebra({:tag_block, name, attrs, block, meta}, context) when name in @languages do
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
          line()

        _ ->
          text =
            lines
            |> Enum.map(&remove_indentation(&1, indentation))
            |> text_to_algebra(0, [])

          case meta do
            %{mode: :preserve} -> text
            _ -> concat(nest(concat(line(), text), 2), line())
          end
      end

    group =
      concat([
        "<#{name}",
        build_attrs(attrs, "", context.attr_formatters, context.opts),
        ">",
        doc,
        "</#{name}>"
      ])
      |> group()

    {:block, group}
  end

  defp to_algebra({:tag_block, _name, _attrs, _block, _meta} = doc, %{mode: :preserve} = context) do
    tag_block_preserve_to_algebra(doc, context)
  end

  defp to_algebra({:tag_block, _name, _attrs, _block, %{mode: :preserve}} = doc, context) do
    tag_block_preserve_to_algebra(doc, context)
  end

  defp to_algebra({:tag_block, name, attrs, block, meta}, context) do
    {block, force_newline?} = trim_block_newlines(block)

    children =
      case block do
        [] -> empty()
        _ -> nest(concat(break(""), block_to_algebra(block, context)), 2)
      end

    children = if force_newline?, do: force_unfit(children), else: children

    doc =
      concat([
        format_tag_open(name, attrs, context),
        children,
        break(""),
        "</#{name}>"
      ])
      |> group()

    if !force_newline? and meta.mode == :inline do
      {:inline, doc}
    else
      {:block, doc}
    end
  end

  defp to_algebra({:tag_self_close, name, attrs}, context) do
    doc =
      case attrs do
        [attr] ->
          concat([
            "<#{name} ",
            render_attribute(attr, context.attr_formatters, context.opts),
            " />"
          ])

        attrs ->
          concat([
            "<#{name}",
            build_attrs(attrs, " ", context.attr_formatters, context.opts),
            "/>"
          ])
      end

    {:inline, group(doc)}
  end

  # Handle EEX blocks within preserve tags
  defp to_algebra({:eex_block, expr, block, meta}, %{mode: :preserve} = context) do
    doc =
      Enum.reduce(block, empty(), fn {block, expr}, doc ->
        children = block_to_algebra(block, context)
        expr = "<% #{expr} %>"
        concat([doc, children, expr])
      end)

    {:block, group(concat("<%#{meta.opt} #{expr} %>", doc))}
  end

  # Handle EEX blocks
  defp to_algebra({:eex_block, expr, block, meta}, context) do
    {doc, _stab} =
      Enum.reduce(block, {empty(), false}, fn {block, expr}, {doc, stab?} ->
        {block, _force_newline?} = trim_block_newlines(block)
        {next_doc, stab?} = eex_block_to_algebra(expr, block, stab?, context)
        {concat(doc, force_unfit(next_doc)), stab?}
      end)

    {:block, group(concat("<%#{meta.opt} #{expr} %>", doc))}
  end

  defp to_algebra({:eex_comment, text}, _context) do
    {:inline, concat(["<%!--", text, "--%>"])}
  end

  defp to_algebra({:eex, text, %{opt: opt} = meta}, context) do
    cond do
      context.mode == :preserve ->
        {:inline, concat(["<%#{opt} ", text, " %>"])}

      context.migrate and opt == ~c"=" and safe_to_migrate?(text, 0) ->
        to_algebra({:body_expr, text, meta}, context)

      true ->
        doc = expr_to_code_algebra(text, meta, context.opts)
        {:inline, concat(["<%#{opt} ", doc, " %>"])}
    end
  end

  defp to_algebra({:body_expr, text, meta}, context) do
    if context.mode == :preserve do
      {:inline, concat(["{", text, "}"])}
    else
      doc = expr_to_code_algebra(text, meta, context.opts)
      {:inline, concat(["{", doc, "}"])}
    end
  end

  # Handle text within <pre>/<script>/<style>/comment tags.
  defp to_algebra({:text, text, _meta}, %{mode: :preserve}) when is_binary(text) do
    {:inline, string(text)}
  end

  defp to_algebra({:text, text, %{mode: :preserve}}, _context) when is_binary(text) do
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

  # Preserve tag_block
  defp tag_block_preserve_to_algebra({:tag_block, name, attrs, block, meta}, context) do
    children = block_to_algebra(block, %{context | mode: :preserve})

    children =
      if meta.mode == :inline do
        children
      else
        nest(children, 2)
      end

    tag =
      concat([
        format_tag_open(name, attrs, context),
        children,
        "</#{name}>"
      ])
      |> group()

    {:inline, tag}
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
    do: acc |> Enum.reverse() |> tl() |> concat()

  defp build_attrs([], on_break, _formatters, _opts), do: on_break

  defp build_attrs(attrs, on_break, formatters, opts) do
    attrs
    |> Enum.sort_by(&attrs_sorter/1)
    |> Enum.reduce(
      empty(),
      &concat([&2, break(" "), render_attribute(&1, formatters, opts)])
    )
    |> nest(2)
    |> concat(break(on_break))
    |> group()
  end

  @attrs_order %{
    ":let" => 1,
    ":for" => 2,
    ":if" => 3
  }

  # Sort attrs by @attrs_order. This will set :let, :for and :if at the beginning
  # and ordinary HTML attributes at the end. HTML attributes will not change their
  # order.
  defp attrs_sorter({attr_name, _, _}) do
    case @attrs_order[attr_name] do
      nil -> 4
      attrs_order -> attrs_order
    end
  end

  defp format_tag_open(name, [attr], context),
    do: concat(["<#{name} ", render_attribute(attr, context.attr_formatters, context.opts), ">"])

  defp format_tag_open(name, attrs, context),
    do: concat(["<#{name}", build_attrs(attrs, "", context.attr_formatters, context.opts), ">"])

  defp render_attribute({:root, {:expr, expr, _}, _}, _formatters, _opts), do: ~s({#{expr}})

  defp render_attribute({name, _, _} = attr, formatters, opts)
       when is_map_key(formatters, name) do
    attr
    |> formatters[name].render_attribute(opts)
    |> render_attribute(%{}, opts)
  end

  defp render_attribute({attr, {:string, value, %{delimiter: ?'}}, _}, _formatters, _opts) do
    if String.contains?(value, ["\"", "'"]) do
      ~s(#{attr}='#{value}')
    else
      ~s(#{attr}="#{value}")
    end
  end

  defp render_attribute({attr, {:string, value, _meta}, _}, _formatters, _opts),
    do: ~s(#{attr}="#{value}")

  defp render_attribute({attr, {:expr, value, meta}, _}, _formatters, opts) do
    case expr_to_quoted(value, meta, opts) do
      {{:__block__, meta, [string]} = block, []} when is_binary(string) ->
        has_quotes? = String.contains?(string, "\"")
        delimiter = Keyword.get(meta, :delimiter)

        if has_quotes? or delimiter == "\"\"\"" do
          # don't try to flatten heredocs or strings with quotes
          group(concat(["#{attr}={", quoted_to_code_algebra(block, [], opts), "}"]))
        else
          # attr={"foo"} -> attr="foo"
          ~s(#{attr}="#{string}")
        end

      {{atom, _, _}, []} when atom in [:<<>>, :<>] ->
        concat(["#{attr}={", string(value), "}"])

      {{:__block__, _, [[_ | _]]} = quoted, []} ->
        expr = quoted_to_code_algebra(quoted, [], opts)
        group(concat(["#{attr}={", expr, "}"]))

      {quoted, comments} ->
        expr =
          break("")
          |> concat(quoted_to_code_algebra(quoted, comments, opts))
          |> nest(2)

        group(concat(["#{attr}={", expr, concat(break(""), "}")]))
    end
  end

  defp render_attribute({attr, {_, value, _meta}, _}, _formatters, _opts),
    do: ~s(#{attr}=#{value})

  defp render_attribute({attr, nil, _}, _formatters, _opts), do: ~s(#{attr})

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

  defp expr_to_quoted(expr, meta, opts) do
    string_to_quoted_opts = [
      literal_encoder: &{:ok, {:__block__, &2, [&1]}},
      token_metadata: true,
      unescape: false,
      line: meta.line,
      column: meta.column,
      file: Keyword.get(opts, :file, "nofile")
    ]

    Code.string_to_quoted_with_comments!(expr, string_to_quoted_opts)
  end

  defp expr_to_code_algebra(expr, meta, opts) do
    {quoted, comments} = expr_to_quoted(expr, meta, opts)
    quoted_to_code_algebra(quoted, comments, opts)
  end

  defp quoted_to_code_algebra(quoted, comments, opts) do
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

  defp inline?({:tag_block, _, _, _, %{mode: :inline}}), do: true
  defp inline?(_), do: false

  defp safe_to_migrate?(~S[\{] <> rest, acc), do: safe_to_migrate?(rest, acc)
  defp safe_to_migrate?(~S[\}] <> rest, acc), do: safe_to_migrate?(rest, acc)
  defp safe_to_migrate?("{" <> rest, acc), do: safe_to_migrate?(rest, acc + 1)
  defp safe_to_migrate?("}" <> rest, acc), do: safe_to_migrate?(rest, acc - 1)
  defp safe_to_migrate?(<<_::utf8, rest::binary>>, acc), do: safe_to_migrate?(rest, acc)
  defp safe_to_migrate?(<<>>, acc), do: acc == 0
end
