defmodule Phoenix.LiveView.Assigns do
  @doc false

  alias Phoenix.HTML.Form

  defguardp is_access(mod)
          when mod == Access or
                  (is_tuple(mod) and elem(mod, 0) == :__aliases__ and elem(mod, 2) == [:Access])

  @assigns_var Macro.var(:assigns, nil)

  def assigns_var, do: @assigns_var

  # Here we compute if an expression should be always computed,
  # never computed, or some times computed based on assigns.
  #
  # If any assign is used, we store it in the assigns and use it to compute
  # if it should be changed or not.
  #
  # However, operations that change the lexical scope, such as imports and
  # defining variables, taint the analysis. Because variables can be set at
  # any moment in Elixir, via macros, without appearing on the left side of
  # `=` or in a clause, whenever we see a variable, we consider it as tainted,
  # regardless of its position.
  #
  # The tainting that happens from lexical scope is called weak-tainting,
  # because it is disabled under certain special forms. There is also
  # strong-tainting, which are always computed. Strong-tainting only happens
  # if the `assigns` variable is used.
  def analyze_and_return_tainted_keys(ast, vars, assigns, caller, maybe_warn_taint) do
    {ast, vars, assigns} = analyze(ast, vars, assigns, caller, maybe_warn_taint)
    {tainted_assigns?, assigns} = Map.pop(assigns, __MODULE__, false)
    keys = if match?({:tainted, _}, vars) or tainted_assigns?, do: :all, else: assigns
    {ast, keys, vars}
  end

  # if we find a variable (or something more complex handled by the other clauses)
  # like foo[:bar][:baz] and foo is marked as :change_track in vars, we consider it
  # as an assign, but look into vars_changed instead of changed
  defp analyze_assign(
         {name, _, context} = expr,
         {type, map} = vars,
         assigns,
         caller,
         nest,
         maybe_warn_taint
       )
       when is_atom(name) and is_atom(context) and is_map_key(map, name) and type != :tainted do
    if map[name] == :change_track do
      {expr, vars, put_changed_assign(assigns, :vars_changed, [name | nest])}
    else
      analyze(expr, vars, assigns, caller, maybe_warn_taint)
    end
  end

  # @name
  defp analyze_assign({:@, meta, [{name, _, context}]}, vars, assigns, _caller, nest, _maybe_warn_taint)
       when is_atom(name) and is_atom(context) do
    expr = {{:., meta, [@assigns_var, name]}, [no_parens: true] ++ meta, []}
    {expr, vars, put_changed_assign(assigns, :changed, [name | nest])}
  end

  # assigns.name
  defp analyze_assign(
         {{:., _, [{:assigns, _, nil}, name]}, _, args} = expr,
         vars,
         assigns,
         _caller,
         nest,
         _maybe_warn_taint
       )
       when is_atom(name) and args in [[], nil] do
    {expr, vars, put_changed_assign(assigns, :changed, [name | nest])}
  end

  # assigns[:name]
  defp analyze_assign(
         {{:., _, [access, :get]}, _, [{:assigns, _, nil}, name]} = expr,
         vars,
         assigns,
         _caller,
         nest,
         _maybe_warn_taint
       )
       when is_atom(name) and is_access(access) do
    {expr, vars, put_changed_assign(assigns, :changed, [name | nest])}
  end

  # Maybe: assigns.foo[:bar]
  defp analyze_assign(
         {{:., dot_meta, [access, :get]}, meta, [left, right]},
         vars,
         assigns,
         caller,
         nest,
         maybe_warn_taint
       )
       when is_access(access) do
    {args, vars, assigns} =
      if Macro.quoted_literal?(right) do
        {left, vars, assigns} =
          analyze_assign(left, vars, assigns, caller, [{:access, right} | nest], maybe_warn_taint)

        {[left, right], vars, assigns}
      else
        {left, vars, assigns} = analyze(left, vars, assigns, caller, maybe_warn_taint)
        {right, vars, assigns} = analyze(right, vars, assigns, caller, maybe_warn_taint)
        {[left, right], vars, assigns}
      end

    {{{:., dot_meta, [Access, :get]}, meta, args}, vars, assigns}
  end

  # Maybe: assigns.foo.bar
  defp analyze_assign({{:., dot_meta, [left, right]}, meta, args}, vars, assigns, caller, nest, maybe_warn_taint)
       when args in [[], nil] do
    {left, vars, assigns} = analyze_assign(left, vars, assigns, caller, [{:struct, right} | nest], maybe_warn_taint)
    {{{:., dot_meta, [left, right]}, meta, []}, vars, assigns}
  end

  defp analyze_assign(expr, vars, assigns, caller, _nest, maybe_warn_taint) do
    analyze(expr, vars, assigns, caller, maybe_warn_taint)
  end

  # Delegates to analyze assign
  def analyze({{:., _, [access, :get]}, _, [_, _]} = expr, vars, assigns, caller, maybe_warn_taint)
       when is_access(access) do
    analyze_assign(expr, vars, assigns, caller, [], maybe_warn_taint)
  end

  def analyze({{:., _, [_, _]}, _, args} = expr, vars, assigns, caller, maybe_warn_taint) when args in [[], nil] do
    analyze_assign(expr, vars, assigns, caller, [], maybe_warn_taint)
  end

  def analyze({:@, _, [{name, _, context}]} = expr, vars, assigns, caller, maybe_warn_taint)
       when is_atom(name) and is_atom(context) do
    analyze_assign(expr, vars, assigns, caller, [], maybe_warn_taint)
  end

  # Assigns is a strong-taint
  def analyze({:assigns, _, nil} = expr, vars, assigns, _caller, _maybe_warn_taint) do
    {expr, vars, taint_assigns(assigns)}
  end

  # Ignore underscore
  def analyze({:_, _, context} = expr, vars, assigns, _caller, _maybe_warn_taint) when is_atom(context) do
    {expr, vars, assigns}
  end

  # Also skip special variables
  def analyze({name, _, context} = expr, vars, assigns, _caller, _maybe_warn_taint)
       when name in [:__MODULE__, :__ENV__, :__STACKTRACE__, :__DIR__] and is_atom(context) do
    {expr, vars, assigns}
  end

  # Vars always taint unless we are in restricted mode
  # or the variable is marked as `:change_track` for vars_changed.
  def analyze({name, meta, nil} = expr, {:restricted, map} = vars, assigns, caller, maybe_warn_taint)
       when is_atom(name) do
    case map do
      %{^name => :tainted} ->
        maybe_warn_taint.(name, meta, caller)
        {expr, {:tainted, map}, assigns}

      %{^name => :change_track} ->
        {expr, vars, put_changed_assign(assigns, :vars_changed, [name])}

      _ ->
        {expr, {:restricted, map}, assigns}
    end
  end

  def analyze({name, meta, nil} = expr, {type, map}, assigns, caller, maybe_warn_taint)
       when is_atom(name) do
    cond do
      Map.get(map, name) == :change_track ->
        {expr, {type, map}, put_changed_assign(assigns, :vars_changed, [name])}

      Keyword.get(meta, :change_track) ->
        # this is a variable inside the left-hand side of a keyed for expression;
        # we mark it as change_track in the vars map so that we treat it as change-tracked
        # when we see it used again later (see the previous analyze clause above)
        {expr, {type, Map.put(map, name, :change_track)}, assigns}

      true ->
        maybe_warn_taint.(name, meta, caller)
        {expr, {:tainted, Map.put(map, name, :tainted)}, assigns}
    end
  end

  # Quoted vars are ignored as they come from engine code.
  def analyze({name, _meta, context} = expr, vars, assigns, _caller, _maybe_warn_taint)
       when is_atom(name) and is_atom(context) do
    {expr, vars, assigns}
  end

  # Ignore right side of |> if a variable
  def analyze({:|>, meta, [left, {_, _, context} = right]}, vars, assigns, caller, maybe_warn_taint)
       when is_atom(context) do
    {left, vars, assigns} = analyze(left, vars, assigns, caller, maybe_warn_taint)
    {{:|>, meta, [left, right]}, vars, assigns}
  end

  # Ignore binary modifiers
  def analyze({:"::", meta, [left, right]}, vars, assigns, caller, maybe_warn_taint) do
    {left, vars, assigns} = analyze(left, vars, assigns, caller, maybe_warn_taint)
    {{:"::", meta, [left, right]}, vars, assigns}
  end

  # Handle for/with to consider the first generator.
  # Ideally we would track all variables on the patterns and expand all generators
  # but except for the unlikely scenario of combinations, all comprehensions will
  # be using nested generators.
  def analyze({for_with, meta, [{:<-, arrow_meta, [left, right]} | args]}, vars, assigns, caller, maybe_warn_taint)
       when for_with in [:for, :with] do
    {right, vars, assigns} = analyze(right, vars, assigns, caller, maybe_warn_taint)

    {[left | args], vars, assigns} =
      analyze_with_restricted_vars([left | args], vars, assigns, caller, maybe_warn_taint)

    {{for_with, meta, [{:<-, arrow_meta, [left, right]} | args]}, vars, assigns}
  end

  # Classify calls
  def analyze({left, meta, args}, vars, assigns, caller, maybe_warn_taint) do
    call = extract_call(left)

    case classify_taint(call, args) do
      :special_form ->
        code = quote do: unquote(__MODULE__).__raise__(unquote(call), unquote(length(args)))
        {code, vars, assigns}

      :none ->
        {left, vars, assigns} = analyze(left, vars, assigns, caller, maybe_warn_taint)
        {args, vars, assigns} = analyze_list(args, vars, assigns, caller, [], maybe_warn_taint)
        {{left, meta, args}, vars, assigns}

      :live ->
        {args, [opts]} = Enum.split(args, -1)
        {args, vars, assigns} = analyze_skip_assignment_list(args, vars, assigns, caller, [], maybe_warn_taint)
        {opts, vars, assigns} = analyze_with_restricted_vars(opts, vars, assigns, caller, maybe_warn_taint)
        {{left, meta, args ++ [opts]}, vars, assigns}

      :never ->
        {args, vars, assigns} = analyze_with_restricted_vars(args, vars, assigns, caller, maybe_warn_taint)
        {{left, meta, args}, vars, assigns}
    end
  end

  def analyze({left, right}, vars, assigns, caller, maybe_warn_taint) do
    {left, vars, assigns} = analyze(left, vars, assigns, caller, maybe_warn_taint)
    {right, vars, assigns} = analyze(right, vars, assigns, caller, maybe_warn_taint)
    {{left, right}, vars, assigns}
  end

  def analyze([_ | _] = list, vars, assigns, caller, maybe_warn_taint) do
    analyze_list(list, vars, assigns, caller, [], maybe_warn_taint)
  end

  def analyze(other, vars, assigns, _caller, _maybe_warn_taint) do
    {other, vars, assigns}
  end

  def analyze_list([head | tail], vars, assigns, caller, acc, maybe_warn_taint) do
    {head, vars, assigns} = analyze(head, vars, assigns, caller, maybe_warn_taint)
    analyze_list(tail, vars, assigns, caller, [head | acc], maybe_warn_taint)
  end

  def analyze_list([], vars, assigns, _caller, acc, _maybe_warn_taint) do
    {Enum.reverse(acc), vars, assigns}
  end

  defp analyze_skip_assignment_list(
         [{:=, meta, [left, right]} | tail],
         vars,
         assigns,
         caller,
         acc,
         maybe_warn_taint
       ) do
    {right, vars, assigns} = analyze(right, vars, assigns, caller, maybe_warn_taint)
    analyze_skip_assignment_list(tail, vars, assigns, caller, [{:=, meta, [left, right]} | acc], maybe_warn_taint)
  end

  defp analyze_skip_assignment_list([head | tail], vars, assigns, caller, acc, maybe_warn_taint) do
    {head, vars, assigns} = analyze(head, vars, assigns, caller, maybe_warn_taint)
    analyze_skip_assignment_list(tail, vars, assigns, caller, [head | acc], maybe_warn_taint)
  end

  defp analyze_skip_assignment_list([], vars, assigns, _caller, acc, _maybe_warn_taint) do
    {Enum.reverse(acc), vars, assigns}
  end

  # vars is one of:
  #
  #   * {:tainted, map}
  #   * {:restricted, map}
  #   * {:untainted, map}
  #
  # Seeing a variable at any moment taints it unless we are inside a
  # scope. For example, in case/cond/with/fn/try, the variable is only
  # tainted if it came from outside of the case/cond/with/fn/try.
  # So for those constructs we set the mode to restricted and stop
  # collecting vars.
  defp analyze_with_restricted_vars(ast, {kind, map}, assigns, caller, maybe_warn_taint) do
    {ast, {new_kind, _}, assigns} =
      analyze(ast, {unless_tainted(kind, :restricted), map}, assigns, caller, maybe_warn_taint)

    {ast, {unless_tainted(new_kind, kind), map}, assigns}
  end

  defp unless_tainted(:tainted, _), do: :tainted
  defp unless_tainted(_, kind), do: kind

  defp taint_assigns(assigns), do: Map.put(assigns, __MODULE__, true)

  defp put_changed_assign(assigns, changed_var, key) do
    if nested_and_parent_is_checked?(changed_var, key, assigns) do
      assigns
    else
      Map.put(assigns, {changed_var, key}, true)
    end
  end

  # If we are accessing @foo.bar.baz but in the same place we also pass
  # @foo.bar or @foo, we don't need to check for @foo.bar.baz.

  # If there is no nesting, then we are not nesting.
  def nested_and_parent_is_checked?(_changed_var, [_], _assigns),
    do: false

  # Otherwise, we convert @foo.bar.baz into [:baz, :bar, :foo], discard :baz,
  # and then check if [:foo, :bar] and then [:foo] is in it.
  def nested_and_parent_is_checked?(changed_var, keys, assigns),
    do: parent_is_checked?(changed_var, tl(Enum.reverse(keys)), assigns)

  def parent_is_checked?(_changed_var, [], _assigns),
    do: false

  def parent_is_checked?(changed_var, rest, assigns),
    do:
      Map.has_key?(assigns, {changed_var, Enum.reverse(rest)}) or
        parent_is_checked?(changed_var, tl(rest), assigns)

  # For case/if/unless in particular, we are not leaking the
  # variables defined in arguments, such as `if var = ... do`.
  # This does not follow Elixir semantics, but yields better
  # optimizations.
  def classify_taint(:case, [_, _]), do: :live
  def classify_taint(:if, [_, _]), do: :live
  def classify_taint(:unless, [_, _]), do: :live
  def classify_taint(:cond, [_]), do: :live
  def classify_taint(:try, [_]), do: :live
  def classify_taint(:receive, [_]), do: :live

  # with/for are specially handled during analyze
  def classify_taint(:with, [_ | _]), do: :live
  def classify_taint(:for, [_ | _]), do: :live

  # Constructs from TagEngine
  def classify_taint(:inner_block, [_, [do: _]]), do: :live

  # Constructs from Phoenix.View
  def classify_taint(:render_layout, [_, _, _, [do: _]]), do: :live

  # Special forms are forbidden and raise.
  def classify_taint(:alias, [_]), do: :special_form
  def classify_taint(:import, [_]), do: :special_form
  def classify_taint(:require, [_]), do: :special_form
  def classify_taint(:alias, [_, _]), do: :special_form
  def classify_taint(:import, [_, _]), do: :special_form
  def classify_taint(:require, [_, _]), do: :special_form

  def classify_taint(:&, [_]), do: :never
  def classify_taint(:fn, _), do: :never
  def classify_taint(_, _), do: :none

  defp extract_call({:., _, [{:__aliases__, _, [:Phoenix, :LiveView, :TagEngine]}, func]}),
    do: func

  defp extract_call(call),
    do: call

  @doc false
  defmacro __raise__(special_form, arity) do
    message = "cannot invoke special form #{special_form}/#{arity} inside HEEx templates or assign_computed"
    reraise ArgumentError.exception(message), Macro.Env.stacktrace(__CALLER__)
  end

  @doc false
  def changed_assign?(changed, name) do
    case changed do
      %{^name => _} -> true
      %{} -> false
      nil -> true
    end
  end

  def changed_assign(changed, name) do
    case changed do
      %{^name => value} -> value
      %{} -> false
      nil -> true
    end
  end

  @doc false
  def nested_changed_assign?(tail, head, assigns, changed),
    do: nested_changed_assign(tail, head, assigns, changed) != false

  def nested_changed_assign(tail, head, assigns, changed) do
    case changed do
      %{^head => changed} ->
        case assigns do
          %{^head => assigns} -> recur_changed_assign(tail, assigns, changed)
          %{} -> true
        end

      %{} ->
        false

      nil ->
        true
    end
  end

  defp recur_changed_assign([{:struct, head} | tail], assigns, changed) do
    recur_changed_assign(tail, head, assigns, changed)
  end

  defp recur_changed_assign([{:access, head}], %Form{} = form1, %Form{} = form2) do
    # Phoenix.HTML does not know about LiveView's _unused_ input tracking,
    # therefore we also need to check if the input's unused state changed
    Form.input_changed?(form1, form2, head) or
      Phoenix.Component.used_input?(form1[head]) !== Phoenix.Component.used_input?(form2[head])
  end

  defp recur_changed_assign([{:access, head} | tail], assigns, changed) do
    if match?(%_{}, assigns) or match?(%_{}, changed) do
      true
    else
      recur_changed_assign(tail, head, assigns, changed)
    end
  end

  defp recur_changed_assign([], head, assigns, changed) do
    case {assigns, changed} do
      {%{^head => value}, %{^head => value}} -> false
      {m1, m2} when not is_map_key(m1, head) and not is_map_key(m2, head) -> false
      {_, %{^head => value}} when is_map(value) -> value
      {_, _} -> true
    end
  end

  defp recur_changed_assign(tail, head, assigns, changed) do
    case {assigns, changed} do
      {%{^head => assigns_value}, %{^head => changed_value}} ->
        recur_changed_assign(tail, assigns_value, changed_value)

      {_, _} ->
        true
    end
  end
end
