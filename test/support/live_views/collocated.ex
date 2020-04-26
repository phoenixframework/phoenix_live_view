defmodule Phoenix.LiveViewTest.CollocatedLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, world: "world")}
  end
end

defmodule Phoenix.LiveViewTest.CollocatedLiveSpecifyingExtension do
  use Phoenix.LiveView, collocated_extension: ".foo"

  def mount(_params, _session, socket) do
    {:ok, assign(socket, world: "world")}
  end
end

defmodule Phoenix.LiveViewTest.CollocatedLiveSpecifyingEngine do
  use Phoenix.LiveView, collocated_engine: Phoenix.LiveViewTest.FooEngine

  def mount(_params, _session, socket) do
    {:ok, assign(socket, world: "world")}
  end
end

defmodule Phoenix.LiveViewTest.CollocatedComponent do
  use Phoenix.LiveComponent
end

defmodule Phoenix.LiveViewTest.CollocatedComponentSpecifyingExtension do
  use Phoenix.LiveComponent, collocated_extension: ".foo"
end

defmodule Phoenix.LiveViewTest.CollocatedComponentSpecifyingEngine do
  use Phoenix.LiveComponent, collocated_engine: Phoenix.LiveViewTest.FooEngine
end
