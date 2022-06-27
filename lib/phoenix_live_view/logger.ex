defmodule Phoenix.LiveView.Logger do
  @moduledoc """
  Instrumenter to handle logging of `Phoenix.LiveView` and `Phoenix.LiveComponent` life-cycle events.

  ## Installation

  By default, the logger is installed when Live View starts.

  To disable logging entirely, add the following to your `config/config.exs`:

  ```elixir
  config :phoenix_live_view, :logger, false
  ```

  ## Configuration

  The log level is configurable for each Live View:

  ```elixir
  use Phoenix.LiveView, log: :debug
  ```

  To disable logging for the Live View:

  ```elixir
  use Phoenix.LiveView, log: false
  ```

  By default, all life-cycle events are logged as `:info`.

  ## Telemetry

  The following `Phoenix.LiveView` and `Phoenix.LiveComponent` events are logged:

  - `[:phoenix, :live_view, :mount, :stop]`
  - `[:phoenix, :live_view, :handle_params, :stop]`
  - `[:phoenix, :live_view, :handle_event, :stop]`
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
      [:phoenix, :live_view, :mount, :stop] => &__MODULE__.live_view_mount_stop/4,
      [:phoenix, :live_view, :handle_params, :stop] => &__MODULE__.live_view_handle_params_stop/4,
      [:phoenix, :live_view, :handle_event, :stop] => &__MODULE__.live_view_handle_event_stop/4,
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

    # avoid duplicate logs by skipping dead render events
    if connected?(socket) do
      level = log_level(socket)

      Logger.log(level, fn ->
        [
          "MOUNTED ",
          inspect(socket.view),
          " in ",
          duration(duration),
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
  def live_view_handle_params_stop(_event, measurement, metadata, _config) do
    %{socket: socket, params: params, uri: _uri} = metadata
    %{duration: duration} = measurement
    level = log_level(socket)

    # avoid duplicate logs by skipping dead render events
    if connected?(socket) do
      Logger.log(level, fn ->
        [
          "HANDLED PARAMS in ",
          duration(duration),
          ?\n,
          "  View: ",
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
        inspect(filter_values(params))
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
        inspect(filter_values(params))
      ]
    end)

    :ok
  end
end
