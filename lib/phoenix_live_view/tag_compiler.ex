defmodule Phoenix.LiveView.TagCompiler do
  @moduledoc """
  TODO
  """

  alias Phoenix.LiveView.TagCompiler

  @doc """
  Compiles a HEEx template into Elixir code.

  TODO
  """
  def compile(source, opts \\ []) do
    opts =
      Keyword.merge(
        [
          tag_handler: Phoenix.LiveView.HTMLEngine,
          engine: Phoenix.LiveView.Engine,
          source: source,
          trim_eex: false
        ],
        opts
      )

    source
    |> TagCompiler.Parser.parse!(opts)
    |> TagCompiler.Compiler.compile(opts)
  end
end
