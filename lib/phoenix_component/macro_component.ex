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
  #   ## Root tag attributes
  #
  #   HEEx templates support adding a root tag attributes to the rendered page.
  #   These can be useful for debugging or as selectors for things such as CSS.
  #
  #   Note that root tag attributes are applied to all root tags in the given
  #   template, not just the outermost root tags. This means that tags at the root
  #   of the template itself, at the root of any component inner blocks, or at
  #   the root of any component slots will all have root tag attributes applied.
  #
  #   For example, imagine the following component definition:
  #
  #  ```elixir
  #   defmodule MyAppWeb.MyModule do
  #     slot :inner_block, required: true
  #     slot :named_slot, required: true
  #
  #     def my_function(assigns) do
  #       ~H"""
  #       <section>
  #         <div>
  #           {render_slot(@inner_block)}
  #         </div>
  #       </section>
  #       <aside>
  #         <div>
  #           {render_slot(@named_slot)}
  #         </div>
  #       </aside>
  #       """
  #     end
  #   end
  #   ```
  #
  #   And the following HEEx template:
  #
  #   ```heex
  #   <div>
  #     <div>
  #       <.my_function>
  #         <p>
  #           <span>
  #             Inner Block
  #           </span>
  #         </p>
  #         <:named_slot>
  #         <p>
  #           <span>
  #             Named Slot
  #           </span>
  #         </p>
  #         </:named_slot>
  #       </.my_function>
  #     </div>
  #   </div>
  #   ```
  #
  #   By setting the global `root_tag_attribute` to "phx-r", the rendered HTML would look as follows:
  #
  #   ```html
  #   <div phx-r>
  #     <div>
  #       <section phx-r>
  #         <div>
  #           <p phx-r>
  #             <span>
  #               Inner Block
  #             </span>
  #           </p>
  #         </div>
  #       </section>
  #       <aside phx-r>
  #         <div>
  #           <p phx-r>
  #             <span>
  #               Named Slot
  #             </span>
  #           </p>
  #         </div>
  #       </aside>
  #     </div>
  #   </div>
  #   ```
  #
  #   This feature works on any `~H` or `.html.heex` template. They can be enabled
  #   globally with the following configuration in your `config/config.exs` file:
  #
  #       config :phoenix_live_view, root_tag_attribute: "phx-r"
  #
  #   Changing this configuration will require `mix clean` and a full recompile.
  #
  #   Additional root tag attributes can also be applied by MacroComponents. See the `Directives` section
  #   below for details.
  #
  #   ## Directives
  #
  #   Macro components may return directives from the module's optional `c:directives/2` callback
  #   which can be used to influence other elements in the template outside of the macro component at compile-time.
  #   For example:
  #
  #   ```elixir
  #   defmodule MyAppWeb.TagRootSampleComponent do
  #     @behaviour Phoenix.Component.MacroComponent
  #
  #     @impl true
  #     def directives(_ast, _meta) do
  #       {:ok, [root_tag_attribute: {"phx-sample-one", "test"}, root_tag_attribute: {"phx-sample-two", "test"}]}
  #     end
  #
  #     @impl true
  #     def transform(_ast, _meta) do
  #       {:ok, "", %{}}
  #     end
  #   end
  #   ```
  #   The following directives are currently supported:
  #
  #   ### Options
  #
  #   * `:root_tag_attribute` - `{name, value}` pair to apply as an attribute to all root tags during template compilation.
  #   Requires that a global `:root_tag_attribute` be configured for the application. `name` must be a compile-time string. `value` must be a
  #   compile-time string or `true`. May be provided multiple times to apply multiple attributes. Requires that a global `:root_tag_attribute` be configured.
  #   See the `Root tag attributes` section above for more details.

  @type tag :: binary()
  @type attribute :: {binary(), Macro.t()}
  @type attributes :: [attribute()]
  @type children :: [heex_ast()]
  @type tag_meta :: %{closing: :self | :void}
  @type heex_ast :: {tag(), attributes(), children(), tag_meta()} | binary()
  @type transform_meta :: %{env: Macro.Env.t()}
  @type directives_meta :: %{env: Macro.Env.t()}
  @type directive :: {:root_tag_attribute, {name :: String.t(), value :: String.t()}}
  @type directives :: [directive]

  @optional_callbacks [directives: 2]

  @callback directives(heex_ast :: heex_ast(), meta :: directives_meta()) :: {:ok, directives()}

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
  def build_ast([{:tag, name, attrs, tag_meta} | rest], env) do
    if closing = tag_meta[:closing] do
      # we assert here because we don't expect any other values
      true = closing in [:self, :void]
    end

    meta = Map.take(tag_meta, [:closing])
    build_ast(rest, [], [{name, token_attrs_to_ast(attrs, env), meta}], env)
  end

  # recursive case: build_ast(tokens, acc, stack)

  # closing for final stack element -> done!
  defp build_ast([{:close, :tag, _, _} | rest], acc, [{tag_name, attrs, meta}], _env) do
    {:ok, {tag_name, attrs, Enum.reverse(acc), meta}, rest}
  end

  # tag open (self closing or void)
  defp build_ast([{:tag, name, attrs, %{closing: type}} | rest], acc, stack, env)
       when type in [:self, :void] do
    acc = [{name, token_attrs_to_ast(attrs, env), [], %{closing: type}} | acc]
    build_ast(rest, acc, stack, env)
  end

  # tag open
  defp build_ast([{:tag, name, attrs, _tag_meta} | rest], acc, stack, env) do
    build_ast(rest, [], [{name, token_attrs_to_ast(attrs, env), %{}, acc} | stack], env)
  end

  # tag close
  defp build_ast(
         [{:close, :tag, name, _tag_meta} | tokens],
         acc,
         [{name, attrs, meta, prev_acc} | stack],
         env
       ) do
    build_ast(tokens, [{name, attrs, Enum.reverse(acc), meta} | prev_acc], stack, env)
  end

  # text
  defp build_ast([{:text, text, _meta} | rest], acc, stack, env) do
    build_ast(rest, [text | acc], stack, env)
  end

  # unsupported token
  defp build_ast([{type, _name, _attrs, meta} | _tokens], _acc, _stack, _env)
       when type in [:local_component, :remote_component] do
    {:error, "function components cannot be nested inside a macro component", meta}
  end

  defp build_ast([{:expr, _, _} | _], _acc, _stack, _env) do
    # we raise here because we don't have a meta map (line + column) available
    raise ArgumentError, "EEx is not currently supported in macro components"
  end

  defp build_ast([{:body_expr, _, meta} | _], _acc, _stack, _env) do
    {:error, "interpolation is not currently supported in macro components", meta}
  end

  defp token_attrs_to_ast(attrs, env) do
    Enum.map(attrs, fn {name, value, _meta} ->
      # for now, we don't support root expressions (<div {@foo}>)
      if name == :root do
        format_attr = fn
          {:string, binary, _meta} -> binary
          {:expr, code, _meta} -> code
          nil -> "nil"
        end

        raise ArgumentError,
              "dynamic attributes are not supported in macro components, got: #{format_attr.(value)}"
      end

      case value do
        {:string, binary, _meta} ->
          {name, binary}

        {:expr, code, meta} ->
          ast = Code.string_to_quoted!(code, line: meta.line, column: meta.column, file: env.file)
          {name, ast}

        nil ->
          {name, nil}
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
