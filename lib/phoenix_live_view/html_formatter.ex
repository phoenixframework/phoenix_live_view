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
  alias Phoenix.LiveView.TagEngine.Parser
  alias Phoenix.LiveView.TagEngine.Tokenizer.ParseError

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
        |> Parser.parse(
          tag_handler: Phoenix.LiveView.HTMLEngine,
          file: "nofile",
          skip_macro_components: true,
          prune_text_after_slots: false,
          process_buffer: &process_buffer/1
        )
        |> case do
          {:ok, result} ->
            result.nodes
            |> transform_tree(source, newlines)
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

  # Buffer processing callback for Parser - handles preserve mode propagation and text metadata
  defp process_buffer([{:text, text, meta} | rest]) do
    rest = may_set_preserve_on_block(rest, text)

    meta =
      meta
      |> Map.put_new(:newlines_before_text, count_newlines_before_text(text))
      |> Map.put_new(:newlines_after_text, count_newlines_after_text(text))

    [{:text, text, meta} | rest]
  end

  defp process_buffer([{:body_expr, _, _} = node | rest]) do
    [node | set_preserve_on_block(rest)]
  end

  defp process_buffer([{:eex, _, _} = node | rest]) do
    [node | set_preserve_on_block(rest)]
  end

  defp process_buffer(buffer), do: buffer

  # In case the closing tag is immediately followed by non-whitespace text,
  # we want to set mode as preserve.
  defp may_set_preserve_on_block(
         [{:block, type, name, attrs, block, meta, close_meta} | rest],
         text
       ) do
    mode =
      if String.trim_leading(text) != "" and :binary.first(text) not in ~c"\s\t\n\r" do
        :preserve
      else
        Map.get(meta, :mode, :normal)
      end

    [{:block, type, name, attrs, block, Map.put(meta, :mode, mode), close_meta} | rest]
  end

  defp may_set_preserve_on_block(buffer, _text), do: buffer

  # Set preserve on block when it is immediately followed by interpolation.
  defp set_preserve_on_block([{:block, type, name, attrs, block, meta, close_meta} | rest]) do
    [{:block, type, name, attrs, block, Map.put(meta, :mode, :preserve), close_meta} | rest]
  end

  defp set_preserve_on_block(buffer), do: buffer

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

  # Tree transformation - augments Parser output with formatter metadata
  defp transform_tree(nodes, source, newlines) do
    state = %{source: {source, newlines}}
    augment_nodes(nodes, state)
  end

  # Augment nodes with formatter-specific metadata
  defp augment_nodes(nodes, state) when is_list(nodes) do
    nodes
    |> reduce_html_comments([])
    |> Enum.map(&augment_node(&1, state))
  end

  # Group text nodes with :comment_start/:comment_end context into {:html_comment, block}
  defp reduce_html_comments([], acc), do: Enum.reverse(acc)

  # Single node that is both comment start and end
  defp reduce_html_comments(
         [{:text, text, %{context: [:comment_start, :comment_end]}} | rest],
         acc
       ) do
    meta = %{
      newlines_before_text: count_newlines_before_text(text),
      newlines_after_text: count_newlines_after_text(text)
    }

    comment = {:html_comment, [{:text, String.trim(text), meta}]}
    reduce_html_comments(rest, [comment | acc])
  end

  # Comment start - begin accumulating comment content
  defp reduce_html_comments(
         [{:text, text, %{context: [:comment_start]}} | rest],
         acc
       ) do
    collect_comment(rest, [{:text, String.trim_leading(text), %{}}], acc)
  end

  # Regular node - pass through
  defp reduce_html_comments([node | rest], acc) do
    reduce_html_comments(rest, [node | acc])
  end

  # Collect comment content until we hit comment_end
  defp collect_comment(
         [{:text, text, %{context: [:comment_end | _rest]}} | rest],
         comment_buffer,
         acc
       ) do
    meta = %{
      newlines_before_text: count_newlines_before_text(text),
      newlines_after_text: count_newlines_after_text(text)
    }

    end_text = {:text, String.trim_trailing(text), meta}
    block = Enum.reverse([end_text | comment_buffer])
    comment = {:html_comment, block}
    reduce_html_comments(rest, [comment | acc])
  end

  defp collect_comment([node | rest], comment_buffer, acc) do
    collect_comment(rest, [node | comment_buffer], acc)
  end

  # Handle block tags - add mode and recursively augment children
  defp augment_node({:block, type, name, attrs, children, meta, close_meta}, state) do
    tag_name = meta.tag_name
    mode = determine_mode(tag_name, attrs, meta)

    {children, meta} =
      if mode == :preserve do
        content =
          content_from_source(state.source, meta.inner_location, close_meta.inner_location)

        {[{:text, content, %{newlines_before_text: 0, newlines_after_text: 0}}],
         Map.put(meta, :mode, :preserve)}
      else
        {augment_nodes(children, state), Map.put(meta, :mode, :normal)}
      end

    {:block, type, name, attrs, children, meta, close_meta}
  end

  # Recursively augment eex_block children
  defp augment_node({:eex_block, expr, blocks, meta}, state) do
    blocks =
      Enum.map(blocks, fn {children, clause, clause_meta} ->
        {augment_nodes(children, state), clause, clause_meta}
      end)

    {:eex_block, expr, blocks, meta}
  end

  # html_comment - recursively augment block content
  defp augment_node({:html_comment, block}, state) do
    {:html_comment, augment_nodes(block, state)}
  end

  # Pass through other node types
  defp augment_node(node, _state), do: node

  # Determine mode based on tag name, attributes, and existing meta
  defp determine_mode(tag_name, attrs, meta) do
    cond do
      Map.get(meta, :mode) == :preserve -> :preserve
      tag_name in ["pre", "textarea"] -> :preserve
      contains_special_attrs?(attrs) -> :preserve
      true -> :normal
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

  # Extract content from source between two locations
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
