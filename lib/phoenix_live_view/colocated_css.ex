defmodule Phoenix.LiveView.ColocatedCSS do
  @moduledoc ~S'''
  A special HEEx `:type` that extracts any CSS styles from a colocated
  `<style>` tag at compile time.

  Note: To use `ColocatedCSS`, you need to run Phoenix 1.8+.

  You can use `ColocatedCSS` to define any CSS styles directly in your components, for example:

  ```heex
  <style :type={Phoenix.LiveView.ColocatedCSS}">
    .sample-class {
        background-color: #FFFFFF;
    }
  </style>
  ```

  > #### A note on dependencies and umbrella projects {: .info}
  >
  > For each application that uses colocated CSS, a separate directory is created
  > inside the `phoenix-colocated` folder. This allows to have clear separation between
  > styles of dependencies, but also applications inside umbrella projects.

  ## Internals

  While compiling the template, colocated CSS is extracted into a special folder inside the
  `Mix.Project.build_path()`, called `phoenix-colocated-css`. This is customizable, as we'll see below,
  but it is important that it is a directory that is not tracked by version control, because the
  components are the source of truth for the code. Also, the directory is shared between applications
  (this also applies to applications in umbrella projects), so it should typically also be a shared
  directory not specific to a single application.

  The colocated CSS directory follows this structure:

  ```text
  _build/$MIX_ENV/phoenix-colocated-css/
  _build/$MIX_ENV/phoenix-colocated-css/my_app/
  _build/$MIX_ENV/phoenix-colocated-css/my_app/colocated.css
  _build/$MIX_ENV/phoenix-colocated-css/my_app/MyAppWeb.DemoLive/line_HASH.css
  _build/$MIX_ENV/phoenix-colocated-css/my_dependency/MyDependency.Module/line_HASH.css
  ...
  ```

  Each application has its own folder. Inside, each module also gets its own folder, which allows
  us to track and clean up outdated code.

  To use colocated CSS, your bundler needs to be configured to resolve the
  `phoenix-colocated-css` folder. For new Phoenix applications, this configuration is already included
  in the esbuild configuration inside `config.exs`:

      config :esbuild,
        ...
        my_app: [
          args:
            ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
          cd: Path.expand("../assets", __DIR__),
          env: %{
            "NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]
          }
        ]

  The important part here is the `NODE_PATH` environment variable, which tells esbuild to also look
  for packages inside the `deps` folder, as well as the `Mix.Project.build_path()`, which resolves to
  `_build/$MIX_ENV`. If you use a different bundler, you'll need to configure it accordingly. If it is not
  possible to configure the `NODE_PATH`, you can also change the folder to which LiveView writes colocated
  CSS by setting the `:target_directory` option in your `config.exs`:

  ```elixir
  config :phoenix_live_view, :colocated_css,
    target_directory: Path.expand("../assets/css/phoenix-colocated", __DIR__)
  ```

  To bundle and use colocated CSS with esbuild, you can import it like this in your `app.js` file:

  ```javascript
  import "phoenix-colocated-css/my_app/colocated.css"
  ```

  Importing CSS in your `app.js` file will cause esbuild to generate a separate `app.css` file.
  To load it, simply add a second `<link>` to your `root.html.heex` file, like so:

  ```html
  <link phx-track-static rel="stylesheet" href={~p"/assets/js/app.css"} />
  ```

  > #### Tip {: .info}
  >
  > If you remove or modify the contents of the `:target_directory` folder, you can use
  > `mix clean --all` and `mix compile` to regenerate all colocated CSS.

  > #### Warning! {: .warning}
  >
  > LiveView assumes full ownership over the configured `:target_directory`. When
  > compiling, it will **delete** any files and folders inside the `:target_directory`,
  > that it does not associate with a colocated CSS file.
  '''

  @behaviour Phoenix.Component.MacroComponent

  alias Phoenix.Component.MacroComponent

  @impl true
  def transform({"style", _attributes, [text_content], _tag_meta} = _ast, meta) do
    validate_phx_version!()

    data = extract(text_content, meta)

    # we always drop colocated CSS from the rendered output
    {:ok, "", data}
  end

  def transform(_ast, _meta) do
    raise ArgumentError, "ColocatedCSS can only be used on style tags"
  end

  defp validate_phx_version! do
    phoenix_version = to_string(Application.spec(:phoenix, :vsn))

    if not Version.match?(phoenix_version, "~> 1.8.0-rc.4") do
      # TODO: bump message to 1.8 once released to avoid confusion
      raise ArgumentError, ~s|ColocatedCSS requires at least {:phoenix, "~> 1.8.0-rc.4"}|
    end
  end

  @doc false
  def extract(text_content, meta) do
    # _build/dev/phoenix-colocated-css/otp_app/MyApp.MyComponent/line_no.css
    target_path =
      target_dir()
      |> Path.join(inspect(meta.env.module))

    hashed_name =
      text_content
      |> then(&:crypto.hash(:md5, &1))
      |> Base.encode32(case: :lower, padding: false)

    filename = "#{meta.env.line}_#{hashed_name}.css"

    File.mkdir_p!(target_path)
    File.write!(Path.join(target_path, filename), text_content)

    filename
  end

  @doc false
  def compile do
    # this step runs after all modules have been compiled
    # so we can write the final css manifest file and remove any
    # outdated colocated css files
    clear_manifest!()
    files = clear_outdated_and_get_files!()
    write_new_manifest!(files)
  end

  defp clear_manifest! do
    target_dir()
    |> Path.join("*")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?(&1))
    |> Enum.each(&File.rm!(&1))
  end

  defp clear_outdated_and_get_files! do
    target_dir = target_dir()
    modules = subdirectories(target_dir)

    Enum.flat_map(modules, fn module_folder ->
      module = Module.concat([Path.basename(module_folder)])
      process_module(module_folder, module)
    end)
  end

  defp process_module(module_folder, module) do
    with true <- Code.ensure_loaded?(module),
         data when data != [] <- MacroComponent.get_data(module, __MODULE__) do
      expected_files = data
      files = File.ls!(module_folder)

      outdated_files = files -- expected_files

      for file <- outdated_files do
        File.rm!(Path.join(module_folder, file))
      end

      Enum.map(data, fn filename ->
        absolute_file_path = Path.join(module_folder, filename)
        absolute_file_path
      end)
    else
      _ ->
        # either the module does not exist any more or
        # does not have any colocated CSS
        File.rm_rf!(module_folder)
        []
    end
  end

  defp write_new_manifest!(files) do
    target_dir = target_dir()
    manifest = Path.join(target_dir, "colocated.css")

    content =
      if files == [] do
        # Ensure that the directory exists to write
        # an empty manifest file in the case that no colocated css
        # files were generated (which would have already created
        # the directory)
        File.mkdir_p!(target_dir)

        ""
      else
        Enum.reduce(files, [], fn file, acc ->
          line = ~s[@import "./#{Path.relative_to(file, target_dir)}";\n]
          [acc | line]
        end)
      end

    File.write!(manifest, content)
  end

  defp target_dir do
    default = Path.join(Mix.Project.build_path(), "phoenix-colocated-css")
    app = to_string(Mix.Project.config()[:app])

    global_settings()
    |> Keyword.get(:target_directory, default)
    |> Path.join(app)
  end

  defp global_settings do
    Application.get_env(:phoenix_live_view, :colocated_css, [])
  end

  defp subdirectories(path) do
    Path.wildcard(Path.join(path, "*")) |> Enum.filter(&File.dir?(&1))
  end
end
