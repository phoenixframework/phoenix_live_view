defmodule Phoenix.LiveView.PlugTest do
  use ExUnit.Case, async: true
  import Plug.Conn
  import Phoenix.ConnTest

  alias Phoenix.LiveView.Plug, as: LiveViewPlug
  alias Phoenix.LiveViewTest.{ThermostatLive, DashboardLive, Endpoint}

  defp call(conn, view, opts \\ []) do
    opts = Keyword.merge([router: Phoenix.LiveViewTest.Router, layout: false], opts)

    conn
    |> Plug.Test.init_test_session(%{})
    |> Phoenix.LiveView.Router.fetch_live_flash([])
    |> put_private(:phoenix_live_view, {view, opts, %{name: :default, extra: %{}, vsn: 0}})
    |> LiveViewPlug.call(view)
  end

  setup config do
    conn =
      build_conn()
      |> fetch_query_params()
      |> Plug.Test.init_test_session(config[:plug_session] || %{})
      |> Plug.Conn.put_private(:phoenix_router, Router)
      |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)

    {:ok, conn: conn}
  end

  def with_session(%Plug.Conn{}, key, value) do
    %{key => value}
  end

  test "without session opts", %{conn: conn} do
    conn = call(conn, DashboardLive)
    assert conn.resp_body =~ ~s(session: %{})
  end

  @tag plug_session: %{user_id: "alex"}
  test "with user session", %{conn: conn} do
    conn = call(conn, DashboardLive)
    assert conn.resp_body =~ ~s(session: %{"user_id" => "alex"})
  end

  test "with a module container", %{conn: conn} do
    conn = call(conn, ThermostatLive)

    assert conn.resp_body =~
             ~r/<article[^>]*class="thermo"[^>]*>/
  end

  test "with container options", %{conn: conn} do
    conn = call(conn, DashboardLive, container: {:span, style: "phx-flex"})

    assert conn.resp_body =~
             ~r/<span[^>]*class="Phoenix.LiveViewTest.DashboardLive"[^>]*style="phx-flex">/
  end
end
