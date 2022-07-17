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
        %{component: {submod, fun}} = call <- module.__components_calls__(),
        function_exported?(submod, :__components__, 0),
        component = submod.__components__()[fun],
        diagnostic <- diagnostics(module, call, component),
        do: diagnostic
  end

  defp diagnostics(caller_module, %{slots: slots, attrs: attrs, root: root} = call, %{
         slots: slots_defs,
         attrs: attrs_defs
       }) do
    {attrs_warnings, {attrs, has_global?}} =
      Enum.flat_map_reduce(attrs_defs, {attrs, false}, fn attr_def, {attrs, has_global?} ->
        %{name: name, required: required, type: type} = attr_def
        {value, attrs} = Map.pop(attrs, name)

        warnings =
          case {type, value} do
            # missing required attr
            {_type, nil} when not root and required ->
              message = "missing required attribute \"#{name}\" for component #{component(call)}"
              [error(message, call.file, call.line)]

            # missing optional attr, or dynamic attr
            {_type, nil} when root or not required ->
              []

            # global attrs cannot be directly used
            {:global, {line, _column, {_kind, _value}}} ->
              message =
                "global attribute \"#{name}\" in component #{component(call)} may not be provided directly"

              [error(message, call.file, line)]

            # expressions cannot be type checked
            {_type, {_line, _column, {:expr, _value}}} ->
              []

            # string attribute type mismatch
            {:string, {line, _column, {_kind, value}}} when not is_binary(value) ->
              message =
                "attribute \"#{name}\" in component #{component(call)} must be a :string, got: #{inspect(value)}"

              [error(message, call.file, line)]

            # atom attribute type mismatch
            {:atom, {line, _column, {kind, value}}} when kind != :lit or not is_atom(value) ->
              message =
                "attribute \"#{name}\" in component #{component(call)} must be an :atom, got: #{inspect(value)}"

              [error(message, call.file, line)]

            # boolean attribute type mismatch
            {:boolean, {line, _column, {_kind, value}}} when not is_boolean(value) ->
              message =
                "attribute \"#{name}\" in component #{component(call)} must be a :boolean, got: #{inspect(value)}"

              [error(message, call.file, line)]

            # integer attribute type mismatch
            {:integer, {line, _column, {_kind, value}}} when not is_integer(value) ->
              message =
                "attribute \"#{name}\" in component #{component(call)} must be an :integer, got: #{inspect(value)}"

              [error(message, call.file, line)]

            # float attribute type mismatch
            {:float, {line, _column, {_kind, value}}} when not is_float(value) ->
              message =
                "attribute \"#{name}\" in component #{component(call)} must be a :float, got: #{inspect(value)}"

              [error(message, call.file, line)]

            # list attribute type mismatch
            {:list, {line, _column, {_kind, value}}} when not is_list(value) ->
              message =
                "attribute \"#{name}\" in component #{component(call)} must be a :list, got: #{inspect(value)}"

              [error(message, call.file, line)]

            # struct attribute type mismatch
            {{:struct, mod}, {line, _column, {kind, value}}} when kind != :struct ->
              message =
                "attribute \"#{name}\" in component #{component(call)} must be a #{inspect(mod)}, got: #{inspect(value)}"

              [error(message, call.file, line)]

            # attribute type match
            {_type, {_line, _column, {_kind, _value}}} ->
              []
          end

        {warnings, {attrs, has_global? || type == :global}}
      end)

    attrs_missing =
      for {name, {line, _column, {_kind, _value}}} <- attrs,
          not (has_global? and Phoenix.Component.__global__?(caller_module, Atom.to_string(name))) do
        message = "undefined attribute \"#{name}\" for component #{component(call)}"
        error(message, call.file, line)
      end

    {slots_warnings, slots} =
      Enum.flat_map_reduce(slots_defs, slots, fn slot_def, slots ->
        %{name: slot_name, required: required} = slot_def
        slot_attr_defs = get_slot_attr_defs(attrs_defs, slot_name)
        {slot_values, slots} = Map.pop(slots, slot_name)

        warnings =
          case {slot_values, slot_attr_defs} do
            # missing required slot
            {nil, _slot_attr_defs} when required ->
              message = "missing required slot \"#{slot_name}\" for component #{component(call)}"
              [error(message, call.file, call.line)]

            # slot with attributes
            {slot_values, slot_attr_defs} ->
              for slot_value <- slot_values,
                  {attr_name, {line, _column, attr_kind, attr_value}} <- slot_value,
                  attr_name != :inner_block,
                  attr_def = Map.get(slot_attr_defs, attr_name, :undef),
                  reduce: [] do
                errors ->
                  case {attr_def, attr_kind, attr_value} do
                    # undefined attribute
                    {:undef, _attr_kind, _attr_value} ->
                      message =
                        "undefined attribute \"#{attr_name}\" in slot \"#{slot_name}\" for component #{component(call)}"

                      [error(message, call.file, line) | errors]

                    # expressions cannot be type checked
                    {%{type: _attr_type}, :expr, _attr_value} ->
                      errors

                    # string attribute type mismatch
                    {%{type: :string}, attr_kind, attr_value}
                    when attr_kind != :lit or not is_binary(attr_value) ->
                      message =
                        "attribute \"#{attr_name}\" in slot \"#{slot_name}\" for component #{component(call)} must be a :string, got: #{inspect(attr_value)}"

                      [error(message, call.file, line) | errors]

                    # atom attribute type mismatch
                    {%{type: :atom}, attr_kind, attr_value}
                    when attr_kind != :lit or not is_atom(attr_value) ->
                      message =
                        "attribute \"#{attr_name}\" in slot \"#{slot_name}\" for component #{component(call)} must be an :atom, got: #{inspect(attr_value)}"

                      [error(message, call.file, line) | errors]

                    # boolean attribute type mismatch
                    {%{type: :boolean}, attr_kind, attr_value}
                    when attr_kind != :lit or not is_boolean(attr_value) ->
                      message =
                        "attribute \"#{attr_name}\" in slot \"#{slot_name}\" for component #{component(call)} must be a :boolean, got: #{inspect(attr_value)}"

                      [error(message, call.file, line) | errors]

                    # integer attribute type mismatch
                    {%{type: :integer}, attr_kind, attr_value}
                    when attr_kind != :lit or not is_integer(attr_value) ->
                      message =
                        "attribute \"#{attr_name}\" in slot \"#{slot_name}\" for component #{component(call)} must be a :integer, got: #{inspect(attr_value)}"

                      [error(message, call.file, line) | errors]

                    # float attribute type mismatch
                    {%{type: :float}, attr_kind, attr_value}
                    when attr_kind != :lit or not is_float(attr_value) ->
                      message =
                        "attribute \"#{attr_name}\" in slot \"#{slot_name}\" for component #{component(call)} must be a :float, got: #{inspect(attr_value)}"

                      [error(message, call.file, line) | errors]

                    # list attribute type mismatch
                    {%{type: :list}, attr_kind, attr_value} when attr_kind != :list ->
                      message =
                        "attribute \"#{attr_name}\" in slot \"#{slot_name}\" for component #{component(call)} must be a :list, got: #{inspect(attr_value)}"

                      [error(message, call.file, line) | errors]

                    # struct attribute type mismatch
                    {%{type: {:struct, mod}}, attr_kind, attr_value} when attr_kind != :struct ->
                      message =
                        "attribute \"#{attr_name}\" in slot \"#{slot_name}\" for component #{component(call)} must be a #{inspect(mod)}, got: #{inspect(attr_value)}"

                      [error(message, call.file, line) | errors]

                    # type attribute type match
                    {_attr_type, _attr_kind, _attr_value} ->
                      errors
                  end
              end
          end

        {warnings, slots}
      end)

    slots_missing =
      for {slot_name, slot_values} <- slots,
          slot_name != :inner_block,
          %{inner_block: {line, _column, _attr_kind, _attr_value}} <- slot_values do
        message = "undefined slot \"#{slot_name}\" for component #{component(call)}"
        error(message, call.file, line)
      end

    slots_warnings ++ slots_missing ++ attrs_warnings ++ attrs_missing
  end

  defp get_slot_attr_defs(attr_defs, slot_name) do
    for attr_def <- attr_defs,
        attr_def.slot == slot_name,
        into: %{},
        do: {attr_def.name, attr_def}
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
