defmodule Phoenix.LiveView.KeyedComprehension do
  @moduledoc false

  use Phoenix.LiveComponent

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
end
