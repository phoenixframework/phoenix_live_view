defmodule Phoenix.Component.MacroComponent do
  @moduledoc false

  #   A macro component is a special type of component that can modify its content
  #   at compile time.
  #
  #   Instead of introducing a special tag syntax like `<#macro-component>`, LiveView
  #   implements them using a special `:type` attribute as the most useful macro
  #   components take their content and extract it to somewhere else, for example
  #   to a file in the local file system. A good example for this is `Phoenix.LiveView.ColocatedHook`
  #   and `Phoenix.LiveView.ColocatedJS`.
  #
  #   ## AST
  #
  #   Macro components work by defining a callback module that implements the
  #   `Phoenix.LiveView.MacroComponent` behaviour. The module's `c:transform/2` callback
  #   is called for each macro component used while LiveView compiles a HEEx component:
  #
  #   ```heex
  #   <div id="hey" phx-hook=".foo">
  #     <!-- content -->
  #   </div>
  #
  #   <script :type={ColocatedHook} name=".foo">
  #     export default {
  #       mounted() {
  #         this.el.firstElementChild.textContent = "Hello from JS!"
  #       }
  #     }
  #   </script>
  #   ```
  #
  #   In this example, the `ColocatedHook`'s `c:transform/2` callback will be invoked
  #   with the AST of the `<script>` tag:
  #
  #   ```elixir
  #   {"script",
  #     [{"name", ".foo"}],
  #     [
  #       "\\n  export default {\\n    mounted() {\\n      this.el.firstElementChild.textContent = \\"Hello from JS!\\"\\n    }\\n  }\\n"
  #     ]}
  #   ```
  #
  #   This module provides some utilities to work with the AST, which uses
  #   standard Elixir data structures:
  #
  #   1. A HTML tag is represented as `{tag, attributes, children, meta}`
  #   2. Text is represented as a plain binary
  #   3. Attributes are represented as a list of `{key, value}` tuples where
  #      the value is an Elixir AST (which can be a plain binary for simple attributes)
  #
  #   > #### Limitations {: .warning}
  #   > The AST is not whitespace preserving. When using macro components,
  #   > the original whitespace between attributes is lost.
  #   >
  #   > Also, macro components can currently only contain simple HTML. Any interpolation
  #   > like `<%= @foo %>` or components inside are not supported.
  #
  #   ## Example: a compile-time markdown renderer
  #
  #   Let's say we want to create a macro component that renders markdown as HTML at
  #   compile time. First, we need some library that actually converts the markdown to
  #   HTML. For this example, we use [`mdex`](https://hex.pm/packages/mdex).
  #
  #   We start by defining the module for the macro component:
  #
  #   ```elixir
  #   defmodule MyAppWeb.MarkdownComponent do
  #     @behaviour Phoenix.Component.MacroComponent
  #
  #     @impl true
  #     def transform({"pre", attrs, children}, _meta) do
  #       markdown = Phoenix.Component.MacroComponent.to_string(children)
  #       html_doc = MDEx.to_html!(markdown)
  #
  #       {:ok, {"div", attrs, [html_doc]}}
  #     end
  #   end
  #   ```
  #
  #   That's it. Since the div could contain nested elements, for example when using
  #   an HTML code block, we need to convert the children to a string first, using the
  #   `Phoenix.Component.MacroComponent.ast_to_string/1` function.
  #
  #   Then, we can simply replace the element's contents with the returned HTML string from
  #   MDEx.
  #
  #   We can now use the macro component inside our HEEx templates:
  #
  #       defmodule MyAppWeb.ExampleLiveView do
  #         use MyAppWeb, :live_view
  #
  #         def render(assigns) do
  #           ~H\"\"\"
  #           <pre :type={MyAppWeb.MarkdownComponent} class="prose mt-8">
  #           ## Hello World
  #
  #           This is some markdown!
  #
  #           ```elixir
  #           defmodule Hello do
  #             def world do
  #               IO.puts "Hello, world!"
  #             end
  #           end
  #           ```
  #           </pre>
  #           \"\"\"
  #         end
  #       end
  #
  #   Note: this example uses the `prose` class from TailwindCSS for styling.
  #
  #   One trick to prevent issues with extra whitespace is that we use a `<pre>` tag in the LiveView
  #   template, which prevents the `Phoenix.LiveView.HTMLFormatter` from indenting the contents, which
  #   would mess with the markdown parsing. When rendering, we replace it with a `<div>` tag in the
  #   macro component.
  #
  #   Another example for a macro component that transforms its content is available in
  #   LiveView's end to end tests: a macro component that performs
  #   [syntax highlighting at compile time](https://github.com/phoenixframework/phoenix_live_view/blob/38851d943f3280c5982d75679291dccb8c442534/test/e2e/support/colocated_live.ex#L4-L35)
  #   using the [Makeup](https://hexdocs.pm/makeup/Makeup.html) library.

  @type tag :: binary()
  @type attribute :: {binary(), Macro.t()}
  @type attributes :: [attribute()]
  @type children :: [heex_ast()]
  @type tag_meta :: %{closing: :self | :void}
  @type heex_ast :: {tag(), attributes(), children(), tag_meta()} | binary()
  @type transform_meta :: %{env: Macro.Env.t()}

  @callback transform(heex_ast :: heex_ast(), meta :: transform_meta()) ::
              {:ok, heex_ast()} | {:ok, heex_ast(), data :: term()}

  @doc """
  Returns the stored data from macro components that returned `{:ok, ast, data}`.

  As one macro component can be used multiple times in one module, the result is a list of all data values.

  If the component module does not have any macro components defined, an empty list is returned.
  """
  @spec get_data(module(), module()) :: [term()] | nil
  def get_data(component_module, macro_component) do
    if Code.ensure_loaded?(component_module) and
         function_exported?(component_module, :__phoenix_macro_components__, 0) do
      component_module.__phoenix_macro_components__()
      |> Map.get(macro_component, [])
    else
      []
    end
  end

  @doc false
  def build_ast(tokens, opts) do
    build_ast(tokens, [], [], opts)
  end

  # recursive case: build_ast(tokens, acc, stack, opts)

  defp build_ast([], acc, [], _opts) do
    {:ok, Enum.reverse(acc)}
  end

  defp build_ast([], _acc, [{_type, meta, [name, _, _], _} | _], opts) do
    open_meta = Keyword.get(meta, :open_meta, [])
    tag_name = Keyword.get(open_meta, :tag_name, name)
    message = "end of #{opts[:context]} reached without closing tag for <#{tag_name}>"
    raise_syntax_error!(message, open_meta, opts)
  end

  # tag open (self closing or void)
  defp build_ast([{type, name, attrs, %{closing: closing} = meta} | rest], acc, stack, opts)
       when type != :close and closing in [:self, :void] do
    meta = Enum.to_list(Map.delete(meta, :closing))

    acc = [
      {type, [open_meta: meta], [name, token_attrs_to_ast(attrs, opts), [closing: closing]]}
      | acc
    ]

    build_ast(rest, acc, stack, opts)
  end

  # tag open
  defp build_ast([{type, name, attrs, tag_meta} | rest], acc, stack, opts)
       when type != :close do
    build_ast(
      rest,
      [],
      [
        {type, [open_meta: Enum.to_list(tag_meta)], [name, token_attrs_to_ast(attrs, opts), []],
         acc}
        | stack
      ],
      opts
    )
  end

  # tag close
  defp build_ast(
         [{:close, type, name, tag_meta} | tokens],
         acc,
         [{type, meta, [name, attrs, args], prev_acc} | stack],
         opts
       ) do
    build_ast(
      tokens,
      [
        {type, meta ++ [{:close_meta, Enum.to_list(tag_meta)}],
         [name, attrs, Keyword.put(args, :do, {:__block__, [], Enum.reverse(acc)})]}
        | prev_acc
      ],
      stack,
      opts
    )
  end

  defp build_ast(
         [{:close, _type, tag_close_name, tag_close_meta} | _tokens],
         _acc,
         [{_opening_type, opening_meta, [opening_name, _, _], _} | _stack],
         opts
       ) do
    opening_meta = Keyword.get(opening_meta, :open_meta, [])
    tag_name = Keyword.get(opening_meta, :tag_name, opening_name)
    hint = closing_void_hint(tag_close_name, opts[:tag_handler])

    message = """
    unmatched closing tag. Expected </#{tag_name}> for <#{tag_name}> \
    at line #{Keyword.get(opening_meta, :line)}, got: </#{tag_close_name}>#{hint}\
    """

    raise_syntax_error!(message, tag_close_meta, opts)
  end

  defp build_ast([{:close, _type, _name, tag_close_meta} = _token | _tokens], _acc, _stack, opts) do
    hint = closing_void_hint(tag_close_meta.tag_name, opts[:tag_handler])
    message = "missing opening tag for </#{tag_close_meta.tag_name}>#{hint}"
    raise_syntax_error!(message, tag_close_meta, opts)
  end

  # text
  defp build_ast([{:text, text, meta} | rest], acc, stack, opts) do
    build_ast(rest, [{:<<>>, Enum.to_list(meta), [text]} | acc], stack, opts)
  end

  defp build_ast([{:expr, marker, ast} | rest], acc, stack, opts) do
    build_ast(rest, [{:expr, [marker: marker], [ast]} | acc], stack, opts)
  end

  defp build_ast([{:body_expr, code, meta} | rest], acc, stack, opts) do
    ast =
      Code.string_to_quoted!(code, line: meta.line, column: meta.column, file: opts[:env].file)

    build_ast(rest, [{:body_expr, Enum.to_list(meta), [ast]} | acc], stack, opts)
  end

  defp token_attrs_to_ast(attrs, opts) do
    Enum.map(attrs, fn {name, value, meta} ->
      case value do
        {:string, binary, string_meta} ->
          {:attribute, Enum.to_list(meta), [name, Enum.to_list(string_meta), binary]}

        {:expr, code, expr_meta} ->
          ast =
            Code.string_to_quoted!(code,
              line: expr_meta.line,
              column: expr_meta.column,
              file: opts[:env].file
            )

          # we set is_expr because it could also evaluate to a string
          {:attribute, [{:is_expr, true} | Enum.to_list(meta)],
           [name, Enum.to_list(expr_meta), ast]}

        nil ->
          {:attribute, Enum.to_list(meta), [name, nil]}
      end
    end)
  end

  defp env do
    require Phoenix.LiveView.TagEngine

    __ENV__
  end

  @doc """
  Turns an AST into a string.

  ## Options

    * `binding` - a custom function to encode attributes to iodata.
       Defaults to an HTML-safe encoder.

    * `tag_handler` - the tag handler, defaults to `Phoenix.LiveView.HTMLEngine`

  """
  @spec ast_to_string(heex_ast()) :: binary()
  def ast_to_string(ast, opts \\ []) do
    binding = Keyword.get(opts, :binding, assigns: %{})
    tag_handler = Keyword.get(opts, :tag_handler, Phoenix.LiveView.HTMLEngine)

    {result, _} =
      Code.eval_quoted(
        quote do
          Phoenix.LiveView.TagEngine.finalize(
            [
              tag_handler: unquote(tag_handler),
              indentation: 0,
              subengine_call: :handle_body,
              source: ""
            ],
            do: unquote(List.wrap(ast))
          )
        end,
        binding,
        env()
      )

    result
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp closing_void_hint(tag_name, tag_handler) do
    if tag_handler && tag_handler.void?(tag_name) do
      " (note <#{tag_name}> is a void tag and cannot have any content)"
    else
      ""
    end
  end

  defp raise_syntax_error!(message, meta, opts) do
    meta = Map.new(meta)
    line = Map.get(meta, :line)
    column = Map.get(meta, :column)

    if !line || !column do
      raise ArgumentError, message
    else
      raise Phoenix.LiveView.Tokenizer.ParseError,
        line: line,
        column: column,
        file: opts[:env].file,
        description:
          message <>
            Phoenix.LiveView.Tokenizer.ParseError.code_snippet(
              opts[:source],
              %{line: line, column: column},
              opts[:indentation]
            )
    end
  end
end
