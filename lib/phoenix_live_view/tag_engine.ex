defmodule Phoenix.LiveView.TagEngine do
  @moduledoc """
  An EEx engine that understands tags.

  This cannot be directly used by Phoenix applications.
  Instead, it is the building block by engines such as
  `Phoenix.LiveView.HTMLEngine`.

  It is typically invoked like this:

      EEx.compile_string(source,
        engine: Phoenix.LiveView.TagEngine,
        line: 1,
        file: path,
        caller: __CALLER__,
        source: source,
        tag_handler: FooBarEngine
      )

  Where `:tag_handler` implements the behaviour defined by this module.
  """

  @doc """
  Classify the tag type from the given binary.

  This must return a tuple containing the type of the tag and the name of tag.
  For instance, for LiveView which uses HTML as default tag handler this would
  return `{:tag, 'div'}` in case the given binary is identified as HTML tag.

  You can also return `{:error, "reason"}` so that the compiler will display this
  error.
  """
  @callback classify_type(name :: binary()) :: {type :: atom(), name :: binary()}

  @doc """
  Returns if the given tag name is void or not.

  That's mainly useful for HTML tags and used internally by the compiler. You
  can just implement as `def void?(_), do: false` if you want to ignore this.
  """
  @callback void?(name :: binary()) :: boolean()

  defmacro finalize(options, do: tokens) do
    options =
      Keyword.merge(options, file: __CALLER__.file, line: __CALLER__.line + 1, caller: __CALLER__)

    function = Keyword.fetch!(options, :subengine_call)

    token_state =
      init(options)
      |> token_state(nil)
      |> continue(tokens)

    opts =
      case function do
        :handle_body ->
          opts = [root: token_state.root || false]

          if annotation = has_tags?(tokens) && options[:tag_handler].annotate_body(__CALLER__) do
            [meta: [template_annotation: annotation]] ++ opts
          else
            opts
          end

        :handle_end ->
          []
      end

    invoke_subengine(token_state, function, [opts])
  end

  @doc """
  Implements processing of attributes.

  It returns a quoted expression or attributes. If attributes are returned,
  the second element is a list where each element in the list represents
  one attribute. If the list element is a two-element tuple, it is assumed
  the key is the name to be statically written in the template. The second
  element is the value which is also statically written to the template whenever
  possible (such as binaries or binaries inside a list).
  """
  @callback handle_attributes(ast :: Macro.t(), meta :: keyword) ::
              {:attributes, [{binary(), Macro.t()} | Macro.t()]} | {:quoted, Macro.t()}

  @doc """
  Callback invoked to add annotations around the whole body of a template.
  """
  @callback annotate_body(caller :: Macro.Env.t()) :: {String.t(), String.t()} | nil

  @doc """
  Callback invoked to add annotations around each slot of a template.

  In case the slot is an implicit inner block, the tag meta points to
  the component.
  """
  @callback annotate_slot(
              name :: atom(),
              tag_meta :: %{line: non_neg_integer(), column: non_neg_integer()},
              close_tag_meta :: %{line: non_neg_integer(), column: non_neg_integer()},
              caller :: Macro.Env.t()
            ) :: {String.t(), String.t()} | nil

  @doc """
  Callback invoked to add caller annotations before a function component is invoked.
  """
  @callback annotate_caller(file :: String.t(), line :: integer()) :: String.t() | nil

  @doc """
  Renders a component defined by the given function.

  This function is rarely invoked directly by users. Instead, it is used by `~H`
  and other engine implementations to render `Phoenix.Component`s. For example,
  the following:

  ```heex
  <MyApp.Weather.city name="Kraków" />
  ```

  Is the same as:

  ```heex
  <%= component(
        &MyApp.Weather.city/1,
        [name: "Kraków"],
        {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
      ) %>
  ```

  """
  def component(func, assigns, caller)
      when (is_function(func, 1) and is_list(assigns)) or is_map(assigns) do
    assigns =
      case assigns do
        %{__changed__: _} -> assigns
        _ -> assigns |> Map.new() |> Map.put_new(:__changed__, nil)
      end

    case func.(assigns) do
      %Phoenix.LiveView.Rendered{} = rendered ->
        %{rendered | caller: caller}

      %Phoenix.LiveView.Component{} = component ->
        component

      other ->
        raise RuntimeError, """
        expected #{inspect(func)} to return a %Phoenix.LiveView.Rendered{} struct

        Ensure your render function uses ~H to define its template.

        Got:

            #{inspect(other)}

        """
    end
  end

  @doc """
  Define a inner block, generally used by slots.

  This macro is mostly used by custom HTML engines that provide
  a `slot` implementation and rarely called directly. The
  `name` must be the assign name the slot/block will be stored
  under.

  If you're using HEEx templates, you should use its higher
  level `<:slot>` notation instead. See `Phoenix.Component`
  for more information.
  """
  defmacro inner_block(name, do: do_block) do
    case do_block do
      [{:->, meta, _} | _] ->
        inner_fun = {:fn, meta, do_block}

        quote do
          fn parent_changed, arg ->
            var!(assigns) =
              unquote(__MODULE__).__assigns__(var!(assigns), unquote(name), parent_changed)

            _ = var!(assigns)
            unquote(inner_fun).(arg)
          end
        end

      _ ->
        quote do
          fn parent_changed, arg ->
            var!(assigns) =
              unquote(__MODULE__).__assigns__(var!(assigns), unquote(name), parent_changed)

            _ = var!(assigns)
            unquote(do_block)
          end
        end
    end
  end

  @doc false
  def __assigns__(assigns, key, parent_changed) do
    # If the component is in its initial render (parent_changed == nil)
    # or the slot/block key is in parent_changed, then we render the
    # function with the assigns as is.
    #
    # Otherwise, we will set changed to an empty list, which is the same
    # as marking everything as not changed. This is correct because
    # parent_changed will always be marked as changed whenever any of the
    # assigns it references inside is changed. It will also be marked as
    # changed if it has any variable (such as the ones coming from let).
    if is_nil(parent_changed) or Map.has_key?(parent_changed, key) do
      assigns
    else
      Map.put(assigns, :__changed__, %{})
    end
  end

  alias Phoenix.LiveView.Tokenizer
  alias Phoenix.LiveView.Tokenizer.ParseError

  @behaviour EEx.Engine

  @impl true
  def init(opts) do
    {subengine, opts} = Keyword.pop(opts, :subengine, Phoenix.LiveView.Engine)
    tag_handler = Keyword.fetch!(opts, :tag_handler)

    %{
      cont: {:text, :enabled},
      tokens: [],
      subengine: subengine,
      substate: subengine.init(opts),
      file: Keyword.get(opts, :file, "nofile"),
      indentation: Keyword.get(opts, :indentation, 0),
      caller: Keyword.fetch!(opts, :caller),
      source: Keyword.fetch!(opts, :source),
      tag_handler: tag_handler
    }
  end

  ## These callbacks return AST

  @impl true
  def handle_body(state) do
    %{tokens: tokens, file: file, cont: cont, source: source} = state

    tokens = Tokenizer.finalize(tokens, file, cont, source)

    {:ok, ast} =
      Phoenix.Component.MacroComponent.build_ast(tokens,
        env: state.caller,
        context: "template",
        source: source,
        indentation: state.indentation,
        tag_handler: state.tag_handler
      )

    quote do
      require Phoenix.LiveView.TagEngine

      Phoenix.LiveView.TagEngine.finalize(
        unquote(
          subengine_call: :handle_body,
          tag_handler: state.tag_handler,
          file: state.file,
          source: state.source,
          line: state.caller.line
        ),
        do: unquote(ast)
      )
    end
  end

  defp has_tags?([{:__block__, _, children} | tokens]),
    do: has_tags?(children) or has_tags?(tokens)

  defp has_tags?([{type, _meta, _args} | _tokens])
       when type in [:local_component, :remote_component, :tag], do: true

  defp has_tags?([_ | tokens]), do: has_tags?(tokens)
  defp has_tags?([]), do: false

  @impl true
  def handle_end(state) do
    {:ok, ast} =
      Phoenix.Component.MacroComponent.build_ast(Enum.reverse(state.tokens),
        env: state.caller,
        context: "do-block",
        source: state.source,
        indentation: state.indentation,
        tag_handler: state.tag_handler
      )

    # we need to wrap the finalize call into a try after
    # to prevent issues from overlapping variables generated by the engine,
    # as we can no longer share the substate
    quote do
      try do
        Phoenix.LiveView.TagEngine.finalize(
          [
            indentation: unquote(state.indentation),
            source: unquote(state.source),
            tag_handler: unquote(state.tag_handler),
            subengine_call: :handle_end
          ],
          do: unquote(ast)
        )
      after
        :ok
      end
    end
  end

  defp token_state(
         %{
           subengine: subengine,
           substate: substate,
           file: file,
           caller: caller,
           source: source,
           indentation: indentation,
           tag_handler: tag_handler
         },
         root
       ) do
    %{
      subengine: subengine,
      substate: substate,
      source: source,
      file: file,
      stack: [],
      tags: [],
      slots: [],
      caller: caller,
      root: root,
      indentation: indentation,
      tag_handler: tag_handler
    }
  end

  defp continue(token_state, tokens) do
    handle_token(tokens, token_state)
  end

  ## These callbacks update the state

  @impl true
  def handle_begin(state) do
    update_subengine(%{state | tokens: []}, :handle_begin, [])
  end

  @impl true
  def handle_text(state, meta, text) do
    %{file: file, indentation: indentation, tokens: tokens, cont: cont, source: source} = state
    tokenizer_state = Tokenizer.init(indentation, file, source, state.tag_handler)
    {tokens, cont} = Tokenizer.tokenize(text, meta, tokens, cont, tokenizer_state)

    %{
      state
      | tokens: tokens,
        cont: cont,
        source: state.source
    }
  end

  @impl true
  def handle_expr(%{tokens: tokens} = state, marker, expr) do
    %{state | tokens: [{:expr, marker, expr} | tokens]}
  end

  ## Helpers

  defp push_substate_to_stack(%{substate: substate, stack: stack} = state) do
    %{state | stack: [{:substate, substate} | stack]}
  end

  defp pop_substate_from_stack(%{stack: [{:substate, substate} | stack]} = state) do
    %{state | stack: stack, substate: substate}
  end

  defp invoke_subengine(%{subengine: subengine, substate: substate}, fun, args) do
    apply(subengine, fun, [substate | args])
  end

  defp update_subengine(state, fun, args) do
    %{state | substate: invoke_subengine(state, fun, args)}
  end

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

  defp prune_text_after_slot([{:<<>>, meta, [text]} | tokens]) when is_binary(text),
    do: [{:<<>>, meta, [String.trim_leading(text)]} | tokens]

  defp prune_text_after_slot([text | tokens]) when is_binary(text),
    do: [String.trim_leading(text) | tokens]

  defp prune_text_after_slot(tokens),
    do: tokens

  defp validate_slot!(%{tags: [{type, _, _, _} | _]}, _name, _tag_meta)
       when type in [:remote_component, :local_component],
       do: :ok

  defp validate_slot!(state, slot_name, meta) do
    message =
      "invalid slot entry <:#{slot_name}>. A slot entry must be a direct child of a component"

    raise_syntax_error!(message, meta, state)
  end

  defp pop_slots(%{slots: [slots | other_slots]} = state) do
    # Perform group_by by hand as we need to group two distinct maps.
    {acc_assigns, acc_info, specials} =
      Enum.reduce(slots, {%{}, %{}, %{}}, fn {key, assigns, special, info},
                                             {acc_assigns, acc_info, specials} ->
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

  defp push_tag(state, token) do
    %{state | tags: [token | state.tags]}
  end

  defp pop_tag!(
         %{tags: [{type, tag_name, _attrs, _meta} = tag | tags]} = state,
         {:close, type, tag_name, _}
       ) do
    {tag, %{state | tags: tags}}
  end

  defp pop_tag!(
         %{tags: [{type, tag_open_name, _attrs, tag_open_meta} | _]} = state,
         {:close, type, tag_close_name, tag_close_meta}
       ) do
    hint = closing_void_hint(tag_close_name, state)

    message = """
    unmatched closing tag. Expected </#{tag_open_name}> for <#{tag_open_name}> \
    at line #{tag_open_meta.line}, got: </#{tag_close_name}>#{hint}\
    """

    raise_syntax_error!(message, tag_close_meta, state)
  end

  defp pop_tag!(state, {:close, _type, tag_name, tag_meta}) do
    hint = closing_void_hint(tag_name, state)
    message = "missing opening tag for </#{tag_name}>#{hint}"
    raise_syntax_error!(message, tag_meta, state)
  end

  defp closing_void_hint(tag_name, state) do
    if state.tag_handler.void?(tag_name) do
      " (note <#{tag_name}> is a void tag and cannot have any content)"
    else
      ""
    end
  end

  ## handle_token

  # Expr

  defp handle_token([{:expr, meta, [quoted]} | tokens], state) do
    state
    |> set_root_on_not_tag()
    |> update_subengine(:handle_expr, [Keyword.fetch!(meta, :marker), quoted])
    |> continue(tokens)
  end

  defp handle_token([{:body_expr, _meta, [quoted]} | tokens], state) do
    state
    |> set_root_on_not_tag()
    |> update_subengine(:handle_expr, ["=", quoted])
    |> continue(tokens)
  end

  # Text

  defp handle_token([{:<<>>, meta, [text]} | tokens], state) do
    if text == "" do
      continue(state, tokens)
    else
      state
      |> set_root_on_not_tag()
      |> update_subengine(:handle_text, [
        [line: Keyword.fetch!(meta, :line_end), column: Keyword.fetch!(meta, :column_end)],
        text
      ])
      |> continue(tokens)
    end
  end

  defp handle_token([text | tokens], state) when is_binary(text) do
    if text == "" do
      continue(state, tokens)
    else
      state
      |> set_root_on_not_tag()
      |> update_subengine(:handle_text, [[], text])
      |> continue(tokens)
    end
  end

  defp handle_token(
         [
           {type, meta, [name, attrs, opts]}
           | tokens
         ],
         state
       )
       when type in [:tag, :local_component, :remote_component, :slot] do
    closing = Keyword.get(opts, :closing)
    tag_meta = Map.new(Keyword.get(meta, :open_meta, []))

    case find_attr(attrs, ":type") do
      {{:attribute, _meta, [":type", _, code]}, attrs} ->
        state
        |> handle_macro_component({type, meta, [name, attrs, opts]}, tag_meta, code)
        |> continue(tokens)

      nil ->
        case type do
          :remote_component ->
            state
            |> handle_remote_component(name, attrs, opts, closing, tag_meta)
            |> continue(tokens)

          :local_component ->
            state
            |> handle_local_component(name, attrs, opts, closing, tag_meta)
            |> continue(tokens)

          :slot ->
            slot_name = String.to_atom(name)

            state
            |> handle_slot(slot_name, attrs, opts, closing, tag_meta)
            |> continue(prune_text_after_slot(tokens))

          :tag ->
            state
            |> handle_tag(name, attrs, opts, closing, tag_meta)
            |> continue(tokens)
        end
    end
  end

  defp handle_token([{:__block__, _, children} | tokens], state) do
    state
    |> continue(children)
    |> continue(tokens)
  end

  defp handle_token([], state), do: state

  # Remote Component (self-close)
  defp handle_remote_component(state, name, attrs, _opts, closing, tag_meta)
       when closing in [:self, :void] do
    attrs = postprocess_attrs(attrs, state)
    {mod_ast, mod_size, fun} = decompose_remote_component_tag!(name, tag_meta, state)
    %{line: line, column: column} = tag_meta

    {assigns, attr_info} =
      build_self_close_component_assigns({"remote component", name}, attrs, tag_meta.line, state)

    mod = expand_with_line(mod_ast, line, state.caller)
    store_component_call({mod, fun}, attr_info, [], line, state)
    meta = [line: line, column: column + mod_size]
    call = {{:., meta, [mod_ast, fun]}, meta, []}

    ast =
      quote line: tag_meta.line do
        Phoenix.LiveView.TagEngine.component(
          &(unquote(call) / 1),
          unquote(assigns),
          {__MODULE__, __ENV__.function, __ENV__.file, unquote(tag_meta.line)}
        )
      end

    case pop_special_attrs!(attrs, tag_meta, state) do
      {false, _tag_meta, _attrs} ->
        state
        |> set_root_on_not_tag()
        |> maybe_anno_caller(meta, state.file, line)
        |> update_subengine(:handle_expr, ["=", ast])

      {true, new_meta, _new_attrs} ->
        state
        |> push_substate_to_stack()
        |> update_subengine(:handle_begin, [])
        |> set_root_on_not_tag()
        |> maybe_anno_caller(meta, state.file, line)
        |> update_subengine(:handle_expr, ["=", ast])
        |> handle_special_expr(new_meta)
    end
  end

  # Remote Component (with inner content)
  defp handle_remote_component(state, name, attrs, opts, nil, tag_meta) do
    mod_fun = decompose_remote_component_tag!(name, tag_meta, state)
    content = List.wrap(Keyword.fetch!(opts, :do))

    tag_meta =
      tag_meta
      |> Map.put(:mod_fun, mod_fun)
      |> Map.put(:has_tags?, has_tags?(content))

    case pop_special_attrs!(attrs, tag_meta, state) do
      {false, tag_meta, attrs} ->
        state
        |> set_root_on_not_tag()
        |> push_tag({:remote_component, name, attrs, tag_meta})
        |> init_slots()
        |> push_substate_to_stack()
        |> update_subengine(:handle_begin, [])
        |> continue(content)
        |> handle_remote_component_close(
          name,
          attrs,
          tag_meta,
          Map.get(tag_meta, :close_meta, [])
        )

      {true, new_meta, new_attrs} ->
        state
        |> set_root_on_not_tag()
        |> push_tag({:remote_component, name, attrs, tag_meta})
        |> init_slots()
        |> push_substate_to_stack()
        |> update_subengine(:handle_begin, [])
        |> push_substate_to_stack()
        |> update_subengine(:handle_begin, [])
        |> continue(content)
        |> handle_remote_component_close(
          name,
          new_attrs,
          new_meta,
          Map.get(new_meta, :close_meta, [])
        )
    end
  end

  defp handle_remote_component_close(state, name, attrs, tag_meta, tag_close_meta) do
    tag_close_meta = Map.new(tag_close_meta)

    # we validate the tags again, because a macro component might introduce invalid tokens
    token = {:close, :remote_component, name, tag_close_meta}
    {{:remote_component, name, _attrs, _tag_meta}, state} = pop_tag!(state, token)
    %{mod_fun: {mod_ast, mod_size, fun}, line: line, column: column} = tag_meta

    mod = expand_with_line(mod_ast, line, state.caller)
    attrs = postprocess_attrs(attrs, state)
    ref = {"remote component", name}

    {assigns, attr_info, slot_info, state} =
      build_component_assigns(ref, attrs, line, tag_meta, tag_close_meta, state)

    store_component_call({mod, fun}, attr_info, slot_info, line, state)
    meta = [line: line, column: column + mod_size]
    call = {{:., meta, [mod_ast, fun]}, meta, []}

    ast =
      quote line: line do
        Phoenix.LiveView.TagEngine.component(
          &(unquote(call) / 1),
          unquote(assigns),
          {__MODULE__, __ENV__.function, __ENV__.file, unquote(line)}
        )
      end
      |> tag_slots(slot_info)

    state
    |> pop_substate_from_stack()
    |> maybe_anno_caller(meta, state.file, line)
    |> update_subengine(:handle_expr, ["=", ast])
    |> handle_special_expr(tag_meta)
  end

  # Slot (self-close)
  defp handle_slot(state, slot_name, attrs, _opts, closing, tag_meta)
       when closing in [:self, :void] do
    validate_slot!(state, slot_name, tag_meta)
    attrs = postprocess_attrs(attrs, state)
    %{line: line} = tag_meta
    {special, roots, attrs, attr_info} = split_component_attrs({"slot", slot_name}, attrs, state)
    let = special[":let"]

    with {_, let_meta} <- let do
      message = "cannot use :let on a slot without inner content"
      raise_syntax_error!(message, let_meta, state)
    end

    attrs = [__slot__: slot_name, inner_block: nil] ++ attrs
    assigns = wrap_special_slot(special, merge_component_attrs(roots, attrs, line))

    add_slot(state, slot_name, assigns, attr_info, tag_meta, special)
  end

  # Slot (with inner content)
  defp handle_slot(state, slot_name, attrs, opts, nil, tag_meta) do
    validate_slot!(state, slot_name, tag_meta)
    content = List.wrap(Keyword.fetch!(opts, :do))
    tag_meta = Map.put(tag_meta, :has_tags?, has_tags?(content))

    state
    |> push_tag({:slot, slot_name, attrs, tag_meta})
    |> push_substate_to_stack()
    |> update_subengine(:handle_begin, [])
    |> continue(content)
    |> handle_slot_close(slot_name, attrs, tag_meta, Map.get(tag_meta, :close_meta, []))
  end

  defp handle_slot_close(state, slot_name, attrs, tag_meta, tag_close_meta) do
    tag_close_meta = Map.new(tag_close_meta)

    # we validate the tags again, because a macro component might introduce invalid tokens
    token = {:close, :slot, slot_name, tag_close_meta}
    {{:slot, _name, _attrs, _tag_meta}, state} = pop_tag!(state, token)
    %{line: line} = tag_meta

    attrs = postprocess_attrs(attrs, state)
    {special, roots, attrs, attr_info} = split_component_attrs({"slot", slot_name}, attrs, state)
    clauses = build_component_clauses(special[":let"], slot_name, tag_meta, tag_close_meta, state)

    ast =
      quote line: line do
        Phoenix.LiveView.TagEngine.inner_block(unquote(slot_name), do: unquote(clauses))
      end

    attrs = [__slot__: slot_name, inner_block: ast] ++ attrs
    assigns = wrap_special_slot(special, merge_component_attrs(roots, attrs, line))
    inner = add_inner_block(attr_info, ast, tag_meta)

    state
    |> add_slot(slot_name, assigns, inner, tag_meta, special)
    |> pop_substate_from_stack()
  end

  # Local function component (self close)
  defp handle_local_component(state, name, attrs, _opts, closing, tag_meta)
       when closing in [:self, :void] do
    fun = String.to_atom(name)
    %{line: line, column: column} = tag_meta
    attrs = postprocess_attrs(attrs, state)

    {assigns, attr_info} =
      build_self_close_component_assigns({"local component", fun}, attrs, line, state)

    mod = actual_component_module(state.caller, fun)
    store_component_call({mod, fun}, attr_info, [], line, state)
    meta = [line: line, column: column]
    call = {fun, meta, __MODULE__}

    ast =
      quote line: line do
        Phoenix.LiveView.TagEngine.component(
          &(unquote(call) / 1),
          unquote(assigns),
          {__MODULE__, __ENV__.function, __ENV__.file, unquote(line)}
        )
      end

    case pop_special_attrs!(attrs, tag_meta, state) do
      {false, _tag_meta, _attrs} ->
        state
        |> set_root_on_not_tag()
        |> maybe_anno_caller(meta, state.file, line)
        |> update_subengine(:handle_expr, ["=", ast])

      {true, new_meta, _new_attrs} ->
        state
        |> push_substate_to_stack()
        |> update_subengine(:handle_begin, [])
        |> set_root_on_not_tag()
        |> maybe_anno_caller(meta, state.file, line)
        |> update_subengine(:handle_expr, ["=", ast])
        |> handle_special_expr(new_meta)
    end
  end

  # Local function component (with inner content)
  defp handle_local_component(state, name, attrs, opts, nil, tag_meta) do
    content = List.wrap(Keyword.fetch!(opts, :do))
    tag_meta = Map.put(tag_meta, :has_tags?, has_tags?(content))

    case pop_special_attrs!(attrs, tag_meta, state) do
      {false, tag_meta, attrs} ->
        state
        |> set_root_on_not_tag()
        |> push_tag({:local_component, name, attrs, tag_meta})
        |> init_slots()
        |> push_substate_to_stack()
        |> update_subengine(:handle_begin, [])
        |> continue(content)
        |> handle_local_component_close(name, attrs, tag_meta, Map.get(tag_meta, :close_meta, []))

      {true, new_meta, new_attrs} ->
        state
        |> set_root_on_not_tag()
        |> push_tag({:local_component, name, new_attrs, new_meta})
        |> init_slots()
        |> push_substate_to_stack()
        |> update_subengine(:handle_begin, [])
        |> push_substate_to_stack()
        |> update_subengine(:handle_begin, [])
        |> continue(content)
        |> handle_local_component_close(
          name,
          new_attrs,
          new_meta,
          Map.get(new_meta, :close_meta, [])
        )
    end
  end

  defp handle_local_component_close(state, name, attrs, tag_meta, tag_close_meta) do
    tag_close_meta = Map.new(tag_close_meta)

    # we validate the tags again, because a macro component might introduce invalid tokens
    token = {:close, :local_component, name, tag_close_meta}
    {{:local_component, name, _attrs, _tag_meta}, state} = pop_tag!(state, token)
    fun = String.to_atom(name)
    %{line: line, column: column} = tag_meta
    attrs = postprocess_attrs(attrs, state)
    mod = actual_component_module(state.caller, fun)
    ref = {"local component", fun}

    {assigns, attr_info, slot_info, state} =
      build_component_assigns(ref, attrs, line, tag_meta, tag_close_meta, state)

    store_component_call({mod, fun}, attr_info, slot_info, line, state)
    meta = [line: line, column: column]
    call = {fun, meta, __MODULE__}

    ast =
      quote line: line do
        Phoenix.LiveView.TagEngine.component(
          &(unquote(call) / 1),
          unquote(assigns),
          {__MODULE__, __ENV__.function, __ENV__.file, unquote(line)}
        )
      end
      |> tag_slots(slot_info)

    state
    |> pop_substate_from_stack()
    |> maybe_anno_caller(meta, state.file, line)
    |> update_subengine(:handle_expr, ["=", ast])
    |> handle_special_expr(tag_meta)
  end

  # HTML element (self close)
  defp handle_tag(state, name, attrs, _opts, closing, tag_meta) when closing in [:self, :void] do
    suffix = if closing == :void, do: ">", else: "></#{name}>"
    attrs = postprocess_attrs(attrs, state)
    validate_phx_attrs!(attrs, tag_meta, state)
    validate_tag_attrs!(name, attrs, state)

    case pop_special_attrs!(attrs, tag_meta, state) do
      {false, tag_meta, attrs} ->
        state
        |> set_root_on_tag()
        |> handle_tag_and_attrs(name, attrs, suffix, to_location(tag_meta))

      {true, new_meta, new_attrs} ->
        state
        |> push_substate_to_stack()
        |> update_subengine(:handle_begin, [])
        |> set_root_on_not_tag()
        |> handle_tag_and_attrs(name, new_attrs, suffix, to_location(new_meta))
        |> handle_special_expr(new_meta)
    end
  end

  # HTML element
  defp handle_tag(state, name, attrs, opts, nil, tag_meta) do
    attrs = postprocess_attrs(attrs, state)
    validate_phx_attrs!(attrs, tag_meta, state)
    validate_tag_attrs!(name, attrs, state)
    content = List.wrap(Keyword.fetch!(opts, :do))

    case pop_special_attrs!(attrs, tag_meta, state) do
      {false, tag_meta, attrs} ->
        state
        |> set_root_on_tag()
        |> push_tag({:tag, name, attrs, tag_meta})
        |> handle_tag_and_attrs(name, attrs, ">", to_location(tag_meta))
        |> continue(content)
        |> handle_tag_close(name, attrs, tag_meta, Map.get(tag_meta, :close_meta, []))

      {true, new_meta, new_attrs} ->
        state
        |> push_substate_to_stack()
        |> update_subengine(:handle_begin, [])
        |> set_root_on_not_tag()
        |> push_tag({:tag, name, new_attrs, new_meta})
        |> handle_tag_and_attrs(name, new_attrs, ">", to_location(new_meta))
        |> continue(content)
        |> handle_tag_close(name, new_attrs, new_meta, Map.get(new_meta, :close_meta, []))
    end
  end

  defp handle_tag_close(state, name, _attrs, tag_meta, tag_close_meta) do
    tag_close_meta = Map.new(tag_close_meta)

    # we validate the tags again, because a macro component might introduce invalid tokens
    token = {:close, :tag, name, tag_close_meta}
    {{:tag, _name, _attrs, _tag_meta}, state} = pop_tag!(state, token)

    state
    |> update_subengine(:handle_text, [to_location(tag_close_meta), "</#{name}>"])
    |> handle_special_expr(tag_meta)
  end

  defp handle_macro_component(
         state,
         ast,
         tag_meta,
         module_ast
       ) do
    # Macro components work by converting the HEEx tokens into an AST
    # (see Phoenix.Component.MacroComponent) and then calling the transform
    # function on the macro component module, which can return a transformed
    # AST.
    #
    # The AST is limited in functionality and we handle it separately in
    # the handle_ast function.

    Macro.Env.required?(state.caller, Phoenix.Component) ||
      raise ArgumentError,
            "macro components are only supported in modules that `use Phoenix.Component`"

    module = validate_module!(module_ast, tag_meta, state)

    case module.transform(ast, %{env: state.caller}) do
      {:ok, new_ast} ->
        continue(state, List.wrap(new_ast))

      {:ok, new_ast, data} ->
        Module.put_attribute(state.caller.module, :__macro_components__, {module, data})
        continue(state, List.wrap(new_ast))

      other ->
        raise ArgumentError,
              "a macro component must return {:ok, ast} or {:ok, ast, data}, got: #{inspect(other)}"
    end
  end

  defp validate_module!(module_ast, tag_meta, state) do
    module = Macro.expand(module_ast, state.caller)

    if not is_atom(module) do
      raise_syntax_error!(
        "the given macro component #{Macro.to_string(module_ast)} is not a valid module",
        tag_meta,
        state
      )
    end

    _ = Code.ensure_compiled!(module)

    if not function_exported?(module, :transform, 2) do
      raise_syntax_error!(
        "the given macro component #{inspect(module)} does not implement the `Phoenix.LiveView.MacroComponent` behaviour",
        tag_meta,
        state
      )
    end

    module
  end

  # Pop the given attr from attrs. Raises if the given attr is duplicated within
  # attrs.
  #
  # Examples:
  #
  #   attrs = [{":for", {...}}, {"class", {...}}]
  #   pop_special_attrs!(state, ":for", attrs, %{}, state)
  #   => {%{for: parsed_ast}}, {{":for", {...}}, [{"class", {...}]}}
  #
  #   attrs = [{"class", {...}}]
  #   pop_special_attrs!(state, ":for", attrs, %{}, state)
  #   => {%{}, []}
  defp pop_special_attrs!(attrs, tag_meta, state) do
    Enum.reduce([for: ":for", if: ":if"], {false, tag_meta, attrs}, fn
      {attr, string_attr}, {special_acc, meta_acc, attrs_acc} ->
        attrs_acc
        |> find_attr(string_attr)
        |> raise_if_duplicated_special_attr!(state)
        |> case do
          {{:attribute, meta, [^string_attr, _meta, expr]}, attrs} when not is_binary(expr) ->
            validate_quoted_special_attr!(string_attr, expr, Map.new(meta), state)
            {true, Map.put(meta_acc, attr, expr), attrs}

          {{:attribute, meta, [^string_attr, _meta, _string]}, _attrs} ->
            message = "#{string_attr} must be an expression between {...}"
            raise_syntax_error!(message, Map.new(meta), state)

          nil ->
            {special_acc, meta_acc, attrs_acc}
        end
    end)
  end

  defp raise_if_duplicated_special_attr!({{:attribute, _, [attr, _, _]}, attrs} = result, state) do
    case find_attr(attrs, attr) do
      {{:attribute, meta, _}, _attrs} ->
        message =
          "cannot define multiple #{inspect(attr)} attributes. Another #{inspect(attr)} has already been defined at line #{Keyword.get(meta, :line)}"

        raise_syntax_error!(message, meta, state)

      nil ->
        result
    end
  end

  defp raise_if_duplicated_special_attr!(nil, _state), do: nil

  # mimics List.keytake for our attributes
  defp find_attr(attrs, key) do
    {found, remaining} =
      for {:attribute, _meta, args} = attr <- attrs, reduce: {nil, []} do
        {nil, acc} ->
          case args do
            [^key, _, _] -> {attr, acc}
            _ -> {nil, [attr | acc]}
          end

        {found, acc} ->
          {found, [attr | acc]}
      end

    case found do
      nil -> nil
      found -> {found, Enum.reverse(remaining)}
    end
  end

  # Root tracking
  defp set_root_on_not_tag(%{root: root, tags: tags} = state) do
    if tags == [] and root != false do
      %{state | root: false}
    else
      state
    end
  end

  defp set_root_on_tag(state) do
    case state do
      %{root: nil, tags: []} -> %{state | root: true}
      %{root: true, tags: []} -> %{state | root: false}
      %{root: bool} when is_boolean(bool) -> state
    end
  end

  ## handle_tag_and_attrs

  defp handle_tag_and_attrs(state, name, attrs, suffix, meta) do
    text =
      if Application.get_env(:phoenix_live_view, :debug_tags_location, false) do
        "<#{name} data-phx-loc=\"#{meta[:line]}\""
      else
        "<#{name}"
      end

    state
    |> update_subengine(:handle_text, [meta, text])
    |> handle_tag_attrs(meta, attrs)
    |> update_subengine(:handle_text, [meta, suffix])
  end

  defp handle_tag_attrs(state, meta, attrs) do
    Enum.reduce(attrs, state, fn
      {:attribute, _attr_meta, [:root, _meta, ast]}, state ->
        # If we have a map of literal keys, we unpack it as a list
        # to simplify the downstream check.
        ast =
          with {:%{}, _meta, pairs} <- ast,
               true <- literal_keys?(pairs) do
            pairs
          else
            _ -> ast
          end

        handle_tag_expr_attrs(state, meta, ast)

      {:attribute, _attr_meta, [name, nil]}, state ->
        update_subengine(state, :handle_text, [meta, " #{name}"])

      {:attribute, attr_meta, [name, text_meta, value]}, state ->
        if is_binary(value) and not Keyword.get(attr_meta, :is_expr, false) do
          text =
            case Keyword.get(text_meta, :delimiter) do
              nil ->
                encode_binary_attribute(name, value)

              ?" ->
                ~s( #{name}="#{value}")

              ?' ->
                ~s( #{name}='#{value}')
            end

          update_subengine(state, :handle_text, [[], text])
        else
          handle_tag_expr_attrs(state, meta, [{name, value}])
        end
    end)
  end

  defp encode_binary_attribute(key, value) when is_binary(key) and is_binary(value) do
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

  defp handle_tag_expr_attrs(state, meta, ast) do
    # It is safe to List.wrap/1 because if we receive nil,
    # it would become the interpolation of nil, which is an
    # empty string anyway.
    case state.tag_handler.handle_attributes(ast, meta) do
      {:attributes, attrs} ->
        Enum.reduce(attrs, state, fn
          {name, value}, state ->
            state = update_subengine(state, :handle_text, [meta, ~s( #{name}=")])

            state =
              value
              |> List.wrap()
              |> Enum.reduce(state, fn
                binary, state when is_binary(binary) ->
                  update_subengine(state, :handle_text, [meta, binary])

                expr, state ->
                  update_subengine(state, :handle_expr, ["=", expr])
              end)

            update_subengine(state, :handle_text, [meta, ~s(")])

          quoted, state ->
            update_subengine(state, :handle_expr, ["=", quoted])
        end)

      {:quoted, quoted} ->
        update_subengine(state, :handle_expr, ["=", quoted])
    end
  end

  defp literal_keys?([{key, _value} | rest]) when is_atom(key) or is_binary(key),
    do: literal_keys?(rest)

  defp literal_keys?([]), do: true
  defp literal_keys?(_other), do: false

  defp handle_special_expr(state, tag_meta) do
    ast =
      case tag_meta do
        %{for: for_expr, if: if_expr} ->
          quote do
            for unquote(for_expr), unquote(if_expr),
              do: unquote(invoke_subengine(state, :handle_end, []))
          end

        %{for: for_expr} ->
          quote do
            for unquote(for_expr), do: unquote(invoke_subengine(state, :handle_end, []))
          end

        %{if: if_expr} ->
          quote do
            if unquote(if_expr), do: unquote(invoke_subengine(state, :handle_end, []))
          end

        %{} ->
          nil
      end

    if ast do
      state
      |> pop_substate_from_stack()
      |> update_subengine(:handle_expr, ["=", ast])
    else
      state
    end
  end

  ## build_self_close_component_assigns/build_component_assigns

  defp build_self_close_component_assigns(type_component, attrs, line, state) do
    {special, roots, attrs, attr_info} = split_component_attrs(type_component, attrs, state)
    raise_if_let!(special[":let"], state.file)
    {merge_component_attrs(roots, attrs, line), attr_info}
  end

  defp build_component_assigns(type_component, attrs, line, tag_meta, tag_close_meta, state) do
    {special, roots, attrs, attr_info} = split_component_attrs(type_component, attrs, state)

    clauses =
      build_component_clauses(special[":let"], :inner_block, tag_meta, tag_close_meta, state)

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

    {slot_assigns, slot_info, state} = pop_slots(state)

    slot_info = [
      {:inner_block, [{tag_meta, add_inner_block({false, [], []}, inner_block, tag_meta)}]}
      | slot_info
    ]

    attrs = attrs ++ [{:inner_block, [inner_block_assigns]} | slot_assigns]
    {merge_component_attrs(roots, attrs, line), attr_info, slot_info, state}
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
         {:attribute, _attr_meta, [:root, meta, quoted_value]},
         {special, r, a, locs},
         _state,
         _type_component
       ) do
    quoted_value = quote line: line(meta), do: Map.new(unquote(quoted_value))
    {special, [quoted_value | r], a, locs}
  end

  @special_attrs ~w(:let :if :for)
  defp split_component_attr(
         {:attribute, attr_meta, [attr, meta, quoted_value]},
         {special, r, a, locs},
         state,
         _type_component
       )
       when attr in @special_attrs and not is_binary(quoted_value) do
    case special do
      %{^attr => {_, attr_meta}} ->
        message = """
        cannot define multiple #{attr} attributes. \
        Another #{attr} has already been defined at line #{line(meta)}\
        """

        raise_syntax_error!(message, Map.new(attr_meta), state)

      %{} ->
        validate_quoted_special_attr!(attr, quoted_value, attr_meta, state)
        {Map.put(special, attr, {quoted_value, Map.new(attr_meta)}), r, a, locs}
    end
  end

  defp split_component_attr(
         {:attribute, meta, [attr, _, _]},
         _state,
         state,
         {type, component_or_slot}
       )
       when attr in @special_attrs do
    message = "#{attr} must be a pattern between {...} in #{type}: #{component_or_slot}"
    raise_syntax_error!(message, meta, state)
  end

  defp split_component_attr(
         {:attribute, meta, [":" <> _ = name, _, _]},
         _state,
         state,
         {type, component_or_slot}
       ) do
    message = "unsupported attribute #{inspect(name)} in #{type}: #{component_or_slot}"
    raise_syntax_error!(message, meta, state)
  end

  defp split_component_attr(
         {:attribute, attr_meta, [name, _meta, quoted_value]},
         {special, r, a, locs},
         _state,
         _type_component
       ) do
    {special, r, [{String.to_atom(name), quoted_value} | a], [line_column(attr_meta) | locs]}
  end

  defp split_component_attr(
         {:attribute, attr_meta, [name, nil]},
         {special, r, a, locs},
         _state,
         _type_component
       ) do
    {special, r, [{String.to_atom(name), true} | a], [line_column(attr_meta) | locs]}
  end

  defp line(list) when is_list(list), do: Keyword.get(list, :line)
  defp line(map) when is_map(map), do: map.line

  defp line_column(list) when is_list(list), do: list |> Map.new() |> line_column()
  defp line_column(%{line: line, column: column}), do: {line, column}
  defp line_column(other), do: IO.inspect({0, 0}, label: "falling back from #{inspect(other)}")

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

  @doc false
  def __unmatched_let__!(pattern, value) do
    message = """
    cannot match arguments sent from render_slot/2 against the pattern in :let.

    Expected a value matching `#{pattern}`, got: #{inspect(value)}\
    """

    stacktrace =
      self()
      |> Process.info(:current_stacktrace)
      |> elem(1)
      |> Enum.drop(2)

    reraise(message, stacktrace)
  end

  defp raise_if_let!(let, file) do
    with {_pattern, %{line: line}} <- let do
      message = "cannot use :let on a component without inner content"
      raise CompileError, line: line, file: file, description: message
    end
  end

  defp build_component_clauses(let, name, tag_meta, tag_close_meta, %{caller: caller} = state) do
    opts =
      if annotation =
           caller && Map.get(tag_meta, :has_tags?, false) &&
             state.tag_handler.annotate_slot(name, tag_meta, tag_close_meta, caller) do
        [meta: [template_annotation: annotation]]
      else
        []
      end

    ast = invoke_subengine(state, :handle_end, [opts])

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
          quote line: line, generated: true do
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

  ## Helpers

  defp to_location(%{line: line, column: column}), do: [line: line, column: column]
  defp to_location(%{}), do: [line: 0, column: 0]

  defp actual_component_module(env, fun) do
    case Macro.Env.lookup_import(env, {fun, 1}) do
      [{_, module} | _] -> module
      _ -> env.module
    end
  end

  # removes phx-no-format, etc. and maps phx-hook=".name" to the fully qualified name
  defp postprocess_attrs(attrs, state) do
    attrs_to_remove = ~w(phx-no-format phx-no-curly-interpolation)

    for {:attribute, meta, [key | _] = args} <- attrs,
        key not in attrs_to_remove do
      case args do
        ["phx-hook", str_meta, "." <> name] ->
          {:attribute, meta, ["phx-hook", str_meta, "#{inspect(state.caller.module)}.#{name}"]}

        _ ->
          {:attribute, meta, args}
      end
    end
  end

  defp validate_tag_attrs!("input", attrs, state) do
    # warn if using name="id" on an input
    case Enum.find(attrs, &match?({:attribute, _, ["name", _, "id"]}, &1)) do
      {:attribute, attr_meta, _value} ->
        meta = [
          line: Keyword.get(attr_meta, :line),
          column: Keyword.get(attr_meta, :column),
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

  defp validate_tag_attrs!(_name, _attrs, _state), do: :ok

  # Check if `phx-update` or `phx-hook` is present in attrs and raises in case
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
  defp validate_phx_attrs!([{:attribute, _, [:root, _, _]} | t], meta, state, attr, _id?),
    do: validate_phx_attrs!(t, meta, state, attr, true)

  defp validate_phx_attrs!([{:attribute, _, ["id", _, _]} | t], meta, state, attr, _id?),
    do: validate_phx_attrs!(t, meta, state, attr, true)

  defp validate_phx_attrs!(
         [{:attribute, attr_meta, ["phx-update", _, value]} | t],
         meta,
         state,
         _attr,
         id?
       )
       when is_binary(value) do
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

  defp validate_phx_attrs!([{:attribute, _, ["phx-update", _, _]} | t], meta, state, _attr, id?) do
    validate_phx_attrs!(t, meta, state, "phx-update", id?)
  end

  defp validate_phx_attrs!([{:attribute, _, ["phx-hook", _, _]} | t], meta, state, _attr, id?),
    do: validate_phx_attrs!(t, meta, state, "phx-hook", id?)

  defp validate_phx_attrs!(
         [{:attribute, attr_meta, [special, _meta, value]} | t],
         meta,
         state,
         attr,
         id?
       )
       when special in ~w(:if :for :type) do
    is_expr = Keyword.get(attr_meta, :is_expr, false)

    case value do
      binary when is_binary(binary) and not is_expr ->
        message = "#{special} must be an expression between {...}"
        raise_syntax_error!(message, attr_meta, state)

      _ ->
        validate_phx_attrs!(t, meta, state, attr, id?)
    end
  end

  defp validate_phx_attrs!(
         [{:attribute, attr_meta, [":" <> name, _, _]} | _],
         _meta,
         state,
         _attr,
         _id?
       )
       when name not in ~w(if for) do
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

  defp tag_slots({call, meta, args}, slot_info) do
    {call, [slots: Keyword.keys(slot_info)] ++ meta, args}
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

  defp expand_with_line(ast, line, env) do
    Macro.expand(ast, %{env | line: line})
  end

  defp raise_syntax_error!(message, meta, state) do
    meta = Map.new(meta)

    raise ParseError,
      line: meta.line,
      column: meta.column,
      file: state.file,
      description: message <> ParseError.code_snippet(state.source, meta, state.indentation)
  end

  defp maybe_anno_caller(state, meta, file, line) do
    if anno = state.tag_handler.annotate_caller(file, line) do
      update_subengine(state, :handle_text, [meta, anno])
    else
      state
    end
  end
end
