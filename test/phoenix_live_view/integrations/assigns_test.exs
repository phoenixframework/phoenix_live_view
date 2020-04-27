defmodule Phoenix.LiveView.AssignsTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.Endpoint

  @endpoint Endpoint

  setup do
    {:ok, conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})}
  end

  describe "assign_new from root" do
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

  describe "assign_new from dynamically rendered child" do
    test "invokes own assign_new", %{conn: conn} do
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

    test "can be configured with a list of atom and keyword list", %{conn: conn} do
      {:ok, conf_live, html} =
        conn
        |> put_session(:opts, temporary_assigns: [:description, title: "My Awesome Title"])
        |> live("/opts")

      assert html =~ "long description. canary"
      assert render(conf_live) =~ "long description. canary"
      socket = GenServer.call(conf_live.pid, {:exec, fn socket -> {:reply, socket, socket} end})

      assert %Phoenix.LiveView.UnsetTemporary{} = socket.assigns.description
      assert socket.assigns.title == "My Awesome Title"
      assert socket.assigns.canary == "canary"
    end

    test "raises error with invalid temporary_assigns values", %{conn: conn} do
      assert_raise Plug.Conn.WrapperError,
                   ~r/the :temporary_assigns mount option must include atoms or keyword list/,
                   fn ->
                     conn
                     |> put_session(:opts, temporary_assigns: ["invalid", "values", :one])
                     |> live("/opts")
                   end
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
