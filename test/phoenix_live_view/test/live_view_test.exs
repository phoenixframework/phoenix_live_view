defmodule PhoenixLiveView.Test.LiveViewTest.CatchAll do
  use ExUnit.Case
  import Plug.Conn
  import Phoenix.ConnTest

  import Phoenix.LiveViewTest

  alias Phoenix.LiveView
  alias Phoenix.LiveViewTest.Endpoint
  alias Phoenix.LiveViewTest.Router

  @endpoint Endpoint

  setup_all do
    ExUnit.CaptureLog.capture_log(fn -> Endpoint.start_link() end)
    :ok
  end

  setup do
    conn =
      Phoenix.ConnTest.build_conn(:get, "http://www.example.com/", nil)
      |> Plug.Test.init_test_session(%{})
      |> put_session(:test_pid, self())

    {:ok, conn: conn}
  end

  defp put_serialized_session(conn, key, value) do
    put_session(conn, key, :erlang.term_to_binary(value))
  end

  describe "redirected_params/2" do
    test "raises ArgumentError for conn with no router", %{conn: conn} do
      reason =
        conn
        |> put_serialized_session(
          :on_handle_params,
          &{:noreply, LiveView.push_redirect(&1, to: "/unknown")}
        )
        |> get("/counter/123?from=handle_params")
        |> live()

      assert_raise ArgumentError,
                   ~r"Plug.Conn does not have Router set. Pass in a Router explicity",
                   fn ->
                     redirected_params(reason, conn)
                   end
    end
  end

  describe "redirected_params/3" do
    test "matching route with path", %{conn: conn} do
      {:error, {:live_redirect, %{to: to}}} =
        conn
        |> put_serialized_session(
          :on_handle_params,
          &{:noreply, LiveView.push_redirect(&1, to: "/counter/456")}
        )
        |> get("/counter/123?from=handle_params")
        |> live()

      assert redirected_params(to, Router, conn) == %{id: "456"}
    end

    test "matching route with reason", %{conn: conn} do
      assert conn
             |> put_serialized_session(
               :on_handle_params,
               &{:noreply, LiveView.push_redirect(&1, to: "/counter/456")}
             )
             |> get("/counter/123?from=handle_params")
             |> live()
             |> redirected_params(Router, conn) == %{id: "456"}
    end

    test "raises Phoenix.Router.NoRouteError for unmatched location", %{conn: conn} do
      reason =
        conn
        |> put_serialized_session(
          :on_handle_params,
          &{:noreply, LiveView.push_redirect(&1, to: "/unknown")}
        )
        |> get("/counter/123?from=handle_params")
        |> live()

      assert_raise Phoenix.Router.NoRouteError, fn ->
        redirected_params(reason, Router, conn)
      end
    end

    test "without redirection", %{conn: conn} do
      assert_raise RuntimeError, "LiveView did not redirect", fn ->
        conn
        |> live("/counter/123")
        |> redirected_params(Router, conn)
      end
    end
  end
end
