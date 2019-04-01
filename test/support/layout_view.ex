defmodule Phoenix.LayoutView do
  use Phoenix.View, root: ""

  def render("app.html", assigns) do
    ["LAYOUT", render(assigns.view_module, assigns.view_template, assigns)]
  end
end
