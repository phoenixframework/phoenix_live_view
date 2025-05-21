defmodule Mix.Tasks.Compile.PhoenixLiveView do
  @moduledoc """
  A LiveView compiler for HEEx macro component cleanup.

  You must add it to your `mix.exs` as:

      compilers: Mix.compilers() ++ [:phoenix_live_view]

  """
  use Mix.Task

  @recursive true
  @manifest ".compile_live_view"
  @manifest_version 2

  @switches [
    force: :boolean
  ]

  @doc false
  def run(args) do
    {compile_opts, _argv, _errors} = OptionParser.parse(args, switches: @switches)

    # TODO: we don't really need a manifest, we could just always prune?
    {version, manifest_content} = read_manifest()
    manifest_outdated? = version != @manifest_version or manifest_older?()

    cond do
      manifest_outdated? || compile_opts[:force] ->
        remove_outdated(manifest_content)

      true ->
        {:noop, []}
    end
  end

  defp remove_outdated(_manifest_content) do
    Application.get_env(:phoenix_live_view, :colocated_cleanup, [Phoenix.LiveView.ColocatedHook])
    |> Enum.each(fn module ->
      module.prune()
    end)

    write_manifest!(:ok)
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

  defp write_manifest!(contents) do
    File.write!(manifest(), :erlang.term_to_binary({@manifest_version, contents}))
  end

  defp manifest_older? do
    other_manifests = Mix.Tasks.Compile.Elixir.manifests()
    manifest_mtime = mtime(manifest())
    Enum.any?(other_manifests, fn m -> mtime(m) > manifest_mtime end)
  end

  @doc false
  def get_extracts(modules) do
    extracts =
      for module <- modules,
          Code.ensure_loaded?(module),
          function_exported?(module, :__phoenix_component_extracts__, 0),
          extracts <- module.__phoenix_component_extracts__(),
          do: extracts

    List.flatten(extracts)
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

  defp mtime(file) do
    %File.Stat{mtime: mtime} = File.stat!(file)
    mtime
  end
end
