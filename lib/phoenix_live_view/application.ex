defmodule Phoenix.LiveView.Application do
  @moduledoc false
  use Application

  require Logger

  # TODO: Remove this whole module once we require Elixir v1.12+.
  def start(_, _) do
    unless Code.ensure_loaded?(:counters) do
      Logger.error("Phoenix.LiveView requires Erlang/OTP 21.2+")
      raise "Phoenix.LiveView requires Erlang/OTP 21.2+"
    end

    Supervisor.start_link([], strategy: :one_for_one)
  end
end
