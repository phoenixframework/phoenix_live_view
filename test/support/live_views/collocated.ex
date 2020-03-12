defmodule Phoenix.LiveViewTest.CollocatedLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, world: "world")}
  end
end

defmodule Phoenix.LiveViewTest.CollocatedComponent do
  use Phoenix.LiveComponent
end
