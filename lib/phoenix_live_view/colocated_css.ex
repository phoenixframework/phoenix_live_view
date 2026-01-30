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
  @behaviour Phoenix.LiveView.ColocatedAssets

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

    data =
      Phoenix.LiveView.ColocatedAssets.extract(__MODULE__, meta.env.module, filename, styles, nil)

    {scope, data}
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
