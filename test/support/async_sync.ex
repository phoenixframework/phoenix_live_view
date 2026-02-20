defmodule Phoenix.LiveViewTest.Support.AsyncSync do
  def wait_for_async_ready_and_monitor(name) do
    receive do
      :async_ready -> :ok
    end

    async_ref = Process.monitor(name)
    send(name, :monitoring)

    receive do
      :monitoring_received -> :ok
    end

    async_ref
  end

  def register_and_sleep(notify_name, register_name) do
    Process.register(self(), register_name)
    send(notify_name, :async_ready)

    receive do
      :monitoring ->
        send(notify_name, :monitoring_received)
        Process.sleep(:infinity)
    end
  end
end
