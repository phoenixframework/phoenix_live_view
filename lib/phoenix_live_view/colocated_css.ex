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

  ## Scoped CSS

  By default, Colocated CSS is not scoped. This means that the styles defined in a Colocated CSS block are extracted as is.
  However, LiveView supports scoping Colocated CSS by defining a `:scoper` module implementing the `Phoenix.LiveView.ColocatedCSS.Scoper`
  behaviour. When a `:scoper` is configured, Colocated CSS that is not defined with the `global` attribute will be scoped
  according to the configured scoper.

  An example scoper using CSS `@scope` can be implemented like this:

  ```elixir
  defmodule MyAppWeb.CSSScoper do
    @behaviour Phoenix.LiveView.ColocatedCSS.Scoper

    @impl true
    def scope("style", attrs, css, meta) do
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

  To use this scoper, you would configure it in your `config.exs` like this:

  ```elixir
  config :phoenix_live_view, Phoenix.LiveView.ColocatedCSS, scoper: MyAppWeb.CSSScoper
  ```

  This scoper transforms a given style tag like

  ```heex
  <style :type={Phoenix.LiveView.ColocatedCSS}>
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

  This uses [CSS donut scoping](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@scope) to
  apply any styles defined in the colocated CSS block to any element between a local root and a component.
  It relies on LiveView's global `:root_tag_attribute`, which is an attribute that LiveView adds to all root tags,
  no matter if colocated CSS is used or not. When the browser encounters a `phx-r` attribute, which in this case
  is assumed to be the configured global `:root_tag_attribute`, it stops the scoped CSS rule.

  Another way to implement a scoper could be to use PostCSS and apply a tag to all tags in a template.

  ## Options

  Colocated CSS can be configured through the attributes of the `<style>` tag.
  The supported attributes are:

    * `global` - If provided, the Colocated CSS rules contained within the `<style>` tag
      will not be scoped to the template within which it is defined, and will instead act
      as global CSS rules, even if a scoper is configured.

  '''

  @behaviour Phoenix.Component.MacroComponent
  @behaviour Phoenix.LiveView.ColocatedAssets

  @impl true
  def transform({"style", attributes, [text_content], _tag_meta} = _ast, meta) do
    validate_phx_version!()

    opts = Map.new(attributes)

    validate_opts!(opts)

    {data, directives} = extract(opts, text_content, meta)

    # we always drop colocated CSS from the rendered output
    {:ok, "", data, directives}
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

  defp validate_opt!({"global", val}, _other_opts) when val in [nil, true] do
    :ok
  end

  defp validate_opt!({"global", val}, _other_opts) do
    raise ArgumentError,
          "expected nil or true for the `global` attribute of colocated css, got: #{inspect(val)}"
  end

  defp validate_opt!(_opt, _other_opts), do: :ok

  @doc false
  def extract(opts, text_content, meta) do
    global =
      case opts do
        %{"global" => val} -> val in [true, nil]
        _ -> false
      end

    {styles, directives} =
      case Application.get_env(:phoenix_live_view, Phoenix.LiveView.ColocatedCSS, [])[:scoper] do
        nil ->
          {text_content, []}

        _scoper when global in [true, nil] ->
          {text_content, []}

        scoper ->
          scope_meta = %{
            module: meta.env.module,
            file: meta.env.file,
            line: meta.env.line
          }

          case scoper.scope("style", opts, text_content, scope_meta) do
            {:ok, scoped_css, directives} when is_binary(scoped_css) and is_list(directives) ->
              {scoped_css, directives}

            {:error, reason} ->
              raise ArgumentError,
                    "the scoper returned an error: #{inspect(reason)}"

            other ->
              raise ArgumentError,
                    "expected the ColocatedCSS scoper to return {:ok, scoped_css, directives} or {:error, term}, got: #{inspect(other)}"
          end
      end

    filename = "#{meta.env.line}_#{hash(styles)}.css"

    data =
      Phoenix.LiveView.ColocatedAssets.extract(__MODULE__, meta.env.module, filename, styles, nil)

    {data, directives}
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
