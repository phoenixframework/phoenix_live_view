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

defmodule Mix.Tasks.Compile.WithoutDiagnostics do
  import Phoenix.LiveView.Helpers


  def subtitle(assigns), do: ~H[<%= @str %>]
end

defmodule Mix.Tasks.Compile.WithDiagnostics do
  use Phoenix.Component

  alias Mix.Tasks.Compile.WithoutDiagnostics

  attr :str, :string
  def title(assigns), do: ~H[<WithoutDiagnostics.subtitle str={@str}/>]
end
