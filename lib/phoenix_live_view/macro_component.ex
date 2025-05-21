defmodule Phoenix.LiveView.MacroComponent do
  @type tag :: binary()
  @type attributes :: %{atom() => term()}
  @type children :: [heex_ast() | String.t()]
  @type heex_ast :: {tag(), attributes(), children()}

  @callback call(heex_ast :: heex_ast()) :: heex_ast()

  @callback cleanup() :: :ok

  defmacro __using__(_opts) do
    quote do
      @behaviour Phoenix.LiveView.MacroComponent

      @impl Phoenix.LiveView.MacroComponent
      def cleanup, do: :ok

      defoverridable cleanup: 0
    end
  end
end
