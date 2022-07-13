defmodule Phoenix.LiveView.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    log_level = Application.get_env(:phoenix_live_view, :log_level, :info)

    if log_level do
      Phoenix.LiveView.Logger.install(log_level)
    end

    Supervisor.start_link([], strategy: :one_for_one, name: Phoenix.LiveView.Supervisor)
  end
end
