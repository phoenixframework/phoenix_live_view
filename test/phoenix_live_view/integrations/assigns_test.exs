defmodule Phoenix.LiveView.AssignsTest do
  use ExUnit.Case, async: true
  import Plug.Conn
  import Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.Endpoint

  @endpoint Endpoint

  setup do
    {:ok, conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})}
  end

  describe "assign_new" do
    test "uses conn.assigns on static render then fetches on connected mount", %{conn: conn} do
      user = %{name: "user-from-conn", id: 123}

      conn =
        conn
        |> Plug.Conn.assign(:current_user, user)
        |> Plug.Conn.put_session(:user_id, user.id)
        |> get("/root")

      assert html_response(conn, 200) =~ "root name: user-from-conn"
      assert html_response(conn, 200) =~ "child static name: user-from-conn"

      {:ok, _, connected_html} = live(conn)
      assert connected_html =~ "root name: user-from-root"
      assert connected_html =~ "child static name: user-from-root"
    end

    test "uses assign_new from parent on dynamically added child", %{conn: conn} do
      user = %{name: "user-from-conn", id: 123}

      {:ok, view, _html} =
        conn
        |> Plug.Conn.assign(:current_user, user)
        |> Plug.Conn.put_session(:user_id, user.id)
        |> live("/root")

      assert render(view) =~ "child static name: user-from-root"
      refute render(view) =~ "child dynamic name"

      :ok = GenServer.call(view.pid, {:dynamic_child, :dynamic})

      html = render(view)
      assert html =~ "child static name: user-from-root"
      assert html =~ "child dynamic name: user-from-child"
    end
  end

  describe "temporary assigns" do
    test "can be configured with mount options", %{conn: conn} do
      {:ok, conf_live, html} =
        conn
        |> put_session(:opts, temporary_assigns: [description: nil])
        |> live("/opts")

      assert html =~ "long description. canary"
      assert render(conf_live) =~ "long description. canary"
      socket = GenServer.call(conf_live.pid, {:exec, fn socket -> {:reply, socket, socket} end})

      assert socket.assigns.description == nil
      assert socket.assigns.canary == "canary"
    end

    test "raises with invalid options", %{conn: conn} do
      assert_raise Plug.Conn.WrapperError,
                   ~r/invalid option returned from Phoenix.LiveViewTest.OptsLive.mount\/3/,
                   fn ->
                     conn
                     |> put_session(:opts, oops: [:description])
                     |> live("/opts")
                   end
    end
  end
end
