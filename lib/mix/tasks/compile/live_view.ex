defmodule Mix.Tasks.Compile.LiveView do
  use Mix.Task
  @recursive true

  alias Mix.Task.Compiler.Diagnostic

  @doc false
  def run(args) do
    {compile_opts, _argv, _errors} = OptionParser.parse(args, strict: [return_errors: :boolean])

    diagnostics = validate_components_calls(project_modules())

    if !compile_opts[:return_errors] do
      print_diagnostics(diagnostics)
    end

    {:ok, diagnostics}
  end

  @doc false
  def validate_components_calls(modules) do
    for module <- modules,
        Code.ensure_loaded?(module),
        function_exported?(module, :__components_calls__, 0),
        call <- module.__components_calls__() do
      [validate_required_attrs(call), validate_undefined_attrs(call)]
    end
    |> List.flatten()
  end

  defp validate_required_attrs(call) do
    %{component: {module, fun}, attrs: call_attrs, file: file, line: line} = call
    attrs_defs = module.__components__()[fun] || []
    passed_attrs = Enum.map(call_attrs, &elem(&1, 0))

    for %{name: name, opts: opts} <- attrs_defs, opts[:required], "#{name}" not in passed_attrs do
      message = "missing required attribute `#{name}` for component `#{inspect(module)}.#{fun}/1`"
      error(message, file, line)
    end
  end

  defp validate_undefined_attrs(call) do
    %{component: {module, fun}, attrs: call_attrs, file: file} = call
    attrs_defs = module.__components__()[fun] || []
    defined_attrs = Enum.map(attrs_defs, fn %{name: name} -> "#{name}" end)

    for {name, _value, %{line: line}} <- call_attrs, name not in defined_attrs do
      message = "undefined attribute `#{name}` for component `#{inspect(module)}.#{fun}/1`"
      error(message, file, line)
    end
  end

  defp project_modules do
    files =
      Mix.Project.config()[:app]
      |> Application.app_dir()
      |> Path.join("ebin")
      |> File.ls!
      |> Enum.sort()

    for file <- files, {basename, ".beam"} <- [String.split_at(file, -5)] do
      String.to_atom(basename)
    end
  end

  defp print_diagnostics(diagnostics) do
    for %Diagnostic{file: file, position: line, message: message} <- diagnostics do
      IO.puts(:stderr, "** (CompileError) #{Path.relative_to_cwd(file)}:#{line}: #{message}")
    end
  end

  defp error(message, file, line) do
    %Diagnostic{
      compiler_name: "live_view",
      file: file,
      message: message,
      position: line,
      severity: :error
    }
  end
end
