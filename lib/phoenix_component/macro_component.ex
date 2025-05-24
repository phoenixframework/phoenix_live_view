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
    [{":type", {:__aliases__, [line: 1], [:ColocatedHook]}}, {"name", ".foo"}],
    [
      "\\n  export default {\\n    mounted() {\\n      this.el.firstElementChild.textContent = \\"Hello from JS!\\"\\n    }\\n  }\\n"
    ]}
  ```

  This module provides some utilities to work with the AST, which uses
  standard Elixir data structures:

  1. A HTML tag is represented as `{tag, attributes, children}`
  2. Text is represented as a plain binary
  3. Attributes are represented as a list of `{key, value}` tuples where
     the value is an Elixir AST (which can be a plain binary for simple attributes)

  > #### Limitations {: .warning}
  > The AST is not whitespace preserving, so in cases where you return a modified AST,
  > the original whitespace between attributes is lost.
  >
  > Also, macro components can currently only contain simple HTML. Any interpolation
  > like `<%= @foo %>` or components inside are not supported.

  ## Example: a compile-time markdown renderer

  Let's say we want to create a macro component that renders markdown as HTML at
  compile time. First, we need some library that actually converts the markdown to
  HTML. For this example, we use [`earmark`](https://hex.pm/packages/earmark).

  We start by defining the module for the macro component:

  ```elixir
  defmodule MyAppWeb.MarkdownComponent do
    @behaviour Phoenix.Component.MacroComponent

    @impl true
    def transform({"pre", attrs, children}, _meta) do
      markdown = Phoenix.Component.MacroComponent.to_string(children)
      {:ok, html_doc, _} = Earmark.as_html(markdown)

      {"div", attrs, [html_doc]}
    end
  end
  ```

  That's it. Since the div could contain nested elements, for example when using
  an HTML code block, we need to convert the children to a string first, using the
  `Phoenix.Component.MacroComponent.to_string/1` function.

  Then, we can simply replace the element's contents with the returned HTML string from
  Earmark.

  We can now use the macro component inside our HEEx templates:

      defmodule MyAppWeb.ExampleLiveView do
        use MyAppWeb, :live_view

        def render(assigns) do
          ~H\"\"\"
          <pre :type={ColocatedDemoWeb.Markdown} class="prose mt-8">
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
  """

  @type tag :: binary()
  @type attributes :: %{atom() => term()}
  @type children :: [heex_ast()]
  @type heex_ast :: {tag(), attributes(), children()} | binary()

  @callback transform(heex_ast :: heex_ast(), meta :: map()) :: heex_ast()

  @doc """
  Returns the stored data from macro components that returned `{:ok, ast, data}` in
  the format `%{module => [data]}`.
  """
  def get_data(module) do
    if Code.ensure_loaded?(module) and
         function_exported?(module, :__phoenix_macro_components__, 0) do
      module.__phoenix_macro_components__()
    else
      :error
    end
  end

  @doc false
  def build_ast([{:tag, name, attrs, _tag_meta} | rest]) do
    build_ast(rest, [], [{name, token_attrs_to_ast(attrs)}])
  end

  # recursive case: build_ast(tokens, acc, stack)

  # closing for final stack element -> done!
  defp build_ast([{:close, :tag, _, _} | rest], acc, [{tag_name, attrs}]) do
    {:ok, {tag_name, attrs, Enum.reverse(acc)}, rest}
  end

  # tag open (self closing or void)
  defp build_ast([{:tag, name, attrs, %{closing: type}} | rest], acc, stack)
       when type in [:self, :void] do
    build_ast(rest, [{name, token_attrs_to_ast(attrs), []} | acc], stack)
  end

  # tag open
  defp build_ast([{:tag, name, attrs, _tag_meta} | rest], acc, stack) do
    build_ast(rest, [], [{name, token_attrs_to_ast(attrs), acc} | stack])
  end

  # tag close
  defp build_ast([{:close, :tag, name, _tag_meta} | tokens], acc, [
         {name, attrs, prev_acc} | stack
       ]) do
    build_ast(tokens, [{name, attrs, Enum.reverse(acc)} | prev_acc], stack)
  end

  # text
  defp build_ast([{:text, text, _meta} | rest], acc, stack) do
    build_ast(rest, [text | acc], stack)
  end

  # unsupported token
  defp build_ast([{type, _name, _attrs, meta} | _tokens], _acc, _stack)
       when type in [:local_component, :remote_component] do
    {:error, "function components cannot be nested inside a macro component", meta}
  end

  defp build_ast([{:expr, _, _} | _], _acc, _stack) do
    raise ArgumentError, "EEx is not currently supported in macro components"
  end

  defp build_ast([{:body_expr, _, meta} | _], _acc, _stack) do
    {:error, "interpolation is not currently supported in macro components", meta}
  end

  defp token_attrs_to_ast(attrs) do
    Enum.map(attrs, fn {name, value, _meta} ->
      # TODO: decide how we want to treat expressions
      #       for now we just do binary / Elixir AST
      case value do
        {:string, binary, _meta} ->
          {name, binary}

        {:expr, code, _meta} ->
          ast = Code.string_to_quoted!(code)
          {name, ast}

        nil ->
          {name, nil}
      end
    end)
  end

  @doc """
  Turns an AST into a string.
  """
  def ast_to_string(ast) do
    IO.iodata_to_binary(ast_to_iodata(ast))
  end

  defp ast_to_iodata(list) when is_list(list) do
    Enum.map(list, &ast_to_iodata/1)
  end

  defp ast_to_iodata({name, attrs, children}) do
    [
      "<",
      name,
      attrs_to_iodata(attrs),
      ">",
      Enum.map(children, &ast_to_iodata/1),
      "</",
      name,
      ">"
    ]
  end

  defp ast_to_iodata(bin) when is_binary(bin), do: bin

  defp attrs_to_iodata([]), do: []

  defp attrs_to_iodata(attrs) do
    [
      " ",
      Enum.map_join(attrs, " ", fn {key, value} when is_binary(value) ->
        {:safe, escaped} = Phoenix.HTML.html_escape(value)
        <<key::binary, "=", "\"", escaped::binary, "\"">>
      end)
    ]
  end

  @doc false
  def ast_to_tokens({name, attrs, children}) do
    [
      {:tag, name, ast_attrs_to_token_attrs(attrs), %{line: 0, column: 0}}
      | Enum.flat_map(children, &ast_to_tokens/1)
    ] ++ [{:close, :tag, name, %{line: 0, column: 0, tag_name: name}}]
  end

  def ast_to_tokens(bin) when is_binary(bin) do
    [{:text, bin, %{line_end: 0, column_end: 0}}]
  end

  defp ast_attrs_to_token_attrs(attrs) do
    Enum.map(attrs, fn {key, value} ->
      {key,
       case value do
         nil -> nil
         bin when is_binary(bin) -> {:string, value, %{delimiter: ?"}}
         ast -> {:expr, Macro.to_string(ast), %{line: 0, column: 0}}
       end, %{line: 0, column: 0}}
    end)
  end
end
