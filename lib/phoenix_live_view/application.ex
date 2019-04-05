defmodule Phoenix.LiveView.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    Supervisor.start_link(
      [
        {DynamicSupervisor, strategy: :one_for_one, name: Phoenix.LiveView.DynamicSupervisor},
      ],
      strategy: :one_for_one,
      name: Phoenix.LiveView.Supervisor
    )
  end
end
