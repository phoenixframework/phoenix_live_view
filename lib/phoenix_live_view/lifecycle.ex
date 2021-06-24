defmodule Phoenix.LiveView.Hook do
  @moduledoc false

  if Version.match?(System.version(), ">= 1.8.0") do
    @derive {Inspect, only: [:id, :stage]}
  end

  defstruct id: nil, stage: nil, function: nil

  @type t :: %__MODULE__{
          id: term(),
          stage: :handle_event | :handle_info | :handle_params,
          function: function()
        }

  @spec new!(any, atom, fun) :: Phoenix.LiveView.Hook.t()
  def new!(id, stage, fun) when is_atom(stage) and is_function(fun) do
    %__MODULE__{id: id, stage: stage, function: fun}
  end
end

defmodule Phoenix.LiveView.Lifecycle do
  @moduledoc false
  alias Phoenix.LiveView.{Hook, Socket}

  @lifecycle :__lifecycle__

  @type t :: %__MODULE__{
          handle_event: [Hook.t()],
          handle_info: [Hook.t()],
          handle_params: [Hook.t()]
        }

  defstruct handle_event: [], handle_info: [], handle_params: []

  @doc """
  TODO

  `fun` must match the arity of the lifecycle event callback and
  it must return either {:cont, socket} or {:halt, socket}
  """
  def attach_hook(%Socket{} = socket, id, stage, fun)
      when stage in [:handle_event, :handle_info, :handle_params] do
    hook = Hook.new!(id, stage, fun)
    lifecycle = lifecycle(socket)
    existing = for h <- Map.fetch!(lifecycle, stage), h.id == id, do: h

    unless existing == [] do
      raise ArgumentError, """
      existing hook #{inspect(hook.id)} already attached on #{inspect(hook.stage)}.
      """
    end

    update_lifecycle(socket, stage, fn hooks ->
      hooks = Enum.reverse(hooks)
      Enum.reverse([hook | hooks])
    end)
  end

  def attach_hook(%Socket{}, _id, stage, _fun) do
    raise ArgumentError, """
    invalid lifecycle event provided to attach_hook.

    Expected one of: :handle_event | :handle_info | :handle_params

    Got: #{inspect(stage)}
    """
  end

  @doc """
  TODO

  Must match the id given to attach_hook/4
  """
  def detach_hook(%Socket{} = socket, id, stage)
      when stage in [:handle_event, :handle_info, :handle_params] do
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

  defp lifecycle(socket) do
    Map.get(socket.private, @lifecycle, %__MODULE__{})
  end

  defp update_lifecycle(socket, stage, fun) do
    lifecycle = lifecycle(socket)
    new_lifecycle = Map.update!(lifecycle, stage, fun)
    put_lifecycle(socket, new_lifecycle)
  end

  defp put_lifecycle(socket, lifecycle) do
    put_private(socket, @lifecycle, lifecycle)
  end

  defp put_private(%Socket{private: private} = socket, key, value) when is_atom(key) do
    %{socket | private: Map.put(private, key, value)}
  end
end
