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
  #     def transform({"pre", attrs, children, _tag_meta}, _meta) do
  #       markdown = Phoenix.Component.MacroComponent.ast_to_string(children)
  #       html_doc = MDEx.to_html!(markdown)
  #
  #       {:ok, {"div", attrs, [html_doc], %{}}}
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
  #
  #   ## Directives
  #
  #   Macro components may return directives from `transform/2` which can be used to influence
  #   other elements in the template outside of the macro component at compile-time. For example:
  #
  #   ```elixir
  #   defmodule MyAppWeb.TagRootSampleComponent do
  #     @behaviour Phoenix.Component.MacroComponent
  #
  #     @impl true
  #     def transform(_ast, _meta) do
  #       {:ok, "", %{}, [root_tag_attribute: {"phx-sample-one", "test"}, root_tag_attribute: {"phx-sample-two", true}]}
  #     end
  #   end
  #   ```
  #
  #   The following directives are currently supported:
  #
  #   * `:root_tag_attribute` - A `{name, value}` tuple to apply as an attribute to all root tags during template compilation.
  #     Requires that a global `:root_tag_attribute` is configured for the application. The attribute name must be a string and the attribute value must be a string or `true`.
  #     May be provided multiple times to apply multiple attributes.
  #

  @type tag :: binary()
  @type attribute :: {binary(), Macro.t()}
  @type attributes :: [attribute()]
  @type children :: [heex_ast()]
  @type tag_meta :: %{closing: :self | :void}
  @type heex_ast :: {tag(), attributes(), children(), tag_meta()} | binary()
  @type transform_meta :: %{env: Macro.Env.t()}
  @type directive :: {:root_tag_attribute, {name :: String.t(), value :: String.t() | true}}
  @type directives :: [directive]

  @callback transform(heex_ast :: heex_ast(), meta :: transform_meta()) ::
              {:ok, heex_ast()}
              | {:ok, heex_ast(), data :: term()}
              | {:ok, heex_ast(), data :: term(), directives :: directives()}

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
  def build_ast(node, env) when is_tuple(node) do
    case node do
      {:self_close, :tag, name, attrs, meta} ->
        closing_meta = Map.take(meta, [:closing])
        {:ok, {name, attrs_to_ast(attrs, env), [], closing_meta}}

      {:block, :tag, name, attrs, children, _meta, _close_meta} ->
        children_ast = build_ast(children, env)
        {:ok, {name, attrs_to_ast(attrs, env), children_ast, %{}}}
    end
  catch
    {:ast_error, message, error_meta} ->
      {:error, message, error_meta}
  end

  def build_ast(children, env) when is_list(children) do
    Enum.map(children, fn
      {:text, text, _meta} ->
        text

      {:self_close, :tag, name, attrs, meta} ->
        closing_meta = Map.take(meta, [:closing])
        {name, attrs_to_ast(attrs, env), [], closing_meta}

      {:block, :tag, name, attrs, nested_children, _meta, _close_meta} ->
        {name, attrs_to_ast(attrs, env), build_ast(nested_children, env), %{}}

      {:self_close, type, _name, _attrs, meta}
      when type in [:local_component, :remote_component] ->
        throw({:ast_error, "function components cannot be nested inside a macro component", meta})

      {:block, type, _name, _attrs, _children, meta, _close_meta}
      when type in [:local_component, :remote_component] ->
        throw({:ast_error, "function components cannot be nested inside a macro component", meta})

      {:self_close, :slot, _name, _attrs, meta} ->
        throw({:ast_error, "slots cannot be nested inside a macro component", meta})

      {:block, :slot, _name, _attrs, _children, meta, _close_meta} ->
        throw({:ast_error, "slots cannot be nested inside a macro component", meta})

      {:body_expr, _expr, meta} ->
        throw({:ast_error, "interpolation is not currently supported in macro components", meta})

      {:eex, _expr, meta} ->
        throw({:ast_error, "EEx is not currently supported in macro components", meta})

      {:eex_block, _expr, _blocks, meta} ->
        throw({:ast_error, "EEx is not currently supported in macro components", meta})
    end)
  end

  defp attrs_to_ast(attrs, env) do
    Enum.map(attrs, fn
      # for now, we don't support root expressions (<div {@foo}>)
      {:root, value, attr_meta} ->
        format_attr = fn
          {:string, binary, _meta} -> binary
          {:expr, code, _meta} -> code
          nil -> "nil"
        end

        throw(
          {:ast_error,
           "dynamic attributes are not supported in macro components, got: #{format_attr.(value)}",
           attr_meta}
        )

      {name, {:string, binary, _meta}, _attr_meta} ->
        {name, binary}

      {name, {:expr, code, expr_meta}, _attr_meta} ->
        ast =
          Code.string_to_quoted!(code,
            line: expr_meta.line,
            column: expr_meta.column,
            file: env.file
          )

        {name, ast}

      {name, nil, _attr_meta} ->
        {name, nil}
    end)
  end

  @doc false
  # Convert macro AST back to tree nodes (parser format)
  # We keep reuse the original line + column metadata from the original tag
  def ast_to_tree({tag, attrs, [], %{closing: _closing} = meta}, original_meta) do
    tree_attrs = attrs_to_tree(attrs, original_meta)
    {:self_close, :tag, tag, tree_attrs, Map.merge(original_meta, meta)}
  end

  def ast_to_tree({tag, attrs, children, _meta}, original_meta) do
    tree_attrs = attrs_to_tree(attrs, original_meta)
    tree_children = Enum.map(children, &ast_to_tree(&1, original_meta))
    {:block, :tag, tag, tree_attrs, tree_children, original_meta, %{}}
  end

  def ast_to_tree(text, _original_meta) when is_binary(text) do
    {:text, text, %{}}
  end

  defp attrs_to_tree(attrs, meta) do
    Enum.map(attrs, fn
      {name, nil} ->
        {name, nil, meta}

      {name, value} when is_binary(value) ->
        delimiter = attr_quotes(name, value)
        {name, {:string, value, Map.put(meta, :delimiter, delimiter)}, meta}

      {name, ast} ->
        # Convert quoted AST back to string for the tree node format
        code = Macro.to_string(ast)
        {name, {:expr, code, meta}, meta}
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

  defp encode_binary_attribute(key, value) when is_binary(key) and is_binary(value) do
    case attr_quotes(key, value) do
      ?" ->
        ~s( #{key}="#{value}")

      ?' ->
        ~s( #{key}='#{value}')
    end
  end

  defp attr_quotes(key, value) do
    case {:binary.match(value, ~s["]), :binary.match(value, "'")} do
      {:nomatch, _} ->
        ?"

      {_, :nomatch} ->
        ?'

      _ ->
        raise ArgumentError, """
        invalid attribute value for \"#{key}\".
        Attribute values must not contain single and double quotes at the same time.

        You need to escape your attribute before using it in the MacroComponent AST. You can use `Phoenix.HTML.attributes_escape/1` to do so.
        """
    end
  end
end
