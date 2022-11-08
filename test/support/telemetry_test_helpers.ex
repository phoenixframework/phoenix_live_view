defmodule Phoenix.LiveView.TelemetryTestHelpers do
  @moduledoc false

  import ExUnit.Callbacks, only: [on_exit: 1]

  def attach_telemetry(prefix) when is_list(prefix) do
    unique_name = :"PID#{System.unique_integer()}"
    Process.register(self(), unique_name)

    for suffix <- [:start, :stop, :exception] do
      :telemetry.attach(
        {suffix, unique_name},
        prefix ++ [suffix],
        fn event, measurements, metadata, :none ->
          send(unique_name, {:event, event, measurements, metadata})
        end,
        :none
      )
    end

    on_exit(fn ->
      for suffix <- [:start, :stop] do
        :telemetry.detach({suffix, unique_name})
      end
    end)
  end
end
