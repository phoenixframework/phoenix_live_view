defmodule Phoenix.LiveView.ColocatedHook do
  @behaviour Phoenix.LiveView.MacroComponent

  @impl true
  def transform({"script", attributes, [text_content]} = _ast, meta) do
    opts = Map.new(attributes)

    name =
      case opts do
        %{"name" => "." <> name} ->
          "#{inspect(meta.env.module)}.#{name}"

        %{"name" => name} ->
          raise ArgumentError,
                """
                colocated hook names must start with a dot, invalid hook name: #{name}

                Hint: name your hook <script :type={ColocatedHook} name=".#{name}" ...>
                """

        %{} ->
          raise ArgumentError, "missing required name attribute for ColocatedHook"
      end

    case Map.get(opts, "bundle-mode", :bundle) do
      :runtime ->
        new_content = """
        window["phx_hook_#{Phoenix.HTML.javascript_escape(name)}"] = function() {
          #{text_content}
        }
        """

        {"script", [{"data-phx-runtime-hook", name}], [new_content]}

      :bundle ->
        # a colocated hook is just a special type of colocated JS,
        # exported under the top-level `hooks` key.
        opts =
          opts
          |> Map.put("key", "hooks")
          |> Map.put("name", name)
          |> Map.drop(["bundle-mode"])

        Phoenix.LiveView.ColocatedJS.extract(opts, text_content, meta)
        ""
    end
  end

  def transform(_ast, _meta) do
    raise ArgumentError, "a ColocatedHook can only be used on script tags"
  end
end
