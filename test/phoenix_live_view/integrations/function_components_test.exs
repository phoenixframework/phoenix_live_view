defmodule Phoenix.LiveView.FunctionComponentsTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.Endpoint

  @endpoint Endpoint

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  defmodule RenderOnly do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~L"""
      <%= component &hello/1, name: "WORLD" %>
      """
    end

    defp hello(assigns) do
      ~L"""
      Hello <%= @name %>
      """
    end
  end

  defmodule RenderWithBlock do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~L"""
      <%= component &hello/1, name: "WORLD" do %>
      THE INNER BLOCK
      <% end %>
      """
    end

    def hello(assigns) do
      ~L"""
      Hello <%= @name %>
      <%= render_block @inner_block %>
      """
    end
  end

  defmodule RenderWithBlockPassingArgs do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~L"""
      <%= component &hello/1, name: "WORLD" do %>
      <% [arg1: arg1, arg2: arg2] -> %>
      THE INNER BLOCK
      ARG1: <%= arg1 %>
      ARG2: <%= arg2 %>
      <% end %>
      """
    end

    def hello(assigns) do
      ~L"""
      Hello <%= @name %>
      <%= render_block @inner_block, arg1: 1, arg2: 2 %>
      """
    end
  end

  defmodule RenderWithLiveComponent do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~L"""
      <%= component &render_with_live_component/1 %>
      """
    end

    def render_with_live_component(assigns) do
      ~L"""
      COMPONENT
      <%= live_component RenderWithBlockPassingArgs %>
      """
    end
  end

  test "render component" do
    assert render_component(RenderOnly, %{}) == """
    Hello WORLD

    """
  end

  test "render component with block" do
    assert render_component(RenderWithBlock, %{}) == """
    Hello WORLD

    THE INNER BLOCK


    """
  end

  test "render component with block passing args" do
    assert render_component(RenderWithBlockPassingArgs, %{}) == """
    Hello WORLD

    THE INNER BLOCK
    ARG1: 1
    ARG2: 2


    """
  end

  test "render component with live_component" do
    assert render_component(RenderWithLiveComponent, %{}) == """
    COMPONENT
    Hello WORLD

    THE INNER BLOCK
    ARG1: 1
    ARG2: 2




    """
  end
end
