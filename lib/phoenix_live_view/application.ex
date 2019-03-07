defmodule Phoenix.LiveView.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {DynamicSupervisor, name: Phoenix.LiveView.DynamicSupervisor, strategy: :one_for_one},
      {Registry, keys: :unique, name: Phoenix.LiveView.Registry}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Phoenix.LiveView.Supervisor)
  end
end
