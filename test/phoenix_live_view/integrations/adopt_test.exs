defmodule Phoenix.LiveView.AdoptTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.Component, only: [sigil_H: 2]

  alias __MODULE__.{Endpoint, NotFoundError}

  @endpoint Endpoint
  @moduletag :capture_log

  defmodule NotFoundError do
    defexception message: "not found", plug_status: 404
  end

  defmodule AdoptLive do
    use Phoenix.LiveView, adoptable: true

    def mount(params, _session, socket) do
      socket = assign_new(socket, :test_pid, fn -> nil end)

      if pid = socket.assigns.test_pid do
        send(pid, {:mounted, self(), connected?(socket), socket.transport_pid})
      end

      case params do
        %{"redirect" => "external"} ->
          {:ok, redirect(socket, to: "/elsewhere")}

        %{"redirect" => "navigate"} ->
          {:ok,
           socket
           |> Phoenix.LiveView.put_flash(:info, "navigated")
           |> push_navigate(to: "/adopt/other")}

        %{"raise" => "not_found"} ->
          raise NotFoundError

        %{"raise" => "exit"} ->
          exit(:mount_exit)

        %{"raise" => "throw"} ->
          throw(:mount_throw)

        _ ->
          {:ok,
           socket
           |> assign(page_title: "Adopted")
           |> assign(connected: connected?(socket))
           |> assign(connect_params: get_connect_params(socket))
           |> assign(static_changed: static_changed?(socket))
           |> assign_new(:current_user, fn -> "fetched in mount" end)}
      end
    end

    def render(assigns) do
      ~H"""
      <p id="connected">connected: {@connected}</p>
      <p id="connect-params">connect params: {inspect(@connect_params)}</p>
      <p id="static-changed">static changed: {@static_changed}</p>
      <p id="user">user: {@current_user}</p>
      <p id="csrf">{Plug.CSRFProtection.get_csrf_token()}</p>
      """
    end
  end

  defmodule DeadLive do
    use Phoenix.LiveView

    def mount(_params, _session, socket), do: {:ok, assign(socket, connected: connected?(socket))}
    def render(assigns), do: ~H"<p>connected: {@connected}</p>"
  end

  defmodule SecondLive do
    use Phoenix.LiveView, adoptable: true

    def mount(_params, _session, socket) do
      {:ok, assign(socket, connected: connected?(socket))}
    end

    def render(assigns), do: ~H"<p>second connected: {@connected}</p>"
  end

  defmodule ErrorHTML do
    def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)
  end

  defmodule PatchLive do
    use Phoenix.LiveView, adoptable: true

    def mount(_params, _session, socket), do: {:ok, socket}

    # normalizes the URL, as LiveViews do for pagination
    def handle_params(%{"page" => page}, _uri, socket), do: {:noreply, assign(socket, page: page)}

    def handle_params(_params, _uri, socket),
      do: {:noreply, push_patch(socket, to: "/patch?page=1")}

    def render(assigns), do: ~H"<p>page: {@page}</p>"
  end

  # renders LiveViews like a controller template, which cannot return the conn
  defmodule EmbedController do
    use Phoenix.Controller, formats: [:html]

    def show(conn, _params) do
      content =
        for id <- ["first", "second"] do
          conn
          |> Phoenix.Component.live_render(SecondLive, id: id)
          |> Phoenix.HTML.safe_to_string()
        end

      html(conn, Enum.join(content))
    end
  end

  defmodule Layouts do
    use Phoenix.Component

    def root(assigns) do
      ~H"""
      <html>
        <head>
          <title>{assigns[:page_title]}</title>
        </head>
        <body>{@inner_content}</body>
      </html>
      """
    end

    def with_second(assigns) do
      ~H"""
      <html>
        <body>
          {@inner_content}
          {Phoenix.Component.live_render(@conn, SecondLive, id: "second")}
        </body>
      </html>
      """
    end
  end

  defmodule Router do
    use Phoenix.Router
    import Phoenix.LiveView.Router

    pipeline :browser do
      plug :fetch_session
      plug :fetch_live_flash
      plug :protect_from_forgery
      plug :put_root_layout, html: {Layouts, :root}
    end

    scope "/" do
      pipe_through :browser

      live "/adopt", AdoptLive
      live "/adopt/other", AdoptLive
      live "/dead", DeadLive
      live "/patch", PatchLive
      Phoenix.Router.get("/embed", EmbedController, :show)

      live_session :with_second, root_layout: {Layouts, :with_second} do
        live "/with-second", AdoptLive
      end
    end
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix_live_view

    @session_options [store: :cookie, key: "_adopt_key", signing_salt: "adopt"]

    socket "/live", Phoenix.LiveView.Socket,
      websocket: [resumable: true, connect_info: [session: @session_options]],
      longpoll: [connect_info: [session: @session_options]]

    socket "/plain", Phoenix.LiveView.Socket, websocket: true

    plug Plug.Session, @session_options
    plug Router

    defoverridable config: 1, config: 2

    # the :adopt configuration of each test
    def config(:live_view) do
      [signing_salt: "1234567812345678", adopt: Process.get(:adopt_config, socket: "/live")]
    end

    def config(which), do: super(which)
    def config(which, default), do: super(which, default)

    def adopt?(conn, enabled), do: Map.get(conn.assigns, :adopt?, enabled)
  end

  Application.put_env(:phoenix_live_view, Endpoint,
    secret_key_base: String.duplicate("abcdefgh", 8),
    pubsub_server: __MODULE__.PubSub,
    render_errors: [formats: [html: ErrorHTML]],
    server: false,
    # the client connects to the socket with this prefix
    url: [path: "/prefix"]
  )

  setup do
    start_supervised!({Phoenix.PubSub, name: __MODULE__.PubSub})
    start_supervised!(Endpoint)
    :ok
  end

  # LiveViewTest renders in the test process, so we ask for adoption explicitly
  defp adopt_conn(assigns \\ %{}) do
    build_conn()
    |> Plug.Conn.put_private(:phoenix_live_view_adopt, :test)
    |> Map.update!(:assigns, &Map.merge(&1, Map.put(assigns, :test_pid, self())))
  end

  defp attr(html, selector, attr) do
    html |> LazyHTML.from_document() |> LazyHTML.query(selector) |> LazyHTML.attribute(attr)
  end

  test "mounts the LiveView once, connected, in a detached socket session" do
    count = Phoenix.Socket.detached_count()
    conn = get(adopt_conn(), "/adopt")
    html = html_response(conn, 200)

    assert_received {:mounted, lv, true, session}
    refute_received {:mounted, _, _, _}
    assert Process.alive?(lv)
    assert Phoenix.Socket.detached_count() == count + 1

    assert html =~ "connected: true"
    # the client did not join yet
    assert html =~ "connect params: nil"
    assert html =~ "static changed: false"
    # the root layout receives the assigns of the LiveView
    assert html =~ "<title>Adopted</title>"

    [view_id] = attr(html, "[data-phx-main]", "id")
    assert [token] = attr(html, "##{view_id}", "data-phx-adopt")
    assert ["phx-" <> _] = attr(html, "##{view_id}", "data-phx-adopt-ref")
    assert ["/prefix/live"] = attr(html, "##{view_id}", "data-phx-adopt-socket")
    assert [_] = attr(html, "##{view_id}", "data-phx-session")
    assert [_] = attr(html, "##{view_id}", "data-phx-static")

    {:ok, {:v1, _, ^session, _}} =
      Phoenix.Token.verify(Endpoint, Atom.to_string(__MODULE__.PubSub), token)
  end

  test "assign_new uses the assigns of the request" do
    html = adopt_conn(%{current_user: "from conn"}) |> get("/adopt") |> html_response(200)
    assert html =~ "user: from conn"
  end

  test "renders forms with the CSRF token of the request" do
    conn = get(adopt_conn(), "/adopt")
    token = conn |> html_response(200) |> LazyHTML.from_document() |> LazyHTML.query("#csrf")
    token = LazyHTML.text(token)

    state =
      Plug.CSRFProtection.dump_state_from_session(Plug.Conn.get_session(conn, "_csrf_token"))

    assert Plug.CSRFProtection.valid_state_and_csrf_token?(state, token)
  end

  test "LiveViews in the layout join the session of the page" do
    html = adopt_conn() |> get("/with-second") |> html_response(200)
    assert html =~ "connected: true"
    assert html =~ "second connected: true"
    assert [token, token] = attr(html, "[data-phx-adopt]", "data-phx-adopt")
    assert [ref1, ref2] = attr(html, "[data-phx-adopt]", "data-phx-adopt-ref")
    assert ref1 != ref2
  end

  test "LiveViews in a controller template join the same session" do
    count = Phoenix.Socket.detached_count()
    html = adopt_conn() |> get("/embed") |> html_response(200)
    assert html =~ "second connected: true"
    refute html =~ "second connected: false"
    assert [token, token] = attr(html, "[data-phx-adopt]", "data-phx-adopt")
    assert Phoenix.Socket.detached_count() == count + 1
  end

  test "requests of the same process get their own session" do
    html = adopt_conn() |> get("/adopt") |> html_response(200)
    assert [first] = attr(html, "[data-phx-adopt]", "data-phx-adopt")
    html = adopt_conn() |> get("/adopt") |> html_response(200)
    assert [second] = attr(html, "[data-phx-adopt]", "data-phx-adopt")
    assert first != second
  end

  test "requests that a process dispatches with the same adapter get their own session" do
    conn = Plug.Adapters.Test.Conn.conn(adopt_conn(), :get, "/adopt", nil)

    tokens =
      for _ <- 1..2 do
        conn
        |> Endpoint.call(Endpoint.init([]))
        |> html_response(200)
        |> attr("[data-phx-adopt]", "data-phx-adopt")
      end

    assert [[first], [second]] = tokens
    assert first != second
  end

  test "redirects when handle_params patches on mount, as without adoption" do
    conn = get(adopt_conn(), "/patch")
    assert redirected_to(conn, 302) == "/patch?page=1"

    html = adopt_conn() |> get("/patch?page=1") |> html_response(200)
    assert html =~ "page: 1"
    assert [_token] = attr(html, "[data-phx-adopt]", "data-phx-adopt")
  end

  test "redirects when the LiveView redirects on mount and stops the session" do
    conn = get(adopt_conn(), "/adopt?redirect=external")
    assert redirected_to(conn) == "/elsewhere"
    assert_received {:mounted, lv, true, session}
    ref = Process.monitor(session)
    assert_receive {:DOWN, ^ref, _, _, _}
    refute Process.alive?(lv)

    conn = get(adopt_conn(), "/adopt?redirect=navigate")
    assert redirected_to(conn) == "/adopt/other"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "navigated"
  end

  test "raises the exceptions of the mount in the request" do
    assert_error_sent 404, fn -> get(adopt_conn(), "/adopt?raise=not_found") end
    assert_received {:mounted, _lv, true, session}
    ref = Process.monitor(session)
    assert_receive {:DOWN, ^ref, _, _, _}
  end

  test "exits and throws of the mount reach the request without mounting again" do
    assert catch_exit(get(adopt_conn(), "/adopt?raise=exit")) == :mount_exit
    assert_received {:mounted, _lv, true, _session}
    refute_received {:mounted, _, _, _}

    assert catch_throw(get(adopt_conn(), "/adopt?raise=throw")) == :mount_throw
    assert_received {:mounted, _lv, true, _session}
    refute_received {:mounted, _, _, _}
  end

  test "renders LiveViews that are not adoptable as before" do
    html = adopt_conn() |> get("/dead") |> html_response(200)
    assert html =~ "connected: false"
    refute html =~ "data-phx-adopt"
  end

  test "renders as before in LiveViewTest" do
    html = build_conn() |> get("/adopt") |> html_response(200)
    assert html =~ "connected: false"
    refute html =~ "data-phx-adopt"
  end

  test "renders without adoption when the node reaches :max_pending" do
    Process.put(:adopt_config, socket: "/live", max_pending: 0)
    html = adopt_conn() |> get("/adopt") |> html_response(200)
    assert html =~ "connected: false"
    refute html =~ "data-phx-adopt"
  end

  test "renders as before when :enabled is false" do
    Process.put(:adopt_config, socket: "/live", enabled: {Endpoint, :adopt?, [true]})
    html = adopt_conn(%{adopt?: false}) |> get("/adopt") |> html_response(200)
    assert html =~ "connected: false"

    Process.put(:adopt_config, socket: "/live", enabled: false)
    html = adopt_conn() |> get("/adopt") |> html_response(200)
    assert html =~ "connected: false"
  end

  test "raises without the :adopt configuration" do
    Process.put(:adopt_config, nil)

    assert %ArgumentError{message: message} = catch_error(get(adopt_conn(), "/adopt"))

    assert message =~ "require the :adopt configuration"
  end

  test "raises when the socket is not resumable" do
    Process.put(:adopt_config, socket: "/plain")

    assert %ArgumentError{message: message} = catch_error(get(adopt_conn(), "/adopt"))

    assert message =~ ~s(Cannot adopt LiveViews through socket "/plain")
  end
end
