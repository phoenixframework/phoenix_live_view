defmodule Phoenix.Component.ChangeTrackBody do
  @moduledoc false

  # When a component opts in via `Phoenix.Component.change_track_body/0`, every
  # `assigns = <expr>` statement in its body is analyzed for the assigns it
  # depends on. The statement *always* executes, but when none of its
  # dependencies changed we restore the `__changed__` map from before the
  # statement, so the assigns it computed are not marked as changed and are
  # therefore not sent to the client.
  #
  # Because the expression always runs, every key it assigns is always present.
  # That is what makes this safe to apply to a body that was not written with
  # change tracking in mind: the only observable difference is a smaller diff.

  alias Phoenix.LiveView.Assigns

  @attribute :__change_track_body__
  @default_attribute :__change_track_body_default__
  @assigns_var Macro.var(:assigns, nil)

  # Inside such a statement `assigns` is threaded through `assign/2,3` and
  # control flow rather than read. Bare `assigns` normally strong-taints the
  # analysis, so we mark those positions with `no_taint` meta, which
  # `Phoenix.LiveView.Assigns` skips. Any other use of `assigns` still taints,
  # which is what keeps `assign(assigns, :x, compute(assigns))` from being
  # under-tracked.

  ## Opt-in

  def enable(caller, value) when is_boolean(value) do
    Module.put_attribute(caller.module, @attribute, value)
    :ok
  end

  def enable(caller, other) do
    raise ArgumentError,
          "change_track_body/1 expects a boolean literal, got: #{Macro.to_string(other)}" <>
            "\n  #{Exception.format_file_line(caller.file, caller.line)}"
  end

  # `use Phoenix.Component, change_track_body: true` sets the default for every
  # function component in the module. It has to be read while the `use` is being
  # expanded, because that is when the following `def`s are expanded too.
  def take_option(caller, opts) when is_list(opts) do
    case Keyword.pop(opts, :change_track_body) do
      {nil, opts} ->
        opts

      {value, opts} when is_boolean(value) ->
        Module.put_attribute(caller.module, @default_attribute, value)
        opts

      {other, _opts} ->
        raise ArgumentError,
              ":change_track_body expects a boolean literal, got: #{Macro.to_string(other)}" <>
                "\n  #{Exception.format_file_line(caller.file, caller.line)}"
    end
  end

  def take_option(_caller, opts), do: opts

  ## def/defp hook

  def maybe_rewrite(expr, body, caller) do
    case Module.get_attribute(caller.module, @attribute) do
      nil ->
        # no explicit marker, fall back to the module wide default
        if Module.get_attribute(caller.module, @default_attribute) do
          rewrite(expr, body, caller, :default)
        else
          body
        end

      enabled? ->
        Module.delete_attribute(caller.module, @attribute)
        if enabled?, do: rewrite(expr, body, caller, :explicit), else: body
    end
  end

  # An explicit `change_track_body true` is an assertion that this function is a
  # component, so a bad head is an error. The module wide default applies to
  # every definition in the module, so anything that is not a component, such as
  # `handle_event/3` or a plain helper, is simply left alone.
  defp rewrite(expr, body, caller, source) do
    cond do
      not component_head?(expr) ->
        if source == :explicit, do: raise_bad_head!(expr, caller)
        body

      not Keyword.has_key?(body, :do) ->
        body

      true ->
        Keyword.update!(body, :do, &rewrite_block(&1, caller))
    end
  end

  defp component_head?(expr) do
    match?({_name, _meta, [{:assigns, _, ctx}]} when is_atom(ctx), call(expr))
  end

  defp call({:when, _, [call, _guards]}), do: call
  defp call(call), do: call

  defp raise_bad_head!(expr, caller) do
    {name, _meta, args} = call(expr)

    raise ArgumentError, """
    change_track_body can only be used on a function component, that is, a \
    function taking a single argument named "assigns", got: #{name}/#{length(args || [])}
      #{Exception.format_file_line(caller.file, caller.line)}
    """
  end

  defp rewrite_block({:__block__, meta, stmts}, caller) do
    {:__block__, meta, Enum.flat_map(stmts, &rewrite_stmt(&1, caller))}
  end

  defp rewrite_block(stmt, caller) do
    case rewrite_stmt(stmt, caller) do
      [single] -> single
      many -> {:__block__, [], many}
    end
  end

  defp rewrite_stmt({:=, meta, [{:assigns, _, ctx} = var, rhs]}, caller) when is_atom(ctx) do
    track(var, meta, rhs, caller)
  end

  defp rewrite_stmt(other, _caller), do: [other]

  ## Statement rewriting

  defp track(var, meta, rhs, caller) do
    {ast, keys, _vars} =
      Assigns.analyze_and_return_tainted_keys(
        thread(rhs, caller),
        {:untainted, %{}},
        %{},
        caller,
        Assigns.opts(%{skip_module_attributes: true})
      )

    rhs = ast
    prev = Macro.unique_var(:prev_changed, __MODULE__)

    case dependencies(keys, prev) do
      # The expression uses something we cannot track, such as a variable.
      # Leave the statement alone: it keeps marking everything it assigns as
      # changed, exactly like it does today.
      :always ->
        warn_untracked(meta, caller)
        [{:=, meta, [var, rhs]}]

      # No dependencies at all, so the value can never change between renders.
      :never ->
        [
          capture(prev),
          {:=, meta, [var, rhs]},
          {:=, meta,
           [
             var,
             quote(generated: true) do
               if unquote(prev) do
                 %{unquote(@assigns_var) | __changed__: unquote(prev)}
               else
                 unquote(@assigns_var)
               end
             end
           ]}
        ]

      {:sometimes, check} ->
        changed = Macro.unique_var(:deps_changed?, __MODULE__)

        [
          capture(prev),
          # evaluated *before* the statement, while `assigns` still holds the
          # values the dependencies are relative to
          quote(do: unquote(changed) = unquote(check)),
          {:=, meta, [var, rhs]},
          {:=, meta, [var, restore(changed, prev)]}
        ]
    end
  end

  # A nil `__changed__` means change tracking is off, so every branch below
  # leaves the statement exactly as it was. Matching rather than fetching also
  # keeps the module wide default harmless on a single argument function that
  # is not a component after all and never carries a `__changed__` at all.
  defp capture(prev) do
    quote generated: true do
      unquote(prev) =
        case unquote(@assigns_var) do
          %{__changed__: changed} -> changed
          _ -> nil
        end
    end
  end

  defp restore(changed, prev) do
    quote generated: true do
      case unquote(changed) do
        true -> unquote(@assigns_var)
        false -> %{unquote(@assigns_var) | __changed__: unquote(prev)}
      end
    end
  end

  defp dependencies(:all, _prev), do: :always
  defp dependencies(keys, _prev) when keys == %{}, do: :never

  defp dependencies(keys, prev) do
    # `:vars_changed` keys can only come from `:let` variables inside a template,
    # so they never occur here, but bail out rather than mistrack them.
    if Enum.any?(keys, fn {{changed_var, _key}, _} -> changed_var != :changed end) do
      :always
    else
      checks =
        for {{:changed, key}, _} <- keys,
            not Assigns.nested_and_parent_is_checked?(:changed, key, keys) do
          case key do
            [assign] ->
              quote do
                Phoenix.LiveView.Assigns.changed_assign?(unquote(prev), unquote(assign))
              end

            [assign | tail] ->
              quote do
                Phoenix.LiveView.Assigns.nested_changed_assign?(
                  unquote(tail),
                  unquote(assign),
                  unquote(@assigns_var),
                  unquote(prev)
                )
              end
          end
        end

      {:sometimes, Enum.reduce(checks, &{:or, [], [&1, &2]})}
    end
  end

  defp warn_untracked(meta, caller) do
    IO.warn(
      """
      this assigns expression cannot be change tracked, so everything it assigns \
      will be sent to the client on every render.

      This usually happens because the expression reads a variable, or passes \
      "assigns" to a function other than assign/2,3. Only assigns accessed as \
      assigns.name can be tracked.\
      """,
      Macro.Env.stacktrace(%{caller | line: meta[:line] || caller.line})
    )
  end

  ## Threading

  # Rewrites the positions where `assigns` flows through the expression untouched.
  # Everything else is left for the analyzer, which taints on any other bare use.

  defp thread({:assigns, meta, ctx}, _caller) when is_atom(ctx) do
    {:assigns, [no_taint: true] ++ meta, ctx}
  end

  defp thread({:__block__, meta, []}, _caller), do: {:__block__, meta, []}

  defp thread({:__block__, meta, stmts}, caller) do
    {init, [last]} = Enum.split(stmts, -1)
    {:__block__, meta, init ++ [thread(last, caller)]}
  end

  defp thread({:cond, meta, [[do: clauses]]}, caller) do
    {:cond, meta, [[do: Enum.map(clauses, &thread_clause(&1, caller))]]}
  end

  defp thread({:case, meta, [subject, [do: clauses]]}, caller) do
    {:case, meta, [subject, [do: Enum.map(clauses, &thread_clause(&1, caller))]]}
  end

  defp thread({op, meta, [condition, branches]}, caller)
       when op in [:if, :unless] and is_list(branches) do
    branches = Enum.map(branches, fn {key, body} -> {key, thread(body, caller)} end)
    {op, meta, [condition, branches]}
  end

  # in a pipe the piped argument is not in the AST, so the call is one arity short
  defp thread({:|>, meta, [left, right]}, caller) do
    if assign_call?(right, caller, 1) do
      {:|>, meta, [thread(left, caller), right]}
    else
      {:|>, meta, [left, right]}
    end
  end

  defp thread({fun, meta, [head | rest]} = expr, caller) do
    if assign_call?(expr, caller, 0) do
      {fun, meta, [thread(head, caller) | rest]}
    else
      expr
    end
  end

  defp thread(other, _caller), do: other

  defp thread_clause({:->, meta, [head, body]}, caller),
    do: {:->, meta, [head, thread(body, caller)]}

  defp thread_clause(other, _caller), do: other

  # Only `Phoenix.Component.assign/2,3` and `assign_new/3` merely thread assigns
  # through.
  defp assign_call?({{:., _, [alias_or_mod, fun]}, _, args}, caller, _extra)
       when fun in [:assign, :assign_new] and is_list(args) do
    Macro.expand(alias_or_mod, caller) == Phoenix.Component
  end

  defp assign_call?({fun, _, args}, caller, extra)
       when fun in [:assign, :assign_new] and is_list(args) and is_atom(fun) do
    imported_from_component?(caller, fun, length(args) + extra)
  end

  defp assign_call?(_expr, _caller, _extra), do: false

  defp imported_from_component?(caller, fun, arity) do
    Enum.any?(Macro.Env.lookup_import(caller, {fun, arity}), fn
      {_kind, Phoenix.Component} -> true
      {_kind, _module} -> false
    end)
  end
end
