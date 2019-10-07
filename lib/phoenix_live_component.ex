defmodule Phoenix.LiveComponent do
  defmacro __using__(_) do
    quote do
      import Phoenix.LiveView

      @doc false
      def __live__, do: %{kind: :component}
    end
  end
end
