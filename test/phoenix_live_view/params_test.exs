defmodule Phoenix.LiveView.ParamsTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  import Phoenix.LiveViewTest

  alias Phoenix.LiveView
  alias Phoenix.LiveViewTest.{Endpoint}

  @endpoint Endpoint
  @moduletag :capture_log

  setup do
    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:test_pid, self())

    {:ok, conn: conn}
  end

  describe "handle_params on mount" do
    test "is called on disconnected mount with named and query string params", %{conn: conn} do
      conn = get(conn, "/counter/123", query1: "query1", query2: "query2")

      assert html_response(conn, 200) =~
               ~s|%{"id" => "123", "query1" => "query1", "query2" => "query2"}|
    end

    test "is called on connected mount with named and query string params", %{conn: conn} do
      {:ok, _, html} =
        conn
        |> get("/counter/123?q1=1", q2: "2")
        |> live()

      assert html =~ ~s|%{"id" => "123", "q1" => "1", "q2" => "2"}|
    end
  end

  describe "handle_params on live_link" do
    test "internal links invokes handle_params", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      assert render_live_link(counter_live, "/counter/123?filter=true") =~
               ~s|%{"filter" => "true", "id" => "123"}|
    end
  end

  describe "internal live_redirect" do
    test "from event callback ack", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      assert_redirect(counter_live, "/counter/123?from=event_ack", fn ->
        assert render_click(counter_live, :live_redirect, "/counter/123?from=event_ack") =~
                 ~s|%{"from" => "event_ack", "id" => "123"}|
      end)
    end

    test "from handle_info", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      send(counter_live.pid, {:live_redirect, "/counter/123?from=handle_info"})
      assert render(counter_live) =~ ~s|%{"from" => "handle_info", "id" => "123"}|
    end

    test "from handle_cast", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      :ok = GenServer.cast(counter_live.pid, {:live_redirect, "/counter/123?from=handle_cast"})
      assert render(counter_live) =~ ~s|%{"from" => "handle_cast", "id" => "123"}|
    end

    test "from handle_call", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")
      next = fn socket -> {:reply, :ok, socket} end

      :ok =
        GenServer.call(counter_live.pid, {:live_redirect, "/counter/123?from=handle_call", next})

      assert render(counter_live) =~ ~s|%{"from" => "handle_call", "id" => "123"}|
    end

    test "from handle_params immediately processes another handle_params", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      next = fn socket ->
        send(self(), {:set, :val, 1000})

        new_socket =
          LiveView.assign(socket, :on_handle_params, fn socket ->
            {:noreply, LiveView.live_redirect(socket, to: "/counter/123?from=rehandled_params")}
          end)

        {:reply, :ok, new_socket}
      end

      :ok =
        GenServer.call(
          counter_live.pid,
          {:live_redirect, "/counter/123?from=handle_params", next}
        )

      html = render(counter_live)
      assert html =~ ~s|%{"from" => "rehandled_params", "id" => "123"}|
      assert html =~ "The value is: 1000"

      assert_receive {:handle_params, "http://localhost:4000/counter/123?from=rehandled_params",
                      %{val: 1}, %{"from" => "rehandled_params", "id" => "123"}}
    end

    test "from handle_params with stop", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      next = fn socket ->
        send(self(), {:set, :val, 1000})

        new_socket =
          LiveView.assign(socket, :on_handle_params, fn socket ->
            {:stop, LiveView.redirect(socket, to: "/counter/123?from=stopped_params")}
          end)

        {:reply, :ok, new_socket}
      end

      :ok =
        GenServer.call(
          counter_live.pid,
          {:live_redirect, "/counter/123?from=handle_params", next}
        )

      assert_receive {:handle_params, "http://localhost:4000/counter/123?from=handle_params",
                      %{val: 1}, %{"from" => "handle_params", "id" => "123"}}

      assert_remove(counter_live, {:redirect, "/counter/123?from=stopped_params"})
    end
  end

  describe "external live_redirect" do
    test "from event callback", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      assert_redirect(counter_live, "/thermo/123", fn ->
        assert render_click(counter_live, :live_redirect, "/thermo/123") ==
                 {:error, {:redirect, %{to: "/thermo/123"}}}
      end)

      assert_remove(counter_live, {:redirect, "/thermo/123"})
    end

    test "from mount disconnected", %{conn: conn} do
      conn =
        conn
        |> put_session(:test, %{external_disconnected_redirect: %{to: "/thermo/123"}})
        |> get("/counter/123")

      assert html_response(conn, 302)
    end

    test "from mount connected", %{conn: conn} do
      assert {:error, %{redirect: %{to: "/thermo/456"}}} =
               conn
               |> put_session(:test, %{
                 external_connected_redirect: %{stop: false, to: "/thermo/456"}
               })
               |> live("/counter/123")
    end

    test "from mount connected raises if stopping", %{conn: conn} do
      assert_raise RuntimeError, ~r/attempted to live redirect while stopping/, fn ->
        conn
        |> put_session(:test, %{external_connected_redirect: %{stop: true, to: "/thermo/456"}})
        |> live("/counter/123")
      end
    end

    test "from handle_params", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      next = fn socket ->
        send(self(), {:set, :val, 1000})

        new_socket =
          LiveView.assign(socket, :on_handle_params, fn socket ->
            {:noreply, LiveView.live_redirect(socket, to: "/thermo/123")}
          end)

        {:reply, :ok, new_socket}
      end

      :ok =
        GenServer.call(
          counter_live.pid,
          {:live_redirect, "/counter/123?from=handle_params", next}
        )

      assert_receive {:handle_params, "http://localhost:4000/counter/123?from=handle_params",
                      %{val: 1}, %{"from" => "handle_params", "id" => "123"}}

      assert_remove(counter_live, {:redirect, "/thermo/123"})
    end
  end

  describe "connect_params" do
    test "connect_params can be read on mount", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123", connect_params: %{"connect1" => "1"})

      assert render(counter_live) =~ ~s|connect: %{"connect1" => "1"}|
    end
  end
end
