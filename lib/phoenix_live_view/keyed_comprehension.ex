defmodule Phoenix.LiveView.KeyedComprehension do
  @moduledoc false

  use Phoenix.LiveComponent

  def update(assigns, socket) do
    # we assign all entries from vars_changed to change-track them inside
    # the LiveComponent
    socket =
      Enum.reduce(assigns.vars_changed, socket, fn {key, value}, socket ->
        assign(socket, key, value)
      end)

    socket =
      socket
      |> assign(:render, assigns.render)
      |> assign(:keys, Map.keys(assigns.vars_changed))

    {:ok,
     render_with(socket, fn assigns ->
       vars_changed = Map.take(assigns.__changed__, assigns.keys)
       rendered = assigns.render.(vars_changed)
       # the engine ensures that this is valid
       %{rendered | root: true}
     end)}
  end
end
