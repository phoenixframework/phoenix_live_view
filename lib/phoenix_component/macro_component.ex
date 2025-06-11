defmodule Phoenix.Component.MacroComponent do
  @moduledoc """
  A macro component is a special type of component that can modify its content
  at compile time.

  Instead of introducing a special tag syntax like `<#macro-component>`, LiveView
  implements them using a special `:type` attribute as the most useful macro
  components take their content and extract it to somewhere else, for example
  to a file in the local file system. A good example for this is `Phoenix.LiveView.ColocatedHook`
  and `Phoenix.LiveView.ColocatedJS`.

  ## AST

  Macro components work by defining a callback module that implements the
  `Phoenix.LiveView.MacroComponent` behaviour. The module's `c:transform/2` callback
  is called for each macro component used while LiveView compiles a HEEx component:

  ```heex
  <div id="hey" phx-hook=".foo">
    <!-- content -->
  </div>

  <script :type={ColocatedHook} name=".foo">
    export default {
      mounted() {
        this.el.firstElementChild.textContent = "Hello from JS!"
      }
    }
  </script>
  ```

  In this example, the `ColocatedHook`'s `c:transform/2` callback will be invoked
  with the AST of the `<script>` tag:

  ```elixir
  {"script",
    [{"name", ".foo"}],
    [
      "\\n  export default {\\n    mounted() {\\n      this.el.firstElementChild.textContent = \\"Hello from JS!\\"\\n    }\\n  }\\n"
    ]}
  ```

  This module provides some utilities to work with the AST, which uses
  standard Elixir data structures:

  1. A HTML tag is represented as `{tag, attributes, children, meta}`
  2. Text is represented as a plain binary
  3. Attributes are represented as a list of `{key, value}` tuples where
     the value is an Elixir AST (which can be a plain binary for simple attributes)

  > #### Limitations {: .warning}
  > The AST is not whitespace preserving. When using macro components,
  > the original whitespace between attributes is lost.
  >
  > Also, macro components can currently only contain simple HTML. Any interpolation
  > like `<%= @foo %>` or components inside are not supported.

  ## Example: a compile-time markdown renderer

  Let's say we want to create a macro component that renders markdown as HTML at
  compile time. First, we need some library that actually converts the markdown to
  HTML. For this example, we use [`mdex`](https://hex.pm/packages/mdex).

  We start by defining the module for the macro component:

  ```elixir
  defmodule MyAppWeb.MarkdownComponent do
    @behaviour Phoenix.Component.MacroComponent

    @impl true
    def transform({"pre", attrs, children}, _meta) do
      markdown = Phoenix.Component.MacroComponent.to_string(children)
      html_doc = MDEx.to_html!(markdown)

      {"div", attrs, [html_doc]}
    end
  end
  ```

  That's it. Since the div could contain nested elements, for example when using
  an HTML code block, we need to convert the children to a string first, using the
  `Phoenix.Component.MacroComponent.ast_to_string/1` function.

  Then, we can simply replace the element's contents with the returned HTML string from
  MDEx.

  We can now use the macro component inside our HEEx templates:

      defmodule MyAppWeb.ExampleLiveView do
        use MyAppWeb, :live_view

        def render(assigns) do
          ~H\"\"\"
          <pre :type={MyAppWeb.MarkdownComponent} class="prose mt-8">
          ## Hello World

          This is some markdown!

          ```elixir
          defmodule Hello do
            def world do
              IO.puts "Hello, world!"
            end
          end
          ```
          </pre>
          \"\"\"
        end
      end

  Note: this example uses the `prose` class from TailwindCSS for styling.

  One trick to prevent issues with extra whitespace is that we use a `<pre>` tag in the LiveView
  template, which prevents the `Phoenix.LiveView.HTMLFormatter` from indenting the contents, which
  would mess with the markdown parsing. When rendering, we replace it with a `<div>` tag in the
  macro component.

  Another example for a macro component that transforms its content is available in
  LiveView's end to end tests: a macro component that performs
  [syntax highlighting at compile time](https://github.com/phoenixframework/phoenix_live_view/blob/38851d943f3280c5982d75679291dccb8c442534/test/e2e/support/colocated_live.ex#L4-L35)
  using the [Makeup](https://hexdocs.pm/makeup/Makeup.html) library.
  """

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
  def build_ast(tokens, env) do
    build_ast(tokens, [], [], env)
  end

  # recursive case: build_ast(tokens, acc, stack)
  defp build_ast([], acc, [], _env) do
    {:ok, Enum.reverse(acc)}
  end

  defp build_ast([], _acc, [_ | _], _env) do
    raise ArgumentError, "unexpected end of input"
  end

  # tag open (self closing or void)
  defp build_ast([{type, name, attrs, %{closing: closing} = meta} | rest], acc, stack, env)
       when type != :close and closing in [:self, :void] do
    meta = Enum.to_list(Map.delete(meta, :closing))

    acc = [
      {type, [{:closing, closing} | meta],
       [name, token_attrs_to_ast(attrs, env), {:__block__, [], []}]}
      | acc
    ]

    build_ast(rest, acc, stack, env)
  end

  # tag open
  defp build_ast([{type, name, attrs, tag_meta} | rest], acc, stack, env)
       when type != :close do
    build_ast(
      rest,
      [],
      [
        {type, Enum.to_list(tag_meta), [name, token_attrs_to_ast(attrs, env)], acc}
        | stack
      ],
      env
    )
  end

  # tag close
  defp build_ast(
         [{:close, type, _name, tag_meta} | tokens],
         acc,
         [{type, meta, body, prev_acc} | stack],
         env
       ) do
    build_ast(
      tokens,
      [
        {type, meta ++ [{:close_meta, Enum.to_list(tag_meta)}],
         body ++ [{:__block__, [], Enum.reverse(acc)}]}
        | prev_acc
      ],
      stack,
      env
    )
  end

  # text
  defp build_ast([{:text, text, meta} | rest], acc, stack, env) do
    build_ast(rest, [{:<<>>, Enum.to_list(meta), [text]} | acc], stack, env)
  end

  defp build_ast([{:expr, marker, ast} | rest], acc, stack, env) do
    build_ast(rest, [{:expr, [marker: marker], [ast]} | acc], stack, env)
  end

  defp build_ast([{:body_expr, code, meta} | rest], acc, stack, env) do
    ast = Code.string_to_quoted!(code, line: meta.line, column: meta.column, file: env.file)
    build_ast(rest, [{:body_expr, Enum.to_list(meta), [ast]} | acc], stack, env)
  end

  defp token_attrs_to_ast(attrs, env) do
    Enum.map(attrs, fn {name, value, meta} ->
      case value do
        {:string, binary, string_meta} ->
          {:attribute, Enum.to_list(meta), [name, Enum.to_list(string_meta), binary]}

        {:expr, code, expr_meta} ->
          ast = Code.string_to_quoted!(code, line: meta.line, column: meta.column, file: env.file)
          {:attribute, Enum.to_list(meta), [name, expr_meta, ast]}

        nil ->
          {:attribute, [], [name, nil]}
      end
    end)
  end

  @doc """
  Turns an AST into a string.

  ## Options

    * `attributes_encoder` - a custom function to encode attributes to iodata.
       Defaults to an HTML-safe encoder.

  """
  @spec ast_to_string(heex_ast(), keyword()) :: binary()
  def ast_to_string(ast, opts \\ []) do
    opts = Keyword.put_new(opts, :attributes_encoder, &ast_attributes_to_iodata/1)

    ast
    |> ast_to_iodata(opts)
    |> IO.iodata_to_binary()
  end

  defp ast_to_iodata(list, opts) when is_list(list) do
    Enum.map(list, &ast_to_iodata(&1, opts))
  end

  # self closing / void tags cannot have children
  defp ast_to_iodata({name, attrs, [], %{closing: closing}}, opts) do
    suffix =
      case closing do
        :void -> ">"
        :self -> "/>"
      end

    [
      "<",
      name,
      opts[:attributes_encoder].(attrs),
      suffix
    ]
  end

  defp ast_to_iodata({name, attrs, children, _meta}, opts) do
    [
      "<",
      name,
      opts[:attributes_encoder].(attrs),
      ">",
      Enum.map(children, &ast_to_iodata(&1, opts)),
      "</",
      name,
      ">"
    ]
  end

  defp ast_to_iodata(binary, _opts) when is_binary(binary) do
    binary
  end

  defp ast_attributes_to_iodata(attrs) do
    Enum.map(attrs, fn
      {key, value} when is_binary(value) ->
        encode_binary_attribute(key, value)

      {key, nil} ->
        ~s( #{key})

      {key, value} ->
        raise ArgumentError,
              "cannot convert AST with non-string attribute \"#{key}\" to string. Got: #{Macro.to_string(value)}"
    end)
  end

  @doc false
  def encode_binary_attribute(key, value) when is_binary(key) and is_binary(value) do
    case {:binary.match(value, ~s["]), :binary.match(value, "'")} do
      {:nomatch, _} ->
        ~s( #{key}="#{value}")

      {_, :nomatch} ->
        ~s( #{key}='#{value}')

      _ ->
        raise ArgumentError, """
        invalid attribute value for \"#{key}\".
        Attribute values must not contain single and double quotes at the same time.

        You need to escape your attribute before using it in the MacroComponent AST. You can use `Phoenix.HTML.attributes_escape/1` to do so.
        """
    end
  end
end
