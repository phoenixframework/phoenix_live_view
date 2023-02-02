defmodule Phoenix.LiveView.LiveReloadTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.ChannelTest
  import Phoenix.LiveViewTest

  alias Phoenix.LiveReloader
  alias Phoenix.LiveReloader.Channel

  @endpoint Phoenix.LiveView.LiveReloadTestHelpers.Endpoint
  @pubsub Phoenix.LiveView.PubSub

  setup_all do
    ExUnit.CaptureLog.capture_log(fn ->
      start_supervised!(@endpoint)
      start_supervised!(Phoenix.PubSub.child_spec(name: @pubsub))
    end)

    :ok
  end

  setup config do
    {:ok, _, socket} =
      LiveReloader.Socket |> socket() |> subscribe_and_join(Channel, "phoenix:live_reload", %{})

    conn = Plug.Test.init_test_session(build_conn(), config[:session] || %{})
    {:ok, conn: conn, socket: socket}
  end

  test "LiveView renders again when the phoenix_live_reload is received", %{
    conn: conn,
    socket: socket
  } do
    Phoenix.PubSub.subscribe(@pubsub, "live_view")

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
end
