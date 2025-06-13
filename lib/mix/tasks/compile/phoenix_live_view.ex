defmodule Mix.Tasks.Compile.PhoenixLiveView do
  @moduledoc """
  A LiveView compiler for HEEx macro components.

  Right now, only `Phoenix.LiveView.ColocatedHook` and `Phoenix.LiveView.ColocatedJS`
  are handled.

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
  end
end
