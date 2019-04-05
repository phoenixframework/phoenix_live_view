defmodule Phoenix.LiveView.AssignNewTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.Endpoint

  defmodule ChildLive do
    use Phoenix.LiveView

    def render(assigns) do
      ~L"""
      child <%= @child_id %> name: <%= @current_user.name %>
      """
    end

    def mount(%{user_id: user_id, child: child_id}, socket) do
      {:ok,
       socket
       |> assign(:child_id, child_id)
       |> assign_new(:current_user, fn ->
         %{name: "user-from-child", id: user_id}
       end)}
    end
  end

  defmodule RootLive do
    use Phoenix.LiveView

    def render(assigns) do
      ~L"""
      root name: <%= @current_user.name %>
      <%= live_render(@socket, ChildLive, session: %{child: :static, user_id: @current_user.id}) %>
      <%= if @dynamic_child do %>
        <%= live_render(@socket, ChildLive, session: %{child: :dynamic, user_id: @current_user.id}, child_id: :dyn) %>
      <% end %>
      """
    end

    def mount(%{user_id: user_id}, socket) do
      {:ok,
       socket
       |> assign(:dynamic_child, false)
       |> assign_new(:current_user, fn ->
         %{name: "user-from-root", id: user_id}
       end)}
    end

    def handle_call(:show_dynamic_child, _from, socket) do
      {:reply, :ok, assign(socket, :dynamic_child, true)}
    end
  end

  describe "from root" do
    test "uses conn.assigns on static render then fetches on connected mount" do
      user = %{name: "user-from-conn", id: 123}

      {:ok, view, static_html} =
        mount_disconnected(Endpoint, RootLive,
          session: %{user_id: user.id},
          assigns: %{current_user: user}
        )

      assert static_html =~ "root name: user-from-conn"

      {:ok, view, connected_html} = mount(view)

      assert connected_html =~ "root name: user-from-root"
      assert render(view) =~ "child static name: user-from-root"
    end
  end

  describe "dynamically rendered child" do
    test "invokes own assign_new" do
      user = %{name: "user-from-conn", id: 123}

      {:ok, view, _html} =
        mount(Endpoint, RootLive,
          session: %{user_id: user.id},
          assigns: %{current_user: user}
        )

      assert render(view) =~ "child static name: user-from-root"

      :ok = GenServer.call(view.pid, :show_dynamic_child)

      html = render(view)
      assert html =~ "child static name: user-from-root"
      assert html =~ "child dynamic name: user-from-child"
    end
  end
end
