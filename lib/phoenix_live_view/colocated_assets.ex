defmodule Phoenix.LiveView.ColocatedAssets do
  @moduledoc false

  defstruct [:relative_path, :data]

  @type t() :: %__MODULE__{
          relative_path: String.t(),
          data: term()
        }

  defmodule Entry do
    @moduledoc false
    defstruct [:filename, :data, :callback, :component]
  end

  @callback build_manifests(colocated :: t()) :: list({binary(), binary()})
  @callback finalize(target_directory :: String.t()) :: :ok

  @optional_callbacks [finalize: 1]

  @doc """
  Extracts content into the colocated directory.

  Returns an opaque struct that is stored as macro component data
  for manifest generation.

  The flow is:

    1. MacroComponent transform callback is called.
    2. The transform callback invokes ColocatedAssets.extract/5,
       which writes the content to the target directory.
    3. LiveView compiler invokes ColocatedAssets.compile/0.
    4. ColocatedAssets builds a list of `%ColocatedAssets{}` structs
       grouped by callback module and invokes the callback's
       `build_manifests/1` function.

  """
  def extract(callback_module, module, filename, text, data) do
    # _build/dev/phoenix-colocated/otp_app/MyApp.MyComponent/filename
    target_path =
      target_dir()
      |> Path.join(inspect(module))

    File.mkdir_p!(target_path)
    File.write!(Path.join(target_path, filename), text)

    %Entry{filename: filename, data: data, callback: callback_module}
  end

  @doc false
  def compile do
    # this step runs after all modules have been compiled
    # so we can write the final manifests and remove outdated files
    clear_manifests!()
    callback_colocated_map = clear_outdated_and_get_files!()
    File.mkdir_p!(target_dir())

    warn_for_outdated_config!()

    Enum.each(configured_callbacks(), fn callback_module ->
      true = Code.ensure_loaded?(callback_module)

      files =
        case callback_colocated_map do
          %{^callback_module => files} ->
            files

          _ ->
            []
        end

      for {name, content} <- callback_module.build_manifests(files) do
        File.write!(Path.join(target_dir(), name), content)
      end
    end)

    maybe_link_node_modules!()
  end

  defp clear_manifests! do
    target_dir = target_dir()

    manifests =
      Path.wildcard(Path.join(target_dir, "*"))
      |> Enum.filter(&File.regular?(&1))

    for manifest <- manifests, do: File.rm!(manifest)
  end

  defp clear_outdated_and_get_files! do
    target_dir = target_dir()
    modules = subdirectories(target_dir)

    Enum.flat_map(modules, fn module_folder ->
      module = Module.concat([Path.basename(module_folder)])
      process_module(module_folder, module)
    end)
    |> Enum.group_by(fn {callback, _file} -> callback end, fn {_callback, file} -> file end)
    |> Map.new()
  end

  defp process_module(module_folder, module) do
    with true <- Code.ensure_loaded?(module),
         data when data != %{} <- Phoenix.Component.MacroComponent.get_data(module),
         colocated when colocated != [] <- filter_colocated(data) do
      expected_files = Enum.map(colocated, fn %{filename: filename} -> filename end)
      files = File.ls!(module_folder)

      outdated_files = files -- expected_files

      for file <- outdated_files do
        File.rm!(Path.join(module_folder, file))
      end

      Enum.map(colocated, fn %Entry{} = e ->
        absolute_path = Path.join(module_folder, e.filename)

        {e.callback,
         %__MODULE__{relative_path: Path.relative_to(absolute_path, target_dir()), data: e.data}}
      end)
    else
      _ ->
        # either the module does not exist any more or
        # does not have any colocated assets
        File.rm_rf!(module_folder)
        []
    end
  end

  defp filter_colocated(data) do
    for {macro_component, entries} <- data do
      Enum.flat_map(entries, fn data ->
        case data do
          %Entry{} = d -> [%{d | component: macro_component}]
          _ -> []
        end
      end)
    end
    |> List.flatten()
  end

  defp maybe_link_node_modules! do
    settings = project_settings()

    case Keyword.get(settings, :node_modules_path, {:fallback, "assets/node_modules"}) do
      {:fallback, rel_path} ->
        location = Path.absname(rel_path)
        do_symlink(location, true)

      path when is_binary(path) ->
        location = Path.absname(path)
        do_symlink(location, false)
    end
  end

  defp relative_to_target(location) do
    if function_exported?(Path, :relative_to, 3) do
      apply(Path, :relative_to, [location, target_dir(), [force: true]])
    else
      Path.relative_to(location, target_dir())
    end
  end

  defp do_symlink(node_modules_path, is_fallback) do
    relative_node_modules_path = relative_to_target(node_modules_path)

    with {:error, reason} when reason != :eexist <-
           File.ln_s(relative_node_modules_path, Path.join(target_dir(), "node_modules")),
         false <- Keyword.get(global_settings(), :disable_symlink_warning, false) do
      disable_hint = """
      If you don't use colocated hooks / js or you don't need to import files from "assets/node_modules"
      in your hooks, you can simply disable this warning by setting

          config :phoenix_live_view, :colocated_assets,
            disable_symlink_warning: true
      """

      IO.warn("""
      Failed to symlink node_modules folder for Phoenix.LiveView.ColocatedJS: #{inspect(reason)}

      On Windows, you can address this issue by starting your Windows terminal at least once
      with "Run as Administrator" and then running your Phoenix application.#{is_fallback && "\n\n" <> disable_hint}
      """)
    end
  end

  defp configured_callbacks do
    [
      # Hardcoded for now
      Phoenix.LiveView.ColocatedJS,
      Phoenix.LiveView.ColocatedCSS
    ]
  end

  defp global_settings do
    Application.get_env(
      :phoenix_live_view,
      :colocated_assets,
      Application.get_env(:phoenix_live_view, :colocated_js, [])
    )
  end

  defp project_settings do
    lv_config =
      Mix.Project.config()
      |> Keyword.get(:phoenix_live_view, [])

    Keyword.get_lazy(lv_config, :colocated_assets, fn ->
      Keyword.get(lv_config, :colocated_js, [])
    end)
  end

  defp target_dir do
    app = to_string(Mix.Project.config()[:app])
    default = Path.join(Mix.Project.build_path(), "phoenix-colocated")

    global_settings()
    |> Keyword.get(:target_directory, default)
    |> Path.join(app)
  end

  defp subdirectories(path) do
    Path.wildcard(Path.join(path, "*")) |> Enum.filter(&File.dir?(&1))
  end

  defp warn_for_outdated_config! do
    case Application.get_env(:phoenix_live_view, :colocated_js) do
      nil ->
        :ok

      _ ->
        IO.warn("""
        The :colocated_js configuration option is deprecated!

        Instead of

            config :phoenix_live_view, :colocated_js, ...

        use

            config :phoenix_live_view, :colocated_assets, ...

        instead.
        """)
    end

    lv_config =
      Mix.Project.config()
      |> Keyword.get(:phoenix_live_view, [])

    case Keyword.get(lv_config, :colocated_js) do
      nil ->
        :ok

      _ ->
        IO.warn("""
        The :colocated_js configuration option is deprecated!

        Instead of

            [
              ...,
              phoenix_live_view: [colocated_js: ...]
            ]

        use

            [
              ...,
              phoenix_live_view: [colocated_assets: ...]
            ]

        in your mix.exs instead.
        """)
    end
  end
end
