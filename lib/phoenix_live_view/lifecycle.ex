defmodule Phoenix.LiveView.Lifecycle do
  @moduledoc false
  alias Phoenix.LiveView.{Socket, Utils}

  @lifecycle :lifecycle

  @type hook :: map()

  @type t :: %__MODULE__{
          handle_event: [hook],
          handle_info: [hook],
          handle_params: [hook],
          after_render: [hook],
          mount: [hook]
        }

  defstruct handle_event: [], handle_info: [], handle_params: [], mount: [], after_render: []

  @doc """
  Returns a map of infos about the lifecycle stage for the given `view`.
  """
  def stage_info(%Socket{} = socket, view, stage, arity) do
    callbacks? = callbacks?(socket, stage)
    exported? = function_exported?(view, stage, arity)

    %{
      any?: callbacks? or exported?,
      callbacks?: callbacks?,
      exported?: exported?
    }
  end

  defp callbacks?(%Socket{private: %{@lifecycle => lifecycle}}, stage)
       when stage in [:handle_event, :handle_info, :handle_params, :mount] do
    lifecycle |> Map.fetch!(stage) |> Kernel.!=([])
  end

  def attach_hook(%Socket{router: nil}, id, :handle_params, _fun) do
    raise "cannot attach hook with id #{inspect(id)} on :handle_params because" <>
            " the view was not mounted at the router with the live/3 macro"
  end

  def attach_hook(%Socket{} = socket, id, stage, fun)
      when stage in [:handle_event, :handle_info, :handle_params, :after_render] do
    lifecycle = lifecycle(socket, stage)
    hook = hook!(id, stage, fun)
    existing = Enum.find(Map.fetch!(lifecycle, stage), &(&1.id == id))

    if existing do
      raise ArgumentError, """
      existing hook #{inspect(hook.id)} already attached on #{inspect(hook.stage)}.
      """
    end

    update_lifecycle(socket, stage, fn hooks ->
      hooks ++ [hook]
    end)
  end

  def attach_hook(%Socket{}, _id, stage, _fun) do
    raise ArgumentError, """
    invalid lifecycle event provided to attach_hook.

    Expected one of: :handle_event | :handle_info | :handle_params

    Got: #{inspect(stage)}
    """
  end

  def detach_hook(%Socket{} = socket, id, stage)
      when stage in [:handle_event, :handle_info, :handle_params, :after_render] do
    update_lifecycle(socket, stage, fn hooks ->
      for hook <- hooks, hook.id != id, do: hook
    end)
  end

  def detach_hook(%Socket{}, _id, stage) do
    raise ArgumentError, """
    invalid lifecycle event provided to detach_hook.

    Expected one of: :handle_event | :handle_info | :handle_params

    Got: #{inspect(stage)}
    """
  end

  defp lifecycle(socket, stage) do
    if Utils.cid(socket) && stage not in [:after_render] do
      raise ArgumentError, "lifecycle hooks are not supported on stateful components."
    end

    Map.fetch!(socket.private, @lifecycle)
  end

  defp update_lifecycle(socket, stage, fun) do
    lifecycle = lifecycle(socket, stage)
    new_lifecycle = Map.update!(lifecycle, stage, fun)
    put_lifecycle(socket, new_lifecycle)
  end

  defp put_lifecycle(socket, lifecycle) do
    put_private(socket, @lifecycle, lifecycle)
  end

  defp put_private(%Socket{private: private} = socket, key, value) when is_atom(key) do
    %{socket | private: Map.put(private, key, value)}
  end

  @doc false
  def on_mount(_view, {module, arg}) when is_atom(module) do
    mount_hook!({module, arg})
  end

  def on_mount(_view, module) when is_atom(module) do
    mount_hook!({module, :default})
  end

  def on_mount(view, result) do
    raise ArgumentError, """
    invalid on_mount hook declared in #{inspect(view)}.

    Expected one of:

        Module
        {Module, arg}

    Got: #{inspect(result)}
    """
  end

  defp mount_hook!({mod, _arg} = id) do
    hook!(id, :mount, Function.capture(mod, :on_mount, 4))
  end

  defp hook!(id, stage, fun) when is_atom(stage) and is_function(fun) do
    %{id: id, stage: stage, function: fun}
  end

  # Lifecycle Event API

  @doc false
  def mount(_view, hooks) when is_list(hooks) do
    %__MODULE__{mount: Enum.reverse(hooks)}
  end

  @doc false
  def mount(params, session, %Socket{private: %{@lifecycle => lifecycle}} = socket) do
    reduce_socket(lifecycle.mount, socket, fn %{id: {_mod, arg}} = hook, acc ->
      case hook.function.(arg, params, session, acc) do
        {:halt, %Socket{redirected: nil}} ->
          raise_halt_without_redirect!(hook)

        {:cont, %Socket{redirected: to}} when not is_nil(to) ->
          raise_continue_with_redirect!(hook)

        ok ->
          ok
      end
    end)
  end

  @doc false
  def handle_event(event, val, %Socket{private: %{@lifecycle => lifecycle}} = socket) do
    reduce_handle_event(lifecycle.handle_event, socket, fn hook, acc ->
      hook.function.(event, val, acc)
    end)
  end

  defp reduce_handle_event([hook | hooks], acc, function) do
    case function.(hook, acc) do
      {:cont, %Socket{} = socket} -> reduce_handle_event(hooks, socket, function)
      {:halt, %Socket{} = socket} -> {:halt, socket}
      {:halt, reply, %Socket{} = socket} -> {:halt, reply, socket}
      other -> bad_lifecycle_response!(other, hook)
    end
  end

  defp reduce_handle_event([], acc, _function), do: {:cont, acc}

  @doc false
  def handle_params(params, uri, %Socket{private: %{@lifecycle => lifecycle}} = socket) do
    reduce_socket(lifecycle.handle_params, socket, fn hook, acc ->
      hook.function.(params, uri, acc)
    end)
  end

  @doc false
  def handle_info(msg, %Socket{private: %{@lifecycle => lifecycle}} = socket) do
    reduce_socket(lifecycle.handle_info, socket, fn hook, acc ->
      hook.function.(msg, acc)
    end)
  end

  @doc false
  def after_render(%Socket{private: %{@lifecycle => lifecycle}} = socket) do
    {:cont, new_socket} =
      reduce_socket(lifecycle.after_render, socket, fn hook, acc ->
        case hook.function.(acc) do
          ^socket ->
            {:cont, socket}

          %Socket{} = new_socket ->
            {:cont, Utils.clear_changed(new_socket)}

          other ->
            raise ArgumentError,
                  "expected after_render hook to return a socket, got: #{inspect(other)}"
        end
      end)

    new_socket
  end

  defp reduce_socket([hook | hooks], acc, function) do
    case function.(hook, acc) do
      {:cont, %Socket{} = socket} -> reduce_socket(hooks, socket, function)
      {:halt, %Socket{} = socket} -> {:halt, socket}
      other -> bad_lifecycle_response!(other, hook)
    end
  end

  defp reduce_socket([], acc, _function), do: {:cont, acc}

  defp bad_lifecycle_response!(result, hook) do
    raise ArgumentError, """
    invalid return from hook #{inspect(hook.id)} for lifecycle event #{inspect(hook.stage)}.

    Expected one of:

        #{expected_return(hook)}

    Got: #{inspect(result)}
    """
  end

  defp expected_return(%{stage: :handle_event}) do
    """
    {:cont, %Socket{}}
    {:halt, %Socket{}}
    {:halt, map, %Socket{}}
    """
  end

  defp expected_return(_) do
    """
    {:cont, %Socket{}}
    {:halt, %Socket{}}
    """
  end

  defp raise_halt_without_redirect!(hook) do
    raise ArgumentError,
          "the hook #{inspect(hook.id)} for lifecycle event :mount attempted to halt without redirecting."
  end

  defp raise_continue_with_redirect!(hook) do
    raise ArgumentError,
          "the hook #{inspect(hook.id)} for lifecycle event :mount attempted to redirect without halting."
  end
end
