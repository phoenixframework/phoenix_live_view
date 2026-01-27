defmodule Phoenix.LiveView.ColocatedCSS do
  @moduledoc ~S'''
  A special HEEx `:type` that extracts any CSS styles from a colocated `<style>` tag at compile time.

  Note: To use `ColocatedCSS`, you need to run Phoenix 1.8+.

  Note: `ColocatedCSS` **must** be defined at the very beginning of the template in which it is used.

  You can use `ColocatedCSS` to define any CSS styles directly in your components, for example:

  ```heex
  <style :type={Phoenix.LiveView.ColocatedCSS}>
    .sample-class {
        background-color: #FFFFFF;
    }
  </style>
  ```

  ## Scoped CSS

  By default, Colocated CSS styles are scoped at compile time to the template in which they are defined.
  This provides style encapsulation preventing CSS rules within a component from unintentionally applying
  to elements in other nested components. Scoping is performed via the use of the `@scope` CSS at-rule.
  For more information, see [the docs on MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@scope).

  To prevent Colocated CSS styles from being scoped to the current template you can provide the `global`
  attribute, for example:

  ```heex
  <style :type={Phoenix.LiveView.ColocatedCSS} global>
    .sample-class {
        background-color: #FFFFFF;
    }
  </style>
  ```

  **Note:** When using Scoped Colocated CSS with implicit `inner_block` slots or named slots, the content
  provided will be scoped to the parent template which is providing the content, not the component which
  defines the slot. For example, in the following snippet the elements within [`intersperse/1`](`Phoenix.Component.intersperse/1`)'s
  `inner_block` and `separator` slots will both be styled by the `.sample-class` rule, not any rules defined within the
  [`intersperse/1`](`Phoenix.Component.intersperse/1`) component itself:

  ```heex
  <style :type={Phoenix.LiveView.ColocatedCSS}>
    .sample-class {
        background-color: #FFFFFF;
    }
  </style>
  <div class="sample-class">
    <.intersperse :let={item} enum={[1, 2, 3]}>
      <:separator>
        <span class="sample-class">|</span>
      </:separator>
      <div class="sample-class">
        <p>Item {item}</p>
      </div>
    </.intersperse>
  </div>
  ```

  > #### Warning! {: .warning}
  >
  > The `@scope` CSS at-rule is Baseline available as of the end of 2025. To ensure that Scoped CSS will
  > work on the browsers you need, be sure to check [Can I Use?](https://caniuse.com/css-cascade-scope) for
  > browser compatibility.

  > #### Tip {: .info}
  >
  > When Colocated CSS is scoped via the `@scope` rule, all "local root" elements in the given template serve as scoping roots.
  > "Local root" elements are the outermost elements of the template itself and the outermost elements of any content passed to
  > child components' slots. For selectors in your Colocated CSS to target the scoping root, you will need to
  > specify the scoping root in the selector via the use of the `:scope` pseudo-selector. For more details,
  > see [the docs on MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@scope#scope_pseudo-class_within_scope_blocks).

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

  > #### A note on dependencies and umbrella projects {: .info}
  >
  > For each application that uses colocated CSS, a separate directory is created
  > inside the `phoenix-colocated-css` folder. This allows to have clear separation between
  > styles of dependencies, but also applications inside umbrella projects.

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
    target_directory: Path.expand("../assets/css/phoenix-colocated-css", __DIR__)
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

  To bundle and use colocated CSS with esbuild, you can import it like this in your `app.js` file:

  ```javascript
  import "phoenix-colocated-css/my_app/colocated.css"
  ```

  Importing CSS in your `app.js` file will cause esbuild to generate a separate `app.css` file.
  To load it, simply add a second `<link>` to your `root.html.heex` file, like so:

  ```html
  <link phx-track-static rel="stylesheet" href={~p"/assets/js/app.css"} />
  ```

  ## Options

  Colocated CSS can be configured through the attributes of the `<style>` tag.
  The supported attributes are:

    * `global` - If provided, the Colocated CSS rules contained within the `<style>` tag
      will not be scoped to the template within which it is defined, and will instead act
      as global CSS rules.

    * `lower-bound` - Configure whether or not the the lower-bound of Scoped Colocated CSS is inclusive, that is,
      root elements of child components can be styled by the parent component's Colocated CSS. This can be
      useful for applying styles to the child component's root elements for layout purposes. Valid values are
      `"inclusive"` and `"exclusive"`. Scoped Colocated CSS defaults to `"exclusive"`, so that styles are entirely
      scoped to the parent unless otherwise specified.
  '''

  @behaviour Phoenix.Component.MacroComponent

  alias Phoenix.Component.MacroComponent

  @impl true
  def transform({"style", attributes, [text_content], _tag_meta} = _ast, meta) do
    validate_phx_version!()

    opts = Map.new(attributes)

    validate_opts!(opts)

    {scope, data} = extract(opts, text_content, meta)

    # we always drop colocated CSS from the rendered output
    {:ok, "", data, [root_tag_attribute: {"phx-css-#{scope}", true}]}
  end

  def transform(_ast, _meta) do
    raise ArgumentError, "ColocatedCSS can only be used on style tags"
  end

  defp validate_phx_version! do
    phoenix_version = to_string(Application.spec(:phoenix, :vsn))

    if not Version.match?(phoenix_version, "~> 1.8.0") do
      raise ArgumentError, ~s|ColocatedCSS requires at least {:phoenix, "~> 1.8.0"}|
    end
  end

  defp validate_opts!(opts) do
    Enum.each(opts, fn {key, val} -> validate_opt!({key, val}, Map.delete(opts, key)) end)
  end

  defp validate_opt!({"global", val}, other_opts) when val in [nil, true] do
    case other_opts do
      %{"lower-bound" => _} ->
        raise ArgumentError,
              "colocated css must be scoped to use the `lower-bound` attribute, but `global` attribute was provided"

      _ ->
        :ok
    end
  end

  defp validate_opt!({"global", val}, _other_opts) do
    raise ArgumentError,
          "expected nil or true for the `global` attribute of colocated css, got: #{inspect(val)}"
  end

  defp validate_opt!({"lower-bound", val}, _other_opts) when val in ["inclusive", "exclusive"] do
    :ok
  end

  defp validate_opt!({"lower-bound", val}, _other_opts) do
    raise ArgumentError,
          ~s|expected "inclusive" or "exclusive" for the `lower-bound` attribute of colocated css, got: #{inspect(val)}|
  end

  defp validate_opt!(_opt, _other_opts), do: :ok

  @doc false
  def extract(opts, text_content, meta) do
    # _build/dev/phoenix-colocated-css/otp_app/MyApp.MyComponent/line_no.css
    target_path = Path.join(target_dir(), inspect(meta.env.module))

    scope = scope(text_content, meta)
    root_tag_attribute = root_tag_attribute()

    upper_bound_selector = ~s|[phx-css-#{scope}]|
    lower_bound_selector = ~s|[#{root_tag_attribute}]|

    lower_bound_selector =
      case opts do
        %{"lower-bound" => "inclusive"} -> lower_bound_selector <> " > *"
        _ -> lower_bound_selector
      end

    styles =
      case opts do
        %{"global" => _} ->
          text_content

        _ ->
          "@scope (#{upper_bound_selector}) to (#{lower_bound_selector}) { #{text_content} }"
      end

    filename = "#{meta.env.line}_#{hash(styles)}.css"

    File.mkdir_p!(target_path)

    target_path
    |> Path.join(filename)
    |> File.write!(styles)

    {scope, filename}
  end

  defp scope(text_content, meta) do
    hash("#{meta.env.module}_#{meta.env.line}: #{text_content}")
  end

  defp hash(string) do
    # It is important that we do not pad
    # the Base32 encoded value as we use it in
    # an HTML attribute name and = (the padding character)
    # is not valid.
    string
    |> then(&:crypto.hash(:md5, &1))
    |> Base.encode32(case: :lower, padding: false)
  end

  defp root_tag_attribute() do
    case Application.get_env(:phoenix_live_view, :root_tag_attribute) do
      configured_attribute when is_binary(configured_attribute) ->
        configured_attribute

      configured_attribute ->
        message = """
        a global :root_tag_attribute must be configured to use colocated css

        Expected global :root_tag_attribute to be a string, got: #{inspect(configured_attribute)}

        The global :root_tag_attribute is usually configured to `"phx-r"`, but it needs to be explicitly enabled in your configuration:

            config :phoenix_live_view, root_tag_attribute: "phx-r"

        You can also use a different value than `"phx-r"`.
        """

        raise ArgumentError, message
    end
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
        module_folder
        |> Path.join(file)
        |> File.rm!()
      end

      Enum.map(data, fn filename ->
        _absolute_file_path = Path.join(module_folder, filename)
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
    path
    |> Path.join("*")
    |> Path.wildcard()
    |> Enum.filter(&File.dir?(&1))
  end
end
