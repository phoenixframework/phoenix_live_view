defmodule Phoenix.LiveView.Logger do
  @moduledoc """
  Instrumenter to handle logging of `Phoenix.LiveView` and `Phoenix.LiveComponent` life-cycle events.

  ## Installation

  The logger is installed automatically when Live View starts.
  By default, the log level is set to `:debug`.

  ## Module configuration

  The log level can be overridden for an individual Live View module:

      use Phoenix.LiveView, log: :debug

  To disable logging for an individual Live View module:

      use Phoenix.LiveView, log: false

  ## Telemetry

  The following `Phoenix.LiveView` and `Phoenix.LiveComponent` events are logged:

    - `[:phoenix, :live_view, :mount, :start]`
    - `[:phoenix, :live_view, :mount, :stop]`
    - `[:phoenix, :live_view, :handle_params, :start]`
    - `[:phoenix, :live_view, :handle_params, :stop]`
    - `[:phoenix, :live_view, :handle_event, :start]`
    - `[:phoenix, :live_view, :handle_event, :stop]`
    - `[:phoenix, :live_component, :handle_event, :start]`
    - `[:phoenix, :live_component, :handle_event, :stop]`

  See the [Telemetry](./guides/server/telemetry.md) guide for more information.

  ## Parameter filtering

  If enabled, `Phoenix.LiveView.Logger` will filter parameters based on the configuration of `Phoenix.Logger`.
  """

  import Phoenix.LiveView, only: [connected?: 1]

  import Phoenix.Logger, only: [duration: 1, filter_values: 1]

  require Logger

  @doc false
  def install do
    handlers = %{
      [:phoenix, :live_view, :mount, :start] => &__MODULE__.lv_mount_start/4,
      [:phoenix, :live_view, :mount, :stop] => &__MODULE__.lv_mount_stop/4,
      [:phoenix, :live_view, :handle_params, :start] => &__MODULE__.lv_handle_params_start/4,
      [:phoenix, :live_view, :handle_params, :stop] => &__MODULE__.lv_handle_params_stop/4,
      [:phoenix, :live_view, :handle_event, :start] => &__MODULE__.lv_handle_event_start/4,
      [:phoenix, :live_view, :handle_event, :stop] => &__MODULE__.lv_handle_event_stop/4,
      [:phoenix, :live_component, :handle_event, :start] => &__MODULE__.lc_handle_event_start/4,
      [:phoenix, :live_component, :handle_event, :stop] => &__MODULE__.lc_handle_event_stop/4
    }

    for {key, fun} <- handlers do
      :telemetry.attach({__MODULE__, key}, key, fun, %{})
    end
  end

  defp log_level(socket) do
    Map.fetch!(socket.view.__live__(), :log)
  end

  @doc false
  def lv_mount_start(_event, measurement, metadata, _config) do
    %{socket: socket, params: params, session: session, uri: _uri} = metadata
    %{system_time: _system_time} = measurement
    level = log_level(socket)

    if level && connected?(socket) do
      Logger.log(level, fn ->
        [
          "MOUNT ",
          inspect(socket.view),
          ?\n,
          "  Parameters: ",
          inspect(filter_values(params)),
          ?\n,
          "  Session: ",
          inspect(session)
        ]
      end)
    end

    :ok
  end

  @doc false
  def lv_mount_stop(_event, measurement, metadata, _config) do
    %{socket: socket, params: _params, session: _session, uri: _uri} = metadata
    %{duration: duration} = measurement
    level = log_level(socket)

    if level && connected?(socket) do
      Logger.log(level, fn ->
        [
          "Replied in ",
          duration(duration)
        ]
      end)
    end

    :ok
  end

  @doc false
  def lv_handle_params_start(_event, measurement, metadata, _config) do
    %{socket: socket, params: params, uri: _uri} = metadata
    %{system_time: _system_time} = measurement
    level = log_level(socket)

    if level && connected?(socket) do
      Logger.log(level, fn ->
        [
          "HANDLE PARAMS in ",
          inspect(socket.view),
          ?\n,
          "  Parameters: ",
          inspect(filter_values(params))
        ]
      end)
    end

    :ok
  end

  @doc false
  def lv_handle_params_stop(_event, measurement, metadata, _config) do
    %{socket: socket, params: _params, uri: _uri} = metadata
    %{duration: duration} = measurement
    level = log_level(socket)

    if level && connected?(socket) do
      Logger.log(level, fn ->
        [
          "Replied in ",
          duration(duration)
        ]
      end)
    end

    :ok
  end

  @doc false
  def lv_handle_event_start(_event, measurement, metadata, _config) do
    %{socket: socket, event: event, params: params} = metadata
    %{system_time: _system_time} = measurement
    level = log_level(socket)

    if level do
      Logger.log(level, fn ->
        [
          "HANDLE EVENT ",
          inspect(event),
          " in ",
          inspect(socket.view),
          ?\n,
          "  Parameters: ",
          inspect(filter_values(params))
        ]
      end)
    end

    :ok
  end

  @doc false
  def lv_handle_event_stop(_event, measurement, metadata, _config) do
    %{socket: socket, event: _event, params: _params} = metadata
    %{duration: duration} = measurement
    level = log_level(socket)

    if level do
      Logger.log(level, fn ->
        [
          "Replied in ",
          duration(duration)
        ]
      end)
    end

    :ok
  end

  @doc false
  def lc_handle_event_start(_event, measurement, metadata, _config) do
    %{socket: socket, component: component, event: event, params: params} = metadata
    %{system_time: _system_time} = measurement
    level = log_level(socket)

    if level do
      Logger.log(level, fn ->
        [
          "HANDLE EVENT ",
          inspect(event),
          " in ",
          inspect(socket.view),
          "\n  Component: ",
          inspect(component),
          "\n  Parameters: ",
          inspect(filter_values(params))
        ]
      end)
    end

    :ok
  end

  @doc false
  def lc_handle_event_stop(_event, measurement, metadata, _config) do
    %{socket: socket, component: _component, event: _event, params: _params} = metadata
    %{duration: duration} = measurement
    level = log_level(socket)

    if level do
      Logger.log(level, fn ->
        [
          "Replied in ",
          duration(duration)
        ]
      end)
    end

    :ok
  end
end
