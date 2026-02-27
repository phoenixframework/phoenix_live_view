defmodule Phoenix.LiveView.HTMLFormatter.TagFormatter do
  @moduledoc """
  A behaviour for formatting specific tags.
  """

  @doc """
  Callback invoked to format each tag.

  The callback receives a tuple of `{tag_name, attrs, content}`
  and the Mix [formatter options](https://hexdocs.pm/mix/Mix.Tasks.Format.html#module-formatting-options)

  Note: since the formatter does not compile code, the `:type` attribute of a
  macro component is given as a string as in the template.
  If you aliased `Phoenix.LiveView.ColocatedHook`, you will receive the aliased
  version as a string. For example:

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

    * `{tag_name, attrs, content}`
      with `tag_name` being `"script"`,
      attrs as `%{"manifest" => "foo.ts", ":type" => "ColocatedHook"}`
      and `content` being the string content inside the `<script>` tag
    * opts: `[file: "/path/to/template.html.heex", line: ...]`
      the Mix [formatter options](https://hexdocs.pm/mix/Mix.Tasks.Format.html#module-formatting-options)

  ### Example for formatting with [`prettier`](https://prettier.io/)

  ```elixir
  defmodule Prettier do
    @moduledoc false

    @behaviour Phoenix.LiveView.HTMLFormatter.TagFormatter

    require Logger

    @impl true
    def render_tag({"script", attrs, content}, _opts) do
      suffix =
        case attrs do
          %{":type" => _} ->
            # assume ColocatedHook / ColocatedJS and check for extension in manifest attribute
            Map.get(attrs, "manifest", "index.js")

          _ ->
            "tmp.js"
        end

      tmp_file =
        Path.join(System.tmp_dir!(), "prettier_\#{System.unique_integer([:positive])}_\#{suffix}")

      try do
        File.write!(tmp_file, content)

        # This example assumes that your project has prettier installed as a dependency
        # in your package.json. If not, you should pin prettier to a specific version like
        # "prettier@3.8.1" to avoid potential issues when prettier updates.
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
  end
  ```

  ```
  # .formatter.exs
  [
    plugins: [Phoenix.LiveView.HTMLFormatter],
    tag_formatters: %{script: Prettier}
  ]
  ```

  """
  @callback render_tag(
              tag :: {String.t(), map(), String.t()},
              opts :: keyword()
            ) :: {:ok, String.t()} | :skip
end
