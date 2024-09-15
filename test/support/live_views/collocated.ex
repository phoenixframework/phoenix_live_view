defmodule Phoenix.LiveViewTest.Support.CollocatedLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, world: "world")}
  end
end

defmodule Phoenix.LiveViewTest.Support.CollocatedComponent do
  use Phoenix.LiveComponent
end
