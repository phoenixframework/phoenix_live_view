defmodule Mix.Tasks.Compile.PhoenixLiveView do
  @moduledoc """
  A LiveView compiler for HEEx macro components.

  Right now, only `Phoenix.LiveView.ColocatedHook`, `Phoenix.LiveView.ColocatedJS`,
  and `Phoenix.LiveView.ColocatedCSS` are handled.

  You must add it to your `mix.exs` as:

      compilers: [:phoenix_live_view] ++ Mix.compilers()

  """
  use Mix.Task.Compiler

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
    Phoenix.LiveView.ColocatedCSS.compile()
  end
end
