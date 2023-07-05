defmodule Phoenix.LiveView.SourceCodeInspector do
  @default_tooltip "Right click to go to source"
  @max_dom_id 2**63

  @doc false
  def enabled?() do
    case Process.get(:phoenix_live_view_enable_source_code_inspector, nil) do
      nil ->
        # The process dictionary doesn't define whether it's enabled or disabled.
        # Take the value from the config option
        Application.get_env(:phoenix_live_view, :enable_source_code_inspector, false)

      false ->
        # The process dictionary overrides the config option
        false

      true ->
        # The process dictionary overrides the config option
        true
    end
  end

  @doc """
  Runs the given function with the source code inspector enabled.
  This function can be used in async tests.

  After running the function, it restores the state of the source code inspector
  to the previous state.
  """
  def with_source_code_inspector_enabled(fun) do
    with_source_code_inspector(true, fun)
  end

  @doc """
  Runs the given function with the source code inspector disabled.
  This function can be used in async tests.

  After running the function, it restores the state of the source code inspector
  to the previous state.
  """
  def with_source_code_inspector_disabled(fun) do
    with_source_code_inspector(false, fun)
  end

  defp with_source_code_inspector(enabled, fun) do
    # Get the old value from the process dictionary.
    old_value = Process.get(:phoenix_live_view_enable_source_code_inspector, nil)
    # Make the source code inspector active for the current process
    Process.put(:phoenix_live_view_enable_source_code_inspector, enabled)

    try do
      fun.()
    after
      # Restore the previous state (which will probably be `nil`)
      Process.put(:phoenix_live_view_enable_source_code_inspector, old_value)
    end
  end

  @doc false
  def random_dom_id() do
    part1 = :rand.uniform(@max_dom_id) |> Integer.to_string(16)
    part2 = :rand.uniform(@max_dom_id) |> Integer.to_string(16)
    part1 <> part2
  end

  @doc false
  def tooltip() do
    Application.get_env(
      :phoenix_live_view,
      :source_code_inspector_tooltip,
      @default_tooltip
    )
  end

  @doc """
  Activate the source code inspector for the current process.
  """
  def activate_locally() do
    Process.put(:phoenix_live_view_enable_source_code_inspector, true)
  end

  @doc """
  Deactivate the source code inspector for the current process.
  """
  def deactivate_locally() do
    Process.put(:phoenix_live_view_enable_source_code_inspector, false)
  end

  @doc """
  Activate the source code inspector globally.
  """
  def activate() do
    Application.put_env(
      :phoenix_live_view,
      :enable_source_code_inspector,
      true
    )
  end

  @doc """
  Deactivate the source code inspector globally.
  """
  def deactivate() do
    Application.put_env(
      :phoenix_live_view,
      :enable_source_code_inspector,
      false
    )
  end

  def attributes(state, tag_meta, has_id_attr_test, has_phx_hook_test) do
    meta = %{line: tag_meta.line || 0, column: 0}

    inspector_value =
      quote do
        case unquote(__MODULE__).enabled?() do
          true -> "true"
          false -> nil
        end
      end

    id_value =
      quote do
        case unquote(__MODULE__).enabled?() and
              (not unquote(has_id_attr_test)) do
          true -> unquote(__MODULE__).random_dom_id()
          false -> nil
        end
      end

    phx_hook_value =
      quote do
        case unquote(__MODULE__).enabled?() and
              (not unquote(has_phx_hook_test)) do
          true -> "SourceCodeInspector"
          false -> nil
        end
      end

    file_value =
      quote do
        case unquote(__MODULE__).enabled?() do
          true -> unquote(state.caller.file)
          false -> nil
        end
      end

    line_value =
      quote do
        case unquote(__MODULE__).enabled?() do
          true -> unquote(tag_meta.line)
          false -> nil
        end
      end

    tooltip_value =
      quote do
        case unquote(__MODULE__).enabled?() do
          true -> unquote(__MODULE__).tooltip()
          false -> nil
        end
      end

    attrs = [
      make_attr("data-source-code-inspector", inspector_value, meta),
      make_attr("data-source-code-inspector-file", file_value, meta),
      make_attr("data-source-code-inspector-line", line_value, meta),
      make_attr("data-source-code-inspector-tooltip", tooltip_value, meta),
      make_attr("id", id_value, meta),
      make_attr("phx-hook", phx_hook_value, meta)
    ]

    attrs
  end

  defp make_attr(name, quoted_value, quoted_meta) do
    # Convert the AST into code because that's what the engine expects
    code = Macro.to_string(quoted_value)
    # Return an attribute with a dynamic expression for a value
    {name, {:expr, code, quoted_meta}, quoted_meta}
  end
end
