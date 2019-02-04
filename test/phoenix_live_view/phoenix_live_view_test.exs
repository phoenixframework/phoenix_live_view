defmodule Phoenix.LiveView.LiveViewTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  defmodule CounterView do
    use Phoenix.LiveView

    def render(assigns) do
      ~L"""
      The count is: <%= @val %>
      <button phx-click="dec">-</button>
      <button phx-click="inc">+</button>
      """
    end

    def mount(_session, socket) do
      if connected?(socket) do
        {:ok, assign(socket, :val, 1)}
      else
        {:ok, assign(socket, :val, 0)}
      end
    end

    def handle_event("inc", _, socket), do: {:noreply, update(socket, :val, &(&1 + 1))}

    def handle_event("dec", _, socket), do: {:noreply, update(socket, :val, &(&1 - 1))}

    def handle_info({:set, val}, socket) do
      {:noreply, assign(socket, :val, val)}
    end
  end

  setup do
    {:ok, view, html} = live_render_static(CounterView, session: %{})
    {:ok, view: view, html: html}
  end

  describe "rendering" do
    test "live render with valid session", %{view: view, html: html} do
      assert html =~ """
             The count is: 0
             <button phx-click="dec">-</button>
             <button phx-click="inc">+</button>
             """

      {:ok, view, html} = live_render_connect(view)
      assert is_pid(view.pid)

      assert html =~ """
             The count is: 1
             <button phx-click="dec">-</button>
             <button phx-click="inc">+</button>
             """
    end

    test "live render with bad session", %{view: view} do
      assert {:error, %{reason: "badsession"}} =
               live_render_connect(%Phoenix.LiveViewTest.View{view | token: "bad"})
    end
  end

  describe "messaging callbacks" do
    test "handle_info", %{view: view} do
      {:ok, view, _html} = live_render_connect(view)

      send(view.pid, {:set, 10})
      send(view.pid, {:set, 11})
      send(view.pid, {:set, 12})

      assert_render view, """
             The count is: 10
             <button phx-click="dec">-</button>
             <button phx-click="inc">+</button>
             """

      assert_render view, ~r/The count is: 12/

      assert_render view, """
             The count is: 11
             <button phx-click="dec">-</button>
             <button phx-click="inc">+</button>
             """
    end
  end
end
