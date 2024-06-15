defmodule Phoenix.LiveView.HTMLFormatter do
  @moduledoc """
  Format HEEx templates from `.heex` files or `~H` sigils.

  This is a `mix format` [plugin](https://hexdocs.pm/mix/main/Mix.Tasks.Format.html#module-plugins).

  > Note: The HEEx HTML Formatter requires Elixir v1.13.4 or later.

  ## Setup

  Add it as plugin to your `.formatter.exs` file and make sure to put
  the`heex` extension in the `inputs` option.

  ```elixir
  [
    plugins: [Phoenix.LiveView.HTMLFormatter],
    inputs: ["*.{heex,ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{heex,ex,exs}"],
    # ...
  ]
  ```

  > ### For umbrella projects {: .info}
  >
  > In umbrella projects you must also change two files at the umbrella root,
  > add `:phoenix_live_view` to your `deps` in the `mix.exs` file
  > and add `plugins: [Phoenix.LiveView.HTMLFormatter]` in the `.formatter.exs` file.
  > This is because the formatter does not attempt to load the dependencies of
  > all children applications.

  ### Editor support

  Most editors that support `mix format` integration should automatically format
  `.heex` and `~H` templates. Other editors may require custom integration or
  even provide additional functionality. Here are some reference posts:

    * [Formatting HEEx templates in VS Code](https://pragmaticstudio.com/tutorials/formatting-heex-templates-in-vscode)

  ## Options

    * `:line_length` - The Elixir formatter defaults to a maximum line length
      of 98 characters, which can be overwritten with the `:line_length` option
      in your `.formatter.exs` file.

    * `:heex_line_length` - change the line length only for the HEEx formatter.

      ```elixir
      [
        # ...omitted
        heex_line_length: 300
      ]
      ```

  ## Formatting

  This formatter tries to be as consistent as possible with the Elixir formatter.

  Given HTML like this:

  ```eex
    <section><h1>   <b><%= @user.name %></b></h1></section>
  ```

  It will be formatted as:

  ```eex
  <section>
    <h1><b><%= @user.name %></b></h1>
  </section>
  ```

  A block element will go to the next line, while inline elements will be kept in the current line
  as long as they fit within the configured line length.

  The following links list all block and inline elements.

  * https://developer.mozilla.org/en-US/docs/Web/HTML/Block-level_elements#elements
  * https://developer.mozilla.org/en-US/docs/Web/HTML/Inline_elements#list_of_inline_elements

  It will also keep inline elements in their own lines if you intentionally write them this way:

  ```eex
  <section>
    <h1>
      <b><%= @user.name %></b>
    </h1>
  </section>
  ```

  This formatter will place all attributes on their own lines when they do not all fit in the
  current line. Therefore this:

  ```eex
  <section id="user-section-id" class="sm:focus:block flex w-full p-3" phx-click="send-event">
    <p>Hi</p>
  </section>
  ```

  Will be formatted to:

  ```eex
  <section
    id="user-section-id"
    class="sm:focus:block flex w-full p-3"
    phx-click="send-event"
  >
    <p>Hi</p>
  </section>
  ```

  This formatter **does not** format Elixir expressions with `do...end`.
  The content within it will be formatted accordingly though. Therefore, the given
  input:

  ```eex
  <%= live_redirect(
         to: "/my/path",
    class: "my class"
  ) do %>
          My Link
  <% end %>
  ```

  Will be formatted to

  ```eex
  <%= live_redirect(
         to: "/my/path",
    class: "my class"
  ) do %>
    My Link
  <% end %>
  ```

  Note that only the text `My Link` has been formatted.

  ### Intentional new lines

  The formatter will keep intentional new lines. However, the formatter will
  always keep a maximum of one line break in case you have multiple ones:

  ```eex
  <p>
    text


    text
  </p>
  ```

  Will be formatted to:

  ```eex
  <p>
    text

    text
  </p>
  ```

  ### Inline elements

  We don't format inline elements when there is a text without whitespace before
  or after the element. Otherwise it would compromise what is rendered adding
  an extra whitespace.

  This is the list of inline elements:

  https://developer.mozilla.org/en-US/docs/Web/HTML/Inline_elements#list_of_inline_elements

  ## Skip formatting

  In case you don't want part of your HTML to be automatically formatted.
  You can use the special `phx-no-format` attribute so that the formatter will
  skip the element block. Note that this attribute will not be rendered.

  Therefore:

  ```eex
  <.textarea phx-no-format>My content</.textarea>
  ```

  Will be kept as is your code editor, but rendered as:

  ```html
  <textarea>My content</textarea>
  ```

  ## Comments

  Inline comments `<%# comment %>` are deprecated and the formatter will discard them
  silently from templates. You must change them to the multi-line comment
  `<%!-- comment --%>` on Elixir v1.14+ or introduce a space between `<%` and `#`,
  such as `<% # comment %>`.
  """

  alias Phoenix.LiveView.HTMLAlgebra
  alias Phoenix.LiveView.Tokenizer
  alias Phoenix.LiveView.Tokenizer.ParseError

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

  # Default line length to be used in case nothing is specified in the `.formatter.exs` options.
  @default_line_length 98

  @behaviour Mix.Tasks.Format

  @impl Mix.Tasks.Format
  def features(_opts) do
    [sigils: [:H], extensions: [".heex"]]
  end

  @impl Mix.Tasks.Format
  def format(source, opts) do
    line_length = opts[:heex_line_length] || opts[:line_length] || @default_line_length
    newlines = :binary.matches(source, ["\r\n", "\n"])

    formatted =
      source
      |> tokenize()
      |> to_tree([], [], {source, newlines})
      |> case do
        {:ok, nodes} ->
          nodes
          |> HTMLAlgebra.build(opts)
          |> Inspect.Algebra.format(line_length)

        {:error, line, column, message} ->
          file = opts[:file] || "nofile"
          raise ParseError, line: line, column: column, file: file, description: message
      end

    # If the opening delimiter is a single character, such as ~H"...", or the formatted code is empty,
    # do not add trailing newline.
    newline = if match?(<<_>>, opts[:opening_delimiter]) or formatted == [], do: [], else: ?\n

    # TODO: Remove IO.iodata_to_binary/1 call on Elixir v1.14+
    IO.iodata_to_binary([formatted, newline])
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

  defp to_tree([{:eex, :start_expr, expr, meta} | tokens], buffer, stack, source) do
    to_tree(tokens, [], [{:eex_block, expr, meta, buffer} | stack], source)
  end

  defp to_tree(
         [{:eex, :middle_expr, middle_expr, _meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack],
         source
       ) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr} | middle_buffer]
    to_tree(tokens, [], [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack], source)
  end

  defp to_tree(
         [{:eex, :middle_expr, middle_expr, _meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer} | stack],
         source
       ) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr}]
    to_tree(tokens, [], [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack], source)
  end

  defp to_tree(
         [{:eex, :end_expr, end_expr, _meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack],
         source
       ) do
    block = Enum.reverse([{Enum.reverse(buffer), end_expr} | middle_buffer])
    to_tree(tokens, [{:eex_block, expr, block, meta} | upper_buffer], stack, source)
  end

  defp to_tree(
         [{:eex, :end_expr, end_expr, _meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer} | stack],
         source
       ) do
    block = [{Enum.reverse(buffer), end_expr}]
    to_tree(tokens, [{:eex_block, expr, block, meta} | upper_buffer], stack, source)
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
