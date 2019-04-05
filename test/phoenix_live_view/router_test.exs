defmodule Phoenix.LiveView.RouterTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  alias Phoenix.LiveViewTest.Endpoint

  @endpoint Endpoint

  defmodule Router do
    use Phoenix.Router
    import Phoenix.LiveView.Router

    scope "/", Phoenix.LiveViewTest do
      live "/thermo_defaults/:id", DashboardLive
      live "/thermo_session/:id", DashboardLive, session: [:path_params, :user_id]
      live "/thermo_container/:id", DashboardLive, container: {:span, style: "flex-grow"}
    end
  end

  setup config do
    conn =
      build_conn()
      |> put_private(:router, Router)
      |> Plug.Test.init_test_session(config[:plug_session] || %{})

    {:ok, conn: conn}
  end

  test "routing with defaults", %{conn: conn} do
    conn = get(conn, "/thermo_defaults/123")
    assert conn.resp_body =~ ~s(session: %{path_params: %{"id" => "123"}})
  end

  @tag plug_session: %{user_id: "chris"}
  test "routing with custom session", %{conn: conn} do
    conn = get(conn, "/thermo_session/123")
    assert conn.resp_body =~ ~s(session: %{path_params: %{"id" => "123"}, user_id: "chris"})
  end

  test "routing with container", %{conn: conn} do
    conn = get(conn, "/thermo_container/123")
    assert conn.resp_body =~ ~r/<span[^>]*data-phx-view="Phoenix.LiveViewTest.DashboardLive"[^>]*style="flex-grow">/
  end

  test "default layout is inflected", %{conn: conn} do
    conn = get(conn, "/thermo_session/123")
    assert conn.resp_body =~ "LAYOUT"
  end
end
