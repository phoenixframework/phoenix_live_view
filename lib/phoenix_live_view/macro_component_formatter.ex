defmodule Phoenix.LiveView.MacroComponentFormatter do
  @moduledoc """
  A behaviour for formatting macro component contents.

  You can configure one formatter module using

      config :phoenix_live_view, Phoenix.LiveView.HTMLFormatter,
        macro_component_handler: YourApp.MacroComponentFormatter

  """

  @doc """
  Callback invoked to format each macro component.

  Only invoked for macro components that contain only string content.

  The callback receives the tag_name, string attributes as map, the macro
  component name as given in the template, the string content, and the formatter
  options of the `Phoenix.LiveView.HTMLFormatter` plugin.

  Note: since the formatter does not compile code, the macro component is
  given as a string. If you aliased `Phoenix.LiveView.ColocatedHook`, you will
  receive the aliased version as a string. For example:

  ```heex
  <script :type={ColocatedHook} manifest="foo.ts">
    export default {
      mounted() {
        console.log("mounted");
      }
    }
  </script>
  ```

  will invoke the callback with:

      * tag_name: `"script"`
      * attrs: `%{"manifest" => "foo.ts"}
      * macro_component: `"ColocatedHook"`
      * content: the string content inside the `<script>` tag
      * opts: [file: "/path/to/template.html.heex", line: ...]

  ### Example for formatting with `prettier`

  ```elixir
  defmodule MyApp.PrettierColocatedFormatter do
    @moduledoc false

    @behaviour Phoenix.LiveView.MacroComponentFormatter

    require Logger

    @impl true
    def format("script", attrs, _macro_component, content, _opts) do
      manifest = Map.get(attrs, "manifest", "index.js")

      tmp_file =
        Path.join(System.tmp_dir!(), "prettier_\#{System.unique_integer([:positive])}_\#{manifest}")

      try do
        File.write!(tmp_file, content)

        case System.cmd("npx", ["prettier", tmp_file], stderr_to_stdout: true) do
          {output, 0} ->
            {:ok, String.trim(output)}

          {error, _} ->
            Logger.error("Failed to format with prettier: \#{error}")
            :skip
        end
      after
        File.rm(tmp_file)
      end
    end

    def format(_other, _attrs, _macro_component, _content, _opts) do
      :skip
    end
  end
  ```

  Note that this example assumes that all `<script>` tags macro components
  should be formatted with `prettier`. It checks the `manifest` attribute as that an
  argument for `Phoenix.LiveView.ColocatedHook`. Depending on your usage of
  macro components, you might need to add additional checks.

  """
  @callback format(
              tag_name :: String.t(),
              attrs :: map(),
              macro_component :: String.t(),
              content :: String.t(),
              opts :: keyword()
            ) :: String.t()
end
