defmodule Phoenix.LiveView.HTMLFormatter do
  @moduledoc """
  Format HEEx templates from `.heex` files or `~H` sigils.

  This is a `mix format` [plugin](https://hexdocs.pm/mix/main/Mix.Tasks.Format.html#module-plugins).

  ## Setup

  Add it as a plugin to your `.formatter.exs` file and make sure to put
  the `heex` extension in the `inputs` option.

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

    * `:migrate_eex_to_curly_interpolation` - Automatically migrate single expression
      `<%= ... %>` EEx expression to the curly braces one. Defaults to true.

    * `:attribute_formatters` - Specify formatters for certain attributes.

      ```elixir
      [
        plugins: [Phoenix.LiveView.HTMLFormatter],
        attribute_formatters: %{class: ClassFormatter},
      ]
      ```

    * `:inline_matcher` - a list of regular expressions to determine if a component
      should be treated as inline.
      Defaults to `["link", "button"]`, which treats any component with `link`
      or `button` in its name as inline.
      Can be disabled by setting it to an empty list.

  ## Formatting

  This formatter tries to be as consistent as possible with the Elixir formatter
  and also take into account "block" and "inline" HTML elements.

  In the past, HTML elements were categorized as either "block-level" or
  "inline". While now these concepts are specified by CSS, the historical
  distinction remains as it typically dictates the default browser rendering
  behavior. In particular, adding or removing whitespace between the start and
  end tags of a block-level element will not change the rendered output, while
  it may for inline elements.

  The following links further explain these concepts:

  * https://developer.mozilla.org/en-US/docs/Glossary/Block-level_content
  * https://developer.mozilla.org/en-US/docs/Glossary/Inline-level_content

  Given HTML like this:

  ```heex
    <section><h1>   <b>{@user.name}</b></h1></section>
  ```

  It will be formatted as:

  ```heex
  <section>
    <h1><b>{@user.name}</b></h1>
  </section>
  ```

  A block element will go to the next line, while inline elements will be kept in the current line
  as long as they fit within the configured line length.

  It will also keep inline elements in their own lines if you intentionally write them this way:

  ```heex
  <section>
    <h1>
      <b>{@user.name}</b>
    </h1>
  </section>
  ```

  This formatter will place all attributes on their own lines when they do not all fit in the
  current line. Therefore this:

  ```heex
  <section id="user-section-id" class="sm:focus:block flex w-full p-3" phx-click="send-event">
    <p>Hi</p>
  </section>
  ```

  Will be formatted to:

  ```heex
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

  ```heex
  <p>
    text


    text
  </p>
  ```

  Will be formatted to:

  ```heex
  <p>
    text

    text
  </p>
  ```

  ### Inline elements

  We don't format inline elements when there is a text without whitespace before
  or after the element. Otherwise it would compromise what is rendered adding
  an extra whitespace.

  The formatter will consider these tags as inline elements:

  - `<a>`
  - `<abbr>`
  - `<acronym>`
  - `<audio>`
  - `<b>`
  - `<bdi>`
  - `<bdo>`
  - `<big>`
  - `<br>`
  - `<button>`
  - `<canvas>`
  - `<cite>`
  - `<code>`
  - `<data>`
  - `<datalist>`
  - `<del>`
  - `<dfn>`
  - `<em>`
  - `<embed>`
  - `<i>`
  - `<iframe>`
  - `<img>`
  - `<input>`
  - `<ins>`
  - `<kbd>`
  - `<label>`
  - `<map>`
  - `<mark>`
  - `<meter>`
  - `<noscript>`
  - `<object>`
  - `<output>`
  - `<picture>`
  - `<progress>`
  - `<q>`
  - `<ruby>`
  - `<s>`
  - `<samp>`
  - `<select>`
  - `<slot>`
  - `<small>`
  - `<span>`
  - `<strong>`
  - `<sub>`
  - `<sup>`
  - `<svg>`
  - `<template>`
  - `<textarea>`
  - `<time>`
  - `<u>`
  - `<tt>`
  - `<var>`
  - `<video>`
  - `<wbr>`
  - Tags/components that match the `:inline_matcher` option.

  All other tags are considered block elements.

  ## Skip formatting

  In case you don't want part of your HTML to be automatically formatted.
  You can use the special `phx-no-format` attribute so that the formatter will
  skip the element block. Note that this attribute will not be rendered.

  Therefore:

  ```heex
  <.textarea phx-no-format>My content</.textarea>
  ```

  Will be kept as is your code editor, but rendered as:

  ```heex
  <textarea>My content</textarea>
  ```
  """

  require Logger

  alias Phoenix.LiveView.HTMLAlgebra
  alias Phoenix.LiveView.Tokenizer
  alias Phoenix.LiveView.Tokenizer.ParseError

  defguard is_tag_open(tag_type)
           when tag_type in [:slot, :remote_component, :local_component, :tag]

  # Reference for all inline elements so that we can tell the formatter to not
  # force a line break. This list has been taken from here:
  #
  # https://web.archive.org/web/20220405120608/https://developer.mozilla.org/en-US/docs/Web/HTML/Inline_elements#list_of_inline_elements
  #
  # A notable omission is `<script>`, which is handled separately in `html_algebra.ex`.
  @inline_tags ~w(a abbr acronym audio b bdi bdo big br button canvas cite
  code data datalist del dfn em embed i iframe img input ins kbd label map
  mark meter noscript object output picture progress q ruby s samp select slot
  small span strong sub sup svg template textarea time u tt var video wbr)

  # Default line length to be used in case nothing is specified in the `.formatter.exs` options.
  @default_line_length 98

  @behaviour Mix.Tasks.Format

  @impl Mix.Tasks.Format
  def features(_opts) do
    [sigils: [:H], extensions: [".heex"]]
  end

  @impl Mix.Tasks.Format
  def format(source, opts) do
    if opts[:sigil] === :H and opts[:modifiers] === ~c"noformat" do
      source
    else
      line_length = opts[:heex_line_length] || opts[:line_length] || @default_line_length
      newlines = :binary.matches(source, ["\r\n", "\n"])
      inline_matcher = opts[:inline_matcher] || ["link", "button"]

      opts =
        Keyword.update(opts, :attribute_formatters, %{}, fn formatters ->
          Enum.reduce(formatters, %{}, fn {attr, formatter}, formatters ->
            if Code.ensure_loaded?(formatter) do
              Map.put(formatters, to_string(attr), formatter)
            else
              Logger.error("module #{inspect(formatter)} is not loaded and could not be found")
              formatters
            end
          end)
        end)

      formatted =
        source
        |> tokenize()
        |> to_tree([], [], %{
          source: {source, newlines},
          inline_elements: @inline_tags,
          inline_matcher: inline_matcher
        })
        |> case do
          {:ok, nodes} ->
            nodes
            |> HTMLAlgebra.build(opts)
            |> Inspect.Algebra.format(line_length)

          {:error, line, column, message} ->
            file = Keyword.get(opts, :file, "nofile")
            raise ParseError, line: line, column: column, file: file, description: message
        end

      # If the opening delimiter is a single character, such as ~H"...", or the formatted code is empty,
      # do not add trailing newline.
      newline =
        if match?(<<_>>, opts[:opening_delimiter]) or formatted == [] or formatted == "",
          do: [],
          else: ?\n

      IO.iodata_to_binary([formatted, newline])
    end
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
  @eex_expr [:start_expr, :expr, :end_expr, :middle_expr]

  defp tokenize(source) do
    {:ok, eex_nodes} = EEx.tokenize(source)
    {tokens, cont} = Enum.reduce(eex_nodes, {[], {:text, :enabled}}, &do_tokenize(&1, &2, source))
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
  defp to_tree([], buffer, [], _opts) do
    {:ok, Enum.reverse(buffer)}
  end

  defp to_tree([], _buffer, [{name, _, %{line: line, column: column}, _} | _], _opts) do
    message = "end of template reached without closing tag for <#{name}>"
    {:error, line, column, message}
  end

  defp to_tree([{:text, text, %{context: [:comment_start]}} | tokens], buffer, stack, opts) do
    to_tree(tokens, [], [{:comment, text, buffer} | stack], opts)
  end

  defp to_tree(
         [{:text, text, %{context: [:comment_end | _rest]}} | tokens],
         buffer,
         [{:comment, start_text, upper_buffer} | stack],
         opts
       ) do
    buffer = Enum.reverse([{:text, String.trim_trailing(text), %{}} | buffer])
    text = {:text, String.trim_leading(start_text), %{}}
    to_tree(tokens, [{:html_comment, [text | buffer]} | upper_buffer], stack, opts)
  end

  defp to_tree(
         [{:text, text, %{context: [:comment_start, :comment_end]}} | tokens],
         buffer,
         stack,
         opts
       ) do
    meta = %{
      newlines_before_text: count_newlines_before_text(text),
      newlines_after_text: count_newlines_after_text(text)
    }

    to_tree(tokens, [{:html_comment, [{:text, String.trim(text), meta}]} | buffer], stack, opts)
  end

  defp to_tree([{:text, text, _meta} | tokens], buffer, stack, opts) do
    buffer = may_set_preserve_on_block(buffer, text)

    if line_html_comment?(text) do
      to_tree(tokens, [{:comment, text} | buffer], stack, opts)
    else
      meta = %{newlines: count_newlines_before_text(text)}
      to_tree(tokens, [{:text, text, meta} | buffer], stack, opts)
    end
  end

  defp to_tree([{:body_expr, value, meta} | tokens], buffer, stack, opts) do
    buffer = set_preserve_on_block(buffer)
    to_tree(tokens, [{:body_expr, value, meta} | buffer], stack, opts)
  end

  defp to_tree([{type, _name, attrs, %{closing: _} = meta} | tokens], buffer, stack, opts)
       when is_tag_open(type) do
    to_tree(tokens, [{:tag_self_close, meta.tag_name, attrs} | buffer], stack, opts)
  end

  defp to_tree([{type, _name, attrs, meta} | tokens], buffer, stack, opts)
       when is_tag_open(type) do
    to_tree(tokens, [], [{meta.tag_name, attrs, meta, buffer} | stack], opts)
  end

  defp to_tree(
         [{:close, _type, _name, close_meta} | tokens],
         reversed_buffer,
         [{tag_name, attrs, open_meta, upper_buffer} | stack],
         opts
       ) do
    {mode, block} =
      cond do
        tag_name in ["pre", "textarea"] or contains_special_attrs?(attrs) ->
          content =
            content_from_source(opts.source, open_meta.inner_location, close_meta.inner_location)

          {:preserve, [{:text, content, %{newlines: 0}}]}

        preceeded_by_non_white_space?(upper_buffer) ->
          {:preserve, Enum.reverse(reversed_buffer)}

        inline?(tag_name, opts.inline_elements, opts.inline_matcher) ->
          {:inline,
           reversed_buffer
           |> may_set_preserve_on_text(:last)
           |> Enum.reverse()
           |> may_set_preserve_on_text(:first)}

        true ->
          {:block, Enum.reverse(reversed_buffer)}
      end

    tag_block = {:tag_block, tag_name, attrs, block, %{mode: mode}}
    to_tree(tokens, [tag_block | upper_buffer], stack, opts)
  end

  # handle eex

  defp to_tree([{:eex_comment, text, _meta} | tokens], buffer, stack, opts) do
    to_tree(tokens, [{:eex_comment, text} | buffer], stack, opts)
  end

  defp to_tree([{:eex, :start_expr, expr, meta} | tokens], buffer, stack, opts) do
    to_tree(tokens, [], [{:eex_block, expr, meta, buffer} | stack], opts)
  end

  defp to_tree(
         [{:eex, :middle_expr, middle_expr, _meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack],
         opts
       ) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr} | middle_buffer]
    to_tree(tokens, [], [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack], opts)
  end

  defp to_tree(
         [{:eex, :middle_expr, middle_expr, _meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer} | stack],
         opts
       ) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr}]
    to_tree(tokens, [], [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack], opts)
  end

  defp to_tree(
         [{:eex, :end_expr, end_expr, _meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack],
         opts
       ) do
    block = Enum.reverse([{Enum.reverse(buffer), end_expr} | middle_buffer])
    to_tree(tokens, [{:eex_block, expr, block, meta} | upper_buffer], stack, opts)
  end

  defp to_tree(
         [{:eex, :end_expr, end_expr, _meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer} | stack],
         opts
       ) do
    block = [{Enum.reverse(buffer), end_expr}]
    to_tree(tokens, [{:eex_block, expr, block, meta} | upper_buffer], stack, opts)
  end

  defp to_tree([{:eex, _type, expr, meta} | tokens], buffer, stack, opts) do
    buffer = set_preserve_on_block(buffer)
    to_tree(tokens, [{:eex, expr, meta} | buffer], stack, opts)
  end

  # -- HELPERS

  defp inline?(tag_name, inline_elements, inline_matcher) do
    tag_name in inline_elements or
      Enum.any?(inline_matcher, &(tag_name =~ &1))
  end

  defp count_newlines_before_text(binary),
    do: count_newlines_until_text(binary, 0, 0, 1)

  defp count_newlines_after_text(binary),
    do: count_newlines_until_text(binary, 0, byte_size(binary) - 1, -1)

  defp count_newlines_until_text(binary, counter, pos, inc) do
    try do
      :binary.at(binary, pos)
    rescue
      _ -> counter
    else
      char when char in [?\s, ?\t] -> count_newlines_until_text(binary, counter, pos + inc, inc)
      ?\n -> count_newlines_until_text(binary, counter + 1, pos + inc, inc)
      _ -> counter
    end
  end

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

  # In case the opening tag is immediately preceeded by non whitespace text,
  # or an interpolation, we will set it as preserve.
  defp preceeded_by_non_white_space?([{:text, text, _meta} | _]),
    do: String.trim_leading(text) != "" and :binary.last(text) not in ~c"\s\t\n\r"

  defp preceeded_by_non_white_space?([{:body_expr, _, _} | _]), do: true
  defp preceeded_by_non_white_space?([{:eex, _, _} | _]), do: true
  defp preceeded_by_non_white_space?(_), do: false

  # In case the closing tag is immediatelly followed by non whitespace text,
  # we want to set mode as preserve.
  defp may_set_preserve_on_block([{:tag_block, name, attrs, block, meta} | list], text) do
    mode =
      if String.trim_leading(text) != "" and :binary.first(text) not in ~c"\s\t\n\r" do
        :preserve
      else
        meta.mode
      end

    [{:tag_block, name, attrs, block, %{meta | mode: mode}} | list]
  end

  defp may_set_preserve_on_block(buffer, _text), do: buffer

  # Set preserve on block when it is immediately followed by interpolation.
  defp set_preserve_on_block([{:tag_block, name, attrs, block, meta} | list]) do
    [{:tag_block, name, attrs, block, %{meta | mode: :preserve}} | list]
  end

  defp set_preserve_on_block(buffer), do: buffer

  defp may_set_preserve_on_text([{:text, text, meta} | buffer], where) do
    {meta, text} =
      if whitespace_around?(text, where) do
        {Map.put(meta, :mode, :preserve), cleanup_extra_spaces(text, where)}
      else
        {meta, text}
      end

    [{:text, text, meta} | buffer]
  end

  defp may_set_preserve_on_text(buffer, _where), do: buffer

  defp whitespace_around?(text, :first) do
    :binary.first(text) in ~c"\s\t" and count_newlines_before_text(text) == 0
  end

  defp whitespace_around?(text, :last) do
    :binary.last(text) in ~c"\s\t" and count_newlines_after_text(text) == 0
  end

  defp cleanup_extra_spaces(text, :first) do
    " " <> String.trim_leading(text)
  end

  defp cleanup_extra_spaces(text, :last) do
    String.trim_trailing(text) <> " "
  end

  defp contains_special_attrs?(attrs) do
    Enum.any?(attrs, fn
      {"contenteditable", {:string, "false", _meta}, _} -> false
      {"contenteditable", _v, _} -> true
      {"phx-no-format", _v, _} -> true
      _ -> false
    end)
  end

  defp content_from_source(
         {source, newlines},
         {line_start, column_start},
         {line_end, column_end}
       ) do
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
