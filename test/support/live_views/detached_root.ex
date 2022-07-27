defmodule Phoenix.LiveViewTest.DetachedRootLive do
  # for testing that live views have similar root-pathing capabilities as
  # Phoenix.View (see: https://hexdocs.pm/phoenix_view/Phoenix.View.html)

  use Phoenix.LiveView, root: "test/support/live_views/detached_root"

  def mount(_params, _session, socket) do
    {:ok, assign(socket, world: "world")}
  end
end

defmodule Phoenix.LiveViewTest.DetachedRootComponent do
  # for testing that live components have similar root-pathing capabilities as
  # Phoenix.View (see: https://hexdocs.pm/phoenix_view/Phoenix.View.html)

  use Phoenix.LiveComponent, root: "test/support/live_views/detached_root"
end

defmodule Phoenix.LiveViewTest.RootAndPathLive do
  # for testing that live views have similar root-pathing capabilities as
  # Phoenix.View (see: https://hexdocs.pm/phoenix_view/Phoenix.View.html)

  use Phoenix.LiveView, root: "test/support/live_views/detached_root", path: "path_live.html"

  def mount(_params, _session, socket) do
    {:ok, assign(socket, world: "world")}
  end
end

defmodule Phoenix.LiveViewTest.RootAndPathComponent do
  # for testing that live components have similar root-pathing capabilities as
  # Phoenix.View (see: https://hexdocs.pm/phoenix_view/Phoenix.View.html)

  use Phoenix.LiveComponent,
    root: "test/support/live_views/detached_root",
    path: "path_component.html"
end
