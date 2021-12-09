defmodule Mix.Tasks.Compile.LiveView do
  use Mix.Task
  @recursive true

  alias Mix.Task.Compiler.Diagnostic

  @doc false
  def run(args) do
    {compile_opts, _argv, _errors} = OptionParser.parse(args, switches: [return_errors: :boolean])

    case validate_components_calls(project_modules()) do
      [] ->
        {:noop, []}

      diagnostics ->
        if !compile_opts[:return_errors], do: print_diagnostics(diagnostics)
        {:error, diagnostics}
    end
  end

  @doc false
  def validate_components_calls(modules) do
    for module <- modules,
        Code.ensure_loaded?(module),
        function_exported?(module, :__components_calls__, 0),
        %{component: {mod, fun}, attrs: attrs, file: file, line: line} <- module.__components_calls__(),
        attrs_defs = callee_attrs_defs(mod, fun) do
      {dyn_attrs, static_attrs} = Enum.split_with(attrs, &match?({:root, _, _}, &1))
      meta = %{file: file, line: line, callee: "#{inspect(mod)}.#{fun}/1"}

      [
        maybe_validate_required_attrs(static_attrs, dyn_attrs, attrs_defs, meta),
        validate_undefined_attrs(static_attrs, attrs_defs, meta)
      ]
    end
    |> List.flatten()
  end

  defp maybe_validate_required_attrs(static_attrs, _dyn_attrs = [], attrs_defs, meta) do
    validate_required_attrs(static_attrs, attrs_defs, meta)
  end

  defp maybe_validate_required_attrs(_, _, _, _) do
    []
  end

  defp validate_required_attrs(static_attrs, attrs_defs, meta) do
    %{callee: callee, file: file, line: line} = meta
    passed_attrs = Enum.map(static_attrs, &elem(&1, 0))

    for %{name: name, opts: opts} <- attrs_defs, opts[:required], "#{name}" not in passed_attrs do
      message = "missing required attribute `#{name}` for component `#{callee}`"
      error(message, file, line)
    end
  end

  defp validate_undefined_attrs(static_attrs, attrs_defs, meta) do
    %{callee: callee, file: file} = meta
    defined_attrs = Enum.map(attrs_defs, fn %{name: name} -> "#{name}" end)

    for {name, _value, %{line: line}} <- static_attrs, name not in defined_attrs do
      message = "undefined attribute `#{name}` for component `#{callee}`"
      error(message, file, line)
    end
  end

  defp callee_attrs_defs(module, fun) do
    module.__components__()[fun]
  end

  defp project_modules do
    files =
      Mix.Project.compile_path()
      |> File.ls!
      |> Enum.sort()

    for file <- files, [basename, ""] <- [:binary.split(file, ".beam")] do
      String.to_atom(basename)
    end
  end

  defp print_diagnostics(diagnostics) do
    for %Diagnostic{file: file, position: line, message: message} <- diagnostics do
      IO.puts(:stderr, "** (CompileError) #{Path.relative_to_cwd(file)}:#{line}: #{message}")
    end
  end

  defp error(message, file, line) do
    # TODO: Provide column information in diagnostic once we depend on Elixir v1.13+
    %Diagnostic{
      compiler_name: "live_view",
      file: file,
      message: message,
      position: line,
      severity: :error
    }
  end
end
