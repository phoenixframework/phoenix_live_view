defmodule Mix.Tasks.Compile.LiveView do
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

  defp manifest, do: Path.join(Mix.Project.manifest_path, @manifest)

  defp read_manifest do
    case File.read(manifest()) do
      {:ok, contents} -> :erlang.binary_to_term(contents)
      _ -> {:unknown, nil}
    end
  end

  defp write_manifest!(diagnostics) do
    File.write!(manifest(), :erlang.term_to_binary({@manifest_version, diagnostics}))
  end

  defp manifest_older?(version) do
    other_manifests = Mix.Tasks.Compile.Elixir.manifests()
    manifest_mtime = mtime(manifest())
    Enum.any?(other_manifests, fn m -> mtime(m) > manifest_mtime end)
  end

  @doc false
  def validate_components_calls(modules) do
    for module <- modules,
        Code.ensure_loaded?(module),
        function_exported?(module, :__components_calls__, 0),
        %{component: {mod, fun}, attrs: attrs, file: file, line: line} <- module.__components_calls__(),
        attrs_defs = mod.__components__()[fun] do
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

    for %{name: name, opts: opts} <- attrs_defs,
        opts[:required],
        Atom.to_string(name) not in passed_attrs do
      message = "missing required attribute `#{name}` for component `#{callee}`"
      error(message, file, line)
    end
  end

  defp validate_undefined_attrs(static_attrs, attrs_defs, meta) do
    %{callee: callee, file: file} = meta
    defined_attrs = Enum.map(attrs_defs, fn %{name: name} -> Atom.to_string(name) end)

    for {name, _value, %{line: line}} <- static_attrs, name not in defined_attrs do
      message = "undefined attribute `#{name}` for component `#{callee}`"
      error(message, file, line)
    end
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
      rel_file = file |> Path.relative_to_cwd() |> to_charlist()
      # Use IO.warn(message, file: ..., line: ...) on Elixir v1.14+ 
      IO.warn(message, [{nil, :__FILE__, 1, [file: rel_file, line: line]}])
    end
  end

  defp error(message, file, line) do
    # TODO: Provide column information in diagnostic once we depend on Elixir v1.13+
    %Diagnostic{
      compiler_name: "live_view",
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
