defmodule Phoenix.LiveView.ParamsTest do
  use ExUnit.Case, async: false
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

      response = html_response(conn, 200)

      assert response =~
               escape(~s|params: %{"id" => "123", "query1" => "query1", "query2" => "query2"}|)

      assert response =~
               escape(~s|mount: %{"id" => "123", "query1" => "query1", "query2" => "query2"}|)
    end

    test "hard redirects", %{conn: conn} do
      assert conn
             |> put_serialized_session(
               :on_handle_params,
               &{:stop, LiveView.redirect(&1, to: "/")}
             )
             |> get("/counter/123?from=handle_params")
             |> redirected_to() == "/"
    end

    test "hard redirect with flash message", %{conn: conn} do
      conn =
        put_serialized_session(conn, :on_handle_params, fn socket ->
          {:stop, socket |> LiveView.put_flash(:info, "msg") |> LiveView.redirect(to: "/")}
        end)
        |> fetch_flash()
        |> get("/counter/123?from=handle_params")

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) == "msg"
    end

    test "internal live redirects", %{conn: conn} do
      assert conn
             |> put_serialized_session(:on_handle_params, fn socket ->
               {:noreply,
                LiveView.live_redirect(socket, to: "/counter/123?from=rehandled_params")}
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

    test "raises on stop without redirect", %{conn: conn} do
      assert_raise Plug.Conn.WrapperError, ~r"attempted to stop socket without redirecting", fn ->
        conn
        |> put_serialized_session(:on_handle_params, &{:stop, &1})
        |> get("/counter/123?from=handle_params")
      end
    end

    test "with encoded URL", %{conn: conn} do
      assert conn = get(conn, "/counter/Wm9uZTozNzYxOA%3D%3D")
      assert_receive {:handle_params, uri, _assigns, %{"id" => "Wm9uZTozNzYxOA=="}}
    end
  end

  describe "handle_params on connected mount" do
    test "is called on connected mount with query string params from get", %{conn: conn} do
      {:ok, _, html} =
        conn
        |> get("/counter/123?q1=1", q2: "2")
        |> live()

      assert html =~ escape(~s|params: %{"id" => "123", "q1" => "1"}|)
      assert html =~ escape(~s|mount: %{"id" => "123", "q1" => "1"}|)
    end

    test "is called on connected mount with query string params from live", %{conn: conn} do
      {:ok, _, html} =
        conn
        |> live("/counter/123?q1=1")

      assert html =~ escape(~s|%{"id" => "123", "q1" => "1"}|)
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

      response = render(counter_live)
      assert response =~ escape(~s|params: %{"from" => "rehandled_params", "id" => "123"}|)
      assert response =~ escape(~s|mount: %{"from" => "handle_params", "id" => "123"}|)
    end

    test "external live redirects", %{conn: conn} do
      {:error, %{live_redirect: %{to: "/thermo/456"}}} =
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

    test "raises on stop without redirect", %{conn: conn} do
      assert ExUnit.CaptureLog.capture_log(fn ->
               pid =
                 spawn(fn ->
                   conn
                   |> put_serialized_session(:on_handle_params, fn socket ->
                     if LiveView.connected?(socket) do
                       {:stop, socket}
                     else
                       {:noreply, socket}
                     end
                   end)
                   |> get("/counter/123?from=handle_params")
                   |> live()
                 end)

               ref = Process.monitor(pid)

               assert_receive {:DOWN, ^ref, :process, _, _}
             end) =~ ~r"attempted to stop socket without redirecting"
    end

    test "with encoded URL", %{conn: conn} do
      {:ok, _counter_live, _html} = live(conn, "/counter/Wm9uZTozNzYxOA%3D%3D")

      assert_receive {:handle_params, uri, %{connected?: true}, %{"id" => "Wm9uZTozNzYxOA=="}}
    end
  end

  describe "live_link" do
    test "renders static container", %{conn: conn} do
      assert conn
             |> put_req_header("x-requested-with", "live-link")
             |> get("/counter/123", query1: "query1", query2: "query2")
             |> html_response(200) =~
               ~r(<div data-phx-session="[^"]+" data-phx-view="[^"]+" id="[^"]+"></div>)
    end

    test "invokes handle_params", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      assert render_live_link(counter_live, "/counter/123?filter=true") =~
               escape(~s|%{"filter" => "true", "id" => "123"}|)
    end

    test "with encoded URL", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      assert render_live_link(counter_live, "/counter/Wm9uZTozNzYxOa%3d%3d") =~
               escape(~s|%{"id" => "Wm9uZTozNzYxOa=="}|)
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

    test "raises if stopping", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      next = fn socket ->
        {:stop, LiveView.live_redirect(socket, to: "/counter/123?from=handle_call")}
      end

      assert ExUnit.CaptureLog.capture_log(fn ->
               catch_exit(GenServer.call(counter_live.pid, {:live_redirect, next}))
             end) =~ "a LiveView cannot be stopped while issuing a live redirect"
    end

    test "raises on stop without redirect", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")
      next = fn socket -> {:stop, socket} end

      assert ExUnit.CaptureLog.capture_log(fn ->
               catch_exit(GenServer.call(counter_live.pid, {:live_redirect, next}))
             end) =~ "attempted to stop socket without redirecting"
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
                 {:error, {:live_redirect, %{to: "/thermo/123"}}}
      end)

      assert_remove(counter_live, {:redirect, "/thermo/123"})
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

    test "raises if stopping", %{conn: conn} do
      {:ok, counter_live, _html} = live(conn, "/counter/123")

      next = fn socket ->
        {:stop, LiveView.live_redirect(socket, to: "/thermo/123")}
      end

      assert ExUnit.CaptureLog.capture_log(fn ->
               catch_exit(GenServer.call(counter_live.pid, {:live_redirect, next}))
             end) =~ "a LiveView cannot be stopped while issuing a live redirect"
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
      {:ok, counter_live, _html} =
        live(conn, "/counter/123", connect_params: %{"connect1" => "1"})

      assert render(counter_live) =~ escape(~s|connect: %{"connect1" => "1"}|)
    end
  end

  defp escape(str) do
    str
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
