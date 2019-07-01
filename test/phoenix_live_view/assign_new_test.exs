defmodule Phoenix.LiveView.AssignNewTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  import Phoenix.LiveViewTest

  alias Phoenix.LiveViewTest.{Endpoint, Router}
  alias Phoenix.LiveView
  alias Phoenix.LiveView.View

  @endpoint Endpoint
  @moduletag :capture_log

  setup do
    {:ok,
     conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})}
  end

  test "uses socket assigns if no parent assigns are present" do
    socket =
      Endpoint
      |> View.build_socket(Router, %{})
      |> LiveView.assign(:existing, "existing")
      |> LiveView.assign_new(:existing, fn -> "new-existing" end)
      |> LiveView.assign_new(:notexisting, fn -> "new-notexisting" end)

    assert socket.assigns == %{existing: "existing", notexisting: "new-notexisting"}
  end

  test "uses parent assigns when present and falls back to socket assigns" do
    socket =
      Endpoint
      |> View.build_socket(Router, %{assigned_new: {%{existing: "existing-parent"}, []}})
      |> LiveView.assign(:existing2, "existing2")
      |> LiveView.assign_new(:existing, fn -> "new-existing" end)
      |> LiveView.assign_new(:existing2, fn -> "new-existing2" end)
      |> LiveView.assign_new(:notexisting, fn -> "new-notexisting" end)

    assert socket.assigns == %{
             existing: "existing-parent",
             existing2: "existing2",
             notexisting: "new-notexisting"
           }
  end

  describe "mounted from root" do
    test "uses conn.assigns on static render then fetches on connected mount", %{conn: conn} do
      user = %{name: "user-from-conn", id: 123}

      conn =
        conn
        |> Plug.Conn.assign(:current_user, user)
        |> Plug.Conn.put_session(:user_id, user.id)
        |> get("/root")

      assert html_response(conn, 200) =~ "root name: user-from-conn"

      {:ok, view, connected_html} = live(conn)

      assert connected_html =~ "root name: user-from-root"
      assert render(view) =~ "child static name: user-from-root"
    end
  end

  describe "mounted from dynamically rendered child" do
    test "invokes own assign_new", %{conn: conn} do
      user = %{name: "user-from-conn", id: 123}

      {:ok, view, _html} =
        conn
        |> Plug.Conn.assign(:current_user, user)
        |> Plug.Conn.put_session(:user_id, user.id)
        |> live("/root")

      assert render(view) =~ "child static name: user-from-root"

      :ok = GenServer.call(view.pid, :show_dynamic_child)

      html = render(view)
      assert html =~ "child static name: user-from-root"
      assert html =~ "child dynamic name: user-from-child"
    end
  end
end
