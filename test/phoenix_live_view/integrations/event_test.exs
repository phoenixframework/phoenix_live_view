defmodule Phoenix.LiveView.EventTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.{Component, LiveView}
  alias Phoenix.LiveViewTest.{Endpoint}

  @endpoint Endpoint

  setup config do
    {:ok, conn: Plug.Test.init_test_session(build_conn(), config[:session] || %{})}
  end

  describe "push_event" do
    test "sends updates with general assigns diff", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/events")

      GenServer.call(
        view.pid,
        {:run,
         fn socket ->
           new_socket =
             socket
             |> Component.assign(count: 123)
             |> LiveView.push_event("my-event", %{one: 1})

           {:reply, :ok, new_socket}
         end}
      )

      assert_push_event(view, "my-event", %{one: 1})
      assert render(view) =~ "count: 123"
    end

    test "sends updates with no assigns diff", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/events")

      GenServer.call(
        view.pid,
        {:run,
         fn socket ->
           {:reply, :ok, LiveView.push_event(socket, "my-event", %{two: 2})}
         end}
      )

      assert_push_event(view, "my-event", %{two: 2})
      assert render(view) =~ "count: 0"
    end

    test "sends updates in root and child mounts", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/events-in-mount")

      assert_push_event(view, "root-mount", %{root: "foo"})
      assert_push_event(view, "child-mount", %{child: "bar"})
    end

    test "sends updates in components", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/events-in-component")
      assert_received {:plug_conn, :sent}
      assert_received {_, {200, _, _}}

      assert_push_event(view, "component", %{count: 1})
      render_click(view, "bump", %{})
      assert_push_event(view, "component", %{count: 2})
      refute_received _
    end
  end

  describe "replies" do
    test "sends reply from handle_event with general assigns diff", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/events")

      assert render_hook(view, :reply, %{count: 456, reply: %{"val" => "my-reply"}}) =~
               "count: 456"

      assert_reply(view, %{"val" => "my-reply"})

      # Check type is preserved
      assert render_hook(view, :reply, %{count: 456, reply: %{"val" => 123}}) =~
               "count: 456"

      assert_reply(view, %{"val" => 123})
    end

    test "sends reply from handle_event with no assigns diff", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/events")
      assert render_hook(view, :reply, %{reply: %{"val" => "nodiff"}}) =~ "count: 0"
      assert_reply(view, %{"val" => "nodiff"})
    end

    test "raises when trying to reply outside of handle_event", %{conn: conn} do
      Process.flag(:trap_exit, true)
      {:ok, view, _html} = live(conn, "/events")
      pid = view.pid
      Process.monitor(pid)

      assert ExUnit.CaptureLog.capture_log(fn ->
               send(
                 view.pid,
                 {:run,
                  fn socket ->
                    {:reply, :boom, socket}
                  end}
               )

               assert_receive {:DOWN, _ref, :process, ^pid, _reason}
             end) =~ "Got: {:reply, :boom"
    end

    test "sends replies in components", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/events-in-component")
      assert_received {:plug_conn, :sent}
      assert_received {_, {200, _, _}}

      assert_push_event(view, "component", %{count: 1})

      view
      |> element("#comp-reply")
      |> render_click(%{reply: "123"})

      assert_reply(view, %{"comp-reply" => %{"reply" => "123"}})

      view
      |> element("#comp-noreply")
      |> render_click(%{reply: "123"})

      refute_received _
    end
  end

  describe "LiveViewTest supports multiple JS.push events" do
    test "from one click", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/events-multi-js")

      assert element(view, "#add-one-and-ten")
             |> render_click() =~ "count: 11"
    end

    test "with repiles", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/events-multi-js")

      assert element(view, "#reply-values")
             |> render_click()

      assert_reply(view, %{value: 1})
      assert_reply(view, %{value: 2})
    end

    test "from a component to itself", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/events-multi-js-in-component")

      html =
        element(view, "#child_1 #push-to-self")
        |> render_click()

      assert html =~ "child_1 count: 11"
      assert html =~ "child_2 count: 0"
    end

    test "from a component to other targets", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/events-multi-js-in-component")

      html =
        element(view, "#child_1 #push-to-other-targets")
        |> render_click()

      assert html =~ "child_1 count: 1"
      assert html =~ "child_2 count: 2"
      assert html =~ "root count: -1"
    end
  end
end
