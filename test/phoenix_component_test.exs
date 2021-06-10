defmodule Phoenix.ComponentTest do
  use ExUnit.Case, async: true

  use Phoenix.Component

  defp h2s(template) do
    template
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp hello(assigns) do
    ~H"""
    Hello <%= @name %>
    """
  end

  test "renders component" do
    assigns = %{}

    assert h2s(~H"""
           <%= component &hello/1, name: "WORLD" %>
           """) == """
           Hello WORLD

           """
  end

  def hello_with_block(assigns) do
    ~H"""
    Hello <%= @name %>
    <%= render_block @inner_block %>
    """
  end

  test "renders component with block" do
    assigns = %{}

    assert h2s(~H"""
           <%= component &hello_with_block/1, name: "WORLD" do %>
           THE INNER BLOCK
           <% end %>
           """) == """
           Hello WORLD

           THE INNER BLOCK


           """
  end

  test "renders component with block from content_tag" do
    assigns = %{}

    assert h2s(~H"""
           <%= Phoenix.HTML.Tag.content_tag :div do %>
           <%= component &hello_with_block/1, name: "WORLD" do %>
           THE INNER BLOCK
           <% end %>
           <% end %>
           """) == """
           <div>
           Hello WORLD

           THE INNER BLOCK


           </div>
           """
  end

  defp hello_with_block_args(assigns) do
    ~H"""
    Hello <%= @name %>
    <%= render_block @inner_block, arg1: 1, arg2: 2 %>
    """
  end

  test "render component with block passing args" do
    assigns = %{}

    assert h2s(~H"""
           <%= component &hello_with_block_args/1, name: "WORLD" do %>
           <% [arg1: arg1, arg2: arg2] -> %>
           THE INNER BLOCK
           ARG1: <%= arg1 %>
           ARG2: <%= arg2 %>
           <% end %>
           """) == """
           Hello WORLD

           THE INNER BLOCK
           ARG1: 1
           ARG2: 2


           """
  end
end
