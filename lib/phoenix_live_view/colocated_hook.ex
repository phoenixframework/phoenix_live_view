defmodule Phoenix.LiveView.ColocatedHook do
  use Phoenix.LiveView.MacroComponent

  @impl true
  def call({"script", attributes, [text_content]} = ast, meta) do
    opts = Map.new(attributes)

    case Map.get(opts, "bundle_mode", :bundle) do
      :runtime ->
        hashed_name = hashed_name(meta)

        new_content = """
        window["phx_hook_#{hashed_name}"] = function() {
          #{text_content}
        }
        """

        {:ok, [{"script", [{"data-phx-runtime-hook", hashed_name}], [new_content]}],
         %{hashed_name: hashed_name}}

      :current_otp_app ->
        if should_bundle?(opts["colocated-hooks-app"]) do
          process_bundled_hook(opts, text_content, meta)
        else
          {:ok, [], nil}
        end

      :bundle ->
        process_bundled_hook(opts, text_content, meta)
    end

    {:ok, [], nil}
  end

  def call(ast, _meta) do
    raise ArgumentError, "a ColocatedHook can only be used on script tags"
  end

  @impl true
  def prune do
    target_path = Path.join(Mix.Project.app_path(), inspect(__MODULE__))
    extract_regex = ~r/extract_(.*):(.*)/
    manifest_regex = ~r/manifest_.*/

    if File.exists?(target_path) do
      files = File.ls!(target_path)

      result =
        Enum.reduce(files, %{extracts: [], manifests: []}, fn file, acc ->
          extract_match = Regex.run(extract_regex, file)
          manifest_match = Regex.run(manifest_regex, file)

          case {extract_match, manifest_match} do
            {[file, module_name, hash], _} ->
              Map.update!(acc, :extracts, fn extracts ->
                [{module_name, hash, file} | extracts]
              end)

            {_, [manifest_name, _]} ->
              Map.update!(acc, :manifests, fn manifests ->
                [manifest_name | manifests]
              end)

            _ ->
              acc
          end
        end)

      new_extracts =
        for {module_name, _hash, _file} <- result.extracts, reduce: [] do
          acc ->
            module = Module.concat([module_name])

            if Code.ensure_loaded?(module) and
                 function_exported?(module, :__phoenix_component_extracts__, 0) do
              extracts = module.__phoenix_component_extracts__()
              acc ++ extracts
            else
              acc
            end
        end

      dbg(new_extracts)
      dbg(result.extracts)

      :ok
    else
      :ok
    end
  end

  defp hashed_name(meta) do
    hashed_script_name(meta.file) <> "_#{meta.line}_#{meta.column}"
  end

  defp hashed_script_name(file) do
    :md5 |> :crypto.hash(file) |> Base.encode16()
  end

  defp should_bundle?(app) do
    current_otp_app() == colocated_hooks_app(app)
  end

  defp colocated_hooks_app(nil) do
    Application.get_env(:phoenix_live_view, :colocated_hooks_app, current_otp_app())
  end

  defp colocated_hooks_app(app) do
    app
  end

  defp current_otp_app do
    Application.get_env(:logger, :compile_time_application)
  end

  defp process_bundled_hook(opts, text_content, meta) do
    %{file: file, line: line, column: column} = meta
    js_filename = hashed_name(meta)

    script_content =
      "// #{Path.relative_to_cwd(file)}:#{line}:#{column}\n" <> text_content

    manifest_path = manifest_path(opts)
    dir = Path.dirname(manifest_path)
    js_path = Path.join(dir, js_filename <> ".js")

    # colocated hooks are always written to the current otp_app's dir;
    # so when a dependency is compiled, the hooks will be placed in the deps folder;
    # but they are still included in the configured manifest, for example:
    #
    # /path/to/app/deps/my_dep/assets/js/hooks/HOOKHASH_X_Y.js
    # /path/to/app/assets/js/hooks/HOOKHASH_Y_Z.js
    #
    # the full path is either
    # ./HOOKHASH_Y_Z.js for a local hook
    # ../../../deps/my_dep/assets/js/hooks/HOOKHASH_X_Y.js for a hook from a dependency
    #
    # the manifest is always ./assets/js/hooks/index.js;
    # but it can be configured with:
    #
    #     config :phoenix_live_view, colocated_hooks_manifest: PATH

    relative =
      if function_exported?(Path, :relative_to, 3) do
        # force option is only available since Elixir 1.16;
        # in earlier versions, the path will be absolute, but that should be fine
        &apply(Path, :relative_to, [&1, &2, [force: true]])
      else
        &Path.relative_to(&1, &2)
      end

    js_full_path =
      case relative.(Path.expand(js_path), Path.dirname(manifest_path)) do
        <<".", _rest::binary>> = p -> p
        p -> "./#{p}"
      end

    File.mkdir_p!(dir)
    File.write!(js_path, script_content)

    if !File.exists?(manifest_path) do
      File.write!(manifest_path, empty_manifest())
    end

    manifest = File.read!(manifest_path)

    File.open(manifest_path, [:append], fn file ->
      if !String.contains?(manifest, js_filename) do
        IO.binwrite(
          file,
          ~s|\nimport hook_#{js_filename} from "#{js_full_path}"; hooks["#{js_filename}"] = hook_#{js_filename};|
        )
      end
    end)

    %{hashed_name: js_filename}
  end

  defp empty_manifest do
    """
    let hooks = {}
    export default hooks
    """
  end

  defp manifest_path(opts) do
    target_path = Path.join(Mix.Project.app_path(), inspect(__MODULE__))

    Path.join(
      target_path,
      "manifest_#{opts["manifest-name"] || "default"}.#{opts["manifest-extension"] || "js"}"
    )
  end
end
