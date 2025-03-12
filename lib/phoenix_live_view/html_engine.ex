defmodule Phoenix.LiveView.HTMLEngine do
  @moduledoc """
  The HTMLEngine that powers `.heex` templates and the `~H` sigil.

  It works by adding a HTML parsing and validation layer on top
  of `Phoenix.LiveView.TagEngine`.
  """

  @behaviour Phoenix.Template.Engine

  @impl true
  def compile(path, _name) do
    # We need access for the caller, so we return a call to a macro.
    quote do
      require Phoenix.LiveView.HTMLEngine
      Phoenix.LiveView.HTMLEngine.compile(unquote(path))
    end
  end

  @doc false
  defmacro compile(path) do
    trim = Application.get_env(:phoenix, :trim_on_html_eex_engine, true)
    source = File.read!(path)

    EEx.compile_string(source,
      engine: Phoenix.LiveView.TagEngine,
      line: 1,
      file: path,
      trim: trim,
      caller: __CALLER__,
      source: source,
      tag_handler: __MODULE__
    )
  end

  @behaviour Phoenix.LiveView.TagEngine

  @impl true
  def classify_type(":inner_block"), do: {:error, "the slot name :inner_block is reserved"}
  def classify_type(":" <> name), do: {:slot, name}

  def classify_type(<<first, _::binary>> = name) when first in ?A..?Z,
    do: {:remote_component, name}

  def classify_type("."), do: {:error, "a component name is required after ."}
  def classify_type("." <> name), do: {:local_component, name}
  def classify_type(name), do: {:tag, name}

  @impl true
  for void <- ~w(area base br col hr img input link meta param command keygen source) do
    def void?(unquote(void)), do: true
  end

  def void?(_), do: false

  @impl true
  def handle_attributes(ast, meta) do
    if is_list(ast) and literal_keys?(ast) do
      # Optimization: if keys are known at compilation time, we
      # inline the dynamic attributes
      attrs =
        Enum.map(ast, fn {key, value} ->
          name = to_string(key)

          case handle_attr_escape(name, value, meta) do
            :error -> handle_attrs_escape([{safe_unless_special(name), value}], meta)
            parts -> {name, parts}
          end
        end)

      {:attributes, attrs}
    else
      {:quoted, handle_attrs_escape(ast, meta)}
    end
  end

  defp literal_keys?([{key, _value} | rest]) when is_atom(key) or is_binary(key),
    do: literal_keys?(rest)

  defp literal_keys?([]), do: true
  defp literal_keys?(_other), do: false

  defp handle_attrs_escape(attrs, meta) do
    quote line: meta[:line] do
      unquote(__MODULE__).attributes_escape(unquote(attrs))
    end
  end

  defp handle_attr_escape("class", [head | tail], meta) when is_binary(head) do
    {bins, tail} = Enum.split_while(tail, &is_binary/1)
    encoded = class_attribute_encode([head | bins])

    if tail == [] do
      [IO.iodata_to_binary(encoded)]
    else
      tail =
        quote line: meta[:line] do
          {:safe, unquote(__MODULE__).class_attribute_encode(unquote(tail))}
        end

      [IO.iodata_to_binary([encoded, ?\s]), tail]
    end
  end

  defp handle_attr_escape("class", value, meta) do
    [
      quote(
        line: meta[:line],
        do: {:safe, unquote(__MODULE__).class_attribute_encode(unquote(value))}
      )
    ]
  end

  defp handle_attr_escape("style", value, meta) do
    [
      quote(
        line: meta[:line],
        do: {:safe, unquote(__MODULE__).empty_attribute_encode(unquote(value))}
      )
    ]
  end

  defp handle_attr_escape(_name, value, meta) do
    case extract_binaries(value, true, [], meta) do
      :error -> :error
      reversed -> Enum.reverse(reversed)
    end
  end

  defp extract_binaries({:<>, _, [left, right]}, _root?, acc, meta) do
    extract_binaries(right, false, extract_binaries(left, false, acc, meta), meta)
  end

  defp extract_binaries({:<<>>, _, parts} = binary, _root?, acc, meta) do
    Enum.reduce(parts, acc, fn
      part, acc when is_binary(part) ->
        [binary_encode(part) | acc]

      {:"::", _, [binary, {:binary, _, _}]}, acc ->
        [quoted_binary_encode(binary, meta) | acc]

      _, _ ->
        throw(:unknown_part)
    end)
  catch
    :unknown_part ->
      [quoted_binary_encode(binary, meta) | acc]
  end

  defp extract_binaries(binary, _root?, acc, _meta) when is_binary(binary),
    do: [binary_encode(binary) | acc]

  defp extract_binaries(value, false, acc, meta),
    do: [quoted_binary_encode(value, meta) | acc]

  defp extract_binaries(_value, true, _acc, _meta),
    do: :error

  @doc false
  def attributes_escape(attrs) do
    # We don't want to dasherize keys, which Phoenix.HTML does for atoms,
    # so we convert those to strings
    attrs
    |> Enum.map(fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      other -> other
    end)
    |> Phoenix.HTML.attributes_escape()
  end

  @doc false
  def class_attribute_encode(list) when is_list(list),
    do: list |> class_attribute_list() |> Phoenix.HTML.Engine.encode_to_iodata!()

  def class_attribute_encode(other),
    do: empty_attribute_encode(other)

  defp class_attribute_list(value) do
    value
    |> Enum.flat_map(fn
      nil -> []
      false -> []
      inner when is_list(inner) -> [class_attribute_list(inner)]
      other -> [other]
    end)
    |> Enum.join(" ")
  end

  @doc false
  def empty_attribute_encode(nil), do: ""
  def empty_attribute_encode(false), do: ""
  def empty_attribute_encode(true), do: ""
  def empty_attribute_encode(value), do: Phoenix.HTML.Engine.encode_to_iodata!(value)

  @doc false
  def binary_encode(value) when is_binary(value) do
    value
    |> Phoenix.HTML.Engine.encode_to_iodata!()
    |> IO.iodata_to_binary()
  end

  def binary_encode(value) do
    raise ArgumentError, "expected a binary in <>, got: #{inspect(value)}"
  end

  defp quoted_binary_encode(binary, meta) do
    quote line: meta[:line] do
      {:safe, unquote(__MODULE__).binary_encode(unquote(binary))}
    end
  end

  # We mark attributes as safe so we don't escape them
  # at rendering time. However, some attributes are
  # specially handled, so we keep them as strings shape.
  defp safe_unless_special("id"), do: :id
  defp safe_unless_special("aria"), do: :aria
  defp safe_unless_special("class"), do: :class
  defp safe_unless_special("data"), do: :data
  defp safe_unless_special(name), do: {:safe, name}

  @impl true
  def annotate_body(%Macro.Env{} = caller) do
    if Application.get_env(:phoenix_live_view, :debug_heex_annotations, false) do
      %Macro.Env{module: mod, function: {func, _}, file: file, line: line} = caller
      line = if line == 0, do: 1, else: line
      file = Path.relative_to_cwd(file)

      before = "<#{inspect(mod)}.#{func}> #{file}:#{line}"
      aft = "</#{inspect(mod)}.#{func}>"
      {"<!-- #{before} (#{current_otp_app()}) -->", "<!-- #{aft} -->"}
    end
  end

  @impl true
  def annotate_caller(file, line) do
    if Application.get_env(:phoenix_live_view, :debug_heex_annotations, false) do
      line = if line == 0, do: 1, else: line
      file = Path.relative_to_cwd(file)

      "<!-- @caller #{file}:#{line} (#{current_otp_app()}) -->"
    end
  end

  defp current_otp_app do
    Application.get_env(:logger, :compile_time_application)
  end

  defp colocated_hooks_app do
    Application.get_env(:phoenix_live_view, :colocated_hooks_app, current_otp_app())
  end

  defp colocated_hooks_manifest do
    Application.get_env(
      :phoenix_live_view,
      :colocated_hooks_manifest,
      Path.join(File.cwd!(), "assets/js/hooks/index.js")
    )
  end

  @impl true
  def token_preprocess(tokens, opts) do
    file = Keyword.fetch!(opts, :file)
    caller = Keyword.fetch!(opts, :caller)
    module = caller.module

    {hooks, tokens} = process_hooks(tokens, %{module: module, file: file}, {%{}, []})

    if hooks == %{} do
      Enum.reverse(tokens)
    else
      write_hooks_and_manifest(hooks)
      # when a <script type="text/phx-hook" name="..." > is found, we generate the hook name
      # based on its content. Then, we need to rewrite the phx-hook="..." attribute of all
      # other tags to match the generated hook name.
      # This is expensive, as we traverse all tags and attributes,
      # but we only do it if a script hook is present.
      rewrite_hook_names(hooks, tokens)
    end
  end

  defp process_hooks(
         [
           {:tag, "script", attrs, start_meta} = start,
           {:text, text, _} = content,
           {:close, :tag, "script", _} = end_ | rest
         ],
         meta,
         {hooks, tokens_acc}
       ) do
    str_attrs = for {name, {:string, value, _}, _} <- attrs, into: %{}, do: {name, value}
    %{line: line, column: column} = start_meta
    hook_meta = Map.merge(meta, %{line: line, column: column})

    case classify_hook(str_attrs) do
      # keep runtime hooks
      {:runtime, name} ->
        # keep bundle="runtime" hooks in DOM
        {hooks, start, content, end_} =
          process_runtime_hook(hooks, name, start, content, end_, hook_meta)

        process_hooks(rest, meta, {hooks, [end_, content, start | tokens_acc]})

      {:bundle_current, name} ->
        # only consider bundle="current_otp_app" hooks if they are part of the current otp_app
        if current_otp_app() == colocated_hooks_app() do
          IO.puts(
            "Adding hook #{name} from colo #{colocated_hooks_app()} == current #{current_otp_app()}"
          )

          hooks = process_bundled_hook(hooks, name, text, hook_meta)
          process_hooks(rest, meta, {hooks, tokens_acc})
        else
          IO.puts("Skipping hook #{name} from #{colocated_hooks_app()}")
          process_hooks(rest, meta, {hooks, tokens_acc})
        end

      {:bundle, name} ->
        # by default, hooks with no special bundle value are extracted, no matter where they're from
        hooks = process_bundled_hook(hooks, name, text, hook_meta)
        process_hooks(rest, meta, {hooks, tokens_acc})

      :invalid ->
        # TODO: nice error message
        raise ArgumentError,
              "scripts with type=\"text/phx-hook\" must have a compile-time string \"name\" attribute"

      :no_hook ->
        process_hooks(rest, meta, {hooks, [end_, content, start | tokens_acc]})
    end
  end

  # if the first clause did not match (tag open, text, close),
  # this means that there is interpolation inside the script, which is not supported
  # for colocated hooks
  defp process_hooks([{:tag, "script", attrs, _meta} = start | rest], meta, {hooks, tokens_acc}) do
    if Enum.find(attrs, &match?({"type", {:string, "text/phx-hook", _}, _}, &1)) do
      # TODO: nice error message
      raise ArgumentError,
            "scripts with type=\"text/phx-hook\" must not contain any interpolation!"
    else
      process_hooks(rest, meta, {hooks, [start | tokens_acc]})
    end
  end

  defp process_hooks([token | rest], meta, {hooks, tokens_acc}),
    do: process_hooks(rest, meta, {hooks, [token | tokens_acc]})

  defp process_hooks([], _meta, acc), do: acc

  defp classify_hook(%{"type" => "text/phx-hook", "name" => name, "bundle" => "runtime"}),
    do: {:runtime, name}

  defp classify_hook(%{"type" => "text/phx-hook", "name" => name, "bundle" => "current_otp_app"}),
    do: {:bundle_current, name}

  defp classify_hook(%{"type" => "text/phx-hook", "name" => name}), do: {:bundle, name}
  defp classify_hook(%{"type" => "text/phx-hook"}), do: :invalid
  defp classify_hook(_), do: :no_hook

  defp hashed_hook_name(%{file: file, line: line, column: column}) do
    hashed_script_name(file) <> "_#{line}_#{column}"
  end

  defp hashed_script_name(file) do
    :md5 |> :crypto.hash(file) |> Base.encode16()
  end

  # A runtime hook is sent to the browser in a <script> tag
  # and actually executed there.
  #
  # This is useful for environments where the JS bundle is not controlled
  # by the user, for example with Phoenix LiveDashboard.
  defp process_runtime_hook(hooks, name, start, content, end_, meta) do
    {:tag, "script", attrs, start_meta} = start
    {:text, content, content_meta} = content

    hashed_name = hashed_hook_name(meta)

    # remove type="text/phx-hook"
    attrs =
      for {name, value, meta} <- attrs, name not in ["type", "name"], do: {name, value, meta}

    # add new special attrs
    attr_meta = %{delimiter: ?"}

    attrs = [
      {"data-phx-runtime-hook", {:string, hashed_name, attr_meta}, %{}}
      | attrs
    ]

    # inject runtime hook into window
    content = """
    window["phx_hook_#{hashed_name}"] = function() {
      #{content}
    }
    """

    hooks = Map.put(hooks, name, %{runtime: true, name: hashed_name})

    # the line and column metadata are not correct any more,
    # but we don't need them for rendering
    {hooks, {:tag, "script", attrs, start_meta}, {:text, content, content_meta}, end_}
  end

  # A bundled hook is extracted at compile time and stripped from the DOM.
  # It is the responsibility of the user to import the extracted hook manifest
  # into their JS bundle.
  # New apps (mix phx.new) automatically include an empty manifest
  # (assets/js/hooks/index.js) therefore colocated hooks work out of the box.
  defp process_bundled_hook(hooks, name, raw_content, meta) do
    %{file: file, line: line, column: column} = meta
    hashed_name = hashed_hook_name(meta)

    content =
      "// #{Path.relative_to_cwd(file)}:#{line}:#{column}\n" <> raw_content

    hooks = Map.put(hooks, name, %{bundled: true, name: hashed_name, content: content})
    hooks
  end

  defp rewrite_hook_names(hooks, tokens) do
    for token <- tokens, reduce: [] do
      acc ->
        case token do
          {:tag, name, attrs, meta} ->
            [{:tag, name, rewrite_hook_attrs(hooks, attrs), meta} | acc]

          {:local_component, name, attrs, meta} ->
            [{:local_component, name, rewrite_hook_attrs(hooks, attrs), meta} | acc]

          {:remote_component, name, attrs, meta} ->
            [{:remote_component, name, rewrite_hook_attrs(hooks, attrs), meta} | acc]

          other ->
            [other | acc]
        end
    end
  end

  defp rewrite_hook_attrs(hooks, attrs) do
    Enum.map(attrs, fn
      {"phx-hook", {:string, name, meta1}, meta2} ->
        if is_map_key(hooks, name) do
          {"phx-hook", {:string, hooks[name].name, meta1}, meta2}
        else
          {"phx-hook", {:string, name, meta1}, meta2}
        end

      {attr, value, meta} ->
        {attr, value, meta}
    end)
  end

  defp write_hooks_and_manifest(hooks) do
    for {_name, %{bundled: true, name: js_filename, content: script_content}} <- hooks do
      dir = "assets/js/hooks"
      manifest_path = colocated_hooks_manifest()
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
          &apply(Path, :relative_to, [&1, &2, force: true])
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
        File.write!(manifest_path, """
        let hooks = {}
        export default hooks
        """)
      end

      manifest = File.read!(manifest_path)

      File.open(manifest_path, [:append], fn file ->
        if !String.contains?(manifest, js_filename) do
          IO.puts("Add hook to #{manifest_path}")

          IO.binwrite(
            file,
            ~s|\nimport hook_#{js_filename} from "#{js_full_path}"; hooks["#{js_filename}"] = hook_#{js_filename};|
          )
        end
      end)

      IO.puts("Write hook to #{js_path}")
    end
  end

  @doc false
  def prune_hooks(file) do
    # This is executed whenever a file that uses Phoenix.Component is compiled
    # and strips all hooks, because they will be re-injected anyway.
    #
    # This ensures that old hooks are properly removed when they are no longer part
    # of the source.
    #
    # See `Phoenix.Component.__using__/1`
    hashed_name = hashed_script_name(file)
    hooks_dir = Path.expand("assets/js/hooks", File.cwd!())
    manifest_path = colocated_hooks_manifest()

    case File.ls(hooks_dir) do
      {:ok, hooks} ->
        for hook_basename <- hooks do
          case String.split(hook_basename, "_") do
            [^hashed_name | _] ->
              File.rm!(IO.inspect(Path.join(hooks_dir, hook_basename), label: "Pruning"))

              if File.exists?(manifest_path) do
                new_file =
                  manifest_path
                  |> File.stream!()
                  |> Enum.filter(fn line -> !String.contains?(line, hashed_name) end)
                  |> Enum.join("")
                  |> String.trim()

                File.write!(manifest_path, new_file)
              end

            _ ->
              :noop
          end
        end

      _ ->
        :noop
    end

    nil
  end
end
