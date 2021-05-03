defmodule Phoenix.LiveView.HTMLEngine do
  @moduledoc """
  The HTMLEngine that powers `.heex` templates and the `~H` sigil.
  """

  alias Phoenix.LiveView.HTMLTokenizer

  @behaviour Phoenix.Template.Engine

  # TODO: Use @impl true instead of @doc false when we require Elixir v1.12

  @doc false
  def compile(path, _name) do
    trim = Application.get_env(:phoenix, :trim_on_html_eex_engine, true)
    EEx.compile_file(path, engine: __MODULE__, line: 1, trim: trim)
  end

  @behaviour EEx.Engine

  @void_elements [
    "area",
    "base",
    "br",
    "col",
    "hr",
    "img",
    "input",
    "link",
    "meta",
    "param",
    "command",
    "keygen",
    "source"
  ]

  @doc false
  def init(opts) do
    {subengine, opts} = Keyword.pop(opts, :subengine, Phoenix.LiveView.Engine)

    unless subengine do
      raise ArgumentError, ":subengine is missing for HTMLEngine"
    end

    state = %{
      subengine: subengine,
      substate: nil,
      stack: [],
      tags: [],
      opts: opts
    }

    update_subengine(state, :init, [])
  end

  ## These callbacks return AST

  @doc false
  def handle_body(state) do
    invoke_subengine(state, :handle_body, [])
  end

  @doc false
  def handle_end(state) do
    invoke_subengine(state, :handle_end, [])
  end

  ## These callbacks udpate the state

  @doc false
  def handle_begin(state) do
    update_subengine(state, :handle_begin, [])
  end

  @doc false
  def handle_text(state, text) do
    handle_text(state, [line: 1, column: 1, skip_metadata: true], text)
  end

  def handle_text(state, meta, text) do
    opts = Keyword.take(state.opts, [:indentation]) ++ meta

    text
    |> HTMLTokenizer.tokenize(opts)
    |> Enum.reduce(state, &handle_token(&1, &2, meta))
  end

  @doc false
  def handle_expr(state, marker, expr) do
    update_subengine(state, :handle_expr, [marker, expr])
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

  defp push_tag(state, {:tag_open, tag, _attrs, _meta}) when tag in @void_elements do
    state
  end

  defp push_tag(state, token) do
    %{state | tags: [token | state.tags]}
  end

  defp pop_tag(%{tags: [{:tag_open, tag_name, _attrs, _meta} = tag | tags]} = state, tag_name) do
    {tag, %{state | tags: tags}}
  end

  defp pop_tag(_state, tag_name) do
    raise "missing open tag for </#{tag_name}>"
  end

  ## handle_token

  # Text

  defp handle_token({:text, text}, state, meta) do
    update_subengine(state, :handle_text, [meta, text])
  end

  # Remote function component (self close)

  defp handle_token(
         {:tag_open, <<first, _::binary>> = tag_name, attrs, %{self_close: true}},
         state,
         _meta
       )
       when first in ?A..?Z do
    {mod, fun} = decompose_remote_component_tag!(tag_name)
    assigns = handle_component_attrs(attrs)

    ast =
      quote do
        component(&unquote(mod).unquote(fun)/1, unquote(assigns))
      end

    update_subengine(state, :handle_expr, ["=", ast])
  end

  # Remote function component (with inner content)

  defp handle_token({:tag_open, <<first, _::binary>> = tag_name, attrs, tag_meta}, state, _meta)
       when first in ?A..?Z do
    mod_fun = decompose_remote_component_tag!(tag_name)
    token = {:tag_open, tag_name, attrs, Map.put(tag_meta, :mod_fun, mod_fun)}

    state
    |> push_tag(token)
    |> push_substate_to_stack()
    |> update_subengine(:handle_begin, [])
  end

  defp handle_token({:tag_close, <<first, _::binary>> = name}, state, _meta)
       when first in ?A..?Z do
    {{:tag_open, _name, attrs, %{mod_fun: {mod, fun}}}, state} = pop_tag(state, name)
    assigns = handle_component_attrs(attrs)

    # TODO: Implement `let`

    ast =
      quote do
        component(&unquote(mod).unquote(fun)/1, unquote(assigns)) do
          _assigns ->
            unquote(invoke_subengine(state, :handle_end, []))
        end
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
    assigns = handle_component_attrs(attrs)

    ast =
      quote do
        component(&unquote(Macro.var(fun, __MODULE__))/1, unquote(assigns))
      end

    update_subengine(state, :handle_expr, ["=", ast])
  end

  # Local function component (with inner content)

  defp handle_token({:tag_open, "." <> _, _attrs, _tag_meta} = token, state, _meta) do
    state
    |> push_tag(token)
    |> push_substate_to_stack()
    |> update_subengine(:handle_begin, [])
  end

  defp handle_token({:tag_close, "." <> fun_name = tag_name}, state, _meta) do
    {{:tag_open, _name, attrs, _tag_meta}, state} = pop_tag(state, tag_name)

    fun = String.to_atom(fun_name)
    assigns = handle_component_attrs(attrs)

    # TODO: Implement `let`

    ast =
      quote do
        component(&unquote(Macro.var(fun, __MODULE__))/1, unquote(assigns)) do
          _assigns ->
            unquote(invoke_subengine(state, :handle_end, []))
        end
      end

    state
    |> pop_substate_from_stack()
    |> update_subengine(:handle_expr, ["=", ast])
  end

  # HTML void element

  defp handle_token({:tag_open, name, attrs, tag_meta}, state, meta)
       when name in @void_elements do
    state
    |> update_subengine(:handle_text, [meta, "<#{String.downcase(name)}"])
    |> handle_attrs(attrs, tag_meta)
    |> update_subengine(:handle_text, [meta, ">"])
  end

  # HTML element (self close)

  defp handle_token({:tag_open, name, attrs, %{self_close: true}}, state, meta) do
    state
    |> update_subengine(:handle_text, [meta, "<#{String.downcase(name)}"])
    |> handle_attrs(attrs, meta)
    |> update_subengine(:handle_text, [meta, "/>"])
  end

  # HTML element (with inner content)

  defp handle_token({:tag_open, name, attrs, _tag_meta} = token, state, meta) do
    state
    |> push_tag(token)
    |> update_subengine(:handle_text, [meta, "<#{String.downcase(name)}"])
    |> handle_attrs(attrs, meta)
    |> update_subengine(:handle_text, [meta, ">"])
  end

  defp handle_token({:tag_close, name}, state, meta) do
    {{:tag_open, _name, _attrs, _tag_meta}, state} = pop_tag(state, name)
    update_subengine(state, :handle_text, [meta, "</#{String.downcase(name)}>"])
  end

  # Fallback

  defp handle_token(_, state, _meta) do
    state
  end

  ## handle_attrs

  defp handle_attrs(state, attrs, meta) do
    {static, static_dynamic, dynamic} = group_attrs(attrs)

    state
    |> handle_static_attrs(static, meta)
    |> handle_static_dynamic_attrs(static_dynamic)
    |> handle_dynamic_attrs(dynamic)
  end

  defp handle_static_attrs(state, parts, meta) do
    update_subengine(state, :handle_text, [meta, to_string(parts)])
  end

  defp handle_static_dynamic_attrs(state, parts) do
    ast =
      quote do
        Phoenix.HTML.Tag.attributes_escape(unquote(parts))
      end

    update_subengine(state, :handle_expr, ["=", ast])
  end

  defp handle_dynamic_attrs(state, parts) do
    Enum.reduce(parts, state, fn expr, state ->
      ast =
        quote do
          Phoenix.HTML.Tag.attributes_escape(unquote(expr))
        end

      update_subengine(state, :handle_expr, ["=", ast])
    end)
  end

  defp group_attrs(attrs) do
    group_attrs(attrs, {[], [], []})
  end

  defp group_attrs([], {s, sd, d}) do
    {Enum.reverse(s), Enum.reverse(sd), Enum.reverse(d)}
  end

  defp group_attrs([{:root, {:expr, value, %{line: line, column: col}}} | attrs], {s, sd, d}) do
    quoted_value = Code.string_to_quoted!(value, line: line, column: col)
    group_attrs(attrs, {s, sd, [quoted_value | d]})
  end

  defp group_attrs([{name, {:expr, value, %{line: line, column: col}}} | attrs], {s, sd, d}) do
    quoted_value = Code.string_to_quoted!(value, line: line, column: col)
    group_attrs(attrs, {s, [{name, quoted_value} | sd], d})
  end

  defp group_attrs([{name, {:string, value, %{delimiter: ?"}}} | attrs], {s, sd, d}) do
    group_attrs(attrs, {[~s( #{name}="#{value}") | s], sd, d})
  end

  defp group_attrs([{name, {:string, value, %{delimiter: ?'}}} | attrs], {s, sd, d}) do
    group_attrs(attrs, {[~s( #{name}='#{value}') | s], sd, d})
  end

  defp group_attrs([{name, nil} | attrs], {s, sd, d}) do
    group_attrs(attrs, {[" #{name}" | s], sd, d})
  end

  defp handle_component_attrs(attrs) do
    {r, d} = build_component_attrs(attrs)

    quote do
      Enum.reduce([unquote_splicing(r ++ [d])], %{}, &Map.merge(&2, Map.new(&1)))
    end
  end

  defp build_component_attrs(attrs) do
    build_component_attrs(attrs, {[], []})
  end

  defp build_component_attrs([], {r, d}) do
    {Enum.reverse(r), Enum.reverse(d)}
  end

  defp build_component_attrs([{:root, {:expr, value, %{line: line, column: col}}} | attrs], {r, d}) do
    quoted_value = Code.string_to_quoted!(value, line: line, column: col)
    build_component_attrs(attrs, {[quoted_value | r], d})
  end

  defp build_component_attrs([{name, {:expr, value, %{line: line, column: col}}} | attrs], {r, d}) do
    quoted_value = Code.string_to_quoted!(value, line: line, column: col)
    build_component_attrs(attrs, {r, [{String.to_atom(name), quoted_value} | d]})
  end

  defp build_component_attrs([{name, {:string, value, %{delimiter: ?"}}} | attrs], {r, d}) do
    build_component_attrs(attrs, {r, [{String.to_atom(name), value} | d]})
  end

  defp build_component_attrs([{name, {:string, value, %{delimiter: ?'}}} | attrs], {r, d}) do
    build_component_attrs(attrs, {r, [{String.to_atom(name), value} | d]})
  end

  defp build_component_attrs([{name, nil} | attrs], {r, d}) do
    build_component_attrs(attrs, {r, [{String.to_atom(name), true} | d]})
  end

  defp decompose_remote_component_tag!(tag_name) do
    case String.split(tag_name, ".") |> Enum.reverse() do
      [<<first, _::binary>> = fun_name | rest] when first in ?a..?z ->
        mod = rest |> Enum.reverse() |> Module.concat()
        fun = String.to_atom(fun_name)
        {mod, fun}

      _ ->
        # TODO: Raise a proper error at the line of the component definition
        raise ArgumentError, "invalid tag #{tag_name}"
    end
  end
end
