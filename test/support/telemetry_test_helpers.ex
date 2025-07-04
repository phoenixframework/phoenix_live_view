defmodule Phoenix.LiveView.TelemetryTestHelpers do
  @moduledoc false

  import ExUnit.Callbacks, only: [on_exit: 1]

  def attach_telemetry(prefix) when is_list(prefix) do
    attach_telemetries([prefix])
  end

  def attach_telemetries(prefixes) when is_list(prefixes) do
    unique_name = :"PID#{System.unique_integer()}"
    Process.register(self(), unique_name)

    for prefix <- prefixes, suffix <- [:start, :stop, :exception] do
      event = prefix ++ [suffix]
      handler_id = {unique_name, event}

      :telemetry.attach(
        handler_id,
        event,
        fn event, measurements, metadata, :none ->
          send(unique_name, {:event, event, measurements, metadata})
        end,
        :none
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)
    end
  end
end
