defmodule Phoenix.LiveView.NavigationTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.LiveViewTest.{Endpoint, DOM}

  @endpoint Endpoint

  setup do
    {:ok, conn: Plug.Test.init_test_session(build_conn(), %{})}
  end

  # Nested used of navigation helpers go to nested_test.exs

  describe "push_navigate" do
    test "when disconnected", %{conn: conn} do
      conn = get(conn, "/redir?during=disconnected&kind=push_navigate&to=/thermo")
      assert redirected_to(conn) == "/thermo"

      {:error, {:live_redirect, %{to: "/thermo"}}} =
        live(conn, "/redir?during=disconnected&kind=push_navigate&to=/thermo")
    end

    test "when connected", %{conn: conn} do
      conn = get(conn, "/redir?during=connected&kind=push_navigate&to=/thermo")
      assert html_response(conn, 200) =~ "parent_content"
      assert {:error, {:live_redirect, %{kind: :push, to: "/thermo"}}} = live(conn)
    end

    test "child when disconnected", %{conn: conn} do
      conn = get(conn, "/redir?during=disconnected&kind=push_navigate&child_to=/thermo")
      assert redirected_to(conn) == "/thermo"
    end

    test "child when connected", %{conn: conn} do
      conn =
        get(conn, "/redir?during=connected&kind=push_navigate&child_to=/thermo?from_child=true")

      assert html_response(conn, 200) =~ "child_content"
      assert {:error, {:live_redirect, %{to: "/thermo?from_child=true"}}} = live(conn)
    end
  end

  describe "push_patch" do
    test "when disconnected", %{conn: conn} do
      assert_raise Plug.Conn.WrapperError, ~r/attempted to live patch while/, fn ->
        get(conn, "/redir?during=disconnected&kind=push_patch&to=/redir?patched=true")
      end
    end

    test "when connected", %{conn: conn} do
      conn = get(conn, "/redir?during=connected&kind=push_patch&to=/redir?patched=true")
      assert html_response(conn, 200) =~ "parent_content"

      assert Exception.format(:exit, catch_exit(live(conn))) =~
               "attempted to live patch while mounting"
    end

    test "child when disconnected", %{conn: conn} do
      assert_raise Plug.Conn.WrapperError,
                   ~r/a LiveView cannot be mounted while issuing a live patch to the client/,
                   fn ->
                     get(
                       conn,
                       "/redir?during=disconnected&kind=push_patch&child_to=/redir?patched=true"
                     )
                   end
    end

    test "child when connected", %{conn: conn} do
      conn = get(conn, "/redir?during=connected&kind=push_patch&child_to=/redir?patched=true")
      assert html_response(conn, 200) =~ "child_content"

      assert Exception.format(:exit, catch_exit(live(conn))) =~
               "a LiveView cannot be mounted while issuing a live patch to the client"
    end
  end

  describe "redirect" do
    test "when disconnected", %{conn: conn} do
      conn = get(conn, "/redir?during=disconnected&kind=redirect&to=/thermo")
      assert redirected_to(conn) == "/thermo"

      {:error, {:redirect, %{to: "/thermo"}}} =
        live(conn, "/redir?during=disconnected&kind=redirect&to=/thermo")
    end

    test "when connected", %{conn: conn} do
      conn = get(conn, "/redir?during=connected&kind=redirect&to=/thermo")
      assert html_response(conn, 200) =~ "parent_content"
      assert {:error, {:redirect, %{to: "/thermo"}}} = live(conn)
    end

    test "child when disconnected", %{conn: conn} do
      conn =
        get(conn, "/redir?during=disconnected&kind=redirect&child_to=/thermo?from_child=true")

      assert redirected_to(conn) == "/thermo?from_child=true"
    end

    test "child when connected", %{conn: conn} do
      conn = get(conn, "/redir?during=connected&kind=redirect&child_to=/thermo?from_child=true")
      assert html_response(conn, 200) =~ "parent_content"
      assert {:error, {:redirect, %{to: "/thermo?from_child=true"}}} = live(conn)
    end
  end

  describe "external redirect" do
    test "when disconnected", %{conn: conn} do
      conn = get(conn, "/redir?during=disconnected&kind=external&to=https://phoenixframework.org")
      assert redirected_to(conn) == "https://phoenixframework.org"

      {:error, {:redirect, %{to: "https://phoenixframework.org"}}} =
        live(conn, "/redir?during=disconnected&kind=external&to=https://phoenixframework.org")
    end

    test "when connected", %{conn: conn} do
      conn = get(conn, "/redir?during=connected&kind=external&to=https://phoenixframework.org")
      assert html_response(conn, 200) =~ "parent_content"
      assert {:error, {:redirect, %{to: "https://phoenixframework.org"}}} = live(conn)
    end

    test "child when disconnected", %{conn: conn} do
      conn =
        get(
          conn,
          "/redir?during=disconnected&kind=external&child_to=https://phoenixframework.org?from_child=true"
        )

      assert redirected_to(conn) == "https://phoenixframework.org?from_child=true"
    end

    test "child when connected", %{conn: conn} do
      conn =
        get(
          conn,
          "/redir?during=connected&kind=external&child_to=https://phoenixframework.org?from_child=true"
        )

      assert html_response(conn, 200) =~ "parent_content"

      assert {:error, {:redirect, %{to: "https://phoenixframework.org?from_child=true"}}} =
               live(conn)
    end
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

    test "assigns given class list to redirected to container", %{conn: conn} do
      assert {:ok, thermo_live, _} = live(conn, "/thermo-live-session")
      assert {:ok, _classlist_live, html} = live_redirect(thermo_live, to: "/classlist")

      assert html =~ ~s|class="foo bar"|
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
