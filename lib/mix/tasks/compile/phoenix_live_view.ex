defmodule Mix.Tasks.Compile.PhoenixLiveView do
  @moduledoc """
  A LiveView compiler for component validation.

  You must add it to your `mix.exs` as:

      compilers: Mix.compilers() ++ [:phoenix_live_view]

  """
  use Mix.Task

  alias Mix.Task.Compiler.Diagnostic

  @recursive true
  @manifest ".compile_live_view"
  @manifest_version 1

  @switches [
    return_errors: :boolean,
    warnings_as_errors: :boolean,
    all_warnings: :boolean,
    force: :boolean
  ]

  @doc false
  def run(args) do
    {compile_opts, _argv, _errors} = OptionParser.parse(args, switches: @switches)

    {version, diagnostics} = read_manifest()
    manifest_outdated? = version != @manifest_version or manifest_older?()

    cond do
      manifest_outdated? || compile_opts[:force] ->
        run_diagnostics(compile_opts)

      compile_opts[:all_warnings] ->
        handle_diagnostics(diagnostics, compile_opts, :noop)

      true ->
        {:noop, []}
    end
  end

  defp run_diagnostics(compile_opts) do
    case validate_components_calls(project_modules()) do
      [] ->
        {:noop, []}

      diagnostics ->
        write_manifest!(diagnostics)
        handle_diagnostics(diagnostics, compile_opts, :ok)
    end
  end

  defp handle_diagnostics(diagnostics, compile_opts, status) do
    if !compile_opts[:return_errors], do: print_diagnostics(diagnostics)
    status = status(compile_opts[:warnings_as_errors], diagnostics, status)
    {status, diagnostics}
  end

  @doc false
  def manifests, do: [manifest()]

  defp manifest, do: Path.join(Mix.Project.manifest_path(), @manifest)

  defp read_manifest do
    case File.read(manifest()) do
      {:ok, contents} -> :erlang.binary_to_term(contents)
      _ -> {:unknown, nil}
    end
  end

  defp write_manifest!(diagnostics) do
    File.write!(manifest(), :erlang.term_to_binary({@manifest_version, diagnostics}))
  end

  defp manifest_older? do
    other_manifests = Mix.Tasks.Compile.Elixir.manifests()
    manifest_mtime = mtime(manifest())
    Enum.any?(other_manifests, fn m -> mtime(m) > manifest_mtime end)
  end

  @doc false
  def validate_components_calls(modules) do
    for module <- modules,
        Code.ensure_loaded?(module),
        function_exported?(module, :__components_calls__, 0),
        %{component: {mod, fun}} = call <- module.__components_calls__(),
        function_exported?(mod, :__components__, 0),
        component = mod.__components__()[fun],
        diagnostic <- diagnostics(call, component),
        do: diagnostic
  end

  defp diagnostics(%{attrs: attrs, root: root} = call, %{attrs: attrs_defs}) do
    {warnings, attrs} =
      Enum.flat_map_reduce(attrs_defs, attrs, fn attr_def, attrs ->
        %{name: name, required: required, type: type} = attr_def
        {value, attrs} = Map.pop(attrs, name)

        warnings =
          case value do
            nil when not root and required ->
              message = "missing required attribute \"#{name}\" for component #{component(call)}"
              [error(message, call.file, call.line)]

            {line, _column, string} when is_binary(string) and type not in [:any, :string] ->
              message =
                "attribute \"#{name}\" in component #{component(call)} must be a #{inspect(type)}, " <>
                  "got string: #{inspect(string)}"

              [error(message, call.file, line)]

            {line, _column, nil} when type not in [:any, :boolean] ->
              message =
                "attribute \"#{name}\" in component #{component(call)} must be a #{inspect(type)}, " <>
                  "got boolean: true"

              [error(message, call.file, line)]

            _ ->
              []
          end

        {warnings, attrs}
      end)

    missing =
      for {name, {line, _column, _value}} <- attrs do
        message = "undefined attribute \"#{name}\" for component #{component(call)}"
        error(message, call.file, line)
      end

    warnings ++ missing
  end

  defp component(%{component: {mod, fun}}) do
    "#{inspect(mod)}.#{fun}/1"
  end

  defp project_modules do
    files =
      Mix.Project.compile_path()
      |> File.ls!()
      |> Enum.sort()

    for file <- files, [basename, ""] <- [:binary.split(file, ".beam")] do
      String.to_atom(basename)
    end
  end

  defp print_diagnostics(diagnostics) do
    for %Diagnostic{file: file, position: line, message: message} <- diagnostics do
      rel_file = file |> Path.relative_to_cwd() |> to_charlist()
      # Use IO.warn(message, file: ..., line: ...) on Elixir v1.14+
      IO.warn(message, [{nil, :__FILE__, 1, [file: rel_file, line: line]}])
    end
  end

  defp error(message, file, line) do
    # TODO: Provide column information in diagnostic once we depend on Elixir v1.13+
    %Diagnostic{
      compiler_name: "phoenix_live_view",
      file: file,
      message: message,
      position: line,
      severity: :warning
    }
  end

  defp mtime(file) do
    %File.Stat{mtime: mtime} = File.stat!(file)
    mtime
  end

  defp status(warnings_as_errors, diagnostics, default) do
    cond do
      Enum.any?(diagnostics, &(&1.severity == :error)) -> :error
      warnings_as_errors && Enum.any?(diagnostics, &(&1.severity == :warning)) -> :error
      true -> default
    end
  end
end
