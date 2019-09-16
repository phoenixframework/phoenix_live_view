defmodule Phoenix.LiveView.ParamsTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  import Phoenix.LiveViewTest

  alias Phoenix.LiveView
  alias Phoenix.LiveViewTest.Endpoint

  @endpoint Endpoint
  @moduletag :capture_log

  setup do
    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:test_pid, self())

    {:ok, conn: conn}
  end

  defp put_serialized_session(conn, key, value) do
    put_session(conn, key, :erlang.term_to_binary(value))
  end

  describe "handle_params on disconnected mount" do
    test "is called with named and query string params", %{conn: conn} do
      conn = get(conn, "/counter/123", query1: "query1", query2: "query2")

      assert html_response(conn, 200) =~ escape(~s|%{"id" => "123", "query1" => "query1", "query2" => "query2"}|)
    end

    test "hard redirects", %{conn: conn} do
      assert conn
             |> put_serialized_session(:on_handle_params, &{:stop, LiveView.redirect(&1, to: "/")})
             |> get("/counter/123?from=handle_params")
             |> redirected_to() == "/"
    end

    test "internal live redirects", %{conn: conn} do
      assert conn
             |> put_serialized_session(:on_handle_params, fn socket ->
               {:noreply, LiveView.live_redirect(socket, to: "/counter/123?from=rehandled_params")}
             end)
             |> get("/counter/123?from=handle_params")
             |> redirected_to() == "/counter/123?from=rehandled_params"
    end

    test "external live redirects", %{conn: conn} do
      assert conn
             |> put_serialized_session(:on_handle_params, fn socket ->
               {:noreply, LiveView.live_redirect(socket, to: "/thermo/456")}
             end)
             |> get("/counter/123?from=handle_params")
             |> redirected_to() == "/thermo/456"
    end
  end

  describe "handle_params on connected mount" do
    test "is called on connected mount with named and query string params", %{conn: conn} do
      {:ok, _, html} =
        conn
        |> get("/counter/123?q1=1", q2: "2")
        |> live()

      assert html =~ escape(~s|%{"id" => "123", "q1" => "1", "q2" => "2"}|)
    end

    test "hard redirects", %{conn: conn} do
      {:error, %{redirect: %{to: "/thermo/456"}}} =
        conn
        |> put_serialized_session(:on_handle_params, fn socket ->
          if LiveView.connected?(socket) do
            {:noreply, LiveView.redirect(socket, to: "/thermo/456")}
          else
            {:noreply, socket}
          end
        end)
        |> get("/counter/123?from=handle_params")
        |> live()
    end

    test "internal live redirects", %{conn: conn} do
      {:ok, counter_live, _html} =
        conn
        |> put_serialized_session(:on_handle_params, fn socket ->
          if LiveView.connected?(socket) do
            {:noreply, LiveView.live_redirect(socket, to: "/counter/123?from=rehandled_params")}
          else
            {:noreply, socket}
          end
        end)
        |> get("/counter/123?from=handle_params")
        |> live()

      assert render(counter_live) =~ escape(~s|%{"from" => "rehandled_params", "id" => "123"}|)
    end

    test "external live redirects", %{conn: conn} do
      {:error, %{redirect: %{to: "/thermo/456"}}} =
        conn
        |> put_serialized_session(:on_handle_params, fn socket ->
          if LiveView.connected?(socket) do
            {:noreply, LiveView.live_redirect(socket, to: "/thermo/456")}
          else
            {:noreply, socket}
          end
        end)
        |> get("/counter/123?from=handle_params")
        |> live()
    end
  end

  describe "handle_params on live_link" do
    test "internal links invokes handle_params", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      assert render_live_link(counter_live, "/counter/123?filter=true") =~
               escape(~s|%{"filter" => "true", "id" => "123"}|)
    end
  end

  describe "internal live_redirect" do
    test "from event callback ack", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      assert_redirect(counter_live, "/counter/123?from=event_ack", fn ->
        assert render_click(counter_live, :live_redirect, "/counter/123?from=event_ack") =~
                 escape(~s|%{"from" => "event_ack", "id" => "123"}|)
      end)
    end

    test "raises if stopping", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      next = fn socket ->
        {:stop, LiveView.live_redirect(socket, to: "/counter/123?from=handle_call")}
      end

      assert ExUnit.CaptureLog.capture_log(fn ->
               catch_exit(GenServer.call(counter_live.pid, {:live_redirect, next}))
             end) =~ "a LiveView cannot be stopped while issuing a live redirect"
    end

    test "from handle_info", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      send(counter_live.pid, {:live_redirect, "/counter/123?from=handle_info"})
      assert render(counter_live) =~ escape(~s|%{"from" => "handle_info", "id" => "123"}|)
    end

    test "from handle_cast", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      :ok = GenServer.cast(counter_live.pid, {:live_redirect, "/counter/123?from=handle_cast"})
      assert render(counter_live) =~ escape(~s|%{"from" => "handle_cast", "id" => "123"}|)
    end

    test "from handle_call", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      next = fn socket ->
        {:reply, :ok, LiveView.live_redirect(socket, to: "/counter/123?from=handle_call")}
      end

      :ok = GenServer.call(counter_live.pid, {:live_redirect, next})
      assert render(counter_live) =~ escape(~s|%{"from" => "handle_call", "id" => "123"}|)
    end

    test "from handle_params", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      next = fn socket ->
        send(self(), {:set, :val, 1000})

        new_socket =
          LiveView.assign(socket, :on_handle_params, fn socket ->
            {:noreply, LiveView.live_redirect(socket, to: "/counter/123?from=rehandled_params")}
          end)

        {:reply, :ok, LiveView.live_redirect(new_socket, to: "/counter/123?from=handle_params")}
      end

      :ok = GenServer.call(counter_live.pid, {:live_redirect, next})

      html = render(counter_live)
      assert html =~ escape(~s|%{"from" => "rehandled_params", "id" => "123"}|)
      assert html =~ "The value is: 1000"

      assert_receive {:handle_params, "http://localhost:4000/counter/123?from=rehandled_params",
                      %{val: 1}, %{"from" => "rehandled_params", "id" => "123"}}
    end

    test "raises if stopping from handle_params", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      next = fn socket ->
        new_socket =
          LiveView.assign(socket, :on_handle_params, fn socket ->
            {:stop, LiveView.live_redirect(socket, to: "/thermo/123?from=rehandle_params")}
          end)

        {:reply, :ok, LiveView.live_redirect(new_socket, to: "/counter/123?from=handle_params")}
      end

      assert ExUnit.CaptureLog.capture_log(fn ->
               catch_exit(GenServer.call(counter_live.pid, {:live_redirect, next}))
               ref = Process.monitor(counter_live.pid)
               assert_receive {:DOWN, ^ref, _, _, _}
             end) =~ "a LiveView cannot be stopped while issuing a live redirect"
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

    test "raises if stopping", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      next = fn socket ->
        {:stop, LiveView.live_redirect(socket, to: "/thermo/123")}
      end

      assert ExUnit.CaptureLog.capture_log(fn ->
               catch_exit(GenServer.call(counter_live.pid, {:live_redirect, next}))
             end) =~ "a LiveView cannot be stopped while issuing a live redirect"
    end

    test "from handle_params", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      next = fn socket ->
        new_socket =
          LiveView.assign(socket, :on_handle_params, fn socket ->
            {:noreply, LiveView.live_redirect(socket, to: "/thermo/123")}
          end)

        {:reply, :ok, LiveView.live_redirect(new_socket, to: "/counter/123?from=handle_params")}
      end

      :ok = GenServer.call(counter_live.pid, {:live_redirect, next})

      assert_receive {:handle_params, "http://localhost:4000/counter/123?from=handle_params",
                      %{val: 1}, %{"from" => "handle_params", "id" => "123"}}

      assert_remove(counter_live, {:redirect, "/thermo/123"})
    end

    test "raises if stopping from handle_params", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      next = fn socket ->
        new_socket =
          LiveView.assign(socket, :on_handle_params, fn socket ->
            {:stop, LiveView.live_redirect(socket, to: "/thermo/123")}
          end)

        {:reply, :ok, LiveView.live_redirect(new_socket, to: "/counter/123?from=handle_params")}
      end

      assert ExUnit.CaptureLog.capture_log(fn ->
               catch_exit(GenServer.call(counter_live.pid, {:live_redirect, next}))
               ref = Process.monitor(counter_live.pid)
               assert_receive {:DOWN, ^ref, _, _, _}
             end) =~ "a LiveView cannot be stopped while issuing a live redirect"
    end
  end

  describe "connect_params" do
    test "connect_params can be read on mount", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123", connect_params: %{"connect1" => "1"})

      assert render(counter_live) =~ escape(~s|connect: %{"connect1" => "1"}|)
    end
  end

  defp escape(str) do
    str
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
