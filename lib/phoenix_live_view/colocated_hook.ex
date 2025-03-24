defmodule Phoenix.LiveView.ColocatedHook do
  @moduledoc """
  Functions for defining colocated hooks.
  """
  alias Phoenix.LiveView.ColocatedHook

  defstruct [:name, :opts]

  def new(name, opts \\ []) do
    opts = Keyword.validate!(opts, [:manifest_path, :colocated_hooks_app, :bundle_mode])

    %__MODULE__{name: name, opts: opts}
  end

  @doc false
  def should_bundle?(hook) do
    current_otp_app() == colocated_hooks_app(hook)
  end

  defp empty_manifest do
    """
    let hooks = {}
    export default hooks
    """
  end

  defp manifest_path(hook) do
    hook.opts[:manifest_path] ||
      Application.get_env(
        :phoenix_live_view,
        :colocated_hooks_manifest,
        Path.join(File.cwd!(), "assets/js/hooks/index.js")
      )
  end

  defp colocated_hooks_app(hook) do
    hook.opts[:colocated_hooks_app] ||
      Application.get_env(:phoenix_live_view, :colocated_hooks_app, current_otp_app())
  end

  defp current_otp_app do
    Application.get_env(:logger, :compile_time_application)
  end

  @doc false
  def hashed_name(%{file: file, line: line, column: column}) do
    hashed_script_name(file) <> "_#{line}_#{column}"
  end

  defp hashed_script_name(file) do
    :md5 |> :crypto.hash(file) |> Base.encode16()
  end

  @doc false
  def process_bundled_hook(hook, text_content, meta) do
    %{file: file, line: line, column: column} = meta
    js_filename = hashed_name(meta)

    script_content =
      "// #{Path.relative_to_cwd(file)}:#{line}:#{column}\n" <> text_content

    manifest_path = manifest_path(hook)
    dir = Path.dirname(manifest_path)
    js_path = Path.join(dir, js_filename <> ".js")

    # colocated hooks are always written to the current otp_app's dir;
    # so when a dependency is compiled, the hooks will be placed in the deps folder;
    # but they are still included in the configured manifest, for example:
    #
    # /path/to/app/deps/my_dep/assets/js/hooks/HOOKHASH_X_Y.js
    # /path/to/app/assets/js/hooks/HOOKHASH_Y_Z.js
    #
    # the full path is either
    # ./HOOKHASH_Y_Z.js for a local hook
    # ../../../deps/my_dep/assets/js/hooks/HOOKHASH_X_Y.js for a hook from a dependency
    #
    # the manifest is always ./assets/js/hooks/index.js;
    # but it can be configured with:
    #
    #     config :phoenix_live_view, colocated_hooks_manifest: PATH

    relative =
      if function_exported?(Path, :relative_to, 3) do
        # force option is only available since Elixir 1.16;
        # in earlier versions, the path will be absolute, but that should be fine
        &apply(Path, :relative_to, [&1, &2, [force: true]])
      else
        &Path.relative_to(&1, &2)
      end

    js_full_path =
      case relative.(Path.expand(js_path), Path.dirname(manifest_path)) do
        <<".", _rest::binary>> = p -> p
        p -> "./#{p}"
      end

    File.mkdir_p!(dir)
    File.write!(js_path, script_content)

    if !File.exists?(manifest_path) do
      File.write!(manifest_path, empty_manifest())
    end

    manifest = File.read!(manifest_path)

    File.open(manifest_path, [:append], fn file ->
      if !String.contains?(manifest, js_filename) do
        IO.binwrite(
          file,
          ~s|\nimport hook_#{js_filename} from "#{js_full_path}"; hooks["#{js_filename}"] = hook_#{js_filename};|
        )
      end
    end)

    %{hashed_name: js_filename}
  end

  @doc false
  def prune(hook, hashed_name) do
    cond do
      hook.opts[:bundle_mode] == :runtime ->
        throw(:noop)

      hook.opts[:bundle_mode] == :current_otp_app and not ColocatedHook.should_bundle?(hook) ->
        throw(:noop)

      true ->
        :ok
    end

    manifest_path = manifest_path(hook)
    dir = Path.dirname(manifest_path)

    case File.ls(dir) do
      {:ok, hooks} ->
        for hook_basename <- hooks do
          if String.starts_with?(hook_basename, hashed_name) do
            File.rm!(Path.join(dir, hook_basename))

            if File.exists?(manifest_path) do
              new_file =
                manifest_path
                |> File.stream!()
                |> Enum.filter(fn line -> !String.contains?(line, hashed_name) end)
                |> Enum.join("")
                |> String.trim()

              File.write!(manifest_path, new_file)
            end
          else
            :noop
          end
        end

      _ ->
        :noop
    end
  catch
    :noop -> :noop
  end
end

defimpl Phoenix.LiveView.TagExtractor, for: Phoenix.LiveView.ColocatedHook do
  alias Phoenix.LiveView.ColocatedHook

  def extract(
        %Phoenix.LiveView.ColocatedHook{opts: opts} = hook,
        attributes,
        text_content,
        meta
      ) do
    case opts[:bundle_mode] do
      :runtime ->
        hashed_name = ColocatedHook.hashed_name(meta)

        new_content = """
        window["phx_hook_#{hashed_name}"] = function() {
          #{text_content}
        }
        """

        {:keep, Map.put(attributes, "data-phx-runtime-hook", {:string, hashed_name}), new_content,
         %{hashed_name: hashed_name}}

      :current_otp_app ->
        if ColocatedHook.should_bundle?(hook) do
          {:drop, ColocatedHook.process_bundled_hook(hook, text_content, meta)}
        else
          {:drop, nil}
        end

      _ ->
        {:drop, ColocatedHook.process_bundled_hook(hook, text_content, meta)}
    end
  end

  def postprocess_tokens(
        %Phoenix.LiveView.ColocatedHook{name: hook_name},
        %{hashed_name: hashed_name},
        tokens
      ) do
    Enum.map(tokens, fn
      {:tag, name, attrs, meta} ->
        {:tag, name, rewrite_hook_attrs(hook_name, hashed_name, attrs), meta}

      {:local_component, name, attrs, meta} ->
        {:local_component, name, rewrite_hook_attrs(hook_name, hashed_name, attrs), meta}

      {:remote_component, name, attrs, meta} ->
        {:remote_component, name, rewrite_hook_attrs(hook_name, hashed_name, attrs), meta}

      other ->
        other
    end)
  end

  def postprocess_tokens(_hook, _state, tokens), do: tokens

  defp rewrite_hook_attrs(name, hashed_name, attrs) do
    Enum.map(attrs, fn
      {"phx-hook", {:string, ^name, meta1}, meta2} ->
        {"phx-hook", {:string, hashed_name, meta1}, meta2}

      {attr, value, meta} ->
        {attr, value, meta}
    end)
  end

  def prune(hook, %{hashed_name: hashed_name}) do
    ColocatedHook.prune(hook, hashed_name)
  end
end
