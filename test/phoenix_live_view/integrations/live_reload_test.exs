defmodule Phoenix.LiveView.LiveReloadTest do
  use ExUnit.Case, async: true

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix_live_view

    socket "/live", Phoenix.LiveView.Socket
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.CodeReloader
    plug Phoenix.LiveViewTest.Support.Router
  end

  import Phoenix.ConnTest
  import Phoenix.ChannelTest
  import Phoenix.LiveViewTest

  @endpoint Endpoint
  @pubsub PubSub

  @live_reload_config [
    url: "ws://localhost:4004",
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$"
    ],
    notify: [
      live_view: [
        ~r"lib/test_auth_web/live/.*(ex)$"
      ]
    ]
  ]

  test "LiveView renders again when the phoenix_live_reload is received" do
    %{conn: conn, socket: socket} = start(@live_reload_config)

    Application.put_env(:phoenix_live_view, :vsn, 1)
    {:ok, lv, _html} = live(conn, "/live-reload")
    assert render(lv) =~ "<div>Version 1</div>"

    send(
      socket.channel_pid,
      {:file_event, self(), {"lib/test_auth_web/live/user_live.ex", :created}}
    )

    Application.put_env(:phoenix_live_view, :vsn, 2)

    assert_receive {:phoenix_live_reload, :live_view, "lib/test_auth_web/live/user_live.ex"}
    assert render(lv) =~ "<div>Version 2</div>"
  end

  test "LiveView renders LiveComponents again when the phoenix_live_reload message is received" do
    %{conn: conn, socket: socket} = start(@live_reload_config)

    Application.put_env(:phoenix_live_view, :vsn, 1)
    {:ok, lv, _html} = live(conn, "/live-component-reload")
    assert render(lv) =~ "<div>Version 1</div>"

    send(
      socket.channel_pid,
      {:file_event, self(), {"lib/test_auth_web/live/user_live.ex", :created}}
    )

    Application.put_env(:phoenix_live_view, :vsn, 2)

    assert_receive {:phoenix_live_reload, :live_view, "lib/test_auth_web/live/user_live.ex"}
    assert render(lv) =~ "<div>Version 2</div>"
  end

  def reload(endpoint, caller) do
    Phoenix.CodeReloader.reload(endpoint)
    send(caller, :reloaded)
  end

  test "custom reloader" do
    reloader = {__MODULE__, :reload, [self()]}
    %{conn: conn, socket: socket} = start([reloader: reloader] ++ @live_reload_config)

    Application.put_env(:phoenix_live_view, :vsn, 1)
    {:ok, lv, _html} = live(conn, "/live-reload")
    assert render(lv) =~ "<div>Version 1</div>"

    send(
      socket.channel_pid,
      {:file_event, self(), {"lib/test_auth_web/live/user_live.ex", :created}}
    )

    Application.put_env(:phoenix_live_view, :vsn, 2)

    assert_receive {:phoenix_live_reload, :live_view, "lib/test_auth_web/live/user_live.ex"}
    assert_receive :reloaded, 1000
    assert render(lv) =~ "<div>Version 2</div>"
  end

  def start(live_reload_config) do
    start_supervised!(
      {@endpoint,
       secret_key_base: String.duplicate("1", 50),
       live_view: [signing_salt: "0123456789"],
       pubsub_server: @pubsub,
       live_reload: live_reload_config}
    )

    conn = Plug.Test.init_test_session(build_conn(), %{})
    start_supervised!({Phoenix.PubSub, name: @pubsub})
    Phoenix.PubSub.subscribe(@pubsub, "live_view")

    {:ok, _, socket} =
      subscribe_and_join(
        socket(Phoenix.LiveReloader.Socket),
        Phoenix.LiveReloader.Channel,
        "phoenix:live_reload",
        %{}
      )

    %{conn: conn, socket: socket}
  end
end
