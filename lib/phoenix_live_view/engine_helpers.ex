defmodule Phoenix.LiveView.EngineHelpers do
  @moduledoc false

  defmacro keyed_comprehension(key, vars, do_block) do
    vars_changed_var = Macro.var(:vars_changed, Phoenix.LiveView.Engine)
    changed_var = Macro.var(:changed, Phoenix.LiveView.Engine)

    render =
      if Macro.Env.has_var?(__CALLER__, {:vars_changed, Phoenix.LiveView.Engine}) do
        quote do
          fn local_vars_changed, track_changes? ->
            unquote(vars_changed_var) =
              case local_vars_changed do
                %{} when track_changes? ->
                  Map.merge(unquote(vars_changed_var) || %{}, local_vars_changed)

                _ ->
                  nil
              end

            unquote(changed_var) = if track_changes?, do: unquote(changed_var)

            unquote(do_block)
          end
        end
      else
        quote do
          fn unquote(vars_changed_var), track_changes? ->
            unquote(vars_changed_var) = if track_changes?, do: unquote(vars_changed_var)
            unquote(changed_var) = if track_changes?, do: unquote(changed_var)

            unquote(do_block)
          end
        end
      end

    quote do
      {unquote(key), unquote(vars), unquote(render)}
    end
  end

  defmacro maybe_vars_changed?(track_changes?) do
    vars_changed_var = Macro.var(:vars_changed, Phoenix.LiveView.Engine)

    if Macro.Env.has_var?(__CALLER__, {:vars_changed, Phoenix.LiveView.Engine}) do
      quote do
        unquote(vars_changed_var) =
          if unquote(track_changes?) do
            unquote(vars_changed_var)
          end
      end
    else
      quote do
      end
    end
  end
end
