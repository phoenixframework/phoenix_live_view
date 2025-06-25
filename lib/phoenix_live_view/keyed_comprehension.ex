defmodule Phoenix.LiveView.KeyedComprehension do
  @moduledoc """
  The struct returned by keyed for-comprehensions in .heex templates.

  It is a subset of a Comprehension struct where all of its entries
  are components.
  """
  use Phoenix.LiveComponent

  defstruct [:entries, :fingerprint, :stream]

  @type t :: %__MODULE__{
          stream: list() | nil,
          entries: [Phoenix.LiveView.Component.t()],
          fingerprint: term()
        }

  @impl true
  def update(assigns, socket) do
    # we assign all entries from vars_changed to change-track them inside
    # the LiveComponent
    socket =
      Enum.reduce(assigns.vars_changed, socket, fn {key, value}, socket ->
        assign(socket, key, value)
      end)

    socket
    |> assign(:render, assigns.render)
    |> assign(:keys, Map.keys(assigns.vars_changed))
    |> then(&{:ok, &1})
  end

  @impl true
  def render(assigns) do
    vars_changed = Map.take(assigns.__changed__, assigns.keys)
    assigns.render.(vars_changed)
  end

  defimpl Phoenix.HTML.Safe do
    def to_iodata(%Phoenix.LiveView.KeyedComprehension{entries: entries}) do
      for entry <- entries, do: Phoenix.HTML.Safe.to_iodata(entry)
    end
  end
end
