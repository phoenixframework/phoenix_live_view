defmodule Phoenix.LiveView.TagEngine.Compiler do
  @moduledoc false

  alias Phoenix.LiveView.TagEngine.Tokenizer.ParseError

  @doc """
  Compiles the node tag tree into Elixir code.

  Under the hood, this uses the `Phoenix.LiveView.Engine`
  to convert template parts into static and dynamic parts
  and perform change tracking. See the Engine documentation
  for more details.

  This function is responsible for converting the nodes into
  text and expression parts and properly invoking the engine
  with the correct code for features like components and slots.
  """
  def compile(nodes, opts) do
    {engine, opts} = Keyword.pop(opts, :engine, Phoenix.LiveView.Engine)
    tag_handler = Keyword.fetch!(opts, :tag_handler)

    state = %{
      engine: engine,
      file: Keyword.get(opts, :file, "nofile"),
      indentation: Keyword.get(opts, :indentation, 0),
      caller: Keyword.fetch!(opts, :caller),
      source: Keyword.fetch!(opts, :source),
      tag_handler: tag_handler,
      # slots is the only key that is updated when traversing nodes
      slots: []
    }

    # Live components require a single, static root tag.
    # This is because they are patched independently on the client
    # and morphdom requires a single DOM node as an entrypoint for patching.
    # It needs to be static, because if it is not, we cannot guarantee
    # that it might render multiple tags at runtime.
    #
    # Because the parser already resolves macro components and trims
    # leading and trailing whitespace, the root check can be a simple
    # pattern match.
    root =
      case nodes do
        # We do not allow any special attribute (:for, :if),
        # because these violate the static requirement.
        [{:block, :tag, _name, _attrs, _children, meta, _close_meta}]
        when is_map_key(meta, :special) and meta.special == [] ->
          true

        [{:self_close, :tag, _name, _attrs, meta}]
        when is_map_key(meta, :special) and meta.special == [] ->
          true

        _ ->
          false
      end

    {state, substate} = handle_node(nodes, engine.init(caller: opts[:caller]), state)

    caller = state.caller
    body_opts = [root: root]

    body_opts =
      if annotation = caller && has_tags?(nodes) && tag_handler.annotate_body(caller) do
        [meta: [template_annotation: annotation]] ++ body_opts
      else
        body_opts
      end

    ast = state.engine.handle_body(substate, body_opts)

    quote do
      require Phoenix.LiveView.TagEngine
      unquote(ast)
    end
  end

  defp handle_node(nodes, substate, state) when is_list(nodes) do
    Enum.reduce(nodes, {state, substate}, fn node, {state, substate} ->
      handle_node(node, substate, state)
    end)
  end

  defp handle_node({:text, "", _meta}, substate, state) do
    {state, substate}
  end

  defp handle_node({:text, text, _meta}, substate, state) do
    substate = state.engine.handle_text(substate, [], text)
    {state, substate}
  end

  ## Skip EEx comments (<%!-- ... --%>)
  defp handle_node({:eex_comment, _text}, substate, state) do
    {state, substate}
  end

  ## HEEx interpolation {...}
  defp handle_node({:body_expr, expr, %{line: line, column: column}}, substate, state) do
    ast = Code.string_to_quoted!(expr, line: line, column: column, file: state.file)
    substate = state.engine.handle_expr(substate, "=", ast)
    {state, substate}
  end

  ## EEx expression (<% ... %> or any modifier like <%= ... %>)
  defp handle_node({:eex, expr, %{opt: opt, line: line, column: column}}, substate, state) do
    ast = Code.string_to_quoted!(expr, line: line, column: column, file: state.file)
    # opt is a charlist from the tokenizer, convert to string for the engine
    marker = to_string(opt)
    substate = state.engine.handle_expr(substate, marker, ast)
    {state, substate}
  end

  ## eex_block (if/case/for/etc)
  #
  # Uses the same approach as EEx.Compiler: builds up the complete expression string
  # with __EEX__(key) placeholders, parses it as Elixir code, then replaces the
  # placeholders with the actual compiled content.
  defp handle_node(
         {:eex_block, expr, blocks, %{line: line, column: column, opt: opt}},
         substate,
         state
       ) do
    # EEx block structure: expr is "case @status do", blocks are [{children, clause_expr}, ...]
    # For example: imagine this template
    #
    # ```heex
    # <%= case @status do %>
    #   <% :connecting -> %>
    #     <.status status={@status} />
    #   <% :loading -> %>
    #     <.status status={@status} />
    #   <% :connected -> %>
    #     <.status status={@status} />
    #   <% :loaded -> %>
    #     <.live_component module={__MODULE__.Form} id="my-form" name={@name} email={@email} />
    # <% end %>
    # ```
    #
    # This ends up as an eex_block like this:
    #
    # [
    #   {:eex_block, "case @status do",
    #   [
    #     {[{:text, "\n      ", %{}}], ":connecting ->"},
    #     {[
    #        {:text, "\n        ", %{}},
    #        {:self_close, :local_component, "status", [...], %{}},
    #        {:text, "\n      ", %{}}
    #      ], ":loading ->"},
    #     {children, ":connected ->"},
    #     {children, ":loaded ->"},
    #     {children, "end"}
    #   ], %{line: 1, opt: ~c"=", column: 1}}
    # ]
    #
    # So we start with the beginning, then we get pairs of children we need to handle,
    # followed by the next clause / end.
    #
    # Each clause is its own EEx nesting, so we call handle_begin, process the children
    # and get the compiled AST for the clause.
    #
    # Now, since we also need to compile the text parts, we also build a string with
    # placeholders that ends up looking like this:
    #
    # case @status do
    #  :connecting -> __EEX__(0);
    #
    #  :loading -> __EEX__(1);
    #
    #  :connected -> __EEX__(2);
    #
    #  :loaded -> __EEX__(3);
    #
    #  end
    #
    # Afterwards, the placeholders are replaced with the compiled content.
    #
    {quoted, combined_expr, _current_line} =
      Enum.reduce(blocks, {[], expr, line}, fn
        {children, clause_expr, clause_meta}, {quoted, acc_expr, prev_line} ->
          # Calculate newlines needed to reach this clause's line
          clause_line = clause_meta.line
          newlines = String.duplicate("\n", clause_line - prev_line)

          if all_spaces?(children) do
            # This handles the case where the start expression is immediately followed
            # by a middle expression, since we don't want to generate
            # case @status do __EEX__(0); :connecting -> __EEX__(1) ...
            # (we nened to skip adding the first placeholder)
            # and instead generate
            # case @status do :connecting -> __EEX__(0); ...
            {quoted, acc_expr <> newlines <> " " <> clause_expr, clause_line}
          else
            inner_substate = state.engine.handle_begin(substate)
            {_state, inner_substate} = handle_node(children, inner_substate, state)
            clause_ast = state.engine.handle_end(inner_substate)

            key = length(quoted)
            placeholder = "__EEX__(#{key});"
            quoted = [{key, clause_ast} | quoted]
            acc_expr = acc_expr <> " " <> placeholder <> newlines <> " " <> clause_expr
            {quoted, acc_expr, clause_line}
          end
      end)

    # Calculate column offset: column points to '<', add length of '<%' + marker
    # opt is a charlist like ~c"=" for <%= or ~c"" for <%
    expr_column = column + 2 + length(opt)

    # Parse the complete expression with placeholders
    block_ast =
      Code.string_to_quoted!(combined_expr,
        line: line,
        column: expr_column,
        columns: true,
        file: state.file
      )

    # Replace placeholders with actual content
    final_ast = insert_quoted(block_ast, quoted)

    # opt is a charlist from the tokenizer, convert to string for the engine
    marker = to_string(opt)
    substate = state.engine.handle_expr(substate, marker, final_ast)
    {state, substate}
  end

  ## Self-closing tag (<div />)
  defp handle_node({:self_close, :tag, name, attrs, meta}, substate, state) do
    %{closing: closing} = meta
    suffix = if closing == :void, do: ">", else: "></#{name}>"
    attrs = postprocess_attrs(attrs, state)
    validate_phx_attrs!(attrs, meta, state)
    validate_tag_attrs!(attrs, meta, state)

    with_special_attrs(attrs, meta, substate, state, fn attrs, meta, substate, state ->
      substate = handle_tag_and_attrs(name, attrs, suffix, to_location(meta), substate, state)
      {state, substate}
    end)
  end

  ## Self-closing slot (<:some_slot />)
  defp handle_node({:self_close, :slot, slot_name, attrs, meta}, substate, state) do
    slot_name = String.to_atom(slot_name)
    attrs = postprocess_attrs(attrs, state)
    %{line: line} = meta
    {special, roots, attrs, attr_info} = split_component_attrs({"slot", slot_name}, attrs, state)
    let = special[":let"]

    with {_, let_meta} <- let do
      message = "cannot use :let on a slot without inner content"
      raise_syntax_error!(message, let_meta, state)
    end

    attrs = [__slot__: slot_name, inner_block: nil] ++ attrs
    assigns = wrap_special_slot(special, merge_component_attrs(roots, attrs, line))

    state = add_slot(state, slot_name, assigns, attr_info, meta, special)
    {state, substate}
  end

  ## Self-closing local component (<.some_component />)
  defp handle_node({:self_close, :local_component, name, attrs, meta}, substate, state) do
    fun = String.to_atom(name)
    %{line: line, column: column} = meta
    attrs = postprocess_attrs(attrs, state)

    {assigns, attr_info} =
      build_self_close_component_assigns({"local component", fun}, attrs, line, state)

    mod = actual_component_module(state.caller, fun)
    store_component_call({mod, fun}, attr_info, [], line, state)
    call_meta = [line: line, column: column]
    call = {fun, call_meta, __MODULE__}

    ast =
      quote line: line do
        Phoenix.LiveView.TagEngine.component(
          &(unquote(call) / 1),
          unquote(assigns),
          {__MODULE__, __ENV__.function, __ENV__.file, unquote(line)}
        )
      end

    with_special_attrs(attrs, meta, substate, state, fn _new_attrs, _new_meta, substate, state ->
      substate = maybe_anno_caller(substate, call_meta, state.file, line, state)
      substate = state.engine.handle_expr(substate, "=", ast)
      {state, substate}
    end)
  end

  ## Self-closing remote component (<MyModule.some_component />)
  defp handle_node({:self_close, :remote_component, name, attrs, meta}, substate, state) do
    attrs = postprocess_attrs(attrs, state)
    {mod_ast, mod_size, fun} = decompose_remote_component_tag!(name, meta, state)
    %{line: line, column: column} = meta

    {assigns, attr_info} =
      build_self_close_component_assigns({"remote component", name}, attrs, meta.line, state)

    mod = expand_with_line(mod_ast, line, state.caller)
    store_component_call({mod, fun}, attr_info, [], line, state)
    call_meta = [line: line, column: column + mod_size]
    call = {{:., call_meta, [mod_ast, fun]}, call_meta, []}

    ast =
      quote line: meta.line do
        Phoenix.LiveView.TagEngine.component(
          &(unquote(call) / 1),
          unquote(assigns),
          {__MODULE__, __ENV__.function, __ENV__.file, unquote(meta.line)}
        )
      end

    with_special_attrs(attrs, meta, substate, state, fn _new_attrs, _new_meta, substate, state ->
      substate = maybe_anno_caller(substate, call_meta, state.file, line, state)
      substate = state.engine.handle_expr(substate, "=", ast)
      {state, substate}
    end)
  end

  ## Regular HTML tag with content (<div>...</div>)
  defp handle_node({:block, :tag, name, attrs, children, meta, close_meta}, substate, state) do
    attrs = postprocess_attrs(attrs, state)
    validate_phx_attrs!(attrs, meta, state)
    validate_tag_attrs!(attrs, meta, state)

    with_special_attrs(attrs, meta, substate, state, fn attrs, meta, substate, state ->
      substate = handle_tag_and_attrs(name, attrs, ">", to_location(meta), substate, state)
      {_child_state, substate} = handle_node(children, substate, state)
      substate = state.engine.handle_text(substate, [to_location(close_meta)], "</#{name}>")
      {state, substate}
    end)
  end

  ## Slot with content (<:slot>...</:slot>)
  defp handle_node({:block, :slot, slot_name, attrs, children, meta, close_meta}, substate, state) do
    slot_name = String.to_atom(slot_name)
    attrs = postprocess_attrs(attrs, state)
    %{line: line} = meta

    {special, roots, attrs, attr_info} =
      split_component_attrs({"slot", slot_name}, attrs, state)

    # The parser verifies that slots are direct component children,
    # so can ignore slots here, as they are always empty.
    {clauses, _slots} =
      build_component_clauses(
        special[":let"],
        slot_name,
        children,
        meta,
        close_meta,
        substate,
        state
      )

    ast =
      quote line: line do
        Phoenix.LiveView.TagEngine.inner_block(unquote(slot_name), do: unquote(clauses))
      end

    attrs = [__slot__: slot_name, inner_block: ast] ++ attrs
    assigns = wrap_special_slot(special, merge_component_attrs(roots, attrs, line))
    inner = add_inner_block(attr_info, ast, meta)

    state = add_slot(state, slot_name, assigns, inner, meta, special)
    {state, substate}
  end

  ## Local component with content (<.some_component>...</.some_component>)
  defp handle_node(
         {:block, :local_component, name, attrs, children, meta, close_meta},
         substate,
         state
       ) do
    fun = String.to_atom(name)
    %{line: line, column: column} = meta
    attrs = postprocess_attrs(attrs, state)
    mod = actual_component_module(state.caller, fun)
    ref = {"local component", fun}

    with_special_attrs(attrs, meta, substate, state, fn attrs, meta, substate, state ->
      {assigns, attr_info, slot_info} =
        build_component_assigns(ref, attrs, children, meta, close_meta, substate, state)

      store_component_call({mod, fun}, attr_info, slot_info, line, state)
      call_meta = [line: line, column: column]
      call = {fun, call_meta, __MODULE__}

      ast =
        quote line: line do
          Phoenix.LiveView.TagEngine.component(
            &(unquote(call) / 1),
            unquote(assigns),
            {__MODULE__, __ENV__.function, __ENV__.file, unquote(line)}
          )
        end
        |> tag_slots(slot_info)

      substate = maybe_anno_caller(substate, call_meta, state.file, line, state)
      substate = state.engine.handle_expr(substate, "=", ast)
      {state, substate}
    end)
  end

  ## Remote component with content (<MyModule.some_component>...</MyModule.some_component>)
  defp handle_node(
         {:block, :remote_component, name, attrs, children, meta, close_meta},
         substate,
         state
       ) do
    {mod_ast, mod_size, fun} = decompose_remote_component_tag!(name, meta, state)
    %{line: line, column: column} = meta
    attrs = postprocess_attrs(attrs, state)
    mod = expand_with_line(mod_ast, line, state.caller)
    ref = {"remote component", name}

    with_special_attrs(attrs, meta, substate, state, fn attrs, meta, substate, state ->
      # Process children in a new nesting
      {assigns, attr_info, slot_info} =
        build_component_assigns(ref, attrs, children, meta, close_meta, substate, state)

      store_component_call({mod, fun}, attr_info, slot_info, line, state)
      call_meta = [line: line, column: column + mod_size]
      call = {{:., call_meta, [mod_ast, fun]}, call_meta, []}

      ast =
        quote line: line do
          Phoenix.LiveView.TagEngine.component(
            &(unquote(call) / 1),
            unquote(assigns),
            {__MODULE__, __ENV__.function, __ENV__.file, unquote(line)}
          )
        end
        |> tag_slots(slot_info)

      substate = maybe_anno_caller(substate, call_meta, state.file, line, state)
      substate = state.engine.handle_expr(substate, "=", ast)
      {state, substate}
    end)
  end

  ## EEx block helpers

  defp all_spaces?(children) do
    Enum.all?(children, fn
      {:eex_comment, _} -> true
      {:text, text, _} -> String.trim_leading(text) == ""
      _ -> false
    end)
  end

  # Replace __EEX__(key) placeholders with actual compiled content
  # This is taken from EEx.Compiler
  defp insert_quoted({:__EEX__, _, [key]}, quoted) do
    {^key, value} = List.keyfind(quoted, key, 0)
    value
  end

  defp insert_quoted({left, meta, right}, quoted) do
    {insert_quoted(left, quoted), meta, insert_quoted(right, quoted)}
  end

  defp insert_quoted({left, right}, quoted) do
    {insert_quoted(left, quoted), insert_quoted(right, quoted)}
  end

  defp insert_quoted(list, quoted) when is_list(list) do
    Enum.map(list, &insert_quoted(&1, quoted))
  end

  defp insert_quoted(other, _quoted) do
    other
  end

  ## Tag attributes

  defp handle_tag_and_attrs(name, attrs, suffix, meta, substate, state) do
    text =
      if debug_attributes?(state.caller) do
        "<#{name} data-phx-loc=\"#{meta[:line]}\""
      else
        "<#{name}"
      end

    substate = state.engine.handle_text(substate, meta, text)
    substate = handle_tag_attrs(meta, attrs, substate, state)
    state.engine.handle_text(substate, meta, suffix)
  end

  defp handle_tag_attrs(meta, attrs, substate, state) do
    Enum.reduce(attrs, substate, fn
      {:root, {:expr, _, _} = expr, _attr_meta}, substate ->
        ast = parse_expr!(expr, state.file)

        # If we have a map of literal keys, we unpack it as a list
        # to simplify the downstream check.
        ast =
          with {:%{}, _meta, pairs} <- ast,
               true <- literal_keys?(pairs) do
            pairs
          else
            _ -> ast
          end

        handle_tag_expr_attrs(meta, ast, substate, state)

      {name, {:expr, _, _} = expr, _attr_meta}, substate ->
        handle_tag_expr_attrs(meta, [{name, parse_expr!(expr, state.file)}], substate, state)

      {name, {:string, value, %{delimiter: ?"}}, _attr_meta}, substate ->
        state.engine.handle_text(substate, meta, ~s( #{name}="#{value}"))

      {name, {:string, value, %{delimiter: ?'}}, _attr_meta}, substate ->
        state.engine.handle_text(substate, meta, ~s( #{name}='#{value}'))

      {name, nil, _attr_meta}, substate ->
        state.engine.handle_text(substate, meta, " #{name}")
    end)
  end

  defp handle_tag_expr_attrs(meta, ast, substate, state) do
    # It is safe to List.wrap/1 because if we receive nil,
    # it would become the interpolation of nil, which is an
    # empty string anyway.
    case state.tag_handler.handle_attributes(ast, meta) do
      {:attributes, attrs} ->
        Enum.reduce(attrs, substate, fn
          {name, value}, substate ->
            substate = state.engine.handle_text(substate, meta, ~s( #{name}="))

            substate =
              value
              |> List.wrap()
              |> Enum.reduce(substate, fn
                binary, substate when is_binary(binary) ->
                  state.engine.handle_text(substate, meta, binary)

                expr, substate ->
                  state.engine.handle_expr(substate, "=", expr)
              end)

            state.engine.handle_text(substate, meta, ~s("))

          quoted, substate ->
            state.engine.handle_expr(substate, "=", quoted)
        end)

      {:quoted, quoted} ->
        state.engine.handle_expr(substate, "=", quoted)
    end
  end

  defp parse_expr!({:expr, value, %{line: line, column: col}}, file) do
    Code.string_to_quoted!(value, line: line, column: col, file: file)
  end

  defp literal_keys?([{key, _value} | rest]) when is_atom(key) or is_binary(key),
    do: literal_keys?(rest)

  defp literal_keys?([]), do: true
  defp literal_keys?(_other), do: false

  ## Component assign helpers

  defp build_self_close_component_assigns(type_component, attrs, line, state) do
    {special, roots, attrs, attr_info} = split_component_attrs(type_component, attrs, state)
    raise_if_let!(special[":let"], state.file)
    {merge_component_attrs(roots, attrs, line), attr_info}
  end

  defp build_component_assigns(
         type_component,
         attrs,
         children,
         tag_meta,
         tag_close_meta,
         substate,
         state
       ) do
    %{line: line} = tag_meta
    {special, roots, attrs, attr_info} = split_component_attrs(type_component, attrs, state)

    {clauses, slots} =
      build_component_clauses(
        special[":let"],
        :inner_block,
        children,
        tag_meta,
        tag_close_meta,
        substate,
        state
      )

    inner_block =
      quote line: line do
        Phoenix.LiveView.TagEngine.inner_block(:inner_block, do: unquote(clauses))
      end

    inner_block_assigns =
      quote line: line do
        %{
          __slot__: :inner_block,
          inner_block: unquote(inner_block)
        }
      end

    {slot_assigns, slot_info} = slots

    slot_info = [
      {:inner_block, [{tag_meta, add_inner_block({false, [], []}, inner_block, tag_meta)}]}
      | slot_info
    ]

    attrs = attrs ++ [{:inner_block, [inner_block_assigns]} | slot_assigns]
    {merge_component_attrs(roots, attrs, line), attr_info, slot_info}
  end

  defp split_component_attrs(type_component, attrs, state) do
    {special, roots, attrs, locs} =
      attrs
      |> Enum.reverse()
      |> Enum.reduce(
        {%{}, [], [], []},
        &split_component_attr(&1, &2, state, type_component)
      )

    {special, roots, attrs, {roots != [], attrs, locs}}
  end

  defp split_component_attr(
         {:root, {:expr, value, %{line: line, column: col}}, _attr_meta},
         {special, r, a, locs},
         state,
         _type_component
       ) do
    quoted_value = Code.string_to_quoted!(value, line: line, column: col, file: state.file)
    quoted_value = quote line: line, do: Map.new(unquote(quoted_value))
    {special, [quoted_value | r], a, locs}
  end

  @special_attrs ~w(:let :if :for :key)
  defp split_component_attr(
         {":key", _expr, attr_meta},
         _,
         state,
         {"slot", slot_name}
       ) do
    message = ":key is not supported on slots: #{slot_name}"
    raise_syntax_error!(message, attr_meta, state)
  end

  defp split_component_attr(
         {attr, {:expr, value, %{line: line, column: col} = meta}, attr_meta},
         {special, r, a, locs},
         state,
         _type_component
       )
       when attr in @special_attrs do
    case special do
      %{^attr => {_, attr_meta}} ->
        message = """
        cannot define multiple #{attr} attributes. \
        Another #{attr} has already been defined at line #{meta.line}\
        """

        raise_syntax_error!(message, attr_meta, state)

      %{} ->
        quoted_value = Code.string_to_quoted!(value, line: line, column: col, file: state.file)
        validate_quoted_special_attr!(attr, quoted_value, attr_meta, state)
        {Map.put(special, attr, {quoted_value, attr_meta}), r, a, locs}
    end
  end

  defp split_component_attr({attr, _, meta}, _state, state, {type, component_or_slot})
       when attr in @special_attrs do
    message = "#{attr} must be a pattern between {...} in #{type}: #{component_or_slot}"
    raise_syntax_error!(message, meta, state)
  end

  defp split_component_attr({":" <> _ = name, _, meta}, _state, state, {type, component_or_slot}) do
    message = "unsupported attribute #{inspect(name)} in #{type}: #{component_or_slot}"
    raise_syntax_error!(message, meta, state)
  end

  defp split_component_attr(
         {name, {:expr, value, %{line: line, column: col}}, attr_meta},
         {special, r, a, locs},
         state,
         _type_component
       ) do
    quoted_value = Code.string_to_quoted!(value, line: line, column: col, file: state.file)
    {special, r, [{String.to_atom(name), quoted_value} | a], [line_column(attr_meta) | locs]}
  end

  defp split_component_attr(
         {name, {:string, value, _meta}, attr_meta},
         {special, r, a, locs},
         _state,
         _type_component
       ) do
    {special, r, [{String.to_atom(name), value} | a], [line_column(attr_meta) | locs]}
  end

  defp split_component_attr(
         {name, nil, attr_meta},
         {special, r, a, locs},
         _state,
         _type_component
       ) do
    {special, r, [{String.to_atom(name), true} | a], [line_column(attr_meta) | locs]}
  end

  defp line_column(%{line: line, column: column}), do: {line, column}

  defp merge_component_attrs(roots, attrs, line) do
    entries =
      case {roots, attrs} do
        {[], []} -> [{:%{}, [], []}]
        {_, []} -> roots
        {_, _} -> roots ++ [{:%{}, [], attrs}]
      end

    Enum.reduce(entries, fn expr, acc ->
      quote line: line, do: Map.merge(unquote(acc), unquote(expr))
    end)
  end

  defp decompose_remote_component_tag!(tag_name, tag_meta, state) do
    case String.split(tag_name, ".") |> Enum.reverse() do
      [<<first, _::binary>> = fun_name | rest] when first in ?a..?z ->
        size = Enum.sum(Enum.map(rest, &byte_size/1)) + length(rest) + 1
        aliases = rest |> Enum.reverse() |> Enum.map(&String.to_atom/1)
        fun = String.to_atom(fun_name)
        %{line: line, column: column} = tag_meta
        {{:__aliases__, [line: line, column: column], aliases}, size, fun}

      _ ->
        message = "invalid tag <#{tag_meta.tag_name}>"
        raise_syntax_error!(message, tag_meta, state)
    end
  end

  defp raise_if_let!(let, file) do
    with {_pattern, %{line: line}} <- let do
      message = "cannot use :let on a component without inner content"
      raise CompileError, line: line, file: file, description: message
    end
  end

  # Given the child nodes, this function builds the clause AST for a component.
  # If a component is defined as <.my_component>, this looks like this:
  #
  # _ -> ast
  #
  # If a component is defined as as <.my_component :let={%{foo: foo, bar: bar}}, we get:
  #
  # %{foo: foo, bar: bar} -> ast
  # other -> Phoenix.LiveView.TagEngine.__unmatched_let__!("%{foo: foo, bar: bar}", other)
  #
  # Which is later wrapped by the inner_block macro.
  #
  # If there are any named slots that are part of the children,
  # those are recursively converted into clauses (slots can also use :let)
  # and returned as {slot_assigns, slot_info}.
  defp build_component_clauses(
         let,
         name,
         children,
         tag_meta,
         tag_close_meta,
         substate,
         %{caller: caller} = state
       ) do
    inner_substate = state.engine.handle_begin(substate)
    state = init_slots(state)
    {inner_state, inner_substate} = handle_node(children, inner_substate, state)
    {slot_assigns, slot_info, _state} = pop_slots(inner_state)

    opts =
      if annotation =
           caller && has_tags?(children) &&
             state.tag_handler.annotate_slot(name, tag_meta, tag_close_meta, caller) do
        [meta: [template_annotation: annotation]]
      else
        []
      end

    ast = state.engine.handle_end(inner_substate, opts)

    clauses =
      case let do
        # If we have a var, we can skip the catch-all clause
        {{var, _, ctx} = pattern, %{line: line}} when is_atom(var) and is_atom(ctx) ->
          quote line: line do
            unquote(pattern) -> unquote(ast)
          end

        {pattern, %{line: line}} ->
          quote line: line do
            unquote(pattern) -> unquote(ast)
          end ++
            quote generated: true do
              other ->
                Phoenix.LiveView.TagEngine.__unmatched_let__!(
                  unquote(Macro.to_string(pattern)),
                  other
                )
            end

        _ ->
          quote do
            _ -> unquote(ast)
          end
      end

    {clauses, {slot_assigns, slot_info}}
  end

  defp store_component_call(component, attr_info, slot_info, line, %{caller: caller} = state) do
    module = caller.module

    if module && Module.open?(module) do
      pruned_slots =
        for {slot_name, slot_values} <- slot_info, into: %{} do
          values =
            for {tag_meta, {root?, attrs, locs}} <- slot_values do
              %{line: tag_meta.line, root: root?, attrs: attrs_for_call(attrs, locs)}
            end

          {slot_name, values}
        end

      {root?, attrs, locs} = attr_info
      pruned_attrs = attrs_for_call(attrs, locs)

      call = %{
        component: component,
        slots: pruned_slots,
        attrs: pruned_attrs,
        file: state.file,
        line: line,
        root: root?
      }

      # This may still fail under a very specific scenario where
      # we are defining a template dynamically inside a function
      # (most likely a test) that starts running while the module
      # is still open.
      try do
        Module.put_attribute(module, :__components_calls__, call)
      rescue
        _ -> :ok
      end
    end
  end

  defp attrs_for_call(attrs, locs) do
    for {{attr, value}, {line, column}} <- Enum.zip(attrs, locs),
        do: {attr, {line, column, attr_type(value)}},
        into: %{}
  end

  defp attr_type({:<<>>, _, _} = value), do: {:string, value}
  defp attr_type(value) when is_list(value), do: {:list, value}
  defp attr_type(value = {:%{}, _, _}), do: {:map, value}
  defp attr_type(value) when is_binary(value), do: {:string, value}
  defp attr_type(value) when is_integer(value), do: {:integer, value}
  defp attr_type(value) when is_float(value), do: {:float, value}
  defp attr_type(value) when is_boolean(value), do: {:boolean, value}
  defp attr_type(value) when is_atom(value), do: {:atom, value}
  defp attr_type({:fn, _, [{:->, _, [args, _]}]}), do: {:fun, length(args)}
  defp attr_type({:&, _, [{:/, _, [_, arity]}]}), do: {:fun, arity}

  # this could be a &myfun(&1, &2)
  defp attr_type({:&, _, args}) do
    {_ast, arity} =
      Macro.prewalk(args, 0, fn
        {:&, _, [n]} = ast, acc when is_integer(n) ->
          {ast, max(n, acc)}

        ast, acc ->
          {ast, acc}
      end)

    (arity > 0 && {:fun, arity}) || :any
  end

  defp attr_type(_value), do: :any

  ## Slot helpers

  defp init_slots(state) do
    %{state | slots: [[] | state.slots]}
  end

  defp add_inner_block({roots?, attrs, locs}, ast, tag_meta) do
    {roots?, [{:inner_block, ast} | attrs], [line_column(tag_meta) | locs]}
  end

  defp add_slot(state, slot_name, slot_assigns, slot_info, tag_meta, special_attrs) do
    %{slots: [slots | other_slots]} = state
    slot = {slot_name, slot_assigns, special_attrs, {tag_meta, slot_info}}
    %{state | slots: [[slot | slots] | other_slots]}
  end

  defp pop_slots(%{slots: [slots | other_slots]} = state) do
    # Perform group_by by hand as we need to group two distinct maps.
    {acc_assigns, acc_info, specials} =
      Enum.reduce(slots, {%{}, %{}, %{}}, fn
        {key, assigns, special, info}, {acc_assigns, acc_info, specials} ->
          special? = Map.has_key?(special, ":if") or Map.has_key?(special, ":for")
          specials = Map.update(specials, key, special?, &(&1 or special?))

          case acc_assigns do
            %{^key => existing_assigns} ->
              acc_assigns = %{acc_assigns | key => [assigns | existing_assigns]}
              %{^key => existing_info} = acc_info
              acc_info = %{acc_info | key => [info | existing_info]}
              {acc_assigns, acc_info, specials}

            %{} ->
              {Map.put(acc_assigns, key, [assigns]), Map.put(acc_info, key, [info]), specials}
          end
      end)

    acc_assigns =
      Enum.into(acc_assigns, %{}, fn {key, assigns_ast} ->
        cond do
          # No special entry, return it as a list
          not Map.fetch!(specials, key) ->
            {key, assigns_ast}

          # We have a special entry and multiple entries, we have to flatten
          match?([_, _ | _], assigns_ast) ->
            {key, quote(do: List.flatten(unquote(assigns_ast)))}

          # A single special entry is guaranteed to return a list from the expression
          true ->
            {key, hd(assigns_ast)}
        end
      end)

    {Map.to_list(acc_assigns), Map.to_list(acc_info), %{state | slots: other_slots}}
  end

  defp wrap_special_slot(special, ast) do
    case special do
      %{":for" => {for_expr, %{line: line}}, ":if" => {if_expr, %{line: _line}}} ->
        quote line: line do
          for unquote(for_expr), unquote(if_expr), do: unquote(ast)
        end

      %{":for" => {for_expr, %{line: line}}} ->
        quote line: line do
          for unquote(for_expr), do: unquote(ast)
        end

      %{":if" => {if_expr, %{line: line}}} ->
        quote line: line do
          if unquote(if_expr), do: [unquote(ast)], else: []
        end

      %{} ->
        ast
    end
  end

  defp tag_slots({call, meta, args}, slot_info) do
    {call, [slots: Keyword.keys(slot_info)] ++ meta, args}
  end

  ## Special expressions (:if, :for, :key)

  # Handles :for, :if wrapping by executing the given function
  # in a new handle_begin / handle_end block, and building the
  # correct wrapper AST.
  defp with_special_attrs(attrs, meta, substate, state, fun) do
    case pop_special_attrs!(attrs, meta, state) do
      {false, meta, attrs} ->
        fun.(attrs, meta, substate, state)

      {true, new_meta, new_attrs} ->
        inner_substate = state.engine.handle_begin(substate)
        {state, inner_substate} = fun.(new_attrs, new_meta, inner_substate, state)
        inner_ast = state.engine.handle_end(inner_substate)

        ast = handle_special_expr(new_meta, inner_ast, state)
        substate = state.engine.handle_expr(substate, "=", ast)
        {state, substate}
    end
  end

  # Pops all special attributes from attrs. Raises if any given attr is duplicated within
  # attrs.
  #
  # Examples:
  #
  #   attrs = [{":for", {...}}, {"class", {...}}]
  #   pop_special_attrs!(attrs, %{}, state)
  #   => {true, %{for: parsed_ast, ...}, [{"class", {...}]}}
  #
  #   attrs = [{"class", {...}}]
  #   pop_special_attrs!(attrs, %{}, state)
  #   => {false, %{}, [{"class", {...}}]}
  defp pop_special_attrs!(attrs, tag_meta, state) do
    Enum.reduce([for: ":for", if: ":if", key: ":key"], {false, tag_meta, attrs}, fn
      {attr, string_attr}, {special_acc, meta_acc, attrs_acc} ->
        attrs_acc
        |> List.keytake(string_attr, 0)
        |> raise_if_duplicated_special_attr!(state)
        |> case do
          {{^string_attr, {:expr, _, _} = expr, meta}, attrs} ->
            parsed_expr = parse_expr!(expr, state.file)
            validate_quoted_special_attr!(string_attr, parsed_expr, meta, state)
            {true, Map.put(meta_acc, attr, parsed_expr), attrs}

          {{^string_attr, _expr, meta}, _attrs} ->
            message = "#{string_attr} must be an expression between {...}"
            raise_syntax_error!(message, meta, state)

          nil ->
            {special_acc, meta_acc, attrs_acc}
        end
    end)
  end

  defp raise_if_duplicated_special_attr!({{attr, _expr, _meta}, attrs} = result, state) do
    case List.keytake(attrs, attr, 0) do
      {{attr, _expr, meta}, _attrs} ->
        message =
          "cannot define multiple #{inspect(attr)} attributes. Another #{inspect(attr)} has already been defined at line #{meta.line}"

        raise_syntax_error!(message, meta, state)

      nil ->
        result
    end
  end

  defp raise_if_duplicated_special_attr!(nil, _state), do: nil

  defp handle_special_expr(tag_meta, inner_ast, state) do
    case tag_meta do
      %{for: _for_expr, if: if_expr} ->
        for_expr = maybe_keyed(tag_meta)

        quote do
          for unquote(for_expr), unquote(if_expr), do: unquote(inner_ast)
        end

      %{for: _for_expr} ->
        for_expr = maybe_keyed(tag_meta)

        quote do
          for unquote(for_expr), do: unquote(inner_ast)
        end

      %{if: if_expr} ->
        quote do
          if unquote(if_expr), do: unquote(inner_ast)
        end

      %{key: _} ->
        raise_syntax_error!("cannot use :key without :for", tag_meta, state)
    end
  end

  defp maybe_keyed(%{key: key_expr, for: for_expr}) do
    # we already validated that the for expression has the correct shape in
    # validate_quoted_special_attr
    {:<-, for_meta, [lhs, rhs]} = for_expr
    {:<-, [keyed_comprehension: true, key_expr: key_expr] ++ for_meta, [lhs, rhs]}
  end

  defp maybe_keyed(%{for: for_expr}), do: for_expr

  ## Generic helpers

  defp to_location(%{line: line, column: column}), do: [line: line, column: column]
  defp to_location(_), do: []

  defp actual_component_module(env, fun) do
    case Macro.Env.lookup_import(env, {fun, 1}) do
      [{_, module} | _] -> module
      _ -> env.module
    end
  end

  # removes phx-no-format, etc. and maps phx-hook=".name" to the fully qualified name
  defp postprocess_attrs(attrs, state) do
    attrs_to_remove = ~w(phx-no-format phx-no-curly-interpolation)

    for {key, value, meta} <- attrs,
        key not in attrs_to_remove do
      case {key, value, meta} do
        {"phx-hook", {:string, "." <> name, str_meta}, meta} ->
          {key, {:string, "#{inspect(state.caller.module)}.#{name}", str_meta}, meta}

        _ ->
          {key, value, meta}
      end
    end
  end

  defp validate_tag_attrs!(attrs, %{tag_name: "input"}, state) do
    # warn if using name="id" on an input
    case Enum.find(attrs, &match?({"name", {:string, "id", _}, _}, &1)) do
      {_name, _value, attr_meta} ->
        meta = [
          line: attr_meta.line,
          column: attr_meta.column,
          file: state.file,
          module: state.caller.module,
          function: state.caller.function
        ]

        IO.warn(
          """
          Setting the "name" attribute to "id" on an input tag overrides the ID of the corresponding form element.
          This leads to unexpected behavior, especially when using LiveView, and is not recommended.

          You should use a different value for the "name" attribute, e.g. "_id" and remap the value in the
          corresponding handle_event/3 callback or controller.
          """,
          meta
        )

      _ ->
        :ok
    end
  end

  defp validate_tag_attrs!(_attrs, _meta, _state), do: :ok

  # Check if `phx-update`, `phx-hook` is present in attrs and raises in case
  # there is no ID attribute set.
  defp validate_phx_attrs!(attrs, meta, state) do
    validate_phx_attrs!(attrs, meta, state, nil, false)
  end

  defp validate_phx_attrs!([], meta, state, attr, false)
       when attr in ["phx-update", "phx-hook"] do
    message = "attribute \"#{attr}\" requires the \"id\" attribute to be set"

    raise_syntax_error!(message, meta, state)
  end

  defp validate_phx_attrs!([], _meta, _state, _attr, _id?), do: :ok

  # Handle <div phx-update="ignore" {@some_var}>Content</div> since here the ID
  # might be inserted dynamically so we can't raise at compile time.
  defp validate_phx_attrs!([{:root, _, _} | t], meta, state, attr, _id?),
    do: validate_phx_attrs!(t, meta, state, attr, true)

  defp validate_phx_attrs!([{"id", _, _} | t], meta, state, attr, _id?),
    do: validate_phx_attrs!(t, meta, state, attr, true)

  defp validate_phx_attrs!(
         [{"phx-update", {:string, value, _meta}, attr_meta} | t],
         meta,
         state,
         _attr,
         id?
       ) do
    cond do
      value in ~w(ignore stream replace) ->
        validate_phx_attrs!(t, meta, state, "phx-update", id?)

      value in ~w(append prepend) ->
        line = meta[:line] || state.caller.line

        IO.warn(
          "phx-update=\"#{value}\" is deprecated, please use streams instead",
          Macro.Env.stacktrace(%{state.caller | line: line})
        )

        validate_phx_attrs!(t, meta, state, "phx-update", id?)

      true ->
        message =
          "the value of the attribute \"phx-update\" must be: ignore, stream, append, prepend, or replace"

        raise_syntax_error!(message, attr_meta, state)
    end
  end

  defp validate_phx_attrs!([{"phx-update", _attrs, _} | t], meta, state, _attr, id?) do
    validate_phx_attrs!(t, meta, state, "phx-update", id?)
  end

  defp validate_phx_attrs!([{"phx-hook", _, _} | t], meta, state, _attr, id?),
    do: validate_phx_attrs!(t, meta, state, "phx-hook", id?)

  defp validate_phx_attrs!([{special, value, attr_meta} | t], meta, state, attr, id?)
       when special in ~w(:if :for :type) do
    case value do
      {:expr, _, _} ->
        validate_phx_attrs!(t, meta, state, attr, id?)

      _ ->
        message = "#{special} must be an expression between {...}"
        raise_syntax_error!(message, attr_meta, state)
    end
  end

  defp validate_phx_attrs!([{":" <> name, _, attr_meta} | _], _meta, state, _attr, _id?)
       when name not in ~w(if for key) do
    message = "unsupported attribute :#{name} in tags"
    raise_syntax_error!(message, attr_meta, state)
  end

  defp validate_phx_attrs!([_h | t], meta, state, attr, id?),
    do: validate_phx_attrs!(t, meta, state, attr, id?)

  defp validate_quoted_special_attr!(attr, quoted_value, attr_meta, state) do
    if attr == ":for" and not match?({:<-, _, [_, _]}, quoted_value) do
      message = ":for must be a generator expression (pattern <- enumerable) between {...}"

      raise_syntax_error!(message, attr_meta, state)
    else
      :ok
    end
  end

  defp expand_with_line(ast, line, env) do
    Macro.expand(ast, %{env | line: line})
  end

  defp raise_syntax_error!(message, meta, state) do
    raise ParseError,
      line: meta.line,
      column: meta.column,
      file: state.file,
      description: message <> ParseError.code_snippet(state.source, meta, state.indentation)
  end

  defp maybe_anno_caller(substate, meta, file, line, state) do
    annotate =
      if function_exported?(state.tag_handler, :annotate_caller, 3) do
        fn file, line -> state.tag_handler.annotate_caller(file, line, state.caller) end
      else
        fn file, line -> state.tag_handler.annotate_caller(file, line) end
      end

    if anno = annotate.(file, line) do
      state.engine.handle_text(substate, meta, anno)
    else
      substate
    end
  end

  defp has_tags?([]), do: false

  defp has_tags?([{:text, _, _} | rest]), do: has_tags?(rest)
  defp has_tags?([{:body_expr, _, _} | rest]), do: has_tags?(rest)
  defp has_tags?([{:eex, _, _} | rest]), do: has_tags?(rest)
  defp has_tags?([{:eex_comment, _} | rest]), do: has_tags?(rest)
  defp has_tags?([{:html_comment, _} | rest]), do: has_tags?(rest)

  # EEx blocks - check children in each clause
  defp has_tags?([{:eex_block, _, blocks, _} | rest]) do
    Enum.any?(blocks, fn {children, _clause_expr, _clause_meta} -> has_tags?(children) end) or
      has_tags?(rest)
  end

  # Skip slots
  defp has_tags?([{:self_close, :slot, _, _, _} | rest]), do: has_tags?(rest)
  defp has_tags?([{:block, :slot, _, _, _, _, _} | rest]), do: has_tags?(rest)

  # Tags and components count as having tags
  defp has_tags?([{:self_close, _type, _, _, _} | _]), do: true
  defp has_tags?([{:block, _type, _, _, _, _, _} | _]), do: true

  defp debug_attributes?(caller) do
    if Module.open?(caller.module) do
      case Module.get_attribute(caller.module, :debug_attributes) do
        false -> false
        _ -> Application.get_env(:phoenix_live_view, :debug_attributes, false)
      end
    else
      Application.get_env(:phoenix_live_view, :debug_attributes, false)
    end
  rescue
    _ -> Application.get_env(:phoenix_live_view, :debug_attributes, false)
  end
end
