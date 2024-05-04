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
  alias Phoenix.LiveView.HTMLParser
  alias Phoenix.LiveView.Tokenizer.ParseError

  # Default line length to be used in case nothing is specified in the `.formatter.exs` options.
  @default_line_length 98

  if Version.match?(System.version(), ">= 1.13.0") do
    @behaviour Mix.Tasks.Format
  end

  @impl Mix.Tasks.Format
  def features(_opts) do
    [sigils: [:H], extensions: [".heex"]]
  end

  @impl Mix.Tasks.Format
  def format(source, opts) do
    line_length = opts[:heex_line_length] || opts[:line_length] || @default_line_length

    formatted =
      source
      |> HTMLParser.parse()
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
end
