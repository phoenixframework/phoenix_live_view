defmodule Phoenix.LiveView.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Phoenix.LiveView.Logger.install()
    Supervisor.start_link([], strategy: :one_for_one, name: Phoenix.LiveView.Supervisor)
  end
end
