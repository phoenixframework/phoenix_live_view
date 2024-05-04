defmodule Phoenix.LiveView.HTMLParser do
  @moduledoc false

  alias Phoenix.LiveView.Tokenizer

  defguard is_tag_open(tag_type)
           when tag_type in [:slot, :remote_component, :local_component, :tag]

  # Reference for all inline elements so that we can tell the formatter to not
  # force a line break. This list has been taken from here:
  #
  # https://developer.mozilla.org/en-US/docs/Web/HTML/Inline_elements#list_of_inline_elements
  @inline_tags ~w(a abbr acronym audio b bdi bdo big br button canvas cite
  code data datalist del dfn em embed i iframe img input ins kbd label map
  mark meter noscript object output picture progress q ruby s samp select slot
  small span strong sub sup svg template textarea time u tt var video wbr)

  @inline_components ~w(.link)

  @inline_elements @inline_tags ++ @inline_components

  @doc false
  def parse(source) do
    newlines = :binary.matches(source, ["\r\n", "\n"])

    source
    |> tokenize()
    |> to_tree([], [], {source, newlines})
  end

  # Tokenize contents using EEx.tokenize and Phoenix.Live.Tokenizer respectively.
  #
  # The following content:
  #
  # "<section>\n  <p><%= user.name ></p>\n  <%= if true do %> <p>this</p><% else %><p>that</p><% end %>\n</section>\n"
  #
  # Will be tokenized as:
  #
  # [
  #   {:tag, "section", [], %{column: 1, line: 1}},
  #   {:text, "\n  ", %{column_end: 3, line_end: 2}},
  #   {:tag, "p", [], %{column: 3, line: 2}},
  #   {:eex_tag_render, "<%= user.name ></p>\n  <%= if true do %>", %{block?: true, column: 6, line: 1}},
  #   {:text, " ", %{column_end: 2, line_end: 1}},
  #   {:tag, "p", [], %{column: 2, line: 1}},
  #   {:text, "this", %{column_end: 12, line_end: 1}},
  #   {::close, :tag, "p", %{column: 12, line: 1}},
  #   {:eex_tag, "<% else %>", %{block?: false, column: 35, line: 2}},
  #   {:tag, "p", [], %{column: 1, line: 1}},
  #   {:text, "that", %{column_end: 14, line_end: 1}},
  #   {::close, :tag, "p", %{column: 14, line: 1}},
  #   {:eex_tag, "<% end %>", %{block?: false, column: 62, line: 2}},
  #   {:text, "\n", %{column_end: 1, line_end: 2}},
  #   {::close, :tag, "section", %{column: 1, line: 2}}
  # ]
  #
  # EEx.tokenize/2 was introduced in Elixir 1.14.
  # TODO: Remove this when we no longer support earlier versions.
  @eex_expr [:start_expr, :expr, :end_expr, :middle_expr]
  if Code.ensure_loaded?(EEx) && function_exported?(EEx, :tokenize, 2) do
    defp tokenize(source) do
      {:ok, eex_nodes} = EEx.tokenize(source)
      {tokens, cont} = Enum.reduce(eex_nodes, {[], :text}, &do_tokenize(&1, &2, source))
      Tokenizer.finalize(tokens, "nofile", cont, source)
    end

    defp do_tokenize({:text, text, meta}, {tokens, cont}, source) do
      text = List.to_string(text)
      meta = [line: meta.line, column: meta.column]
      state = Tokenizer.init(0, "nofile", source, Phoenix.LiveView.HTMLEngine)
      Tokenizer.tokenize(text, meta, tokens, cont, state)
    end

    defp do_tokenize({:comment, text, meta}, {tokens, cont}, _contents) do
      {[{:eex_comment, List.to_string(text), meta} | tokens], cont}
    end

    defp do_tokenize({type, opt, expr, %{column: column, line: line}}, {tokens, cont}, _contents)
         when type in @eex_expr do
      meta = %{opt: opt, line: line, column: column}
      {[{:eex, type, expr |> List.to_string() |> String.trim(), meta} | tokens], cont}
    end
  else
    defp tokenize(source) do
      {:ok, eex_nodes} = EEx.Tokenizer.tokenize(source, 1, 1, %{indentation: 0, trim: false})
      {tokens, cont} = Enum.reduce(eex_nodes, {[], :text}, &do_tokenize(&1, &2, source))
      Tokenizer.finalize(tokens, "nofile", cont, source)
    end

    defp do_tokenize({:text, line, column, text}, {tokens, cont}, source) do
      text = List.to_string(text)
      meta = [line: line, column: column]
      state = Tokenizer.init(0, "nofile", source, Phoenix.LiveView.HTMLEngine)
      Tokenizer.tokenize(text, meta, tokens, cont, state)
    end

    defp do_tokenize({type, line, column, opt, expr}, {tokens, cont}, _contents)
         when type in @eex_expr do
      meta = %{opt: opt, line: line, column: column}
      {[{:eex, type, expr |> List.to_string() |> String.trim(), meta} | tokens], cont}
    end
  end

  defp do_tokenize(_node, acc, _contents) do
    acc
  end

  # Build an HTML Tree according to the tokens from the EEx and HTML tokenizers.
  #
  # This is a recursive algorithm that will build an HTML tree from a flat list of
  # tokens. For instance, given this input:
  #
  # [
  #   {:tag, "div", [], %{column: 1, line: 1}},
  #   {:tag, "h1", [], %{column: 6, line: 1}},
  #   {:text, "Hello", %{column_end: 15, line_end: 1}},
  #   {::close, :tag, "h1", %{column: 15, line: 1}},
  #   {::close, :tag, "div", %{column: 20, line: 1}},
  #   {:tag, "div", [], %{column: 1, line: 2}},
  #   {:tag, "h1", [], %{column: 6, line: 2}},
  #   {:text, "World", %{column_end: 15, line_end: 2}},
  #   {::close, :tag, "h1", %{column: 15, line: 2}},
  #   {::close, :tag, "div", %{column: 20, line: 2}}
  # ]
  #
  # The output will be:
  #
  # [
  #   {:tag_block, "div", [], [{:tag_block, "h1", [], [text: "Hello"]}]},
  #   {:tag_block, "div", [], [{:tag_block, "h1", [], [text: "World"]}]}
  # ]
  #
  # Note that a `tag_block` has been created so that its fourth argument is a list of
  # its nested content.
  #
  # ### How does this algorithm work?
  #
  # As this is a recursive algorithm, it starts with an empty buffer and an empty
  # stack. The buffer will be accumulated until it finds a `{:tag, ..., ...}`.
  #
  # As soon as the `tag_open` arrives, a new buffer will be started and we move
  # the previous buffer to the stack along with the `tag_open`:
  #
  #   ```
  #   defp build([{:tag, name, attrs, _meta} | tokens], buffer, stack) do
  #     build(tokens, [], [{name, attrs, buffer} | stack])
  #   end
  #   ```
  #
  # Then, we start to populate the buffer again until a `{::close, :tag, ...} arrives:
  #
  #   ```
  #   defp build([{::close, :tag, name, _meta} | tokens], buffer, [{name, attrs, upper_buffer} | stack]) do
  #     build(tokens, [{:tag_block, name, attrs, Enum.reverse(buffer)} | upper_buffer], stack)
  #   end
  #   ```
  #
  # In the snippet above, we build the `tag_block` with the accumulated buffer,
  # putting the buffer accumulated before the tag open (upper_buffer) on top.
  #
  # We apply the same logic for `eex` expressions but, instead of `tag_open` and
  # `tag_close`, eex expressions use `start_expr`, `middle_expr` and `end_expr`.
  # The only real difference is that also need to handle `middle_buffer`.
  #
  # So given this eex input:
  #
  # ```elixir
  # [
  #   {:eex, :start_expr, "if true do", %{column: 0, line: 0, opt: '='}},
  #   {:text, "\n  ", %{column_end: 3, line_end: 2}},
  #   {:eex, :expr, "\"Hello\"", %{column: 3, line: 1, opt: '='}},
  #   {:text, "\n", %{column_end: 1, line_end: 2}},
  #   {:eex, :middle_expr, "else", %{column: 1, line: 2, opt: []}},
  #   {:text, "\n  ", %{column_end: 3, line_end: 2}},
  #   {:eex, :expr, "\"World\"", %{column: 3, line: 3, opt: '='}},
  #   {:text, "\n", %{column_end: 1, line_end: 2}},
  #   {:eex, :end_expr, "end", %{column: 1, line: 4, opt: []}}
  # ]
  # ```
  #
  # The output will be:
  #
  # ```elixir
  # [
  #   {:eex_block, "if true do",
  #    [
  #      {[{:eex, "\"Hello\"", %{column: 3, line: 1, opt: '='}}], "else"},
  #      {[{:eex, "\"World\"", %{column: 3, line: 3, opt: '='}}], "end"}
  #    ]}
  # ]
  # ```
  defp to_tree([], buffer, [], _source) do
    {:ok, Enum.reverse(buffer)}
  end

  defp to_tree([], _buffer, [{name, _, %{line: line, column: column}, _} | _], _source) do
    message = "end of template reached without closing tag for <#{name}>"
    {:error, line, column, message}
  end

  defp to_tree([{:text, text, %{context: [:comment_start]}} | tokens], buffer, stack, source) do
    to_tree(tokens, [], [{:comment, text, buffer} | stack], source)
  end

  defp to_tree(
         [{:text, text, %{context: [:comment_end | _rest]}} | tokens],
         buffer,
         [{:comment, start_text, upper_buffer} | stack],
         source
       ) do
    buffer = Enum.reverse([{:text, String.trim_trailing(text), %{}} | buffer])
    text = {:text, String.trim_leading(start_text), %{}}
    to_tree(tokens, [{:html_comment, [text | buffer]} | upper_buffer], stack, source)
  end

  defp to_tree(
         [{:text, text, %{context: [:comment_start, :comment_end]}} | tokens],
         buffer,
         stack,
         source
       ) do
    to_tree(tokens, [{:html_comment, [{:text, String.trim(text), %{}}]} | buffer], stack, source)
  end

  defp to_tree([{:text, text, _meta} | tokens], buffer, stack, source) do
    buffer = may_set_preserve_on_block(buffer, text)

    if line_html_comment?(text) do
      to_tree(tokens, [{:comment, text} | buffer], stack, source)
    else
      meta = %{newlines: count_newlines_until_text(text, 0)}
      to_tree(tokens, [{:text, text, meta} | buffer], stack, source)
    end
  end

  defp to_tree([{type, _name, attrs, %{closing: _} = meta} | tokens], buffer, stack, source)
       when is_tag_open(type) do
    to_tree(tokens, [{:tag_self_close, meta.tag_name, attrs} | buffer], stack, source)
  end

  defp to_tree([{type, _name, attrs, meta} | tokens], buffer, stack, source)
       when is_tag_open(type) do
    to_tree(tokens, [], [{meta.tag_name, attrs, meta, buffer} | stack], source)
  end

  defp to_tree(
         [{:close, _type, _name, close_meta} | tokens],
         buffer,
         [{tag_name, attrs, open_meta, upper_buffer} | stack],
         source
       ) do
    {mode, block} =
      if tag_name in ["pre", "textarea"] or contains_special_attrs?(attrs) do
        content = content_from_source(source, open_meta.inner_location, close_meta.inner_location)
        {:preserve, [{:text, content, %{newlines: 0}}]}
      else
        mode =
          cond do
            preserve_format?(tag_name, upper_buffer) -> :preserve
            tag_name in @inline_elements -> :inline
            true -> :block
          end

        {mode,
         buffer
         |> Enum.reverse()
         |> may_set_preserve_on_text(mode, tag_name)}
      end

    tag_block = {:tag_block, tag_name, attrs, block, %{mode: mode}}

    to_tree(tokens, [tag_block | upper_buffer], stack, source)
  end

  # handle eex

  defp to_tree([{:eex_comment, text, _meta} | tokens], buffer, stack, source) do
    to_tree(tokens, [{:eex_comment, text} | buffer], stack, source)
  end

  defp to_tree([{:eex, :start_expr, expr, _meta} | tokens], buffer, stack, source) do
    to_tree(tokens, [], [{:eex_block, expr, buffer} | stack], source)
  end

  defp to_tree(
         [{:eex, :middle_expr, middle_expr, _meta} | tokens],
         buffer,
         [{:eex_block, expr, upper_buffer, middle_buffer} | stack],
         source
       ) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr} | middle_buffer]
    to_tree(tokens, [], [{:eex_block, expr, upper_buffer, middle_buffer} | stack], source)
  end

  defp to_tree(
         [{:eex, :middle_expr, middle_expr, _meta} | tokens],
         buffer,
         [{:eex_block, expr, upper_buffer} | stack],
         source
       ) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr}]
    to_tree(tokens, [], [{:eex_block, expr, upper_buffer, middle_buffer} | stack], source)
  end

  defp to_tree(
         [{:eex, :end_expr, end_expr, _meta} | tokens],
         buffer,
         [{:eex_block, expr, upper_buffer, middle_buffer} | stack],
         source
       ) do
    block = Enum.reverse([{Enum.reverse(buffer), end_expr} | middle_buffer])
    to_tree(tokens, [{:eex_block, expr, block} | upper_buffer], stack, source)
  end

  defp to_tree(
         [{:eex, :end_expr, end_expr, _meta} | tokens],
         buffer,
         [{:eex_block, expr, upper_buffer} | stack],
         source
       ) do
    block = [{Enum.reverse(buffer), end_expr}]
    to_tree(tokens, [{:eex_block, expr, block} | upper_buffer], stack, source)
  end

  defp to_tree([{:eex, _type, expr, meta} | tokens], buffer, stack, source) do
    to_tree(tokens, [{:eex, expr, meta} | buffer], stack, source)
  end

  # -- HELPERS

  defp count_newlines_until_text(<<char, rest::binary>>, counter) when char in ~c"\s\t\r",
    do: count_newlines_until_text(rest, counter)

  defp count_newlines_until_text(<<?\n, rest::binary>>, counter),
    do: count_newlines_until_text(rest, counter + 1)

  defp count_newlines_until_text(_, counter),
    do: counter

  # We just want to handle as :comment when the whole line is a HTML comment.
  #
  #   <!-- Modal content -->
  #   <%= render_slot(@inner_block) %>
  #
  # Therefore the case above will stay as is. Otherwise it would put them in the
  # same line.
  defp line_html_comment?(text) do
    trimmed_text = String.trim(text)
    String.starts_with?(trimmed_text, "<!--") and String.ends_with?(trimmed_text, "-->")
  end

  # We want to preserve the format:
  #
  # * In case the head is a text that doesn't end with whitespace.
  # * In case the head is eex.
  defp preserve_format?(name, upper_buffer) do
    name in @inline_elements and head_may_not_have_whitespace?(upper_buffer)
  end

  defp head_may_not_have_whitespace?([{:text, text, _meta} | _]),
    do: String.trim_leading(text) != "" and :binary.last(text) not in ~c"\s\t"

  defp head_may_not_have_whitespace?([{:eex, _, _} | _]), do: true
  defp head_may_not_have_whitespace?(_), do: false

  # In case the given tag is inline and there is no white spaces in the next
  # text, we want to set mode as preserve. So this tag will not be formatted.
  defp may_set_preserve_on_block([{:tag_block, name, attrs, block, meta} | list], text)
       when name in @inline_elements do
    mode =
      if String.trim_leading(text) != "" and :binary.first(text) not in ~c"\s\t\n\r" do
        :preserve
      else
        meta.mode
      end

    [{:tag_block, name, attrs, block, %{mode: mode}} | list]
  end

  @non_ws_preserving_elements ["button"]

  defp may_set_preserve_on_block(buffer, _text), do: buffer

  defp may_set_preserve_on_text([{:text, text, meta}], :inline, tag_name)
       when tag_name not in @non_ws_preserving_elements do
    {mode, text} =
      if meta.newlines == 0 and whitespace_around?(text) do
        text =
          text
          |> cleanup_extra_spaces_leading()
          |> cleanup_extra_spaces_trailing()

        {:preserve, text}
      else
        {:normal, text}
      end

    [{:text, text, Map.put(meta, :mode, mode)}]
  end

  defp may_set_preserve_on_text(buffer, _mode, _tag_name), do: buffer

  defp whitespace_around?(text),
    do: :binary.first(text) in ~c"\s\t" or :binary.last(text) in ~c"\s\t"

  defp cleanup_extra_spaces_leading(text) do
    if :binary.first(text) in ~c"\s\t" do
      " " <> String.trim_leading(text)
    else
      text
    end
  end

  defp cleanup_extra_spaces_trailing(text) do
    if :binary.last(text) in ~c"\s\t" do
      String.trim_trailing(text) <> " "
    else
      text
    end
  end

  defp contains_special_attrs?(attrs) do
    Enum.any?(attrs, fn
      {"contenteditable", {:string, "false", _meta}, _} -> false
      {"contenteditable", _v, _} -> true
      {"phx-no-format", _v, _} -> true
      _ -> false
    end)
  end

  defp content_from_source({source, newlines}, {line_start, column_start}, {line_end, column_end}) do
    lines = Enum.slice([{0, 0} | newlines], (line_start - 1)..(line_end - 1))
    [first_line | _] = lines
    [last_line | _] = Enum.reverse(lines)

    offset_start = line_byte_offset(source, first_line, column_start)
    offset_end = line_byte_offset(source, last_line, column_end)

    binary_part(source, offset_start, offset_end - offset_start)
  end

  defp line_byte_offset(source, {line_before, line_size}, column) do
    line_offset = line_before + line_size

    line_extra =
      source
      |> binary_part(line_offset, byte_size(source) - line_offset)
      |> String.slice(0, column - 1)
      |> byte_size()

    line_offset + line_extra
  end
end
