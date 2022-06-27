defmodule Phoenix.LiveView.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    if Application.get_env(:phoenix_live_view, :logger, true) do
      Phoenix.LiveView.Logger.install()
    end

    Supervisor.start_link([], strategy: :one_for_one, name: Phoenix.LiveView.Supervisor)
  end
end
