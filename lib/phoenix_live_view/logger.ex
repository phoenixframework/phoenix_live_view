defmodule Phoenix.LiveView.Logger do
  @moduledoc false

  import Phoenix.Logger, only: [duration: 1]

  require Logger

  @doc false
  def install do
    handlers = %{
      [:phoenix, :live_view, :mount, :stop] => &__MODULE__.live_view_mount_stop/4,
      [:phoenix, :live_view, :handle_params, :stop] => &__MODULE__.live_view_handle_params_stop/4,
      [:phoenix, :live_view, :handle_event, :stop] => &__MODULE__.live_view_handle_event_stop/4,
      [:phoenix, :live_view, :handle_info, :stop] => &__MODULE__.live_view_handle_info_stop/4,
      [:phoenix, :live_component, :handle_event, :stop] =>
        &__MODULE__.live_component_handle_event_stop/4
    }

    for {key, fun} <- handlers do
      :telemetry.attach({__MODULE__, key}, key, fun, :ok)
    end
  end

  defp log_level(socket) do
    socket.view.__live__()[:log]
  end

  @doc false
  def live_view_mount_stop(_event, measurement, metadata, _config) do
    %{socket: socket, params: params, session: session, uri: _uri} = metadata
    %{duration: duration} = measurement
    level = log_level(socket)

    Logger.log(level, fn ->
      [
        "MOUNTED ",
        inspect(socket.view),
        " in ",
        duration(duration),
        ?\n,
        "  Parameters: ",
        inspect(params),
        ?\n,
        "  Session: ",
        inspect(session)
      ]
    end)

    :ok
  end

  @doc false
  def live_view_handle_params_stop(_event, measurement, metadata, _config) do
    %{socket: socket, params: params, uri: _uri} = metadata
    %{duration: duration} = measurement
    level = log_level(socket)

    Logger.log(level, fn ->
      [
        "HANDLED PARAMS in ",
        duration(duration),
        ?\n,
        "  View: ",
        inspect(socket.view),
        ?\n,
        "  Parameters: ",
        inspect(params)
      ]
    end)

    :ok
  end

  @doc false
  def live_view_handle_event_stop(_event, measurement, metadata, _config) do
    %{socket: socket, event: event, params: params} = metadata
    %{duration: duration} = measurement
    level = log_level(socket)

    Logger.log(level, fn ->
      [
        "HANDLED EVENT in ",
        duration(duration),
        ?\n,
        "  View: ",
        inspect(socket.view),
        ?\n,
        "  Event: ",
        inspect(event),
        ?\n,
        "  Parameters: ",
        inspect(params)
      ]
    end)

    :ok
  end

  @doc false
  def live_view_handle_info_stop(_event, measurement, metadata, _config) do
    %{socket: socket, message: message} = metadata
    %{duration: duration} = measurement
    level = log_level(socket)

    Logger.log(level, fn ->
      [
        "HANDLED INFO in ",
        duration(duration),
        ?\n,
        "  View: ",
        inspect(socket.view),
        ?\n,
        "  Message: ",
        inspect(message)
      ]
    end)

    :ok
  end

  @doc false
  def live_component_handle_event_stop(_event, measurement, metadata, _config) do
    %{socket: socket, component: component, event: event, params: params} = metadata
    %{duration: duration} = measurement
    level = log_level(socket)

    Logger.log(level, fn ->
      [
        "HANDLED EVENT in ",
        duration(duration),
        ?\n,
        "  Component: ",
        inspect(component),
        ?\n,
        "  View: ",
        inspect(socket.view),
        ?\n,
        "  Event: ",
        inspect(event),
        ?\n,
        "  Parameters: ",
        inspect(params)
      ]
    end)

    :ok
  end
end
