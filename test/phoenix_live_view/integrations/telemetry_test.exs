defmodule Phoenix.LiveView.TelemtryTest do
  # Telemetry tests need to run synchronously
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Phoenix.LiveView.TelemetryTestHelpers

  alias Phoenix.LiveView.Socket
  alias Phoenix.LiveViewTest.Endpoint

  @endpoint Endpoint
  @moduletag session: %{names: ["chris", "jose"], from: nil}

  setup config do
    {:ok, conn: Plug.Test.init_test_session(build_conn(), config[:session] || %{})}
  end

  describe "live views" do
    @tag session: %{current_user_id: "1"}
    test "static mount emits telemetry events are emitted on successful callback", %{conn: conn} do
      attach_telemetry([:phoenix, :live_view, :mount])

      log =
        capture_log(fn ->
          conn
          |> get("/thermo?foo=bar")
          |> html_response(200)

          assert_receive {:event, [:phoenix, :live_view, :mount, :start], %{system_time: _},
                          %{socket: %Socket{transport_pid: nil}} = metadata}

          assert metadata.params == %{"foo" => "bar"}
          assert metadata.session == %{"current_user_id" => "1"}
          assert metadata.uri == "http://www.example.com/thermo?foo=bar"

          assert_receive {:event, [:phoenix, :live_view, :mount, :stop], %{duration: _},
                          %{socket: %Socket{transport_pid: nil}} = metadata}

          assert metadata.params == %{"foo" => "bar"}
          assert metadata.session == %{"current_user_id" => "1"}
          assert metadata.uri == "http://www.example.com/thermo?foo=bar"
        end)

      refute log =~ "MOUNT Phoenix.LiveViewTest.ThermostatLive"
      refute log =~ "Replied in "

      refute log =~ "HANDLE PARAMS in Phoenix.LiveViewTest.ThermostatLive"
      refute log =~ "Replied in "
    end

    @tag session: %{current_user_id: "1"}
    test "static mount emits telemetry events when callback raises an exception", %{conn: conn} do
      attach_telemetry([:phoenix, :live_view, :mount])

      assert_raise Plug.Conn.WrapperError, ~r/boom/, fn ->
        get(conn, "/errors?crash_on=disconnected_mount")
      end

      assert_receive {:event, [:phoenix, :live_view, :mount, :start], %{system_time: _},
                      %{socket: %Socket{transport_pid: nil}} = metadata}

      assert metadata.params == %{"crash_on" => "disconnected_mount"}
      assert metadata.session == %{"current_user_id" => "1"}
      assert metadata.uri == "http://www.example.com/errors?crash_on=disconnected_mount"

      assert_receive {:event, [:phoenix, :live_view, :mount, :exception], %{duration: _},
                      %{socket: %Socket{transport_pid: nil}} = metadata}

      assert metadata.kind == :error
      assert %RuntimeError{} = metadata.reason
      assert metadata.params == %{"crash_on" => "disconnected_mount"}
      assert metadata.session == %{"current_user_id" => "1"}
      assert metadata.uri == "http://www.example.com/errors?crash_on=disconnected_mount"
    end

    @tag session: %{current_user_id: "1"}
    test "live mount emits telemetry events are emitted on successful callback", %{conn: conn} do
      attach_telemetry([:phoenix, :live_view, :mount])

      log =
        capture_log(fn ->
          {:ok, _view, _html} = live(conn, "/thermo?foo=bar")

          assert_receive {:event, [:phoenix, :live_view, :mount, :start], %{system_time: _},
                          %{socket: %{transport_pid: pid}} = metadata}
                         when is_pid(pid)

          assert metadata.socket.transport_pid
          assert metadata.params == %{"foo" => "bar"}
          assert metadata.session == %{"current_user_id" => "1"}
          assert metadata.uri == "http://www.example.com/thermo?foo=bar"

          assert_receive {:event, [:phoenix, :live_view, :mount, :stop], %{duration: _},
                          %{socket: %{transport_pid: pid}} = metadata}
                         when is_pid(pid)

          assert metadata.socket.transport_pid
          assert metadata.params == %{"foo" => "bar"}
          assert metadata.session == %{"current_user_id" => "1"}
          assert metadata.uri == "http://www.example.com/thermo?foo=bar"
        end)

      assert log =~ "MOUNT Phoenix.LiveViewTest.ThermostatLive"
      assert log =~ "  Parameters: %{\"foo\" => \"bar\"}"
      assert log =~ "  Session: %{\"current_user_id\" => \"1\"}"
      assert log =~ "Replied in"

      assert log =~ "HANDLE PARAMS in Phoenix.LiveViewTest.ThermostatLive"
      assert log =~ "  Parameters: %{\"foo\" => \"bar\"}"
      assert log =~ "Replied in"
    end

    @tag session: %{current_user_id: "1"}
    test "live mount emits telemetry events when callback raises an exception", %{conn: conn} do
      attach_telemetry([:phoenix, :live_view, :mount])

      assert catch_exit(live(conn, "/errors?crash_on=connected_mount"))

      assert_receive {:event, [:phoenix, :live_view, :mount, :start], %{system_time: _},
                      %{socket: %{transport_pid: pid}} = metadata}
                     when is_pid(pid)

      assert metadata.socket.transport_pid
      assert metadata.params == %{"crash_on" => "connected_mount"}
      assert metadata.session == %{"current_user_id" => "1"}
      assert metadata.uri == "http://www.example.com/errors?crash_on=connected_mount"

      assert_receive {:event, [:phoenix, :live_view, :mount, :exception], %{duration: _},
                      %{socket: %{transport_pid: pid}} = metadata}
                     when is_pid(pid)

      assert metadata.socket.transport_pid
      assert metadata.kind == :error
      assert %RuntimeError{} = metadata.reason
      assert metadata.params == %{"crash_on" => "connected_mount"}
      assert metadata.session == %{"current_user_id" => "1"}
      assert metadata.uri == "http://www.example.com/errors?crash_on=connected_mount"
    end

    test "render_* with a successful handle_event callback emits telemetry metrics", %{conn: conn} do
      attach_telemetry([:phoenix, :live_view, :handle_event])

      log =
        capture_log(fn ->
          {:ok, view, _} = live(conn, "/thermo")
          render_submit(view, :save, %{temp: 20})

          assert_receive {:event, [:phoenix, :live_view, :handle_event, :start],
                          %{system_time: _}, metadata}

          assert metadata.socket.transport_pid
          assert metadata.event == "save"
          assert metadata.params == %{"temp" => "20"}

          assert_receive {:event, [:phoenix, :live_view, :handle_event, :stop], %{duration: _},
                          metadata}

          assert metadata.socket.transport_pid
          assert metadata.event == "save"
          assert metadata.params == %{"temp" => "20"}
        end)

      assert log =~ "HANDLE EVENT \"save\" in Phoenix.LiveViewTest.ThermostatLive"
      assert log =~ "  Parameters: %{\"temp\" => \"20\"}"
      assert log =~ "Replied in"
    end

    test "render_* with crashing handle_event callback emits telemetry metrics", %{conn: conn} do
      Process.flag(:trap_exit, true)
      attach_telemetry([:phoenix, :live_view, :handle_event])

      {:ok, view, _} = live(conn, "/errors")
      catch_exit(render_submit(view, :crash, %{"foo" => "bar"}))

      assert_receive {:event, [:phoenix, :live_view, :handle_event, :start], %{system_time: _},
                      metadata}

      assert metadata.socket.transport_pid
      assert metadata.event == "crash"
      assert metadata.params == %{"foo" => "bar"}

      assert_receive {:event, [:phoenix, :live_view, :handle_event, :exception], %{duration: _},
                      metadata}

      assert metadata.socket.transport_pid
      assert metadata.kind == :error
      assert %RuntimeError{} = metadata.reason
      assert metadata.event == "crash"
      assert metadata.params == %{"foo" => "bar"}
    end
  end

  describe "live components" do
    test "emits telemetry events when callback is successful", %{conn: conn} do
      attach_telemetry([:phoenix, :live_component, :handle_event])

      log =
        capture_log(fn ->
          {:ok, view, _html} = live(conn, "/components")

          view |> element("#chris") |> render_click(%{"op" => "upcase"})

          assert_receive {:event, [:phoenix, :live_component, :handle_event, :start],
                          %{system_time: _}, metadata}

          assert metadata.socket.transport_pid
          assert metadata.event == "transform"
          assert metadata.component == Phoenix.LiveViewTest.StatefulComponent
          assert metadata.params == %{"op" => "upcase"}

          assert_receive {:event, [:phoenix, :live_component, :handle_event, :stop],
                          %{duration: _}, metadata}

          assert metadata.socket.transport_pid
          assert metadata.event == "transform"
          assert metadata.component == Phoenix.LiveViewTest.StatefulComponent
          assert metadata.params == %{"op" => "upcase"}
        end)

      assert log =~ "HANDLE EVENT \"transform\" in Phoenix.LiveViewTest.WithComponentLive"
      assert log =~ "  Component: Phoenix.LiveViewTest.StatefulComponent"
      assert log =~ "  Parameters: %{\"op\" => \"upcase\"}"
      assert log =~ "Replied in"
    end

    test "emits telemetry events when callback fails", %{conn: conn} do
      Process.flag(:trap_exit, true)

      attach_telemetry([:phoenix, :live_component, :handle_event])
      {:ok, view, _html} = live(conn, "/components")

      assert view |> element("#chris") |> render_click(%{"op" => "boom"}) |> catch_exit

      assert_receive {:event, [:phoenix, :live_component, :handle_event, :start],
                      %{system_time: _}, metadata}

      assert metadata.socket.transport_pid
      assert metadata.event == "transform"
      assert metadata.component == Phoenix.LiveViewTest.StatefulComponent
      assert metadata.params == %{"op" => "boom"}

      assert_receive {:event, [:phoenix, :live_component, :handle_event, :exception],
                      %{duration: _}, metadata}

      assert metadata.kind == :error
      assert metadata.reason == {:case_clause, "boom"}
      assert metadata.socket.transport_pid
      assert metadata.event == "transform"
      assert metadata.component == Phoenix.LiveViewTest.StatefulComponent
      assert metadata.params == %{"op" => "boom"}
    end
  end

  describe "logging configuration" do
    @tag session: %{current_user_id: "1"}
    test "log level can be overridden for an individual Live View module", %{conn: conn} do
      log =
        capture_log([level: :warning], fn ->
          {:ok, _view, _html} = live(conn, "/log-override")
        end)

      assert log =~ "MOUNT Phoenix.LiveViewTest.WithLogOverride"
      assert log =~ "Replied in "
    end

    @tag session: %{current_user_id: "1"}
    test "logging can be disabled for an individual Live View module", %{conn: conn} do
      log =
        capture_log(fn ->
          {:ok, _view, _html} = live(conn, "/log-disabled")
        end)

      refute log =~ "MOUNT Phoenix.LiveViewTest.WithLogDisabled"
      refute log =~ "Replied in "
    end
  end
end
