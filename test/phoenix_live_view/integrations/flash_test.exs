defmodule Phoenix.LiveView.FlashTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  import Phoenix.LiveViewTest

  alias Phoenix.LiveView
  alias Phoenix.LiveViewTest.{Endpoint, DOM, Router}

  @endpoint Endpoint
  @moduletag :capture_log

  def run(view, func) do
    send(view.pid, {:run, func})
  end

  setup config do
    conn =
      Phoenix.ConnTest.build_conn()
      |> Phoenix.ConnTest.bypass_through(Router, [:browser])
      |> get("/")

    {:ok, conn: conn}
  end

  describe "LiveView <=> LiveView" do
    test "redirect with flash", %{conn: conn} do
      {:ok, clock_live, _} = live(conn, "/clock")

      assert_redirect(clock_live, "/thermo", %{"info" => "ok!"}, fn ->
        run(clock_live, fn socket ->
          {:noreply, socket |> LiveView.put_flash(:info, "ok!") |> LiveView.redirect(to: "/thermo")}
        end)
      end)
    end

    test "push_redirect with flash", %{conn: conn} do
      {:ok, clock_live, _} = live(conn, "/clock")

      assert_redirect(clock_live, "/thermo", %{"info" => "ok!"}, fn ->
        run(clock_live, fn socket ->
          {:noreply, socket |> LiveView.put_flash(:info, "ok!") |> LiveView.push_redirect(to: "/thermo")}
        end)
      end)
    end

    test "push_patch with flash", %{conn: conn} do
      {:ok, clock_live, _} = live(conn, "/clock")

      assert_redirect(clock_live, "/clock?foo", %{"info" => "ok!"}, fn ->
        run(clock_live, fn socket ->
          {:noreply, socket |> LiveView.put_flash(:info, "ok!") |> LiveView.push_patch(to: "/clock?foo")}
        end)
      end)
    end
  end

  describe "LiveComponent => LiveView" do
    test "redirect with flash from component", %{conn: conn} do
    end

    test "push_redirect with flash from component", %{conn: conn} do
    end

    test "push_patch with flash from component", %{conn: conn} do
    end
  end

  describe "LiveView <=> DeadView" do
    test "redirect with flash from LiveView to DeadView", %{conn: conn} do
      {:ok, clock_live, _} = live(conn, "/clock")

      assert_redirect(clock_live, "/", %{"info" => "ok!"}, fn ->
        run(clock_live, fn socket ->
          {:noreply, socket |> LiveView.put_flash(:info, "ok!") |> LiveView.redirect(to: "/")}
        end)
      end)
    end

    test "redirect with flash from DeadView to LiveView", %{conn: conn} do
      conn =
        conn
        |> LiveView.Flash.call(LiveView.Flash.init([]))
        |> Phoenix.Controller.put_flash(:info, "flash from the dead")
        |> Phoenix.Controller.redirect(to: "/clock")
        |> recycle()
        |> get("/clock")

      assert html_response(conn, 200) =~ "flash from the dead"
      {:ok, clock_live, html} = live(conn)
      assert html =~ "flash from the dead"
    end
  end
end
