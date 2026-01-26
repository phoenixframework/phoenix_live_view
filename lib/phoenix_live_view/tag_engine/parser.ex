defmodule Phoenix.LiveView.TagEngine.Parser do
  @moduledoc false

  defstruct [:nodes, :directives]

  @type t :: %__MODULE__{
          nodes: list(tag_node()),
          directives: Phoenix.Component.MacroComponent.directives()
        }

  @type tag_node() :: text() | comment() | block() | self_close() | expression()
  @type text() :: {:text, binary(), meta()}
  @type comment() :: {:eex_comment, binary(), meta()}
  @type block() :: {:block, atom(), binary(), list(attr()), list(tag_node()), meta(), meta()}
  @type self_close() :: {:self_close, atom(), binary(), list(attr()), meta()}
  @type expression() ::
          {:body_expr, binary(), meta()}
          | {:eex, binary(), meta()}
          | {:eex_block, binary(), list(eex_clause()), meta()}
  @type eex_clause() :: {list(tag_node()), binary(), meta()}
  @type attr :: {:root | binary(), attr_value(), meta()}
  @type attr_value :: {:expr, binary(), meta()} | {:string, binary(), meta()}
  @type meta() :: map()

  alias Phoenix.LiveView.TagEngine.Tokenizer
  alias Phoenix.Component.MacroComponent

  defguardp is_tag_open(tag_type) when tag_type not in [:close, :eex]

  defguardp is_tag_block(node)
            when is_tuple(node) and tuple_size(node) == 7 and elem(node, 0) == :block

  defguardp is_self_close(node)
            when is_tuple(node) and tuple_size(node) == 5 and elem(node, 0) == :self_close

  defguardp is_macro_component(node)
            when (is_tag_block(node) and is_map_key(elem(node, 5), :macro_component)) or
                   (is_self_close(node) and is_map_key(elem(node, 4), :macro_component))

  def parse(source, opts \\ []) do
    tag_handler = Keyword.fetch!(opts, :tag_handler)
    caller = Keyword.get(opts, :caller)
    skip_macro_components = Keyword.get(opts, :skip_macro_components, false)
    prune_text_after_slots = Keyword.get(opts, :prune_text_after_slots, true)
    process_buffer = Keyword.get(opts, :process_buffer)

    source
    |> tokenize(opts)
    |> to_tree([], [], %{
      tag_handler: tag_handler,
      caller: caller,
      skip_macro_components: skip_macro_components,
      prune_text_after_slots: prune_text_after_slots,
      process_buffer: process_buffer,
      directives: []
    })
  catch
    {:syntax_error, line, column, message} ->
      {:error, line, column, message}
  end

  def parse!(source, opts \\ []) do
    case parse(source, opts) do
      {:ok, nodes} ->
        nodes

      {:error, line, column, message} ->
        raise Tokenizer.ParseError,
          line: line,
          column: column,
          file: opts[:file] || "nofile",
          description:
            message <>
              Tokenizer.ParseError.code_snippet(
                source,
                %{line: line, column: column},
                opts[:indentation] || 0
              )
    end
  end

  # Tokenize contents using EEx.tokenize and Phoenix.LiveView.TagEngine.Tokenizer respectively.
  #
  # The following content:
  #
  # "<section>\n  <p><%= user.name %></p>\n  <%= if true do %> <p>this</p><% else %><p>that</p><% end %>\n</section>\n"
  #
  # Will be tokenized as:
  #
  # [
  #   {:tag, "section", [], %{column: 1, line: 1}},
  #   {:text, "\n  ", %{column_end: 3, line_end: 2}},
  #   {:tag, "p", [], %{column: 3, line: 2}},
  #   {:eex, :start_expr, "<%= user.name ></p>\n  <%= if true do %>", %{block?: true, column: 6, line: 1}},
  #   {:text, " ", %{column_end: 2, line_end: 1}},
  #   {:tag, "p", [], %{column: 2, line: 1}},
  #   {:text, "this", %{column_end: 12, line_end: 1}},
  #   {:close, :tag, "p", %{column: 12, line: 1}},
  #   {:eex, :middle_expr, "<% else %>", %{block?: false, column: 35, line: 2}},
  #   {:tag, "p", [], %{column: 1, line: 1}},
  #   {:text, "that", %{column_end: 14, line_end: 1}},
  #   {:close, :tag, "p", %{column: 14, line: 1}},
  #   {:eex, :end_expr, "<% end %>", %{block?: false, column: 62, line: 2}},
  #   {:text, "\n", %{column_end: 1, line_end: 2}},
  #   {:close, :tag, "section", %{column: 1, line: 2}}
  # ]
  #
  @eex_expr [:start_expr, :expr, :end_expr, :middle_expr]

  @doc false
  def tokenize(source, opts) do
    file = Keyword.get(opts, :file, "nofile")
    indentation = Keyword.get(opts, :indentation, 0)
    trim_eex = Keyword.get(opts, :trim_eex, true)
    {:ok, eex_nodes} = EEx.tokenize(source, opts)

    {tokens, cont} =
      Enum.reduce(
        eex_nodes,
        {[], {:text, :enabled}},
        &do_tokenize(&1, &2, source, %{file: file, indentation: indentation, trim_eex: trim_eex})
      )

    Tokenizer.finalize(tokens, file, cont, source)
  end

  defp do_tokenize({:text, text, meta}, {tokens, cont}, source, %{
         file: file,
         indentation: indentation
       }) do
    text = List.to_string(text)
    meta = [line: meta.line, column: meta.column]
    state = Tokenizer.init(indentation, file, source, Phoenix.LiveView.HTMLEngine)
    Tokenizer.tokenize(text, meta, tokens, cont, state)
  end

  defp do_tokenize({:comment, text, meta}, {tokens, cont}, _contents, _opts) do
    {[{:eex_comment, List.to_string(text), meta} | tokens], cont}
  end

  defp do_tokenize(
         {type, opt, expr, %{column: column, line: line}},
         {tokens, cont},
         _contents,
         opts
       )
       when type in @eex_expr do
    meta = %{opt: opt, line: line, column: column}

    {[{:eex, type, expr |> List.to_string() |> maybe_trim_eex(opts.trim_eex), meta} | tokens],
     cont}
  end

  defp do_tokenize(_node, acc, _contents, _opts) do
    acc
  end

  defp maybe_trim_eex(string, true), do: String.trim(string)
  defp maybe_trim_eex(string, _), do: string

  # Build an HTML Tree according to the tokens from the EEx and HTML tokenizers.
  #
  # This is a recursive algorithm that will build an HTML tree from a flat list of
  # tokens. For instance, given this input:
  #
  # [
  #   {:tag, "div", [], %{column: 1, line: 1}},
  #   {:tag, "h1", [], %{column: 6, line: 1}},
  #   {:text, "Hello", %{column_end: 15, line_end: 1}},
  #   {:close, :tag, "h1", %{column: 15, line: 1}},
  #   {:close, :tag, "div", %{column: 20, line: 1}},
  #   {:tag, "div", [], %{column: 1, line: 2}},
  #   {:tag, "h1", [], %{column: 6, line: 2}},
  #   {:text, "World", %{column_end: 15, line_end: 2}},
  #   {:close, :tag, "h1", %{column: 15, line: 2}},
  #   {:close, :tag, "div", %{column: 20, line: 2}}
  # ]
  #
  # The output will be:
  #
  # [
  #   {:block, :tag, "div", [],
  #    [{:block, :tag, "h1", [],
  #      [{:text, "Hello", %{...}}],
  #      %{line: 1, column: 6, ...},
  #      %{line: 1, column: 15, ...}}],
  #    %{line: 1, column: 1, ...},
  #    %{line: 1, column: 20, ...}},
  #   {:block, :tag, "div", [],
  #    [{:block, :tag, "h1", [],
  #      [{:text, "World", %{...}}],
  #      %{line: 2, column: 6, ...},
  #      %{line: 2, column: 15, ...}}],
  #    %{line: 2, column: 1, ...},
  #    %{line: 2, column: 20, ...}}
  # ]
  #
  # Note that a `:block` has been created so that its fifth argument is a list of
  # its nested content, followed by open_meta and close_meta.
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
  #   defp to_tree([{type, name, attrs, meta} | tokens], buffer, stack, state)
  #        when is_tag_open(type) do
  #     to_tree(tokens, [], [{type, name, attrs, meta, buffer} | stack], state)
  #   end
  #   ```
  #
  # Then, we start to populate the buffer again until a `{:close, :tag, ...} arrives:
  #
  #   ```
  #   defp to_tree([{:close, type, name, close_meta} | tokens], buffer, [{type, name, attrs, open_meta, upper_buffer} | stack], state) do
  #     to_tree(tokens, [{:block, type, name, attrs, Enum.reverse(buffer), open_meta, close_meta} | upper_buffer], stack)
  #   end
  #   ```
  #
  # In the snippet above, we build the `:block` tuple with the accumulated buffer,
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
  #      {[{:eex, "\"Hello\"", %{column: 3, line: 1, opt: '='}}], "else", %{line: 2, column: 1}},
  #      {[{:eex, "\"World\"", %{column: 3, line: 3, opt: '='}}], "end", %{line: 4, column: 1}}
  #    ], %{line: 0, column: 0, opt: '='}}
  # ]
  # ```
  defp to_tree([], buffer, [], state) do
    {:ok, %__MODULE__{nodes: Enum.reverse(buffer), directives: state.directives}}
  end

  defp to_tree(
         [],
         _buffer,
         [{_type, _name, _, %{line: line, column: column} = meta, _} | _],
         _state
       ) do
    message = "end of template reached without closing tag for <#{meta.tag_name}>"
    {:error, line, column, message}
  end

  defp to_tree([{:text, text, meta} | tokens], buffer, stack, state) do
    # Preserve context for HTML comment handling in formatter
    text_meta = Map.take(meta, [:context])
    buffer = process_buffer([{:text, text, text_meta} | buffer], state)
    to_tree(tokens, buffer, stack, state)
  end

  defp to_tree([{:body_expr, value, meta} | tokens], buffer, stack, state) do
    buffer = process_buffer([{:body_expr, value, meta} | buffer], state)
    to_tree(tokens, buffer, stack, state)
  end

  # Self-closing slot - valid only as direct child of component
  defp to_tree(
         [{:slot, name, attrs, %{closing: _} = meta} | tokens],
         buffer,
         [{parent_type, _, _, _, _} | _] = stack,
         state
       )
       when parent_type in [:local_component, :remote_component] do
    meta = meta |> Map.put(:special, extract_special_attrs(attrs)) |> maybe_macro_component(attrs)

    {tokens, buffer, state} =
      maybe_process_macro_component(
        {:self_close, :slot, name, attrs, meta},
        tokens,
        buffer,
        state
      )

    tokens = if state.prune_text_after_slots, do: prune_text(tokens), else: tokens

    to_tree(tokens, buffer, stack, state)
  end

  # Self-closing slot - invalid context (not direct child of component)
  defp to_tree(
         [{:slot, name, _attrs, %{closing: _} = meta} | _tokens],
         _buffer,
         _stack,
         _state
       ) do
    %{line: line, column: column} = meta
    message = "invalid slot entry <:#{name}>. A slot entry must be a direct child of a component"
    {:error, line, column, message}
  end

  # Opening slot - valid only as direct child of component
  defp to_tree(
         [{:slot, name, attrs, meta} | tokens],
         buffer,
         [{parent_type, _, _, _, _} | _] = stack,
         state
       )
       when parent_type in [:local_component, :remote_component] do
    meta = meta |> Map.put(:special, extract_special_attrs(attrs)) |> maybe_macro_component(attrs)
    to_tree(tokens, [], [{:slot, name, attrs, meta, buffer} | stack], state)
  end

  # Opening slot - invalid context (not direct child of component)
  defp to_tree([{:slot, name, _attrs, meta} | _tokens], _buffer, _stack, _state) do
    %{line: line, column: column} = meta
    message = "invalid slot entry <:#{name}>. A slot entry must be a direct child of a component"
    {:error, line, column, message}
  end

  # Closing a slot
  defp to_tree(
         [{:close, :slot, _name, close_meta} | tokens],
         reversed_buffer,
         [{:slot, tag_name, attrs, open_meta, upper_buffer} | stack],
         state
       ) do
    block = Enum.reverse(reversed_buffer)
    tag_block = {:block, :slot, tag_name, attrs, block, open_meta, close_meta}
    tokens = if state.prune_text_after_slots, do: prune_text(tokens), else: tokens
    to_tree(tokens, [tag_block | upper_buffer], stack, state)
  end

  # Self-closing tag or component
  defp to_tree([{type, name, attrs, %{closing: _} = meta} | tokens], buffer, stack, state)
       when is_tag_open(type) do
    meta = meta |> Map.put(:special, extract_special_attrs(attrs)) |> maybe_macro_component(attrs)

    {tokens, buffer, state} =
      maybe_process_macro_component({:self_close, type, name, attrs, meta}, tokens, buffer, state)

    to_tree(tokens, buffer, stack, state)
  end

  # Opening tag or component
  defp to_tree([{type, name, attrs, meta} | tokens], buffer, stack, state)
       when is_tag_open(type) do
    meta = meta |> Map.put(:special, extract_special_attrs(attrs)) |> maybe_macro_component(attrs)
    to_tree(tokens, [], [{type, name, attrs, meta, buffer} | stack], state)
  end

  # Matching close tag
  defp to_tree(
         [{:close, _type, name, close_meta} | tokens],
         reversed_buffer,
         [{type, name, attrs, open_meta, upper_buffer} | stack],
         state
       ) do
    block = Enum.reverse(reversed_buffer)

    {tokens, buffer, state} =
      maybe_process_macro_component(
        {:block, type, name, attrs, block, open_meta, close_meta},
        tokens,
        upper_buffer,
        state
      )

    to_tree(tokens, buffer, stack, state)
  end

  # Mismatched close tag
  defp to_tree(
         [{:close, _close_type, close_name, close_meta} | _tokens],
         _buffer,
         [{_open_type, open_name, _attrs, open_meta, _upper_buffer} | _stack],
         state
       ) do
    %{line: line, column: column} = close_meta
    void_note = void_tag_note(close_name, state)

    message =
      "unmatched closing tag. Expected </#{open_name}> for <#{open_name}> at line #{open_meta.line}, got: </#{close_name}>#{void_note}"

    {:error, line, column, message}
  end

  # Orphaned close tag - no matching open tag on stack
  defp to_tree([{:close, _type, name, meta} | _tokens], _buffer, [], state) do
    %{line: line, column: column} = meta
    void_note = void_tag_note(name, state)
    message = "missing opening tag for </#{name}>#{void_note}"
    {:error, line, column, message}
  end

  # EEx

  defp to_tree([{:eex_comment, text, _meta} | tokens], buffer, stack, state) do
    to_tree(tokens, [{:eex_comment, text} | buffer], stack, state)
  end

  defp to_tree([{:eex, :start_expr, expr, meta} | tokens], buffer, stack, state) do
    to_tree(tokens, [], [{:eex_block, expr, meta, buffer} | stack], state)
  end

  defp to_tree(
         [{:eex, :middle_expr, middle_expr, middle_meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack],
         state
       ) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr, middle_meta} | middle_buffer]

    to_tree(
      tokens,
      [],
      [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack],
      state
    )
  end

  defp to_tree(
         [{:eex, :middle_expr, middle_expr, middle_meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer} | stack],
         state
       ) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr, middle_meta}]

    to_tree(
      tokens,
      [],
      [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack],
      state
    )
  end

  defp to_tree(
         [{:eex, :end_expr, end_expr, end_meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack],
         state
       ) do
    block = Enum.reverse([{Enum.reverse(buffer), end_expr, end_meta} | middle_buffer])
    to_tree(tokens, [{:eex_block, expr, block, meta} | upper_buffer], stack, state)
  end

  defp to_tree(
         [{:eex, :end_expr, end_expr, end_meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer} | stack],
         state
       ) do
    block = [{Enum.reverse(buffer), end_expr, end_meta}]
    to_tree(tokens, [{:eex_block, expr, block, meta} | upper_buffer], stack, state)
  end

  # end_expr reached but unclosed tag on stack (inside a do-block)
  defp to_tree(
         [{:eex, :end_expr, _end_expr, _end_meta} | _tokens],
         _buffer,
         [{_type, _name, _attrs, %{line: line, column: column} = meta, _upper_buffer} | _stack],
         _state
       ) do
    message = "end of do-block reached without closing tag for <#{meta.tag_name}>"
    {:error, line, column, message}
  end

  defp to_tree([{:eex, _type, expr, meta} | tokens], buffer, stack, state) do
    buffer = process_buffer([{:eex, expr, meta} | buffer], state)
    to_tree(tokens, buffer, stack, state)
  end

  @special_attrs ~w(:if :for :key)
  defp extract_special_attrs(attrs) do
    for {name, _, _} <- attrs, name in @special_attrs, do: name
  end

  # Prune leading whitespace from the next text token (used after slots)
  defp prune_text([{:text, text, meta} | tokens]) do
    [{:text, String.trim_leading(text), meta} | tokens]
  end

  defp prune_text(tokens), do: tokens

  # Allow callers to hook into buffer processing (used by formatter for preserve mode propagation)
  defp process_buffer(buffer, %{process_buffer: fun}) when is_function(fun), do: fun.(buffer)
  defp process_buffer(buffer, _state), do: buffer

  # Removes empty whitespace nodes at the start of the tokens (used after macro components)
  defp strip_text([{:text, "", _meta} | tokens]), do: strip_text(tokens)

  defp strip_text([{:text, text, meta} | tokens]) do
    case String.trim_leading(text) do
      "" ->
        strip_text(tokens)

      text ->
        [{:text, text, meta} | tokens]
    end
  end

  defp strip_text(tokens), do: tokens

  defp void_tag_note(name, state) do
    if state.tag_handler.void?(name) do
      " (note <#{name}> is a void tag and cannot have any content)"
    else
      ""
    end
  end

  ## Macro component handling

  defp maybe_macro_component(meta, attrs) do
    case List.keyfind(attrs, ":type", 0) do
      {":type", {:expr, code, _expr_meta}, _attr_meta} ->
        Map.put(meta, :macro_component, code)

      _ ->
        meta
    end
  end

  defguardp skip_macro_components(state)
            when is_map_key(state, :skip_macro_components) and state.skip_macro_components == true

  defp maybe_process_macro_component(tree_node, tokens, buffer, state)
       when is_macro_component(tree_node) and not skip_macro_components(state) do
    caller = state.caller

    if is_nil(caller) do
      raise ArgumentError, "macro components require a caller environment"
    end

    Macro.Env.required?(caller, Phoenix.Component) ||
      raise ArgumentError,
            "macro components are only supported in modules that `use Phoenix.Component`"

    tree_node =
      case tree_node do
        # Remove :type from attrs for the macro component AST
        {:self_close, :tag, name, attrs, meta} ->
          {:self_close, :tag, name, List.keydelete(attrs, ":type", 0), meta}

        {:block, :tag, name, attrs, children, meta, close_meta} ->
          {:block, :tag, name, List.keydelete(attrs, ":type", 0), children, meta, close_meta}

        # Macro components are currently only allowed on non-special tags
        {:self_close, type, _name, _attrs, meta} ->
          throw_syntax_error!(
            "macro components are only supported on HTML tags, not #{format_type(type)}",
            meta
          )

        {:block, type, _name, _attrs, _children, meta, _close_meta} ->
          throw_syntax_error!(
            "macro components are only supported on HTML tags, not #{format_type(type)}",
            meta
          )
      end

    meta = get_meta(tree_node)
    module_string = meta.macro_component
    module = validate_module!(module_string, meta, state)

    case process_macro_component(tree_node, module, state) do
      {_new_node, directives} when directives != [] and buffer != [] ->
        throw_syntax_error!(
          "macro component #{inspect(module)} specified directives and therefore must appear at the very beginning of the template",
          get_meta(tree_node)
        )

      {{:text, "", _}, directives} ->
        {strip_text(tokens), buffer, %{state | directives: directives}}

      {new_node, directives} ->
        {strip_text(tokens), [new_node | buffer], %{state | directives: directives}}
    end
  end

  defp maybe_process_macro_component(tree_node, tokens, buffer, state) do
    {tokens, [tree_node | buffer], state}
  end

  # Process a macro component: call transform and convert result back to tree nodes
  defp process_macro_component(tree_node, module, state) do
    # Macro components work by converting the tree nodes into a macro AST
    # (see Phoenix.Component.MacroComponent) and then calling the transform
    # function on the macro component module, which can return a transformed
    # AST.
    #
    # The AST is limited in functionality and we convert it back to the regular
    # node format afterwards.
    meta = get_meta(tree_node)

    case MacroComponent.build_ast(tree_node, state.caller) do
      {:ok, macro_ast} ->
        try do
          # Call the transform function
          case module.transform(macro_ast, %{env: state.caller}) do
            {:ok, new_ast} ->
              {MacroComponent.ast_to_tree(new_ast, meta), []}

            {:ok, new_ast, data} ->
              Module.put_attribute(state.caller.module, :__macro_components__, {module, data})
              {MacroComponent.ast_to_tree(new_ast, meta), []}

            {:ok, new_ast, data, directives} ->
              Module.put_attribute(state.caller.module, :__macro_components__, {module, data})

              {MacroComponent.ast_to_tree(new_ast, meta),
               validate_directives!(module, directives, meta)}

            other ->
              throw_syntax_error!(
                "a macro component must return {:ok, ast}, {:ok, ast, data}, or {:ok, ast, data, directives}, got: #{inspect(other)}",
                meta
              )
          end
        rescue
          e in ArgumentError ->
            throw_syntax_error!(Exception.message(e), meta)
        end

      {:error, message, error_meta} ->
        throw_syntax_error!(message, error_meta)
    end
  end

  defp get_meta({:self_close, _type, _name, _attrs, meta}), do: meta
  defp get_meta({:block, _type, _name, _attrs, _children, meta, _close_meta}), do: meta

  defp validate_module!(module_string, tag_meta, state) do
    module =
      Code.string_to_quoted!(module_string,
        file: state.caller.file,
        line: tag_meta.line,
        column: tag_meta.column
      )
      |> Macro.expand(state.caller)

    if not is_atom(module) do
      throw_syntax_error!(
        "the given macro component #{inspect(module_string)} is not a valid module",
        tag_meta
      )
    end

    _ = Code.ensure_compiled!(module)

    if not function_exported?(module, :transform, 2) do
      throw_syntax_error!(
        "the given macro component #{inspect(module)} does not implement the `Phoenix.Component.MacroComponent` behaviour",
        tag_meta
      )
    end

    module
  end

  defp validate_directives!(module, directives, meta) do
    Enum.each(directives, fn {key, value} ->
      validate_directive!(module, key, value, meta)
    end)

    directives
  end

  defp validate_directive!(_module, :root_tag_attribute, nil, _), do: :ok

  defp validate_directive!(_module, :root_tag_attribute, {name, value}, _meta)
       when is_binary(name) and (is_binary(value) or value == true) do
    :ok
  end

  defp validate_directive!(module, :root_tag_attribute, other, meta) do
    throw_syntax_error!(
      """
      expected {name, value} for :root_tag_attribute directive from macro component #{inspect(module)}, got: #{inspect(other)}

      name must be a compile-time string, and value must be a compile-time string or true
      """,
      meta
    )
  end

  defp validate_directive!(module, directive, value, meta) do
    throw_syntax_error!(
      "unknown directive #{inspect({directive, value})} provided by macro component #{inspect(module)}",
      meta
    )
  end

  defp throw_syntax_error!(message, meta) do
    throw({:syntax_error, meta.line, meta.column, message})
  end

  defp format_type(:slot), do: "slots"
  defp format_type(_), do: "components"
end
