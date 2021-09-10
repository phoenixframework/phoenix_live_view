defmodule Phoenix.LiveView.HTMLEngine do
  @moduledoc """
  The HTMLEngine that powers `.heex` templates and the `~H` sigil.
  """

  alias Phoenix.LiveView.HTMLTokenizer
  alias Phoenix.LiveView.HTMLTokenizer.ParseError

  @behaviour Phoenix.Template.Engine

  # TODO: Use @impl true instead of @doc false when we require Elixir v1.12

  @doc false
  def compile(path, _name) do
    trim = Application.get_env(:phoenix, :trim_on_html_eex_engine, true)
    EEx.compile_file(path, engine: __MODULE__, line: 1, trim: trim)
  end

  @behaviour EEx.Engine

  for void <- ~w(area base br col hr img input link meta param command keygen source) do
    defp void?(unquote(void)), do: true
  end

  defp void?(_), do: false

  @doc false
  def init(opts) do
    {subengine, opts} = Keyword.pop(opts, :subengine, Phoenix.LiveView.Engine)
    {module, opts} = Keyword.pop(opts, :module)

    unless subengine do
      raise ArgumentError, ":subengine is missing for HTMLEngine"
    end

    state = %{
      subengine: subengine,
      substate: nil,
      stack: [],
      tags: [],
      root: nil,
      module: module,
      file: Keyword.get(opts, :file, "nofile"),
      indentation: Keyword.get(opts, :indentation, 0)
    }

    update_subengine(state, :init, [])
  end

  ## These callbacks return AST

  @doc false
  def handle_body(state) do
    validate_unclosed_tags!(state)

    opts = [root: state.root || false]
    ast = invoke_subengine(state, :handle_body, [opts])

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

  @doc false
  def handle_end(state) do
    invoke_subengine(state, :handle_end, [])
  end

  ## These callbacks update the state

  @doc false
  def handle_begin(state) do
    update_subengine(state, :handle_begin, [])
  end

  @doc false
  def handle_text(state, text) do
    handle_text(state, [line: 1, column: 1, skip_metadata: true], text)
  end

  def handle_text(%{file: file, indentation: indentation} = state, meta, text) do
    text
    |> HTMLTokenizer.tokenize(file, indentation, meta)
    |> Enum.reduce(state, &handle_token(&1, &2, meta))
  end

  defp validate_unclosed_tags!(%{tags: []} = state) do
    state
  end

  defp validate_unclosed_tags!(%{tags: [tag | _]} = state) do
    {:tag_open, name, _attrs, %{line: line, column: column}} = tag
    file = state.file
    message = "end of file reached without closing tag for <#{name}>"
    raise ParseError, line: line, column: column, file: file, description: message
  end

  @doc false
  def handle_expr(state, marker, expr) do
    state
    |> set_root_on_dynamic()
    |> update_subengine(:handle_expr, [marker, expr])
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

  # Text

  defp handle_token({:text, text}, state, meta) do
    state
    |> set_root_on_text(text)
    |> update_subengine(:handle_text, [meta, text])
  end

  # Remote function component (self close)

  defp handle_token(
         {:tag_open, <<first, _::binary>> = tag_name, attrs, %{self_close: true}} = tag_meta,
         state,
         _meta
       )
       when first in ?A..?Z do
    file = state.file
    {mod, fun} = decompose_remote_component_tag!(tag_name, tag_meta, file)

    {let, assigns} = handle_component_attrs(attrs, file)
    raise_if_let!(let, file)

    ast =
      quote do
        Phoenix.LiveView.Helpers.component(&(unquote(mod).unquote(fun) / 1), unquote(assigns))
      end

    state
    |> set_root_on_dynamic()
    |> update_subengine(:handle_expr, ["=", ast])
  end

  # Remote function component (with inner content)

  defp handle_token({:tag_open, <<first, _::binary>> = tag_name, attrs, tag_meta}, state, _meta)
       when first in ?A..?Z do
    mod_fun = decompose_remote_component_tag!(tag_name, tag_meta, state.file)
    token = {:tag_open, tag_name, attrs, Map.put(tag_meta, :mod_fun, mod_fun)}

    state
    |> set_root_on_dynamic()
    |> push_tag(token)
    |> push_substate_to_stack()
    |> update_subengine(:handle_begin, [])
  end

  defp handle_token({:tag_close, <<first, _::binary>>, _tag_close_meta} = token, state, _meta)
       when first in ?A..?Z do
    {{:tag_open, _name, attrs, %{mod_fun: {mod, fun}}}, state} = pop_tag!(state, token)
    {let, assigns} = handle_component_attrs(attrs, state.file)
    clauses = build_component_clauses(let, state)

    ast =
      quote do
        Phoenix.LiveView.Helpers.component(&(unquote(mod).unquote(fun) / 1), unquote(assigns),
          do: unquote(clauses)
        )
      end

    state
    |> pop_substate_from_stack()
    |> update_subengine(:handle_expr, ["=", ast])
  end

  # Local function component (self close)

  defp handle_token(
         {:tag_open, "." <> name, attrs, %{self_close: true}},
         state,
         _meta
       ) do
    fun = String.to_atom(name)
    file = state.file

    {let, assigns} = handle_component_attrs(attrs, file)
    raise_if_let!(let, file)

    ast =
      quote do
        Phoenix.LiveView.Helpers.component(
          &(unquote(Macro.var(fun, __MODULE__)) / 1),
          unquote(assigns)
        )
      end

    state
    |> set_root_on_dynamic()
    |> update_subengine(:handle_expr, ["=", ast])
  end

  # Local function component (with inner content)

  defp handle_token({:tag_open, "." <> _, _attrs, _tag_meta} = token, state, _meta) do
    state
    |> set_root_on_dynamic()
    |> push_tag(token)
    |> push_substate_to_stack()
    |> update_subengine(:handle_begin, [])
  end

  defp handle_token({:tag_close, "." <> fun_name, _tag_close_meta} = token, state, _meta) do
    {{:tag_open, _name, attrs, _tag_meta}, state} = pop_tag!(state, token)

    fun = String.to_atom(fun_name)
    {let, assigns} = handle_component_attrs(attrs, state.file)
    clauses = build_component_clauses(let, state)

    ast =
      quote do
        Phoenix.LiveView.Helpers.component(
          &(unquote(Macro.var(fun, __MODULE__)) / 1),
          unquote(assigns),
          do: unquote(clauses)
        )
      end

    state
    |> pop_substate_from_stack()
    |> update_subengine(:handle_expr, ["=", ast])
  end

  # HTML element (self close)

  defp handle_token({:tag_open, name, attrs, %{self_close: true}}, state, meta) do
    suffix = if void?(name), do: ">", else: "></#{name}>"

    state
    |> set_root_on_tag()
    |> handle_tag_and_attrs(name, attrs, suffix, meta)
  end

  # HTML element

  defp handle_token({:tag_open, name, attrs, _tag_meta} = token, state, meta) do
    state
    |> set_root_on_tag()
    |> push_tag(token)
    |> handle_tag_and_attrs(name, attrs, ">", meta)
  end

  defp handle_token({:tag_close, name, _tag_close_meta} = token, state, meta) do
    {{:tag_open, _name, _attrs, _tag_meta}, state} = pop_tag!(state, token)
    update_subengine(state, :handle_text, [meta, "</#{name}>"])
  end

  # Root tracking

  defp set_root_on_dynamic(%{root: root, tags: tags} = state) do
    if tags == [] and root != false do
      %{state | root: false}
    else
      state
    end
  end

  defp set_root_on_text(%{root: root, tags: tags} = state, text) do
    if tags == [] and root != false and String.trim_leading(text) != "" do
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
        attrs = Code.string_to_quoted!(value, line: line, column: col)
        handle_attr_escape(state, attrs)

      {name, {:expr, value, %{line: line, column: col}}}, state ->
        attr = Code.string_to_quoted!(value, line: line, column: col)
        handle_attr_escape(state, [{safe_unless_special(name), attr}])

      {name, {:string, value, %{delimiter: ?"}}}, state ->
        update_subengine(state, :handle_text, [meta, ~s( #{name}="#{value}")])

      {name, {:string, value, %{delimiter: ?'}}}, state ->
        update_subengine(state, :handle_text, [meta, ~s( #{name}='#{value}')])

      {name, nil}, state ->
        update_subengine(state, :handle_text, [meta, " #{name}"])
    end)
  end

  defp handle_attr_escape(state, attrs) do
    ast =
      quote do
        Phoenix.HTML.Tag.attributes_escape(unquote(attrs))
      end

    update_subengine(state, :handle_expr, ["=", ast])
  end

  defp safe_unless_special("aria"), do: "aria"
  defp safe_unless_special("class"), do: "class"
  defp safe_unless_special("data"), do: "data"
  defp safe_unless_special(name), do: {:safe, name}

  ## handle_component_attrs

  defp handle_component_attrs(attrs, file) do
    {lets, entries} =
      case build_component_attrs(attrs) do
        {lets, [], []} -> {lets, [{:%{}, [], []}]}
        {lets, r, []} -> {lets, r}
        {lets, r, d} -> {lets, r ++ [{:%{}, [], d}]}
      end

    let =
      case lets do
        [] ->
          nil

        [let] ->
          let

        [{_, meta}, {_, previous_meta} | _] ->
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

    assigns =
      Enum.reduce(entries, fn expr, acc ->
        quote do: Map.merge(unquote(acc), unquote(expr))
      end)

    {let, assigns}
  end

  defp build_component_attrs(attrs) do
    build_component_attrs(attrs, {[], [], []})
  end

  defp build_component_attrs([], {lets, r, d}) do
    {lets, Enum.reverse(r), Enum.reverse(d)}
  end

  defp build_component_attrs(
         [{:root, {:expr, value, %{line: line, column: col}}} | attrs],
         {lets, r, d}
       ) do
    quoted_value = Code.string_to_quoted!(value, line: line, column: col)
    quoted_value = quote do: Map.new(unquote(quoted_value))
    build_component_attrs(attrs, {lets, [quoted_value | r], d})
  end

  defp build_component_attrs(
         [{"let", {:expr, value, %{line: line, column: col} = meta}} | attrs],
         {lets, r, d}
       ) do
    quoted_value = Code.string_to_quoted!(value, line: line, column: col)
    build_component_attrs(attrs, {[{quoted_value, meta} | lets], r, d})
  end

  defp build_component_attrs(
         [{name, {:expr, value, %{line: line, column: col}}} | attrs],
         {lets, r, d}
       ) do
    quoted_value = Code.string_to_quoted!(value, line: line, column: col)
    build_component_attrs(attrs, {lets, r, [{String.to_atom(name), quoted_value} | d]})
  end

  defp build_component_attrs([{name, {:string, value, _}} | attrs], {lets, r, d}) do
    build_component_attrs(attrs, {lets, r, [{String.to_atom(name), value} | d]})
  end

  defp build_component_attrs([{name, nil} | attrs], {lets, r, d}) do
    build_component_attrs(attrs, {lets, r, [{String.to_atom(name), true} | d]})
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
    cannot match arguments sent from `render_block/2` against the pattern in `let`.

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
      {pattern, %{line: line}} ->
        quote line: line do
          unquote(pattern) ->
            unquote(invoke_subengine(state, :handle_end, []))
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
end
