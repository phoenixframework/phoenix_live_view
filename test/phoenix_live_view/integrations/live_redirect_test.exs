defmodule Phoenix.LiveView.LiveRedirectTest do
  use ExUnit.Case

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.LiveViewTest.{Endpoint, DOM}

  @endpoint Endpoint

  setup do
    {:ok, conn: Plug.Test.init_test_session(build_conn(), %{})}
  end

  test "live_redirect within same live session", %{conn: conn} do
    assert {:ok, thermo_live, html} = live(conn, "/thermo-live-session")
    thermo_ref = Process.monitor(thermo_live.pid)

    assert [{"article", root_attrs, _}] = DOM.parse(html)

    %{"data-phx-session" => thermo_session, "data-phx-static" => thermo_static} =
      Enum.into(root_attrs, %{})

    assert {:ok, clock_live, html} = live_redirect(thermo_live, to: "/clock-live-session")
    for str <- [html, render(clock_live)] do
      content = DOM.parse(str)
      assert [{"section", attrs, _inner}] = content
      assert {"class", "clock"} in attrs
      assert {"data-phx-session", thermo_session} in attrs
      assert {"data-phx-static", thermo_static} in attrs
      assert str =~ "time: 12:00 NY"
    end

    assert_receive {:DOWN, ^thermo_ref, :process, _pid, {:shutdown, :closed}}

    assert {:ok, thermo_live2, html} = live_redirect(clock_live, to: "/thermo-live-session")
    for str <- [html, render(thermo_live2)] do
      content = DOM.parse(str)
      assert [{"article", attrs, _inner}] = content
      assert {"class", "thermo"} in attrs
      assert str =~ "The temp is"
    end
  end

  test "live_redirect refused with mismatched live session", %{conn: conn} do
    assert {:ok, thermo_live, _html} = live(conn, "/thermo-live-session")
    assert {:error, {:redirect, _}} = live_redirect(thermo_live, to: "/clock-live-session-admin")
  end

  test "live_redirect refused with no live session", %{conn: conn} do
    assert {:ok, thermo_live, _html} = live(conn, "/thermo")
    assert {:error, {:redirect, _}} = live_redirect(thermo_live, to: "/thermo-live-session")

    assert {:ok, thermo_live, _html} = live(conn, "/thermo")
    assert {:error, {:redirect, _}} = live_redirect(thermo_live, to: "/thermo-live-session-admin")
  end
end
