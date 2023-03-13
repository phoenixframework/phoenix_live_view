defmodule Phoenix.LiveView.LiveViewTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.HTML
  alias Phoenix.LiveView
  alias Phoenix.LiveViewTest.{Endpoint, DOM}

  @endpoint Endpoint

  setup config do
    {:ok, conn: Plug.Test.init_test_session(build_conn(), config[:session] || %{})}
  end

  defp simulate_bad_token_on_page(conn) do
    html = html_response(conn, 200)
    [{_id, session_token, _static} | _] = html |> DOM.parse() |> DOM.find_live_views()
    %Plug.Conn{conn | resp_body: String.replace(html, session_token, "badsession")}
  end

  defp simulate_outdated_token_on_page(conn) do
    html = html_response(conn, 200)
    [{_id, session_token, _static} | _] = html |> DOM.parse() |> DOM.find_live_views()
    salt = Phoenix.LiveView.Utils.salt!(@endpoint)
    outdated_token = Phoenix.Token.sign(@endpoint, salt, {0, %{}})
    %Plug.Conn{conn | resp_body: String.replace(html, session_token, outdated_token)}
  end

  defp simulate_expired_token_on_page(conn) do
    html = html_response(conn, 200)
    [{_id, session_token, _static} | _] = html |> DOM.parse() |> DOM.find_live_views()
    salt = Phoenix.LiveView.Utils.salt!(@endpoint)

    expired_token =
      Phoenix.Token.sign(@endpoint, salt, {Phoenix.LiveView.Static.token_vsn(), %{}}, signed_at: 0)

    %Plug.Conn{conn | resp_body: String.replace(html, session_token, expired_token)}
  end

  describe "mounting" do
    test "static mount followed by connected mount", %{conn: conn} do
      conn = get(conn, "/thermo")
      assert html_response(conn, 200) =~ "The temp is: 0"

      {:ok, _view, html} = live(conn)
      assert html =~ "The temp is: 1"
    end

    test "live mount in single call", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 1"
    end

    test "live mount sets caller", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/thermo")
      {:dictionary, dictionary} = Process.info(view.pid, :dictionary)
      assert dictionary[:"$callers"] == [self()]
    end

    test "live mount without issuing request", %{conn: conn} do
      assert_raise ArgumentError, ~r/a request has not yet been sent/, fn ->
        live(conn)
      end
    end

    test "live mount with unexpected status", %{conn: conn} do
      assert_raise ArgumentError, ~r/unexpected 404 response/, fn ->
        conn
        |> get("/not_found")
        |> live()
      end
    end
  end

  describe "rendering" do
    test "live render with valid session", %{conn: conn} do
      conn = get(conn, "/thermo")
      html = html_response(conn, 200)

      assert html =~ """
             The temp is: 0
             <button phx-click="dec">-</button>
             <button phx-click="inc">+</button>
             """

      {:ok, view, html} = live(conn)
      assert is_pid(view.pid)
      {_tag, _attrs, children} = html |> DOM.parse() |> DOM.by_id!(view.id)

      assert children == [
               "Redirect: none\nThe temp is: 1\n",
               {"button", [{"phx-click", "dec"}], ["-"]},
               {"button", [{"phx-click", "inc"}], ["+"]}
             ]
    end

    test "live render with bad session", %{conn: conn} do
      conn = simulate_bad_token_on_page(get(conn, "/thermo"))
      assert {:error, {:redirect, %{to: "http://www.example.com/thermo"}}} = live(conn)
    end

    test "live render with outdated session", %{conn: conn} do
      conn = simulate_outdated_token_on_page(get(conn, "/thermo"))
      assert {:error, {:redirect, %{to: "http://www.example.com/thermo"}}} = live(conn)
    end

    test "live render with expired session", %{conn: conn} do
      conn = simulate_expired_token_on_page(get(conn, "/thermo"))
      assert {:error, {:redirect, %{to: "http://www.example.com/thermo"}}} = live(conn)
    end

    test "live render in widget-style", %{conn: conn} do
      conn = get(conn, "/widget")
      assert html_response(conn, 200) =~ ~r/WIDGET:[\S\s]*time: 12:00 NY/
    end

    test "live render with socket.assigns", %{conn: conn} do
      assert_raise Plug.Conn.WrapperError,
                   ~r/\(KeyError\) key :boom not found in: #Phoenix.LiveView.Socket.AssignsNotInSocket<>/,
                   fn ->
                     live(conn, "/assigns-not-in-socket")
                   end
    end

    @tag session: %{nest: [], users: [%{name: "Annette O'Connor", email: "anne@email.com"}]}
    test "live render with correct escaping", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 1"
      assert html =~ "O'Connor" |> HTML.html_escape() |> HTML.safe_to_string()
    end

    test "live render with container giving class as list", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/classlist")
      assert html =~ ~s|class="foo bar"|
    end
  end

  describe "render_*" do
    test "render_click", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render_click(view, :save, %{temp: 20}) =~ "The temp is: 20"
    end

    test "render_submit", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render_submit(view, :save, %{temp: 20}) =~ "The temp is: 20"
    end

    test "render_change", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render_change(view, :save, %{temp: 21}) =~ "The temp is: 21"
    end

    test "render_change with _target", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render_change(view, :save, %{_target: "", temp: 21}) =~ "The temp is: 21[]"

      assert render_change(view, :save, %{_target: ["user"], temp: 21}) =~
               "The temp is: 21[&quot;user&quot;]"

      assert render_change(view, :save, %{_target: ["user", "name"], temp: 21}) =~
               "The temp is: 21[&quot;user&quot;, &quot;name&quot;]"

      assert render_change(view, :save, %{_target: ["another", "field"], temp: 21}) =~
               "The temp is: 21[&quot;another&quot;, &quot;field&quot;]"
    end

    test "render_key|up|down", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render(view) =~ "The temp is: 1"
      assert render_keyup(view, :key, %{"key" => "i"}) =~ "The temp is: 2"
      assert render_keydown(view, :key, %{"key" => "d"}) =~ "The temp is: 1"
      assert render_keyup(view, :key, %{"key" => "d"}) =~ "The temp is: 0"
      assert render(view) =~ "The temp is: 0"
    end

    test "render_blur and render_focus", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render(view) =~ "The temp is: 1", view.id
      assert render_blur(view, :inactive, %{value: "Zzz"}) =~ "Tap to wake – Zzz"
      assert render_focus(view, :active, %{value: "Hello!"}) =~ "Waking up – Hello!"
    end

    test "render_hook", %{conn: conn} do
      {:ok, view, _} = live(conn, "/thermo")
      assert render_hook(view, :save, %{temp: 20}) =~ "The temp is: 20"
    end
  end

  describe "container" do
    test "module DOM container", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{nest: []})
        |> get("/thermo")

      static_html = html_response(conn, 200)
      {:ok, view, connected_html} = live(conn)

      assert static_html =~
               ~r/<article class="thermo"[^>]*data-phx-main.*[^>]*>/

      assert static_html =~ ~r/<\/article>/

      assert static_html =~
               ~r/<section class="clock"[^>]*[^>]*>/

      assert static_html =~ ~r/<\/section>/

      assert connected_html =~
               ~r/<section class="clock"[^>]*[^>]*>/

      assert connected_html =~ ~r/<\/section>/

      assert render(view) =~
               ~r/<section class="clock"[^>]*[^>]*>/

      assert render(view) =~ ~r/<\/section>/
    end

    test "custom DOM container and attributes", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{nest: [container: {:p, class: "clock-flex"}]})
        |> get("/thermo-container")

      static_html = html_response(conn, 200)
      {:ok, view, connected_html} = live(conn)

      assert static_html =~
               ~r/<span class="thermo"[^>]*[^>]*style=\"thermo-flex&lt;script&gt;\">/

      assert static_html =~ ~r/<\/span>/

      assert static_html =~
               ~r/<p class=\"clock-flex"[^>]*[^>]*>/

      assert static_html =~ ~r/<\/p>/

      assert connected_html =~
               ~r/<p class=\"clock-flex"[^>]*[^>]*>/

      assert connected_html =~ ~r/<\/p>/

      assert render(view) =~
               ~r/<p class=\"clock-flex"[^>]*[^>]*>/

      assert render(view) =~ ~r/<\/p>/
    end
  end

  describe "messaging callbacks" do
    test "handle_event with no change in socket", %{conn: conn} do
      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 1"
      assert render_click(view, :noop) =~ "The temp is: 1"
    end

    test "handle_info with change", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/thermo")

      assert render(view) =~ "The temp is: 1"

      GenServer.call(view.pid, {:set, :val, 1})
      GenServer.call(view.pid, {:set, :val, 2})
      GenServer.call(view.pid, {:set, :val, 3})

      assert DOM.parse(render_click(view, :inc)) ==
               DOM.parse("""
               Redirect: none\nThe temp is: 4
               <button phx-click="dec">-</button>
               <button phx-click="inc">+</button>
               """)

      assert DOM.parse(render_click(view, :dec)) ==
               DOM.parse("""
               Redirect: none\nThe temp is: 3
               <button phx-click="dec">-</button>
               <button phx-click="inc">+</button>
               """)

      [{_, _, child_nodes} | _] = DOM.parse(render(view))

      assert child_nodes ==
               DOM.parse("""
               Redirect: none\nThe temp is: 3
               <button phx-click="dec">-</button>
               <button phx-click="inc">+</button>
               """)
    end
  end

  describe "title" do
    test "sends page title updates", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/thermo")
      GenServer.call(view.pid, {:set, :page_title, "New Title"})
      assert page_title(view) =~ "New Title"
    end
  end

  describe "live_isolated" do
    test "renders a live view with custom session", %{conn: conn} do
      {:ok, view, _} =
        live_isolated(conn, Phoenix.LiveViewTest.DashboardLive, session: %{"hello" => "world"})

      assert render(view) =~ "session: %{&quot;hello&quot; =&gt; &quot;world&quot;}"
    end

    test "renders a live view with custom session and a router", %{conn: conn} do
      conn = %Plug.Conn{conn | request_path: "/router/thermo_defaults/123"}

      {:ok, view, _} =
        live_isolated(conn, Phoenix.LiveViewTest.DashboardLive, session: %{"hello" => "world"})

      assert render(view) =~ "session: %{&quot;hello&quot; =&gt; &quot;world&quot;}"
    end

    test "raises if handle_params is implemented", %{conn: conn} do
      assert_raise ArgumentError,
                   ~r/it is not mounted nor accessed through the router live\/3 macro/,
                   fn -> live_isolated(conn, Phoenix.LiveViewTest.ParamCounterLive) end
    end

    test "works without an initialized session" do
      {:ok, view, _} =
        live_isolated(Phoenix.ConnTest.build_conn(), Phoenix.LiveViewTest.DashboardLive,
          session: %{"hello" => "world"}
        )

      assert render(view) =~ "session: %{&quot;hello&quot; =&gt; &quot;world&quot;}"
    end

    test "raises on session with atom keys" do
      assert_raise ArgumentError, ~r"LiveView :session must be a map with string keys,", fn ->
        live_isolated(Phoenix.ConnTest.build_conn(), Phoenix.LiveViewTest.DashboardLive,
          session: %{hello: "world"}
        )
      end
    end
  end

  describe "format_status/2" do
    test "returns LiveView information", %{conn: conn} do
      {:ok, %{pid: pid}, _html} = live(conn, "/clock")

      assert {:status, ^pid, {:module, :gen_server},
              [
                _pdict,
                :running,
                _parent,
                _dbg_opts,
                [
                  header: 'Status for generic server ' ++ _,
                  data: _gen_server_data,
                  data: [
                    {'LiveView', Phoenix.LiveViewTest.ClockLive},
                    {'Parent pid', nil},
                    {'Transport pid', _},
                    {'Topic', <<_::binary>>},
                    {'Components count', 0}
                  ]
                ]
              ]} = :sys.get_status(pid)
    end
  end

  describe "transport_pid/1" do
    test "raises when not connected" do
      assert_raise ArgumentError, ~r/may only be called when the socket is connected/, fn ->
        LiveView.transport_pid(%LiveView.Socket{})
      end
    end

    test "return the transport pid as the test process when connected", %{conn: conn} do
      {:ok, clock_view, _html} = live(conn, "/clock")
      parent = self()
      ref = make_ref()

      send(
        clock_view.pid,
        {:run,
         fn socket ->
           send(parent, {ref, LiveView.transport_pid(socket)})
         end}
      )

      assert_receive {^ref, transport_pid}
      assert transport_pid == self()
    end
  end

  describe "connected mount exceptions" do
    test "when disconnected, raises normally per plug wrapper", %{conn: conn} do
      assert_raise(Plug.Conn.WrapperError, ~r/Phoenix.LiveViewTest.ThermostatLive.Error/, fn ->
        get(conn, "/thermo?raise_disconnected=500")
      end)

      assert_raise(Plug.Conn.WrapperError, ~r/Phoenix.LiveViewTest.ThermostatLive.Error/, fn ->
        get(conn, "/thermo?raise_disconnected=404")
      end)
    end

    test "when connected, raises and exits for 5xx", %{conn: conn} do
      assert {{exception, _}, _} = catch_exit(live(conn, "/thermo?raise_connected=500"))
      assert %Phoenix.LiveViewTest.ThermostatLive.Error{plug_status: 500} = exception
    end

    test "when connected, raises and wraps 4xx in client response", %{conn: conn} do
      assert {reason, _} = catch_exit(live(conn, "/thermo?raise_connected=404"))
      assert %{reason: "reload", status: 404} = reason
    end
  end
end
