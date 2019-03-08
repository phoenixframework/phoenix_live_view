defmodule Phoenix.LiveView.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    DynamicSupervisor.start_link(name: Phoenix.LiveView.DynamicSupervisor, strategy: :one_for_one)
  end
end
