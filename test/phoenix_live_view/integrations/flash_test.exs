defmodule Phoenix.LiveView.FlashIntegrationTest do
  use ExUnit.Case, async: false
  use Phoenix.ConnTest

  import Phoenix.LiveViewTest

  alias Phoenix.LiveView
  alias Phoenix.LiveViewTest.{Endpoint, Router}

  @endpoint Endpoint
  @moduletag :capture_log

  setup do
    conn =
      Phoenix.ConnTest.build_conn()
      |> Phoenix.ConnTest.bypass_through(Router, [:browser])
      |> get("/")

    {:ok, conn: conn}
  end

  describe "LiveView <=> LiveView" do
    test "redirect with flash", %{conn: conn} do
      {:ok, flash_child, _} = live(conn, "/flash-child")

      render_click(flash_child, "redirect", %{"to" => "/flash-root", "info" => "ok!"})
      assert_redirect(flash_child, "/flash-root", flash)
      assert flash == %{"info" => "ok!"}
    end

    test "redirect with flash does not include previous event flash", %{conn: conn} do
      {:ok, flash_child, _} = live(conn, "/flash-child")
      render_click(flash_child, "set_error", %{"error" => "ok!"})
      render_click(flash_child, "redirect", %{"to" => "/flash-root", "info" => "ok!"})
      assert_redirect(flash_child, "/flash-root", flash)
      assert flash == %{"info" => "ok!"}
    end

    test "push_redirect with flash", %{conn: conn} do
      {:ok, flash_child, _} = live(conn, "/flash-child")

      render_click(flash_child, "push_redirect", %{"to" => "/flash-root", "info" => "ok!"})
      assert_redirect(flash_child, "/flash-root", flash)
      assert flash == %{"info" => "ok!"}
    end

    test "push_redirect with flash does not include previous event flash", %{conn: conn} do
      {:ok, flash_child, _} = live(conn, "/flash-child")

      render_click(flash_child, "set_error", %{"error" => "ok!"})
      render_click(flash_child, "push_redirect", %{"to" => "/flash-root", "info" => "ok!"})
      assert_redirect(flash_child, "/flash-root", flash)
      assert flash == %{"info" => "ok!"}
    end

    test "push_patch with flash", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")

      result =
        render_click(flash_live, "push_patch", %{"to" => "/flash-root?foo", "info" => "ok!"})

      assert result =~ "uri[http://localhost:4000/flash-root?foo]"
      assert result =~ "root[ok!]:info"
    end

    test "push_patch with flash does not include previous event flash", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")
      result = render_click(flash_live, "set_error", %{"error" => "oops!"})
      assert result =~ "root[oops!]:error"

      result =
        render_click(flash_live, "push_patch", %{"to" => "/flash-root?foo", "info" => "ok!"})

      assert result =~ "uri[http://localhost:4000/flash-root?foo]"
      assert result =~ "root[ok!]:info"
      assert result =~ "root[]:error"
    end

    test "clears flash on client-side patches", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")
      result = render_click(flash_live, "set_error", %{"error" => "oops!"})
      assert result =~ "root[oops!]:error"

      result = render_patch(flash_live, "/flash-root?foo=bar")
      assert result =~ "root[]:error"
    end

    test "clears flash when passed down to component", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")

      result = render_click(flash_live, "set_error", %{"error" => "oops!"})
      assert result =~ "stateless_component[oops!]:error"

      result = render_click(flash_live, "clear_flash", %{"kind" => "error"})
      assert result =~ "stateless_component[]:error"
    end

    test "nested redirect with flash", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")

      flash_child = find_child(flash_live, "flash-child")
      render_click(flash_child, "redirect", %{"to" => "/flash-root?redirect", "info" => "ok!"})
      assert_redirect(flash_child, "/flash-root?redirect", %{"info" => "ok!"})
    end

    test "nested push_redirect with flash", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")

      flash_child = find_child(flash_live, "flash-child")
      render_click(flash_child, "push_redirect", %{"to" => "/flash-root?push", "info" => "ok!"})
      assert_redirect(flash_child, "/flash-root?push", %{"info" => "ok!"})
    end

    test "nested push_patch with flash", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")

      flash_child = find_child(flash_live, "flash-child")
      render_click(flash_child, "push_patch", %{"to" => "/flash-root?patch", "info" => "ok!"})

      result = render(flash_live)
      assert result =~ "uri[http://localhost:4000/flash-root?patch]"
      assert result =~ "root[ok!]"
    end
  end

  describe "LiveComponent => LiveView" do
    test "redirect with flash from component", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")

      render_click([flash_live, "#flash-component"], "redirect", %{
        "to" => "/flash-root",
        "info" => "ok!"
      })

      assert_redirect(flash_live, "/flash-root", %{"info" => "ok!"})
    end

    test "push_redirect with flash from component", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")

      render_click([flash_live, "#flash-component"], "push_redirect", %{
        "to" => "/flash-root",
        "info" => "ok!"
      })

      assert_redirect(flash_live, "/flash-root", %{"info" => "ok!"})
    end

    test "push_patch with flash from component", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")

      render_click([flash_live, "#flash-component"], "push_patch", %{
        "to" => "/flash-root?patch",
        "info" => "ok!"
      })

      result = render(flash_live)
      assert result =~ "uri[http://localhost:4000/flash-root?patch]"
      assert result =~ "root[ok!]"
    end
  end

  describe "LiveView <=> DeadView" do
    test "redirect with flash from LiveView to DeadView", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")

      render_click(flash_live, "redirect", %{"to" => "/", "info" => "ok!"})
      assert_redirect(flash_live, "/", %{"info" => "ok!"})
    end

    test "redirect with flash from DeadView to LiveView", %{conn: conn} do
      conn =
        conn
        |> LiveView.Router.fetch_live_flash([])
        |> Phoenix.Controller.put_flash(:info, "flash from the dead")
        |> Phoenix.Controller.redirect(to: "/flash-root")
        |> recycle()
        |> get("/flash-root")

      assert html_response(conn, 200) =~ "flash from the dead"
      {:ok, _flash_live, html} = live(conn)
      assert html =~ "flash from the dead"
    end
  end

  test "lv:clear-flash", %{conn: conn} do
    {:ok, flash_live, _} = live(conn, "/flash-root")

    result =
      render_click(flash_live, "push_patch", %{"to" => "/flash-root?patch", "info" => "ok!"})

    assert result =~ "uri[http://localhost:4000/flash-root?patch]"
    assert result =~ "root[ok!]:info"

    result = render_click(flash_live, "lv:clear-flash", %{key: "info"})
    assert result =~ "root[]:info"

    result =
      render_click(flash_live, "push_patch", %{"to" => "/flash-root?patch", "info" => "ok!"})

    assert result =~ "uri[http://localhost:4000/flash-root?patch]"
    assert result =~ "root[ok!]:info"

    result = render_click(flash_live, "lv:clear-flash")
    assert result =~ "root[]:info"
  end

  test "lv:clear-flash component", %{conn: conn} do
    {:ok, flash_live, _} = live(conn, "/flash-root")

    result = render_click([flash_live, "#flash-component"], "put_flash", %{"info" => "ok!"})
    assert result =~ "component[ok!]:info"

    result = render_click([flash_live, "#flash-component"], "lv:clear-flash")
    assert result =~ "component[]:info"

    result = render_click([flash_live, "#flash-component"], "put_flash", %{"error" => "oops!"})
    assert result =~ "component[oops!]:error"

    result = render_click([flash_live, "#flash-component"], "lv:clear-flash", %{key: "error"})
    assert result =~ "component[]:error"
  end

  test "works without flash", %{conn: conn} do
    {:ok, live, html} = live(conn, "/thermo-with-metadata")
    assert html =~ "The temp is: 1"
    assert render(live) =~ "The temp is: 1"
  end
end
