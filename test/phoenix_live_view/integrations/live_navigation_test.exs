defmodule Phoenix.LiveView.LiveNavigationTest do
  use ExUnit.Case

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.LiveViewTest.{Endpoint, DOM}
  @endpoint Endpoint

  setup_all do
    ExUnit.CaptureLog.capture_log(fn -> Endpoint.start_link() end)
    :ok
  end

  setup do
    {:ok, conn: Plug.Test.init_test_session(build_conn(), %{})}
  end

  describe "live_redirect" do
    test "within same live session", %{conn: conn} do
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

    test "refused with mismatched live session", %{conn: conn} do
      assert {:ok, thermo_live, _html} = live(conn, "/thermo-live-session")

      assert {:error, {:redirect, _}} =
               live_redirect(thermo_live, to: "/clock-live-session-admin")
    end

    test "refused with no live session", %{conn: conn} do
      assert {:ok, thermo_live, _html} = live(conn, "/thermo")
      assert {:error, {:redirect, _}} = live_redirect(thermo_live, to: "/thermo-live-session")

      assert {:ok, thermo_live, _html} = live(conn, "/thermo")

      assert {:error, {:redirect, _}} =
               live_redirect(thermo_live, to: "/thermo-live-session-admin")
    end

    test "with outdated token", %{conn: conn} do
      assert {:ok, thermo_live, _html} = live(conn, "/thermo-live-session")

      assert {:error, {:redirect, %{to: "http://www.example.com/clock-live-session"}}} =
               Phoenix.LiveViewTest.__live_redirect__(
                 thermo_live,
                 [to: "/clock-live-session"],
                 fn _token ->
                   salt = Phoenix.LiveView.Utils.salt!(@endpoint)
                   Phoenix.Token.sign(@endpoint, salt, {0, %{}})
                 end
               )
    end
  end

  describe "live_patch" do
    test "patches on custom host with full path", %{conn: conn} do
      {:ok, live, html} = live(conn, "https://app.example.com/with-host/full")
      assert html =~ "URI: https://app.example.com/with-host/full"
      assert html =~ "LiveAction: full"

      html = live |> element("#path") |> render_click()
      assert html =~ "URI: https://app.example.com/with-host/path"
      assert html =~ "LiveAction: path"

      html = live |> element("#full") |> render_click()
      assert html =~ "URI: https://app.example.com/with-host/full"
      assert html =~ "LiveAction: full"
    end

    test "patches on custom host with partial path", %{conn: conn} do
      {:ok, live, html} = live(%{conn | host: "app.example.com"}, "/with-host/path")
      assert html =~ "URI: http://app.example.com/with-host/path"
      assert html =~ "LiveAction: path"

      html = live |> element("#full") |> render_click()
      assert html =~ "URI: https://app.example.com/with-host/full"
      assert html =~ "LiveAction: full"

      html = live |> element("#path") |> render_click()
      assert html =~ "URI: http://app.example.com/with-host/path"
      assert html =~ "LiveAction: path"
    end
  end
end
