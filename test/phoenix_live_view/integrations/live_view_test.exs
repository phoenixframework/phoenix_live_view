defmodule Phoenix.LiveView.LiveViewTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.HTML
  alias Phoenix.LiveView
  alias Phoenix.LiveViewTest.DOM
  alias Phoenix.LiveViewTest.Support.Endpoint

  @endpoint Endpoint

  setup config do
    {:ok, conn: Plug.Test.init_test_session(build_conn(), config[:session] || %{})}
  end

  defp simulate_bad_token_on_page(%Plug.Conn{} = conn) do
    html = html_response(conn, 200)
    [{_id, session_token, _static} | _] = html |> DOM.parse() |> DOM.find_live_views()
    %{conn | resp_body: String.replace(html, session_token, "badsession")}
  end

  defp simulate_outdated_token_on_page(%Plug.Conn{} = conn) do
    html = html_response(conn, 200)
    [{_id, session_token, _static} | _] = html |> DOM.parse() |> DOM.find_live_views()
    salt = Phoenix.LiveView.Utils.salt!(@endpoint)
    outdated_token = Phoenix.Token.sign(@endpoint, salt, {0, %{}})
    %{conn | resp_body: String.replace(html, session_token, outdated_token)}
  end

  defp simulate_expired_token_on_page(%Plug.Conn{} = conn) do
    html = html_response(conn, 200)
    [{_id, session_token, _static} | _] = html |> DOM.parse() |> DOM.find_live_views()
    salt = Phoenix.LiveView.Utils.salt!(@endpoint)

    expired_token =
      Phoenix.Token.sign(@endpoint, salt, {Phoenix.LiveView.Static.token_vsn(), %{}},
        signed_at: 0
      )

    %{conn | resp_body: String.replace(html, session_token, expired_token)}
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

  describe "render_with" do
    test "with custom function", %{conn: conn} do
      conn = get(conn, "/render-with")
      html = html_response(conn, 200)
      assert html =~ "FROM RENDER WITH!"

      {:ok, view, html} = live(conn)
      assert html =~ "FROM RENDER WITH!"
      assert render(view) =~ "FROM RENDER WITH!"
    end
  end

  describe "rendering" do
    test "live render with valid session", %{conn: conn} do
      conn = get(conn, "/thermo")
      html = html_response(conn, 200)

      assert html =~ """
             <p>The temp is: 0</p>
             <button phx-click="dec">-</button>
             <button phx-click="inc">+</button>
             """

      {:ok, view, html} = live(conn)
      assert is_pid(view.pid)
      {_tag, _attrs, children} = html |> DOM.parse() |> DOM.by_id!(view.id)

      assert children == [
               {"p", [], ["Redirect: none"]},
               {"p", [], ["The temp is: 1"]},
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
      assert_raise KeyError,
                   ~r/key :boom not found in:\s+#Phoenix.LiveView.Socket.AssignsNotInSocket<>/,
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

    test "raises for duplicate ids by default", %{conn: conn} do
      Process.flag(:trap_exit, true)

      fun = fn ->
        {:ok, view, _html} = live(conn, "/duplicate-id")
        render(view)
      end

      assert catch_exit(fun.())
      assert_receive {:EXIT, _pid, {exception, _}}
      assert Exception.message(exception) =~ "Duplicate id found while testing LiveView: a"
    end

    test "raises for duplicate ids when on_error: :raise", %{conn: conn} do
      Process.flag(:trap_exit, true)

      fun = fn ->
        {:ok, view, _html} = live(conn, "/duplicate-id", on_error: :raise)
        render(view)
      end

      assert catch_exit(fun.())
      assert_receive {:EXIT, _pid, {exception, _}}
      assert Exception.message(exception) =~ "Duplicate id found while testing LiveView: a"
    end

    test "raises for duplicate components by default", %{conn: conn} do
      Process.flag(:trap_exit, true)

      fun = fn ->
        {:ok, view, _html} = live(conn, "/dynamic-duplicate-component", on_error: :raise)
        view |> element("button", "Toggle duplicate LC") |> render_click()
        render(view)
      end

      assert catch_exit(fun.())
      assert_receive {:EXIT, _pid, {exception, _}}
      message = Exception.message(exception)
      assert message =~ "Duplicate live component found while testing LiveView:"
      assert message =~ "I am LiveComponent2"
      refute message =~ "I am a LC inside nested LV"
    end

    test "raises for duplicate components when on_error: :raise", %{conn: conn} do
      Process.flag(:trap_exit, true)

      fun = fn ->
        {:ok, view, _html} = live(conn, "/dynamic-duplicate-component", on_error: :raise)
        view |> element("button", "Toggle duplicate LC") |> render_click()
        render(view)
      end

      assert catch_exit(fun.())
      assert_receive {:EXIT, _pid, {exception, _}}
      message = Exception.message(exception)
      assert message =~ "Duplicate live component found while testing LiveView:"
      assert message =~ "I am LiveComponent2"
      refute message =~ "I am a LC inside nested LV"
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

      dom_matcher = fn html ->
        assert [
                 {"article",
                  [
                    {"id", id},
                    {"data-phx-main", _},
                    {"data-phx-session", _},
                    {"data-phx-static", _},
                    {"class", "thermo"}
                  ],
                  [
                    _p1,
                    _p2,
                    _btn_down,
                    _btn_up,
                    {"section",
                     [
                       {"id", "clock"},
                       {"data-phx-session", _},
                       {"data-phx-static", _},
                       {"data-phx-parent-id", id},
                       {"class", "clock"}
                     ], _}
                  ]}
               ] = DOM.parse(html)
      end

      dom_matcher.(static_html)
      dom_matcher.(connected_html)
      dom_matcher.(render(view))
    end

    test "custom DOM container and attributes", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{nest: [container: {:p, class: "clock-flex"}]})
        |> get("/thermo-container")

      static_html = html_response(conn, 200)
      {:ok, view, connected_html} = live(conn)

      dom_matcher = fn html ->
        assert [
                 {"span",
                  [
                    {"id", id},
                    {"data-phx-main", _},
                    {"data-phx-session", _},
                    {"data-phx-static", _},
                    {"class", "thermo"},
                    {"style", "thermo-flex<script>"}
                  ],
                  [
                    _p1,
                    _p2,
                    _btn_down,
                    _btn_up,
                    {"p",
                     [
                       {"id", "clock"},
                       {"data-phx-session", _},
                       {"data-phx-static", _},
                       {"data-phx-parent-id", id},
                       {"class", "clock-flex"}
                     ], _}
                  ]}
               ] = DOM.parse(html)
      end

      dom_matcher.(static_html)
      dom_matcher.(connected_html)
      dom_matcher.(render(view))
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
               <p>Redirect: none</p>
               <p>The temp is: 4</p>
               <button phx-click="dec">-</button>
               <button phx-click="inc">+</button>
               """)

      assert DOM.parse(render_click(view, :dec)) ==
               DOM.parse("""
               <p>Redirect: none</p>
               <p>The temp is: 3</p>
               <button phx-click="dec">-</button>
               <button phx-click="inc">+</button>
               """)

      [{_, _, child_nodes} | _] = DOM.parse(render(view))

      assert child_nodes ==
               DOM.parse("""
               <p>Redirect: none</p>
               <p>The temp is: 3</p>
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

      GenServer.call(view.pid, {:set, :page_title, "<i>New Title</i>"})
      assert page_title(view) =~ "&lt;i&gt;New Title&lt;/i&gt;"
    end
  end

  describe "live_isolated" do
    test "renders a live view with custom session", %{conn: conn} do
      {:ok, view, _} =
        live_isolated(conn, Phoenix.LiveViewTest.Support.DashboardLive,
          session: %{"hello" => "world"}
        )

      assert render(view) =~ "session: %{&quot;hello&quot; =&gt; &quot;world&quot;}"
    end

    test "renders a live view with custom session and a router", %{conn: %Plug.Conn{} = conn} do
      conn = %{conn | request_path: "/router/thermo_defaults/123"}

      {:ok, view, _} =
        live_isolated(conn, Phoenix.LiveViewTest.Support.DashboardLive,
          session: %{"hello" => "world"}
        )

      assert render(view) =~ "session: %{&quot;hello&quot; =&gt; &quot;world&quot;}"
    end

    test "raises if handle_params is implemented", %{conn: conn} do
      assert_raise ArgumentError,
                   ~r/it is not mounted nor accessed through the router live\/3 macro/,
                   fn -> live_isolated(conn, Phoenix.LiveViewTest.Support.ParamCounterLive) end
    end

    test "works without an initialized session" do
      {:ok, view, _} =
        live_isolated(Phoenix.ConnTest.build_conn(), Phoenix.LiveViewTest.Support.DashboardLive,
          session: %{"hello" => "world"}
        )

      assert render(view) =~ "session: %{&quot;hello&quot; =&gt; &quot;world&quot;}"
    end

    test "raises on session with atom keys" do
      assert_raise ArgumentError, ~r"LiveView :session must be a map with string keys,", fn ->
        live_isolated(Phoenix.ConnTest.build_conn(), Phoenix.LiveViewTest.Support.DashboardLive,
          session: %{hello: "world"}
        )
      end
    end

    test "raises for duplicate ids by default" do
      Process.flag(:trap_exit, true)

      fun = fn ->
        {:ok, view, _html} =
          live_isolated(
            Phoenix.ConnTest.build_conn(),
            Phoenix.LiveViewTest.Support.DuplicateIdLive
          )

        # errors are detected asynchronously, so we need to render again for the message to be processed
        render(view)
      end

      assert catch_exit(fun.())
      assert_receive {:EXIT, _, {exception, _}}
      assert Exception.message(exception) =~ "Duplicate id found while testing LiveView: a"
    end

    test "raises for duplicate ids when on_error: raise" do
      Process.flag(:trap_exit, true)

      fun = fn ->
        {:ok, view, _html} =
          live_isolated(
            Phoenix.ConnTest.build_conn(),
            Phoenix.LiveViewTest.Support.DuplicateIdLive,
            on_error: :raise
          )

        # errors are detected asynchronously, so we need to render again for the message to be processed
        render(view)
      end

      assert catch_exit(fun.())
      assert_receive {:EXIT, _, {exception, _}}
      assert Exception.message(exception) =~ "Duplicate id found while testing LiveView: a"
    end

    test "raises for duplicate components by default" do
      Process.flag(:trap_exit, true)

      fun = fn ->
        {:ok, view, _html} =
          live_isolated(
            Phoenix.ConnTest.build_conn(),
            Phoenix.LiveViewTest.Support.DynamicDuplicateComponentLive
          )

        view |> element("button", "Toggle duplicate LC") |> render_click()
        render(view)
      end

      # errors are detected asynchronously, so we need to render again for the message to be processed
      assert catch_exit(fun.())

      assert_receive {:EXIT, _, {exception, _}}

      assert Exception.message(exception) =~
               "Duplicate live component found while testing LiveView:"
    end

    test "raises for duplicate components when on_error: raise" do
      Process.flag(:trap_exit, true)

      fun = fn ->
        {:ok, view, _html} =
          live_isolated(
            Phoenix.ConnTest.build_conn(),
            Phoenix.LiveViewTest.Support.DynamicDuplicateComponentLive,
            on_error: :raise
          )

        view |> element("button", "Toggle duplicate LC") |> render_click()
        render(view)
      end

      # errors are detected asynchronously, so we need to render again for the message to be processed
      assert catch_exit(fun.())

      assert_receive {:EXIT, _, {exception, _}}

      assert Exception.message(exception) =~
               "Duplicate live component found while testing LiveView:"
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
                  header: ~c"Status for generic server " ++ _,
                  data: _gen_server_data,
                  data: [
                    {~c"LiveView", Phoenix.LiveViewTest.Support.ClockLive},
                    {~c"Parent pid", nil},
                    {~c"Transport pid", _},
                    {~c"Topic", <<_::binary>>},
                    {~c"Components count", 0}
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
      assert_raise(
        Phoenix.LiveViewTest.Support.ThermostatLive.Error,
        fn ->
          get(conn, "/thermo?raise_disconnected=500")
        end
      )

      assert_raise(
        Phoenix.LiveViewTest.Support.ThermostatLive.Error,
        fn ->
          get(conn, "/thermo?raise_disconnected=404")
        end
      )
    end

    test "when connected, raises and exits for 5xx", %{conn: conn} do
      assert {{exception, _}, _} = catch_exit(live(conn, "/thermo?raise_connected=500"))
      assert %Phoenix.LiveViewTest.Support.ThermostatLive.Error{plug_status: 500} = exception
    end

    test "when connected, raises and wraps 4xx in client response", %{conn: conn} do
      assert {reason, _} = catch_exit(live(conn, "/thermo?raise_connected=404"))
      assert %{reason: "reload", status: 404, token: token} = reason

      # does not expose stack or exception module by default
      assert Phoenix.LiveView.Static.verify_token(@endpoint, token) ==
               {:ok,
                %{
                  status: 404,
                  exception: nil,
                  stack: [],
                  view: "Phoenix.LiveViewTest.Support.ThermostatLive"
                }}

      response =
        assert_error_sent(404, fn ->
          conn
          |> put_req_cookie("__phoenix_reload_status__", token)
          |> get("/thermo")
        end)

      # deletes cookie with response
      {404, resp_headers, "Not Found"} = response
      assert %{"set-cookie" => "__phoenix_reload_status__=;" <> _} = Map.new(resp_headers)
    end
  end
end
