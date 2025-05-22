defmodule Phoenix.LiveView.ColocatedJS do
  @behaviour Phoenix.LiveView.MacroComponent

  @impl true
  def transform({"script", attributes, [text_content]} = _ast, meta) do
    opts = Map.new(attributes)
    extract(opts, text_content, meta)

    # we always drop colocated JS from the rendered output
    ""
  end

  def transform(_ast, _meta) do
    raise ArgumentError, "ColocatedJS can only be used on script tags"
  end

  @doc false
  def extract(opts, text_content, meta) do
    Macro.Env.required?(meta.env, Phoenix.Component) ||
      raise "ColocatedHook / ColocatedJS only works in modules that `use Phoenix.Component`"

    if not File.exists?(meta.env.file) do
      raise "ColocatedHook / ColocatedJS only works in stored files"
    end

    module_hash = :crypto.hash(:md5, meta.env.file) |> Base.encode16(case: :lower)
    # _build/dev/phoenix-colocated/HASH_MyApp.MyComponent/hooks/name.ext
    # _build/dev/phoenix-colocated/HASH_MyApp.MyComponent/MyWebComponent.js
    # _build/dev/
    target_path =
      Mix.Project.build_path()
      |> Path.join("phoenix-colocated")
      |> Path.join("#{module_hash}_#{inspect(meta.env.module)}")
      |> maybe_join_key(opts)

    filename = opts["name"] <> "." <> Map.get(opts, "extension", "js")

    File.mkdir_p!(target_path)
    File.write!(Path.join(target_path, filename), text_content)
  end

  defp maybe_join_key(path, opts) do
    case opts do
      %{"key" => key} ->
        Path.join(path, key)

      _ ->
        path
    end
  end

  @doc false
  def compile do
    # this step runs after all modules have been compiled
    # so we can write the final manifests and remove outdated hooks
    target_path = Mix.Project.build_path() |> Path.join("phoenix-colocated")
    module_hashes = get_modules_and_hashes(target_path)

    for {module, hash, folder} <- module_hashes do
      if Code.ensure_loaded?(module) and
           function_exported?(module, :__phoenix_component_hash__, 0) and
           module.__phoenix_component_hash__() == hash do
        :ok
      else
        IO.puts("Removing #{Path.join(target_path, folder)}")
        # the module does not exist any more or the hash does not match
        File.rm_rf!(Path.join(target_path, folder))
      end
    end

    files =
      Path.wildcard(Path.join(target_path, "*/**"))
      |> Enum.filter(&File.regular?(&1))

    dbg(files)

    manifest =
      Enum.group_by(files, fn file ->
        name = String.trim_leading(file, target_path <> "/")

        case String.split(name, "/") do
          [_module_hash, key, _name] ->
            key

          _ ->
            :default
        end
      end)
      |> Enum.reduce([empty_manifest()], fn group, acc ->
        case group do
          {:default, entries} ->
            [
              acc,
              Enum.map(entries, fn file ->
                name = file |> Path.basename() |> Path.rootname()
                import_name = "js_" <> Base.encode16(name, case: :lower)
                escaped_name = Phoenix.HTML.javascript_escape(name)

                ~s<\nimport #{import_name} from "./#{Path.relative_to(file, target_path)}"; js["#{escaped_name}"] = #{import_name};>
              end)
            ]

          {key, entries} ->
            escaped_key = Phoenix.HTML.javascript_escape(key)

            [
              acc,
              ~s<js["#{escaped_key}"] = {};>,
              Enum.map(entries, fn file ->
                name = file |> Path.basename() |> Path.rootname()
                import_name = "js_" <> Base.encode16(name, case: :lower)
                escaped_name = Phoenix.HTML.javascript_escape(name)

                ~s<\nimport #{import_name} from "./#{Path.relative_to(file, target_path)}"; js["#{escaped_key}"]["#{escaped_name}"] = #{import_name};>
              end)
            ]
        end
      end)

    File.write!(Path.join(target_path, "index.js"), manifest)

    File.write!(
      Path.join(target_path, "package.json"),
      Phoenix.json_library().encode_to_iodata!(%{
        name: "phoenix-colocated",
        # the version does not matter, we just use the one from LiveView
        version: to_string(Application.spec(:phoenix_live_view, :vsn)),
        main: "index.js"
      })
    )
  end

  defp get_modules_and_hashes(path) do
    folders =
      case File.ls(path) do
        {:ok, content} -> content
        {:error, _} -> []
      end
      |> Enum.filter(&File.dir?(&1))

    Enum.flat_map(folders, fn name ->
      case String.split(name, "_", parts: 2) do
        [hash, module] ->
          [{Module.concat([module]), hash, name}]

        _other ->
          IO.warn("Invalid colocated JS folder name: #{Path.join(path, name)}")
          []
      end
    end)
  end

  defp empty_manifest do
    """
    const js = {}
    export default js
    """
  end
end
