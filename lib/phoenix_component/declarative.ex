defmodule Phoenix.Component.Declarative do
  @doc false
  defmacro def(expr, body) do
    quote do
      Kernel.def(unquote(annotate_def(:def, expr)), unquote(body))
    end
  end

  @doc false
  defmacro defp(expr, body) do
    quote do
      Kernel.defp(unquote(annotate_def(:defp, expr)), unquote(body))
    end
  end

  defp annotate_def(kind, expr) do
    case expr do
      {:when, meta, [left, right]} -> {:when, meta, [annotate_call(kind, left), right]}
      left -> annotate_call(kind, left)
    end
  end

  defp annotate_call(_kind, {name, meta, [{:\\, _, _} = arg]}), do: {name, meta, [arg]}

  defp annotate_call(kind, {name, meta, [arg]}),
    do: {name, meta, [quote(do: Phoenix.Component.__pattern__!(unquote(kind), unquote(arg)))]}

  defp annotate_call(_kind, left),
    do: left
end
