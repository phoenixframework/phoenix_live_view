defmodule Mix.Tasks.Compile.PhoenixLiveViewTest.Comp1 do
  use Phoenix.Component

  attr :name, :any, required: true
  def func(assigns), do: ~H[]

  def render1(assigns) do
    ~H"""
    <.func/>
    """
  end

  def render2(assigns) do
    ~H"""
    <.func/>
    """
  end
end

defmodule Mix.Tasks.Compile.PhoenixLiveViewTest.Comp2 do
  use Phoenix.Component

  attr :name, :any, required: true
  def func(assigns), do: ~H[]

  def render1(assigns) do
    ~H"""
    <.func/>
    """
  end

  def render2(assigns) do
    ~H"""
    <.func/>
    """
  end
end
