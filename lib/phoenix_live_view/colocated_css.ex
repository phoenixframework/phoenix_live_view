defmodule Phoenix.LiveView.ColocatedCSS do
  @moduledoc ~S'''
  Building blocks for a special HEEx `:type` that extracts any CSS styles
  from a colocated `<style>` tag at compile time.

  To actually use `ColocatedCSS`, you must define a module including `use Phoenix.LiveView.ColocatedCSS`
  and implement the `ColocatedCSS` behaviour.

  Note: To use `ColocatedCSS`, you need to run Phoenix 1.8+.

  Note: `ColocatedCSS` **must** be defined at the very beginning of the template in which it is used.

  Colocated CSS uses the same folder structures as Colocated JS. See `Phoenix.LiveView.ColocatedJS` for more information.

  To bundle and use colocated CSS with esbuild, you can import it like this in your `app.js` file:

  ```javascript
  import "phoenix-colocated/my_app/colocated.css"
  ```

  Importing CSS in your `app.js` file will cause esbuild to generate a separate `app.css` file.
  To load it, simply add a second `<link>` to your `root.html.heex` file, like so:

  ```html
  <link phx-track-static rel="stylesheet" href={~p"/assets/js/app.css"} />
  ```

  ## Global CSS

  If all you need is global CSS, which is extracted as is, you can define your ColocatedCSS module like this:

  ```elixir
  defmodule MyAppWeb.ColocatedCSS do
    use Phoenix.LiveView.ColocatedCSS

    @impl true
    def transform("style", _attrs, css, _meta) do
      {:ok, css, []}
    end
  end
  ```

  ## Scoped CSS

  The idea behind scoped CSS is to restrict the elements that CSS rules apply to
  to only the elements of the current template / component.

  One way to scope CSS is to use [CSS `@scope` rules](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@scope).
  A scoped `ColocatedCSS` module using CSS `@scope` can be implemented like this:

  ```elixir
  defmodule MyAppWeb.ColocatedScopedCSS do
    use Phoenix.LiveView.ColocatedCSS

    @impl true
    def transform("style", attrs, css, meta) do
      validate_opts!(attrs)

      {scope, css} = do_scope(css, attrs, meta)

      {:ok, css, [root_tag_attribute: {"phx-css-#{scope}", true}]}
    end

    defp validate_opts!(opts) do
      Enum.each(opts, fn {key, val} -> validate_opt!({key, val}, Map.delete(opts, key)) end)
    end

    defp validate_opt!({"lower-bound", val}, _other_opts) when val in ["inclusive", "exclusive"] do
      :ok
    end

    defp validate_opt!({"lower-bound", val}, _other_opts) do
      raise ArgumentError,
            ~s|expected "inclusive" or "exclusive" for the `lower-bound` attribute of colocated css, got: #{inspect(val)}|
    end

    defp validate_opt!(_opt, _other_opts), do: :ok

    defp do_scope(css, opts, meta) do
      scope = hash("#{meta.module}_#{meta.line}: #{css}")

      root_tag_attribute = root_tag_attribute()

      upper_bound_selector = ~s|[phx-css-#{scope}]|
      lower_bound_selector = ~s|[#{root_tag_attribute}]|

      lower_bound_selector =
        case opts do
          %{"lower-bound" => "inclusive"} -> lower_bound_selector <> " > *"
          _ -> lower_bound_selector
        end

      css = "@scope (#{upper_bound_selector}) to (#{lower_bound_selector}) { #{css} }"

      {scope, css}
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
          a global :root_tag_attribute must be configured to use scoped css

          Expected global :root_tag_attribute to be a string, got: #{inspect(configured_attribute)}

          The global :root_tag_attribute is usually configured to `"phx-r"`, but it needs to be explicitly enabled in your configuration:

              config :phoenix_live_view, root_tag_attribute: "phx-r"

          You can also use a different value than `"phx-r"`.
          """

          raise ArgumentError, message
      end
    end
  end
  ```

  This module transforms a given style tag like

  ```heex
  <%!-- Note that :type accepts aliases as well! --%>
  <style :type={MyAppWeb.ColocatedScopedCSS}>
    .my-class { color: red; }
  </style>
  ```

  into

  ```css
  @scope ([phx-css-abc123]) to ([phx-r]) {
    .my-class { color: red; }
  }
  ```

  and if `lower-bound` is set to `inclusive`, it transforms it into

  ```css
  @scope ([phx-css-abc123]) to ([phx-r] > *) {
    .my-class { color: red; }
  }
  ```

  This applies any styles defined in the colocated CSS block to any element between a local root and a component.
  It relies on LiveView's global `:root_tag_attribute`, which is an attribute that LiveView adds to all root tags,
  no matter if colocated CSS is used or not. When the browser encounters a `phx-r` attribute, which in this case
  is assumed to be the configured global `:root_tag_attribute`, it stops the scoped CSS rule.

  Another way to implement scoped CSS could be to use PostCSS and apply an attribute to all tags in a template.
  '''

  @doc """
  Callback invoked for each colocated CSS tag.

  The callback receives the tag name, the string attributes and a map of metadata.

  For example, for the following tag:

  ```heex
  <style :type={MyAppWeb.ColocatedCSS} data-scope="my-scope" foo={@bar}>
    .my-class { color: red; }
  </style>
  ```

  The callback would receive the following arguments:

    * tag_name: `"style"`
    * attrs: %{"data-scope" => "my-scope"}
    * meta: `%{file: "path/to/file.ex", module: MyApp.MyModule, line: 10}`

  The callback must return either `{:ok, scoped_css, directives}` or `{:error, reason}`.
  If an error is returned, it will be logged and the CSS will not be extracted.

  The `directives` needs to be a keyword list that supports the following options:

    * `root_tag_attribute`: A `{key, value}` tuple that will be added as
       an attribute to all "root tags" of the template defining the scoped CSS tag.
       See the section on root tags below for more information.
    * `tag_attribute`: A `{key, value}` tuple that will be added as an attribute to
       all HTML tags in the template defining the scoped CSS tag.

  ## Root tags

  In a HEEx template, all outermost tags are considered "root tags" and are
  affected by the `root_tag_attribute` directive. If a template uses components,
  the slots of those components are considered as root tags as well.

  Here's an example showing which elements would be considered root tags:

  ```heex
  <div>                              <---- root tag
    <span>Hello</span>               <---- not a root tag

    <.my_component>
      <p>World</p>                   <---- root tag
    </.my_component>
  </div>

  <.my_component>
    <span>World</span>               <---- root tag

    <:a_named_slot>
      <div>                          <---- root tag
        Foo
        <p>Bar</p>                   <---- not a root tag
      </div>
    </:a_named_slot>
  </.my_component>
  ```
  """
  @callback transform(tag_name :: binary(), attrs :: map(), css :: binary(), meta :: map()) ::
              {:ok, binary(), keyword()} | {:error, term()}

  defmacro __using__(_) do
    # implements the MacroComponent behaviour
    # but we don't add @behaviour to prevent users to need to differentiate
    # @impl true for the ColocatedCSS behaviour itself
    quote do
      @behaviour unquote(__MODULE__)

      def transform(ast, meta) do
        Phoenix.LiveView.ColocatedCSS.__transform__(ast, meta, __MODULE__)
      end
    end
  end

  @behaviour Phoenix.LiveView.ColocatedAssets

  @doc false
  def __transform__({"style", attributes, [text_content], _tag_meta} = _ast, meta, module) do
    validate_phx_version!()

    opts = Map.new(attributes)

    case extract(opts, text_content, meta, module) do
      {data, directives} ->
        # we always drop colocated CSS from the rendered output
        {:ok, "", data, directives}

      nil ->
        {:ok, ""}
    end
  end

  def __transform__(_ast, _meta, _module) do
    raise ArgumentError, "ColocatedCSS can only be used on style tags"
  end

  defp validate_phx_version! do
    phoenix_version = to_string(Application.spec(:phoenix, :vsn))

    if not Version.match?(phoenix_version, "~> 1.8.0") do
      raise ArgumentError, ~s|ColocatedCSS requires at least {:phoenix, "~> 1.8.0"}|
    end
  end

  defp extract(opts, text_content, meta, module) do
    transform_meta = %{
      module: meta.env.module,
      file: meta.env.file,
      line: meta.env.line
    }

    case module.transform("style", opts, text_content, transform_meta) do
      {:ok, styles, directives} when is_binary(styles) and is_list(directives) ->
        filename = "#{meta.env.line}_#{hash(styles)}.css"

        data =
          Phoenix.LiveView.ColocatedAssets.extract(
            __MODULE__,
            meta.env.module,
            filename,
            styles,
            nil
          )

        {data, directives}

      {:error, reason} ->
        IO.warn(
          "ColocatedCSS module #{inspect(module)} returned an error, skipping: #{inspect(reason)}"
        )

        nil

      other ->
        raise ArgumentError,
              "expected the ColocatedCSS implementation to return {:ok, scoped_css, directives} or {:error, term}, got: #{inspect(other)}"
    end
  end

  defp hash(string) do
    string
    |> then(&:crypto.hash(:md5, &1))
    |> Base.encode32(case: :lower, padding: false)
  end

  @impl Phoenix.LiveView.ColocatedAssets
  def build_manifests(files) do
    if files == [] do
      [{"colocated.css", ""}]
    else
      [
        {"colocated.css",
         Enum.reduce(files, [], fn %{relative_path: file}, acc ->
           line = ~s[@import "./#{file}";\n]
           [acc | line]
         end)}
      ]
    end
  end
end
