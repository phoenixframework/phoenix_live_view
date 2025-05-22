defmodule Mix.Tasks.Compile.PhoenixLiveView do
  @moduledoc """
  A LiveView compiler for HEEx macro components (at the moment, only Colocated Hooks).

  You must add it to your `mix.exs` as:

      compilers: Mix.compilers() ++ [:phoenix_live_view]

  """
  use Mix.Task

  @recursive true

  @doc false
  def run(_args) do
    Mix.Task.Compiler.after_compiler(:elixir, fn
      {:noop, diagnostics} ->
        {:noop, diagnostics}

      {status, dignostics} ->
        compile()
        {status, dignostics}
    end)

    :noop
  end

  defp compile do
    Phoenix.LiveView.ColocatedJS.compile()
  end
end
