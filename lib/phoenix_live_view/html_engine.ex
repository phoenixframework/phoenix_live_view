defmodule Phoenix.LiveView.HTMLEngine do
  @moduledoc """
  The HTMLEngine that powers `.heex` templates and the `~H` sigil.

  It works by adding a HTML parsing and validation layer on top
  of EEx engine. By default it uses `Phoenix.LiveView.Engine` as
  its "subengine".
  """

  # TODO: Use @impl true instead of @doc false when we require Elixir v1.12
  alias Phoenix.LiveView.HTMLTokenizer
  alias Phoenix.LiveView.HTMLTokenizer.ParseError

  @behaviour Phoenix.Template.Engine

  @doc false
  def compile(path, _name) do
    trim = Application.get_env(:phoenix, :trim_on_html_eex_engine, true)
    EEx.compile_file(path, engine: __MODULE__, line: 1, trim: trim)
  end

  @behaviour EEx.Engine

  @doc false
  def init(opts) do
    {subengine, opts} = Keyword.pop(opts, :subengine, Phoenix.LiveView.Engine)
    {module, opts} = Keyword.pop(opts, :module)

    unless subengine do
      raise ArgumentError, ":subengine is missing for HTMLEngine"
    end

    %{
      cont: :text,
      tokens: [],
      subengine: subengine,
      substate: subengine.init([]),
      module: module,
      file: Keyword.get(opts, :file, "nofile"),
      indentation: Keyword.get(opts, :indentation, 0)
    }
  end

  ## These callbacks return AST

  @doc false
  def handle_body(%{tokens: tokens, file: file, cont: cont} = state) do
    tokens = HTMLTokenizer.finalize(tokens, file, cont)

    token_state =
      state
      |> token_state(nil)
      |> handle_tokens(tokens)
      |> validate_unclosed_tags!("template")

    opts = [root: token_state.root || false]
    ast = invoke_subengine(token_state, :handle_body, [opts])

    # Do not require if calling module is helpers. Fix for elixir < 1.12
    # TODO remove after Elixir >= 1.12 support
    if state.module === Phoenix.LiveView.Helpers do
      ast
    else
      quote do
        require Phoenix.LiveView.Helpers
        unquote(ast)
      end
    end
  end

  defp validate_unclosed_tags!(%{tags: []} = state, _context) do
    state
  end

  defp validate_unclosed_tags!(%{tags: [tag | _]} = state, context) do
    {:tag_open, name, _attrs, %{line: line, column: column}} = tag
    file = state.file
    message = "end of #{context} reached without closing tag for <#{name}>"
    raise ParseError, line: line, column: column, file: file, description: message
  end

  @doc false
  def handle_end(state) do
    state
    |> token_state(false)
    |> handle_tokens(Enum.reverse(state.tokens))
    |> validate_unclosed_tags!("do-block")
    |> invoke_subengine(:handle_end, [])
  end

  defp token_state(%{subengine: subengine, substate: substate, file: file}, root) do
    %{
      subengine: subengine,
      substate: substate,
      file: file,
      stack: [],
      tags: [],
      slots: [],
      root: root
    }
  end

  defp handle_tokens(token_state, tokens) do
    Enum.reduce(tokens, token_state, &handle_token/2)
  end

  ## These callbacks update the state

  @doc false
  def handle_begin(state) do
    update_subengine(%{state | tokens: []}, :handle_begin, [])
  end

  @doc false
  def handle_text(state, text) do
    handle_text(state, [], text)
  end

  @doc false
  def handle_text(state, meta, text) do
    %{file: file, indentation: indentation, tokens: tokens, cont: cont} = state
    {tokens, cont} = HTMLTokenizer.tokenize(text, file, indentation, meta, tokens, cont)
    %{state | tokens: tokens, cont: cont}
  end

  @doc false
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

  defp invoke_subengine(%{subengine: subengine, substate: substate}, :handle_text, args) do
    # TODO: Remove this once we require Elixir v1.12
    if function_exported?(subengine, :handle_text, 3) do
      apply(subengine, :handle_text, [substate | args])
    else
      apply(subengine, :handle_text, [substate | tl(args)])
    end
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

  defp add_slot!(
         %{slots: [slots | other_slots], tags: [{:tag_open, <<first, _::binary>>, _, _} | _]} =
           state,
         slot,
         _meta
       )
       when first in ?A..?Z or first == ?. do
    %{state | slots: [[slot | slots] | other_slots]}
  end

  defp add_slot!(state, slot, meta) do
    %{line: line, column: column} = meta
    {slot_name, _} = slot
    file = state.file

    message =
      "invalid slot entry <:#{slot_name}>. A slot entry must be a direct child of a component"

    raise ParseError, line: line, column: column, file: file, description: message
  end

  defp pop_slots(%{slots: [slots | other_slots]} = state) do
    grouped =
      slots
      |> Enum.reverse()
      |> Enum.group_by(&elem(&1, 0), fn {_name, slot_ast} -> slot_ast end)
      |> Map.to_list()

    {grouped, %{state | slots: other_slots}}
  end

  defp push_tag(state, token) do
    # If we have a void tag, we don't actually push it into the stack.
    with {:tag_open, name, _attrs, _meta} <- token,
         true <- void?(name) do
      state
    else
      _ -> %{state | tags: [token | state.tags]}
    end
  end

  defp pop_tag!(
         %{tags: [{:tag_open, tag_name, _attrs, _meta} = tag | tags]} = state,
         {:tag_close, tag_name, _}
       ) do
    {tag, %{state | tags: tags}}
  end

  defp pop_tag!(
         %{tags: [{:tag_open, tag_open_name, _attrs, tag_open_meta} | _]} = state,
         {:tag_close, tag_close_name, tag_close_meta}
       ) do
    %{line: line, column: column} = tag_close_meta
    file = state.file

    message = """
    unmatched closing tag. Expected </#{tag_open_name}> for <#{tag_open_name}> \
    at line #{tag_open_meta.line}, got: </#{tag_close_name}>\
    """

    raise ParseError, line: line, column: column, file: file, description: message
  end

  defp pop_tag!(state, {:tag_close, tag_name, tag_meta}) do
    %{line: line, column: column} = tag_meta
    file = state.file
    message = "missing opening tag for </#{tag_name}>"
    raise ParseError, line: line, column: column, file: file, description: message
  end

  ## handle_token

  # Expr

  defp handle_token({:expr, marker, expr}, state) do
    state
    |> set_root_on_not_tag()
    |> update_subengine(:handle_expr, [marker, expr])
  end

  # Text

  defp handle_token({:text, text, %{line_end: line, column_end: column}}, state) do
    state
    |> set_root_on_not_tag()
    |> update_subengine(:handle_text, [[line: line, column: column], text])
  end

  # Remote function component (self close)

  defp handle_token(
         {:tag_open, <<first, _::binary>> = tag_name, attrs, %{self_close: true} = tag_meta},
         state
       )
       when first in ?A..?Z do
    attrs = remove_phx_no_break(attrs)
    file = state.file
    {mod, fun} = decompose_remote_component_tag!(tag_name, tag_meta, file)
    {assigns, state} = build_self_close_component_assigns(attrs, tag_meta.line, state)

    ast =
      quote line: tag_meta.line do
        Phoenix.LiveView.Helpers.component(&(unquote(mod).unquote(fun) / 1), unquote(assigns))
      end

    state
    |> set_root_on_not_tag()
    |> update_subengine(:handle_expr, ["=", ast])
  end

  # Remote function component (with inner content)

  defp handle_token({:tag_open, <<first, _::binary>> = tag_name, attrs, tag_meta}, state)
       when first in ?A..?Z do
    mod_fun = decompose_remote_component_tag!(tag_name, tag_meta, state.file)
    token = {:tag_open, tag_name, attrs, Map.put(tag_meta, :mod_fun, mod_fun)}

    state
    |> set_root_on_not_tag()
    |> push_tag(token)
    |> init_slots()
    |> push_substate_to_stack()
    |> update_subengine(:handle_begin, [])
  end

  defp handle_token({:tag_close, <<first, _::binary>>, _tag_close_meta} = token, state)
       when first in ?A..?Z do
    {{:tag_open, _name, attrs, %{mod_fun: {mod, fun}, line: line}}, state} =
      pop_tag!(state, token)

    attrs = remove_phx_no_break(attrs)
    {assigns, state} = build_component_assigns(attrs, line, state)

    ast =
      quote line: line do
        Phoenix.LiveView.Helpers.component(&(unquote(mod).unquote(fun) / 1), unquote(assigns))
      end

    state
    |> pop_substate_from_stack()
    |> update_subengine(:handle_expr, ["=", ast])
  end

  # Local function component (self close)

  defp handle_token(
         {:tag_open, "." <> name, attrs, %{self_close: true, line: line}},
         state
       ) do
    attrs = remove_phx_no_break(attrs)
    fun = String.to_atom(name)
    {assigns, state} = build_self_close_component_assigns(attrs, line, state)

    ast =
      quote line: line do
        Phoenix.LiveView.Helpers.component(
          &(unquote(Macro.var(fun, __MODULE__)) / 1),
          unquote(assigns)
        )
      end

    state
    |> set_root_on_not_tag()
    |> update_subengine(:handle_expr, ["=", ast])
  end

  # Slot

  defp handle_token({:tag_open, ":inner_block", _attrs, meta}, state) do
    raise ParseError,
      line: meta.line,
      column: meta.column,
      file: state.file,
      description: "the slot name :inner_block is reserved"
  end

  # Slot (self close)

  defp handle_token({:tag_open, ":" <> slot_name, attrs, %{self_close: true} = tag_meta}, state) do
    attrs = remove_phx_no_break(attrs)
    %{line: line} = tag_meta
    slot_key = String.to_atom(slot_name)

    {let, roots, attrs} = split_component_attrs(attrs, state.file)

    with {_, let_meta} <- let do
      raise ParseError,
        line: let_meta.line,
        column: let_meta.column,
        file: state.file,
        description: "cannot use `let` on a slot without inner content"
    end

    attrs = [__slot__: slot_key, inner_block: nil] ++ attrs
    assigns = merge_component_attrs(roots, attrs, line)
    add_slot!(state, {slot_key, assigns}, tag_meta)
  end

  # Slot (with inner content)

  defp handle_token({:tag_open, ":" <> _, _attrs, _tag_meta} = token, state) do
    state
    |> push_tag(token)
    |> push_substate_to_stack()
    |> update_subengine(:handle_begin, [])
  end

  defp handle_token({:tag_close, ":" <> slot_name, _tag_close_meta} = token, state) do
    {{:tag_open, _name, attrs, %{line: line} = tag_meta}, state} = pop_tag!(state, token)
    attrs = remove_phx_no_break(attrs)
    slot_key = String.to_atom(slot_name)

    {let, roots, attrs} = split_component_attrs(attrs, state.file)
    clauses = build_component_clauses(let, state)

    ast =
      quote line: line do
        Phoenix.LiveView.Helpers.inner_block(unquote(slot_key), do: unquote(clauses))
      end

    attrs = [__slot__: slot_key, inner_block: ast] ++ attrs
    assigns = merge_component_attrs(roots, attrs, line)

    state
    |> add_slot!({slot_key, assigns}, tag_meta)
    |> pop_substate_from_stack()
  end

  # Local function component (with inner content)

  defp handle_token({:tag_open, "." <> _, _attrs, _tag_meta} = token, state) do
    state
    |> set_root_on_not_tag()
    |> push_tag(token)
    |> init_slots()
    |> push_substate_to_stack()
    |> update_subengine(:handle_begin, [])
  end

  defp handle_token({:tag_close, "." <> fun_name, _tag_close_meta} = token, state) do
    {{:tag_open, _name, attrs, %{line: line}}, state} = pop_tag!(state, token)
    attrs = remove_phx_no_break(attrs)
    fun = String.to_atom(fun_name)
    {assigns, state} = build_component_assigns(attrs, line, state)

    ast =
      quote line: line do
        Phoenix.LiveView.Helpers.component(
          &(unquote(Macro.var(fun, __MODULE__)) / 1),
          unquote(assigns)
        )
      end

    state
    |> pop_substate_from_stack()
    |> update_subengine(:handle_expr, ["=", ast])
  end

  # HTML element (self close)

  defp handle_token({:tag_open, name, attrs, %{self_close: true} = tag_meta}, state) do
    suffix = if void?(name), do: ">", else: "></#{name}>"
    attrs = remove_phx_no_break(attrs)
    validate_phx_attrs!(attrs, tag_meta, state)

    state
    |> set_root_on_tag()
    |> handle_tag_and_attrs(name, attrs, suffix, to_location(tag_meta))
  end

  # HTML element

  defp handle_token({:tag_open, name, attrs, tag_meta} = token, state) do
    validate_phx_attrs!(attrs, tag_meta, state)
    attrs = remove_phx_no_break(attrs)

    state
    |> set_root_on_tag()
    |> push_tag(token)
    |> handle_tag_and_attrs(name, attrs, ">", to_location(tag_meta))
  end

  defp handle_token({:tag_close, name, tag_meta} = token, state) do
    {{:tag_open, _name, _attrs, _tag_meta}, state} = pop_tag!(state, token)
    update_subengine(state, :handle_text, [to_location(tag_meta), "</#{name}>"])
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
    state
    |> update_subengine(:handle_text, [meta, "<#{name}"])
    |> handle_tag_attrs(meta, attrs)
    |> update_subengine(:handle_text, [meta, suffix])
  end

  defp handle_tag_attrs(state, meta, attrs) do
    Enum.reduce(attrs, state, fn
      {:root, {:expr, value, %{line: line, column: col}}}, state ->
        attrs = Code.string_to_quoted!(value, line: line, column: col, file: state.file)
        handle_attrs_escape(state, meta, attrs)

      {name, {:expr, value, %{line: line, column: col}}}, state ->
        attr = Code.string_to_quoted!(value, line: line, column: col, file: state.file)
        handle_attr_escape(state, meta, name, attr)

      {name, {:string, value, %{delimiter: ?"}}}, state ->
        update_subengine(state, :handle_text, [meta, ~s( #{name}="#{value}")])

      {name, {:string, value, %{delimiter: ?'}}}, state ->
        update_subengine(state, :handle_text, [meta, ~s( #{name}='#{value}')])

      {name, nil}, state ->
        update_subengine(state, :handle_text, [meta, " #{name}"])
    end)
  end

  defp handle_attrs_escape(state, meta, attrs) do
    ast =
      quote line: meta[:line] do
        Phoenix.HTML.attributes_escape(unquote(attrs))
      end

    update_subengine(state, :handle_expr, ["=", ast])
  end

  defp handle_attr_escape(state, meta, name, value) do
    case extract_binaries(value, true, []) do
      :error ->
        if call = empty_attribute_encoder(name, value, meta) do
          state
          |> update_subengine(:handle_text, [meta, ~s( #{name}=")])
          |> update_subengine(:handle_expr, ["=", {:safe, call}])
          |> update_subengine(:handle_text, [meta, ~s(")])
        else
          handle_attrs_escape(state, meta, [{safe_unless_special(name), value}])
        end

      binaries ->
        state
        |> update_subengine(:handle_text, [meta, ~s( #{name}=")])
        |> handle_binaries(meta, binaries)
        |> update_subengine(:handle_text, [meta, ~s(")])
    end
  end

  defp handle_binaries(state, meta, binaries) do
    binaries
    |> Enum.reverse()
    |> Enum.reduce(state, fn
      {:text, value}, state ->
        update_subengine(state, :handle_text, [meta, binary_encode(value)])

      {:binary, value}, state ->
        ast =
          quote line: meta[:line] do
            {:safe, unquote(__MODULE__).binary_encode(unquote(value))}
          end

        update_subengine(state, :handle_expr, ["=", ast])
    end)
  end

  defp extract_binaries({:<>, _, [left, right]}, _root?, acc) do
    extract_binaries(right, false, extract_binaries(left, false, acc))
  end

  defp extract_binaries({:<<>>, _, parts} = bin, _root?, acc) do
    Enum.reduce(parts, acc, fn
      part, acc when is_binary(part) ->
        [{:text, part} | acc]

      {:"::", _, [binary, {:binary, _, _}]}, acc ->
        [{:binary, binary} | acc]

      _, _ ->
        throw(:unknown_part)
    end)
  catch
    :unknown_part -> [{:binary, bin} | acc]
  end

  defp extract_binaries(binary, _root?, acc) when is_binary(binary), do: [{:text, binary} | acc]
  defp extract_binaries(value, false, acc), do: [{:binary, value} | acc]
  defp extract_binaries(_value, true, _acc), do: :error

  # TODO: We can refactor the empty_attribute_encoder to simply return an atom
  # but there is a bug in Elixir v1.12 and earlier where mixing `line: expr`
  # with .unquote(fun) leads to bugs in line numbers.
  defp empty_attribute_encoder("class", value, meta) do
    quote line: meta[:line], do: unquote(__MODULE__).class_attribute_encode(unquote(value))
  end

  defp empty_attribute_encoder("style", value, meta) do
    quote line: meta[:line], do: unquote(__MODULE__).empty_attribute_encode(unquote(value))
  end

  defp empty_attribute_encoder(_, _, _), do: nil

  @doc false
  def class_attribute_encode([_ | _] = list),
    do: list |> Enum.filter(& &1) |> Enum.join(" ") |> Phoenix.HTML.Engine.encode_to_iodata!()

  def class_attribute_encode(other),
    do: empty_attribute_encode(other)

  @doc false
  def empty_attribute_encode(nil), do: ""
  def empty_attribute_encode(false), do: ""
  def empty_attribute_encode(true), do: ""
  def empty_attribute_encode(value), do: Phoenix.HTML.Engine.encode_to_iodata!(value)

  @doc false
  def binary_encode(value) when is_binary(value) do
    value
    |> Phoenix.HTML.Engine.encode_to_iodata!()
    |> IO.iodata_to_binary()
  end

  def binary_encode(value) do
    raise ArgumentError, "expected a binary in <>, got: #{inspect(value)}"
  end

  # We mark attributes as safe so we don't escape them
  # at rendering time. However, some attributes are
  # specially handled, so we keep them as strings shape.
  defp safe_unless_special("id"), do: :id
  defp safe_unless_special("aria"), do: :aria
  defp safe_unless_special("class"), do: :class
  defp safe_unless_special("data"), do: :data
  defp safe_unless_special(name), do: {:safe, name}

  ## build_self_close_component_assigns/build_component_assigns

  defp build_self_close_component_assigns(attrs, line, %{file: file} = state) do
    {let, roots, attrs} = split_component_attrs(attrs, file)
    raise_if_let!(let, file)
    {merge_component_attrs(roots, attrs, line), state}
  end

  defp build_component_assigns(attrs, line, %{file: file} = state) do
    {let, roots, attrs} = split_component_attrs(attrs, file)
    clauses = build_component_clauses(let, state)

    inner_block_assigns =
      quote line: line do
        %{__slot__: :inner_block,
          inner_block: Phoenix.LiveView.Helpers.inner_block(:inner_block, do: unquote(clauses))}
      end

    {slots, state} = pop_slots(state)
    attrs = attrs ++ [{:inner_block, [inner_block_assigns]} | slots]
    {merge_component_attrs(roots, attrs, line), state}
  end

  defp split_component_attrs(attrs, file) do
    attrs
    |> Enum.reverse()
    |> Enum.reduce({nil, [], []}, &split_component_attr(&1, &2, file))
  end

  defp split_component_attr(
         {:root, {:expr, value, %{line: line, column: col}}},
         {let, r, a},
         file
       ) do
    quoted_value = Code.string_to_quoted!(value, line: line, column: col, file: file)
    quoted_value = quote line: line, do: Map.new(unquote(quoted_value))
    {let, [quoted_value | r], a}
  end

  defp split_component_attr(
         {"let", {:expr, value, %{line: line, column: col} = meta}},
         {nil, r, a},
         file
       ) do
    quoted_value = Code.string_to_quoted!(value, line: line, column: col, file: file)
    {{quoted_value, meta}, r, a}
  end

  defp split_component_attr(
         {"let", {:expr, _value, previous_meta}},
         {{_, meta}, _, _},
         file
       ) do
    message = """
    cannot define multiple `let` attributes. \
    Another `let` has already been defined at line #{previous_meta.line}\
    """

    raise ParseError,
      line: meta.line,
      column: meta.column,
      file: file,
      description: message
  end

  defp split_component_attr(
         {name, {:expr, value, %{line: line, column: col}}},
         {let, r, a},
         file
       ) do
    quoted_value = Code.string_to_quoted!(value, line: line, column: col, file: file)
    {let, r, [{String.to_atom(name), quoted_value} | a]}
  end

  defp split_component_attr({name, {:string, value, _}}, {let, r, a}, _file) do
    {let, r, [{String.to_atom(name), value} | a]}
  end

  defp split_component_attr({name, nil}, {let, r, a}, _file) do
    {let, r, [{String.to_atom(name), true} | a]}
  end

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

  defp decompose_remote_component_tag!(tag_name, tag_meta, file) do
    case String.split(tag_name, ".") |> Enum.reverse() do
      [<<first, _::binary>> = fun_name | rest] when first in ?a..?z ->
        aliases = rest |> Enum.reverse() |> Enum.map(&String.to_atom/1)
        fun = String.to_atom(fun_name)
        {{:__aliases__, [], aliases}, fun}

      _ ->
        %{line: line, column: column} = tag_meta
        message = "invalid tag <#{tag_name}>"
        raise ParseError, line: line, column: column, file: file, description: message
    end
  end

  @doc false
  def __unmatched_let__!(pattern, value) do
    message = """
    cannot match arguments sent from `render_slot/2` against the pattern in `let`.

    Expected a value matching `#{pattern}`, got: `#{inspect(value)}`.
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
      message = "cannot use `let` on a component without inner content"
      raise CompileError, line: line, file: file, description: message
    end
  end

  defp build_component_clauses(let, state) do
    case let do
      # If we have a var, we can skip the catch-all clause
      {{var, _, ctx} = pattern, %{line: line}} when is_atom(var) and is_atom(ctx) ->
        quote line: line do
          unquote(pattern) -> unquote(invoke_subengine(state, :handle_end, []))
        end

      {pattern, %{line: line}} ->
        quote line: line do
          unquote(pattern) -> unquote(invoke_subengine(state, :handle_end, []))
        end ++
          quote line: line, generated: true do
            other ->
              Phoenix.LiveView.HTMLEngine.__unmatched_let__!(
                unquote(Macro.to_string(pattern)),
                other
              )
          end

      _ ->
        quote do
          _ -> unquote(invoke_subengine(state, :handle_end, []))
        end
    end
  end

  ## Helpers

  for void <- ~w(area base br col hr img input link meta param command keygen source) do
    defp void?(unquote(void)), do: true
  end

  defp void?(_), do: false

  defp to_location(%{line: line, column: column}), do: [line: line, column: column]

  defp remove_phx_no_break(attrs) do
    List.keydelete(attrs, "phx-no-format", 0)
  end

  # Check if `phx-update` or `phx-hook` is present in attrs and raises in case
  # there is no ID attribute set.
  defp validate_phx_attrs!(attrs, meta, state),
    do: validate_phx_attrs!(attrs, meta, state, nil, false)

  defp validate_phx_attrs!([], meta, state, attr, false)
       when attr in ["phx-update", "phx-hook"] do
    message = "attribute \"#{attr}\" requires the \"id\" attribute to be set"

    raise ParseError,
      line: meta.line,
      column: meta.column,
      file: state.file,
      description: message
  end

  defp validate_phx_attrs!([], _meta, _state, _attr, _id?), do: :ok

  # Handle <div phx-update="ignore" {@some_var}>Content</div> since here the ID
  # might be inserted dynamically so we can't raise at compile time.
  defp validate_phx_attrs!([{:root, _} | t], meta, state, attr, _id?),
    do: validate_phx_attrs!(t, meta, state, attr, true)

  defp validate_phx_attrs!([{"id", _} | t], meta, state, attr, _id?),
    do: validate_phx_attrs!(t, meta, state, attr, true)

  defp validate_phx_attrs!([{"phx-update", {:string, value, _meta}} | t], meta, state, _attr, id?) do
    if value in ~w(ignore append prepend replace) do
      validate_phx_attrs!(t, meta, state, "phx-update", id?)
    else
      message = "the value of the attribute \"phx-update\" must be: ignore, append or prepend"

      raise ParseError,
        line: meta.line,
        column: meta.column,
        file: state.file,
        description: message
    end
  end

  defp validate_phx_attrs!([{"phx-update", _attrs} | t], meta, state, _attr, id?) do
    validate_phx_attrs!(t, meta, state, "phx-update", id?)
  end

  defp validate_phx_attrs!([{"phx-hook", _} | t], meta, state, _attr, id?),
    do: validate_phx_attrs!(t, meta, state, "phx-hook", id?)

  defp validate_phx_attrs!([_h | t], meta, state, attr, id?),
    do: validate_phx_attrs!(t, meta, state, attr, id?)
end
