defmodule Phoenix.LiveView.HTMLTokenizer do
  @moduledoc false
  @space_chars '\s\t\f'
  @quote_chars '"\''
  @stop_chars '>/=\r\n' ++ @quote_chars ++ @space_chars

  defmodule ParseError do
    @moduledoc false
    defexception [:file, :line, :column, :description]

    @impl true
    def message(exception) do
      location =
        exception.file
        |> Path.relative_to_cwd()
        |> format_file_line_column(exception.line, exception.column)

      "#{location} #{exception.description}"
    end

    # Use Exception.format_file_line_column/4 instead when support
    # for Elixir < v1.11 is removed.
    def format_file_line_column(file, line, column, suffix \\ "") do
      cond do
        is_nil(file) -> ""
        is_nil(line) or line == 0 -> "#{file}:#{suffix}"
        is_nil(column) or column == 0 -> "#{file}:#{line}:#{suffix}"
        true -> "#{file}:#{line}:#{column}:#{suffix}"
      end
    end
  end

  def finalize(_tokens, file, {:comment, line, column}) do
    message = "expected closing `-->` for comment"
    raise ParseError, file: file, line: line, column: column, description: message
  end

  def finalize(tokens, _file, _cont) do
    tokens
    |> strip_text_token_fully()
    |> Enum.reverse()
    |> strip_text_token_fully()
  end

  def tokenize(text, file, indentation, meta, tokens, cont) do
    line = Keyword.get(meta, :line, 1)
    column = Keyword.get(meta, :column, 1)
    state = %{file: file, column_offset: indentation + 1, braces: []}

    case cont do
      :text -> handle_text(text, line, column, [], tokens, state)
      :script -> handle_script(text, line, column, [], tokens, state)
      {:comment, _, _} -> handle_comment(text, line, column, [], tokens, state)
    end
  end

  ## handle_text

  defp handle_text("\r\n" <> rest, line, _column, buffer, acc, state) do
    handle_text(rest, line + 1, state.column_offset, ["\r\n" | buffer], acc, state)
  end

  defp handle_text("\n" <> rest, line, _column, buffer, acc, state) do
    handle_text(rest, line + 1, state.column_offset, ["\n" | buffer], acc, state)
  end

  defp handle_text("<!doctype" <> rest, line, column, buffer, acc, state) do
    handle_doctype(rest, line, column + 9, ["<!doctype" | buffer], acc, state)
  end

  defp handle_text("<!DOCTYPE" <> rest, line, column, buffer, acc, state) do
    handle_doctype(rest, line, column + 9, ["<!DOCTYPE" | buffer], acc, state)
  end

  defp handle_text("<!--" <> rest, line, column, buffer, acc, state) do
    handle_comment(rest, line, column + 4, ["<!--" | buffer], acc, state)
  end

  defp handle_text("</" <> rest, line, column, buffer, acc, state) do
    handle_tag_close(rest, line, column + 2, text_to_acc(buffer, acc, line, column), state)
  end

  defp handle_text("<" <> rest, line, column, buffer, acc, state) do
    handle_tag_open(rest, line, column + 1, text_to_acc(buffer, acc, line, column), state)
  end

  defp handle_text(<<c::utf8, rest::binary>>, line, column, buffer, acc, state) do
    handle_text(rest, line, column + 1, [char_or_bin(c) | buffer], acc, state)
  end

  defp handle_text(<<>>, line, column, buffer, acc, _state) do
    ok(text_to_acc(buffer, acc, line, column), :text)
  end

  ## handle_doctype

  defp handle_doctype(<<?>, rest::binary>>, line, column, buffer, acc, state) do
    handle_text(rest, line, column + 1, [?> | buffer], acc, state)
  end

  defp handle_doctype("\r\n" <> rest, line, _column, buffer, acc, state) do
    handle_doctype(rest, line + 1, state.column_offset, ["\r\n" | buffer], acc, state)
  end

  defp handle_doctype("\n" <> rest, line, _column, buffer, acc, state) do
    handle_doctype(rest, line + 1, state.column_offset, ["\n" | buffer], acc, state)
  end

  defp handle_doctype(<<c::utf8, rest::binary>>, line, column, buffer, acc, state) do
    handle_doctype(rest, line, column + 1, [char_or_bin(c) | buffer], acc, state)
  end

  ## handle_script

  defp handle_script("</script>" <> rest, line, column, buffer, acc, state) do
    acc = [
      {:tag_close, "script", %{line: line, column: column}}
      | text_to_acc(buffer, acc, line, column)
    ]

    handle_text(rest, line, column + 9, [], acc, state)
  end

  defp handle_script("\r\n" <> rest, line, _column, buffer, acc, state) do
    handle_script(rest, line + 1, state.column_offset, ["\r\n" | buffer], acc, state)
  end

  defp handle_script("\n" <> rest, line, _column, buffer, acc, state) do
    handle_script(rest, line + 1, state.column_offset, ["\n" | buffer], acc, state)
  end

  defp handle_script(<<c::utf8, rest::binary>>, line, column, buffer, acc, state) do
    handle_script(rest, line, column + 1, [char_or_bin(c) | buffer], acc, state)
  end

  defp handle_script(<<>>, line, column, buffer, acc, _state) do
    ok(text_to_acc(buffer, acc, line, column), :script)
  end

  ## handle_comment

  defp handle_comment("\r\n" <> rest, line, _column, buffer, acc, state) do
    handle_comment(rest, line + 1, state.column_offset, ["\r\n" | buffer], acc, state)
  end

  defp handle_comment("\n" <> rest, line, _column, buffer, acc, state) do
    handle_comment(rest, line + 1, state.column_offset, ["\n" | buffer], acc, state)
  end

  defp handle_comment("-->" <> rest, line, column, buffer, acc, state) do
    handle_text(rest, line, column + 3, ["-->" | buffer], acc, state)
  end

  defp handle_comment(<<c::utf8, rest::binary>>, line, column, buffer, acc, state) do
    handle_comment(rest, line, column + 1, [char_or_bin(c) | buffer], acc, state)
  end

  defp handle_comment(<<>>, line, column, buffer, acc, _state) do
    ok(text_to_acc(buffer, acc, line, column), {:comment, line, column})
  end

  ## handle_tag_open

  defp handle_tag_open(text, line, column, acc, state) do
    case handle_tag_name(text, column, []) do
      {:ok, name, new_column, rest} ->
        acc = if strip_tag?(name), do: strip_text_token_partially(acc), else: acc
        acc = [{:tag_open, name, [], %{line: line, column: column - 1}} | acc]
        handle_maybe_tag_open_end(rest, line, new_column, acc, state)

      {:error, message} ->
        raise ParseError, file: state.file, line: line, column: column, description: message
    end
  end

  ## handle_tag_close

  defp handle_tag_close(text, line, column, acc, state) do
    case handle_tag_name(text, column, []) do
      {:ok, name, new_column, ">" <> rest} ->
        acc = [{:tag_close, name, %{line: line, column: column - 2}} | acc]
        rest = if strip_tag?(name), do: String.trim_leading(rest), else: rest
        handle_text(rest, line, new_column + 1, [], acc, state)

      {:ok, _, new_column, _} ->
        message = "expected closing `>`"
        raise ParseError, file: state.file, line: line, column: new_column, description: message

      {:error, message} ->
        raise ParseError, file: state.file, line: line, column: column, description: message
    end
  end

  ## handle_tag_name

  defp handle_tag_name(<<c::utf8, _rest::binary>> = text, column, buffer)
       when c in @stop_chars do
    done_tag_name(text, column, buffer)
  end

  defp handle_tag_name(<<c::utf8, rest::binary>>, column, buffer) do
    handle_tag_name(rest, column + 1, [char_or_bin(c) | buffer])
  end

  defp handle_tag_name(<<>>, column, buffer) do
    done_tag_name(<<>>, column, buffer)
  end

  defp done_tag_name(_text, _column, []) do
    {:error, "expected tag name"}
  end

  defp done_tag_name(text, column, buffer) do
    {:ok, buffer_to_string(buffer), column, text}
  end

  ## handle_maybe_tag_open_end

  defp handle_maybe_tag_open_end("\r\n" <> rest, line, _column, acc, state) do
    handle_maybe_tag_open_end(rest, line + 1, state.column_offset, acc, state)
  end

  defp handle_maybe_tag_open_end("\n" <> rest, line, _column, acc, state) do
    handle_maybe_tag_open_end(rest, line + 1, state.column_offset, acc, state)
  end

  defp handle_maybe_tag_open_end(<<c::utf8, rest::binary>>, line, column, acc, state)
       when c in @space_chars do
    handle_maybe_tag_open_end(rest, line, column + 1, acc, state)
  end

  defp handle_maybe_tag_open_end("/>" <> rest, line, column, acc, state) do
    acc = reverse_attrs(acc)
    handle_text(rest, line, column + 2, [], put_self_close(acc), state)
  end

  defp handle_maybe_tag_open_end(">" <> rest, line, column, acc, state) do
    case reverse_attrs(acc) do
      [{:tag_open, "script", _, _} | _] = acc ->
        handle_script(rest, line, column + 1, [], acc, state)

      acc ->
        handle_text(rest, line, column + 1, [], acc, state)
    end
  end

  defp handle_maybe_tag_open_end("{" <> rest, line, column, acc, state) do
    handle_root_attribute(rest, line, column + 1, acc, state)
  end

  defp handle_maybe_tag_open_end(<<>>, line, column, _acc, state) do
    message = ~S"""
    expected closing `>` or `/>`

    Make sure the tag is properly closed. This may happen if there
    is an EEx interpolation inside a tag, which is not supported.
    For instance, instead of

        <div id="<%= @id %>">Content</div>

    do

        <div id={@id}>Content</div>

    If @id is nil or false, then no attribute is sent at all.

    Inside {...} you can place any Elixir expression. If you want
    to interpolate in the middle of an attribute value, instead of

        <a class="foo bar <%= @class %>">Text</a>

    you can pass an Elixir string with interpolation:

        <a class={"foo bar #{@class}"}>Text</a>
    """

    raise ParseError, file: state.file, line: line, column: column, description: message
  end

  defp handle_maybe_tag_open_end(text, line, column, acc, state) do
    handle_attribute(text, line, column, acc, state)
  end

  ## handle_attribute

  defp handle_attribute(text, line, column, acc, state) do
    case handle_attr_name(text, column, []) do
      {:ok, name, new_column, rest} ->
        acc = put_attr(acc, name)
        handle_maybe_attr_value(rest, line, new_column, acc, state)

      {:error, message, column} ->
        raise ParseError, file: state.file, line: line, column: column, description: message
    end
  end

  ## handle_root_attribute

  defp handle_root_attribute(text, line, column, acc, state) do
    case handle_interpolation(text, line, column, [], state) do
      {:ok, value, new_line, new_column, rest, state} ->
        acc = put_attr(acc, :root, {:expr, value, %{line: line, column: column}})
        handle_maybe_tag_open_end(rest, new_line, new_column, acc, state)

      {:error, message, line, column} ->
        raise ParseError, file: state.file, line: line, column: column, description: message
    end
  end

  ## handle_attr_name

  defp handle_attr_name(<<c::utf8, _rest::binary>>, column, _buffer)
       when c in @quote_chars do
    {:error, "invalid character in attribute name: #{<<c>>}", column}
  end

  defp handle_attr_name(<<c::utf8, _rest::binary>>, column, [])
       when c in @stop_chars do
    {:error, "expected attribute name", column}
  end

  defp handle_attr_name(<<c::utf8, _rest::binary>> = text, column, buffer)
       when c in @stop_chars do
    {:ok, buffer_to_string(buffer), column, text}
  end

  defp handle_attr_name(<<c::utf8, rest::binary>>, column, buffer) do
    handle_attr_name(rest, column + 1, [char_or_bin(c) | buffer])
  end

  ## handle_maybe_attr_value

  defp handle_maybe_attr_value("\r\n" <> rest, line, _column, acc, state) do
    handle_maybe_attr_value(rest, line + 1, state.column_offset, acc, state)
  end

  defp handle_maybe_attr_value("\n" <> rest, line, _column, acc, state) do
    handle_maybe_attr_value(rest, line + 1, state.column_offset, acc, state)
  end

  defp handle_maybe_attr_value(<<c::utf8, rest::binary>>, line, column, acc, state)
       when c in @space_chars do
    handle_maybe_attr_value(rest, line, column + 1, acc, state)
  end

  defp handle_maybe_attr_value("=" <> rest, line, column, acc, state) do
    handle_attr_value_begin(rest, line, column + 1, acc, state)
  end

  defp handle_maybe_attr_value(text, line, column, acc, state) do
    handle_maybe_tag_open_end(text, line, column, acc, state)
  end

  ## handle_attr_value_begin

  defp handle_attr_value_begin("\r\n" <> rest, line, _column, acc, state) do
    handle_attr_value_begin(rest, line + 1, state.column_offset, acc, state)
  end

  defp handle_attr_value_begin("\n" <> rest, line, _column, acc, state) do
    handle_attr_value_begin(rest, line + 1, state.column_offset, acc, state)
  end

  defp handle_attr_value_begin(<<c::utf8, rest::binary>>, line, column, acc, state)
       when c in @space_chars do
    handle_attr_value_begin(rest, line, column + 1, acc, state)
  end

  defp handle_attr_value_begin("\"" <> rest, line, column, acc, state) do
    handle_attr_value_quote(rest, ?", line, column + 1, [], acc, state)
  end

  defp handle_attr_value_begin("'" <> rest, line, column, acc, state) do
    handle_attr_value_quote(rest, ?', line, column + 1, [], acc, state)
  end

  defp handle_attr_value_begin("{" <> rest, line, column, acc, state) do
    handle_attr_value_as_expr(rest, line, column + 1, acc, state)
  end

  defp handle_attr_value_begin(_text, line, column, _acc, state) do
    message =
      "invalid attribute value after `=`. Expected either a value between quotes " <>
        "(such as \"value\" or \'value\') or an Elixir expression between curly brackets (such as `{expr}`)"

    raise ParseError, file: state.file, line: line, column: column, description: message
  end

  ## handle_attr_value_quote

  defp handle_attr_value_quote("\r\n" <> rest, delim, line, _column, buffer, acc, state) do
    column = state.column_offset
    handle_attr_value_quote(rest, delim, line + 1, column, ["\r\n" | buffer], acc, state)
  end

  defp handle_attr_value_quote("\n" <> rest, delim, line, _column, buffer, acc, state) do
    column = state.column_offset
    handle_attr_value_quote(rest, delim, line + 1, column, ["\n" | buffer], acc, state)
  end

  defp handle_attr_value_quote(<<delim, rest::binary>>, delim, line, column, buffer, acc, state) do
    value = buffer_to_string(buffer)
    acc = put_attr_value(acc, {:string, value, %{delimiter: delim}})
    handle_maybe_tag_open_end(rest, line, column + 1, acc, state)
  end

  defp handle_attr_value_quote(<<c::utf8, rest::binary>>, delim, line, column, buffer, acc, state) do
    handle_attr_value_quote(rest, delim, line, column + 1, [char_or_bin(c) | buffer], acc, state)
  end

  defp handle_attr_value_quote(<<>>, delim, line, column, _buffer, _acc, state) do
    message = """
    expected closing `#{<<delim>>}` for attribute value

    Make sure the attribute is properly closed. This may also happen if
    there is an EEx interpolation inside a tag, which is not supported.
    Instead of

        <div <%= @some_attributes %>>
        </div>

    do

        <div {@some_attributes}>
        </div>

    Where @some_attributes must be a keyword list or a map.
    """

    raise ParseError, file: state.file, line: line, column: column, description: message
  end

  ## handle_attr_value_as_expr

  defp handle_attr_value_as_expr(text, line, column, acc, %{braces: []} = state) do
    case handle_interpolation(text, line, column, [], state) do
      {:ok, value, new_line, new_column, rest, state} ->
        acc = put_attr_value(acc, {:expr, value, %{line: line, column: column}})
        handle_maybe_tag_open_end(rest, new_line, new_column, acc, state)

      {:error, message, line, column} ->
        raise ParseError, file: state.file, line: line, column: column, description: message
    end
  end

  ## handle_interpolation

  defp handle_interpolation("\r\n" <> rest, line, _column, buffer, state) do
    handle_interpolation(rest, line + 1, state.column_offset, ["\r\n" | buffer], state)
  end

  defp handle_interpolation("\n" <> rest, line, _column, buffer, state) do
    handle_interpolation(rest, line + 1, state.column_offset, ["\n" | buffer], state)
  end

  defp handle_interpolation("}" <> rest, line, column, buffer, %{braces: []} = state) do
    value = buffer_to_string(buffer)
    {:ok, value, line, column + 1, rest, state}
  end

  defp handle_interpolation(~S(\}) <> rest, line, column, buffer, state) do
    handle_interpolation(rest, line, column + 2, [~S(\}) | buffer], state)
  end

  defp handle_interpolation(~S(\{) <> rest, line, column, buffer, state) do
    handle_interpolation(rest, line, column + 2, [~S(\{) | buffer], state)
  end

  defp handle_interpolation("}" <> rest, line, column, buffer, state) do
    {_pos, state} = pop_brace(state)
    handle_interpolation(rest, line, column + 1, ["}" | buffer], state)
  end

  defp handle_interpolation("{" <> rest, line, column, buffer, state) do
    state = push_brace(state, {line, column})
    handle_interpolation(rest, line, column + 1, ["{" | buffer], state)
  end

  defp handle_interpolation(<<c::utf8, rest::binary>>, line, column, buffer, state) do
    handle_interpolation(rest, line, column + 1, [char_or_bin(c) | buffer], state)
  end

  defp handle_interpolation(<<>>, line, column, _buffer, _state) do
    {:error, "expected closing `}` for expression", line, column}
  end

  ## helpers

  @compile {:inline, ok: 2, char_or_bin: 1}
  defp ok(acc, cont), do: {acc, cont}

  defp char_or_bin(c) when c <= 127, do: c
  defp char_or_bin(c), do: <<c::utf8>>

  defp buffer_to_string(buffer) do
    IO.iodata_to_binary(Enum.reverse(buffer))
  end

  defp text_to_acc([], acc, _line, _column),
    do: acc

  defp text_to_acc(buffer, acc, line, column),
    do: [{:text, buffer_to_string(buffer), %{line_end: line, column_end: column}} | acc]

  defp put_attr([{:tag_open, name, attrs, meta} | acc], attr, value \\ nil) do
    attrs = [{attr, value} | attrs]
    [{:tag_open, name, attrs, meta} | acc]
  end

  defp put_attr_value([{:tag_open, name, [{attr, _value} | attrs], meta} | acc], value) do
    attrs = [{attr, value} | attrs]
    [{:tag_open, name, attrs, meta} | acc]
  end

  defp reverse_attrs([{:tag_open, name, attrs, meta} | acc]) do
    attrs = Enum.reverse(attrs)
    [{:tag_open, name, attrs, meta} | acc]
  end

  defp put_self_close([{:tag_open, name, attrs, meta} | acc]) do
    meta = Map.put(meta, :self_close, true)
    [{:tag_open, name, attrs, meta} | acc]
  end

  defp push_brace(state, pos) do
    %{state | braces: [pos | state.braces]}
  end

  defp pop_brace(%{braces: [pos | braces]} = state) do
    {pos, %{state | braces: braces}}
  end

  # Strip space before slots
  defp strip_tag?(":" <> _), do: true
  defp strip_tag?(_), do: false

  defp strip_text_token_fully(tokens) do
    with [{:text, text, _} | rest] <- tokens,
         "" <- String.trim_leading(text) do
      strip_text_token_fully(rest)
    else
      _ -> tokens
    end
  end

  defp strip_text_token_partially(tokens) do
    with [{:text, text, meta} | rest] <- tokens do
      case String.trim_leading(text) do
        "" -> strip_text_token_partially(rest)
        text -> [{:text, text, meta} | rest]
      end
    else
      _ -> tokens
    end
  end
end
