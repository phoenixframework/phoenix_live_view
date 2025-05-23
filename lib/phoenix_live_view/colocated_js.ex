defmodule Phoenix.LiveView.ColocatedJS do
  @moduledoc """
  A `Phoenix.Component.MacroComponent` that extracts any JavaScript code from a co-located
  `<script>` tag at compile time.

  Colocated JavaScript is a more generalized version of `Phoenix.LiveView.ColocatedHook`.
  In fact, colocated hooks are built on top of `ColocatedJS`.

  You can use `ColocatedJS` to define things like Web Components or global event listeners
  that do not necessarily need the functionalities of hooks, for example:

  ```heex
  <script :type={Phoenix.LiveView.ColocatedJS} name="MyWebComponent">
    export default class MyWebComponent extends HTMLElement {
      connectedCallback() {
        this.innerHTML = "Hello, world!";
      }
    }
  </script>
  ```

  Then, in your `app.js` file, you could import it like this:

  ```javascript
  import colocated from "phoenix-colocated/my_app";
  customElements.define("my-web-component", colocated.MyWebComponent);
  ```

  In this example, you don't actually need to have special code for the web component
  inside your `app.js` file, since you could also directly call `customElements.define`
  inside the colocated JavaScript. However, this example shows how you can access the
  exported values inside your bundle.

  > #### A note on dependencies and umbrella projects {: .info}
  >
  > For each application that uses colocated JavaScript, a separate directory is created
  > inside the `phoenix-colocated` folder. This allows to have clear separation between
  > hooks and code of dependencies, but also applications inside umbrella projects.
  >
  > While dependencies would typically still bundle their own hooks and colocated JavaScript
  > into a separate file before publishing, simple hooks or code snippets that do not require
  > access to third-party libraries can also be directly imported into your own bundle.
  > If a library requires this, it should be stated in its documentation.

  ## Internals

  While compiling the template, colocated JavaScript is extracted into a special folder inside the
  `Mix.Project.build_path()`, called `phoenix-colocated`. This is customizable, as we'll see below,
  but it is important that it is a directory that is not tracked by version control, because the
  components are the source of truth for the code. Also, the directory is shared between applications
  (this also applies to applications in umbrella projects), so it should typically also be a shared
  directory not specific to a single application.

  The colocated JS directory follows this structure:

  ```text
  _build/$MIX_ENV/phoenix-colocated/
  _build/$MIX_ENV/phoenix-colocated/my_app/
  _build/$MIX_ENV/phoenix-colocated/my_app/index.js
  _build/$MIX_ENV/phoenix-colocated/my_app/HASH_MyAppWeb.DemoLive/file.js
  _build/$MIX_ENV/phoenix-colocated/my_dependency/HASH_MyDependency.Module/file.js
  ...
  ```

  Each application has its own folder. Inside, each module also gets its own folder, which allows
  us to track and clean up outdated code.

  To use colocated JS from your `app.js`, your bundler needs to be configured to resolve the
  `phoenix-colocated` folder. For new Phoenix applications, this configuration is already included
  in the esbuild configuration inside `config.exs`:

      config :esbuild,
        ...
        my_app: [
          args:
            ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
          cd: Path.expand("../assets", __DIR__),
          env: %{
            "NODE_PATH" => Enum.join([Path.expand("../deps", __DIR__), Mix.Project.build_path()], ":")
          }
        ]

  The important part here is the `NODE_PATH` environment variable, which tells esbuild to also look
  for packages inside the `deps` folder, as well as the `Mix.Project.build_path()`, which resolves to
  `_build/$MIX_ENV`. If you use a different bundler, you'll need to configure it accordingly. If it is not
  possible to configure the `NODE_PATH`, you can also change the folder to which LiveView writes colocated
  JavaScript by setting the `:target_directory` option in your project's `config.exs`:

  ```elixir
  config :phoenix_live_view, Phoenix.LiveView.ColocatedJS,
    target_directory: Path.expand("../assets/node_modules/phoenix-colocated", __DIR__)
  ```

  In this example, all colocated JavaScript would be written into the `assets/node_modules/phoenix-colocated`
  folder.

  ### Imports in colocated JS

  The colocated JS files are fully handled by your bundler. For Phoenix apps, this is typically
  `esbuild`. Because colocated JS is extracted to a folder outside the regular `assets` folder,
  special care is necessary when you need to import other files inside the colocated JS:

  ```javascript
  import { someFunction } from "some-dependency";
  import somethingElse from "@/vendor/vendored-file";
  ```

  While dependencies from `node_modules` should work out of the box, you cannot simply refer to your
  `assets/vendor` folder using a relative path. Instead, your bundler needs to be configured to handle
  an alias like `@` to resolve to your local `assets` folder. This is configured by default in the
  esbuild configuration for new Phoenix applications using `esbuild`'s [alias option](https://esbuild.github.io/api/#alias).

  ## Options

  Colocated JavaScript can be configured through the attributes of the `<script>` tag.
  The supported attributes are:

    * `name` - The name under which the default export of the script is available when importing
      the manifest. This is required, even if you don't plan to access the exported values or the
      script does not actually export anything.

    * `key` - A key under which to namespace the export. This is used by `Phoenix.LiveView.ColocatedHook` to
      nest all hooks under the `hooks` key. For example, you could set this to `web_components` for each colocated
      script that defines a web component and then access all of them as `colocated.web_components` when importing
      the manifest.

    * `extension` - a custom extension to use when writing the extracted file. The default is `js`.

    * `manifest` - a custom manifest file to use instead of the default `index.js`. For example,
      `web_components.ts`.

  """

  @behaviour Phoenix.Component.MacroComponent

  @impl true
  def transform({"script", attributes, [text_content]} = _ast, meta) do
    opts = Map.new(attributes)
    validate_name!(opts)
    data = extract(opts, text_content, meta)

    # we always drop colocated JS from the rendered output
    {:ok, "", data}
  end

  def transform(_ast, _meta) do
    raise ArgumentError, "ColocatedJS can only be used on script tags"
  end

  defp validate_name!(opts) do
    case opts do
      %{"name" => name} when is_binary(name) ->
        :ok

      %{"name" => name} ->
        raise ArgumentError,
              "the name attribute of a colocated JS / hook must be a compile-time string. Got: #{inspect(name)}"

      _ ->
        raise ArgumentError, "missing required name attribute for ColocatedJS"
    end
  end

  @doc false
  def extract(opts, text_content, meta) do
    if not File.exists?(meta.env.file) do
      raise "ColocatedHook / ColocatedJS only works in stored files"
    end

    # _build/dev/phoenix-colocated/otp_app/MyApp.MyComponent/hooks/name.ext
    # _build/dev/phoenix-colocated/otp_app/MyApp.MyComponent/MyWebComponent.js
    # _build/dev/
    target_path =
      target_dir()
      |> Path.join(to_string(current_otp_app()))
      |> Path.join(inspect(meta.env.module))

    filename_opts =
      %{name: opts["name"]}
      |> maybe_put_opt(opts, "key", :key)
      |> maybe_put_opt(opts, "manifest", :manifest)

    filename = "#{meta.line}.#{opts["extension"] || "js"}"

    File.mkdir_p!(target_path)
    File.write!(Path.join(target_path, filename), text_content)

    {filename, filename_opts}
  end

  defp maybe_put_opt(map, opts, opts_key, target_key) do
    case opts do
      %{^opts_key => value} ->
        Map.put(map, target_key, value)

      _ ->
        map
    end
  end

  @doc false
  def compile do
    # this step runs after all modules have been compiled
    # so we can write the final manifests and remove outdated hooks
    target_dir = target_dir()
    clear_manifests!(target_dir)
    files = clear_outdated_and_get_files!(target_dir)
    write_new_manifests!(target_dir, files)
  end

  defp clear_manifests!(target_dir) do
    manifests =
      Path.wildcard(Path.join(target_dir, "*/*.*"))
      |> Enum.filter(&File.regular?(&1))

    for manifest <- manifests, do: File.rm!(manifest)
  end

  defp clear_outdated_and_get_files!(target_dir) do
    apps = subdirectories(target_dir)

    Enum.flat_map(apps, fn app_dir ->
      modules = subdirectories(app_dir)

      Enum.flat_map(modules, fn module_folder ->
        module = Module.concat([Path.basename(module_folder)])
        process_module(app_dir, module_folder, module)
      end)
    end)
  end

  defp process_module(app_dir, module_folder, module) do
    with true <- Code.ensure_loaded?(module),
         data when data != [] <- get_data(module) do
      expected_files = Enum.map(data, fn {filename, _opts} -> filename end)
      files = File.ls!(module_folder)

      outdated_files = files -- expected_files

      for file <- outdated_files do
        File.rm!(Path.join(module_folder, file))
      end

      Enum.map(data, fn {filename, config} ->
        absolute_file_path = Path.join(module_folder, filename)
        config = Map.put(config, :app, Path.basename(app_dir))
        {absolute_file_path, config}
      end)
    else
      _ ->
        # either the module does not exist any more or
        # does not have any colocated hooks / JS
        File.rm_rf!(module_folder)
        []
    end
  end

  defp get_data(module) do
    case Phoenix.Component.MacroComponent.get_data(module) do
      :error ->
        []

      data ->
        Map.take(data, [
          Phoenix.LiveView.ColocatedHook,
          Phoenix.LiveView.ColocatedJS
        ])
        |> Enum.flat_map(fn {_mod, entries} -> entries end)
    end
  end

  defp write_new_manifests!(target_dir, files) do
    files
    |> Enum.group_by(fn {_filename, config} -> config.app end)
    |> Enum.each(fn {application, entries} ->
      target_dir = Path.join(target_dir, application)

      entries
      |> Enum.group_by(fn {_file, config} ->
        config[:manifest] || "index.js"
      end)
      |> Enum.each(fn {manifest, entries} ->
        write_manifest(manifest, entries, target_dir)
      end)
    end)
  end

  defp write_manifest(manifest, entries, target_dir) do
    content =
      entries
      |> Enum.group_by(fn {_file, config} -> config[:key] || :default end)
      |> Enum.reduce([empty_manifest()], fn group, acc ->
        case group do
          {:default, entries} ->
            [
              acc,
              Enum.map(entries, fn {file, %{name: name}} ->
                import_name = "js_" <> Base.encode32(name, case: :lower, padding: false)
                escaped_name = Phoenix.HTML.javascript_escape(name)

                ~s<\nimport #{import_name} from "./#{Path.relative_to(file, target_dir)}"; js["#{escaped_name}"] = #{import_name};>
              end)
            ]

          {key, entries} ->
            escaped_key = Phoenix.HTML.javascript_escape(key)

            [
              acc,
              ~s<js["#{escaped_key}"] = {};>,
              Enum.map(entries, fn {file, %{name: name}} ->
                import_name = "js_" <> Base.encode32(name, case: :lower, padding: false)
                escaped_name = Phoenix.HTML.javascript_escape(name)

                ~s<\nimport #{import_name} from "./#{Path.relative_to(file, target_dir)}"; js["#{escaped_key}"]["#{escaped_name}"] = #{import_name};>
              end)
            ]
        end
      end)

    File.write!(Path.join(target_dir, manifest), content)
  end

  defp empty_manifest do
    """
    const js = {};
    export default js;
    """
  end

  defp target_dir do
    Application.get_env(:phoenix_live_view, Phoenix.LiveView.ColocatedJS, [])
    |> Keyword.get(:target_directory, Path.join(Mix.Project.build_path(), "phoenix-colocated"))
  end

  defp current_otp_app do
    Application.get_env(:logger, :compile_time_application) || Mix.Project.config()[:app]
  end

  defp subdirectories(path) do
    Path.wildcard(Path.join(path, "*")) |> Enum.filter(&File.dir?(&1))
  end
end
