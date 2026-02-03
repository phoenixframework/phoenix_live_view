if Mix.env() == :dev do
  defmodule Phoenix.LiveView.Prettier do
    @moduledoc false

    @behaviour Phoenix.LiveView.MacroComponentFormatter

    require Logger

    @impl true
    def format("script", attrs, _macro_component, content, _opts)
        when not is_map_key(attrs, "runtime") do
      manifest = Map.get(attrs, "manifest", "index.js")

      tmp_file =
        Path.join(System.tmp_dir!(), "prettier_#{System.unique_integer([:positive])}_#{manifest}")

      try do
        File.write!(tmp_file, content)

        case System.cmd("npx", ["prettier", tmp_file], stderr_to_stdout: true) do
          {output, 0} ->
            {:ok, String.trim(output)}

          {error, _} ->
            Logger.error("Failed to format with prettier: #{error}")
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
end
