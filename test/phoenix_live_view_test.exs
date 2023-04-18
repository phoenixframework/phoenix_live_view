defmodule Phoenix.LiveViewUnitTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveView

  alias Phoenix.LiveView.{Utils, Socket}
  alias Phoenix.LiveViewTest.Endpoint

  @socket Utils.configure_socket(
            %Socket{
              endpoint: Endpoint,
              router: Phoenix.LiveViewTest.Router,
              view: Phoenix.LiveViewTest.ParamCounterLive
            },
            %{
              connect_params: %{},
              connect_info: %{},
              root_view: Phoenix.LiveViewTest.ParamCounterLive,
              __temp__: %{}
            },
            nil,
            %{},
            URI.parse("https://www.example.com")
          )

  describe "stream_configure/3" do
    test "raises when already streamed" do
      configured_socket = stream_configure(@socket, :songs, [])

      streamed_socket =
        Phoenix.Component.update(configured_socket, :streams, fn streams ->
          Map.put(streams, :songs, %Phoenix.LiveView.LiveStream{})
        end)

      assert_raise ArgumentError,
                   "cannot configure stream :songs after it has been streamed",
                   fn -> stream_configure(streamed_socket, :songs, []) end
    end

    test "raises when already configured" do
      configured_socket = stream_configure(@socket, :songs, [])

      assert_raise ArgumentError,
                   "cannot re-configure stream :songs after it has been configured",
                   fn -> stream_configure(configured_socket, :songs, []) end
    end

    test "configures a bespoke dom_id" do
      dom_id_fun = fn item -> "tunes-#{item.id}" end
      socket = stream_configure(@socket, :songs, dom_id: dom_id_fun)

      assert get_in(socket.assigns.streams, [:__configured__, :songs, :dom_id]) == dom_id_fun
    end
  end

  describe "flash" do
    test "get and put" do
      assert put_flash(@socket, :hello, "world").assigns.flash == %{"hello" => "world"}
      assert put_flash(@socket, :hello, :world).assigns.flash == %{"hello" => :world}
    end

    test "clear" do
      socket = put_flash(@socket, :hello, "world")
      assert clear_flash(socket).assigns.flash == %{}
      assert clear_flash(socket, :hello).assigns.flash == %{}
      assert clear_flash(socket, "hello").assigns.flash == %{}
      assert clear_flash(socket, "other").assigns.flash == %{"hello" => "world"}
    end
  end

  describe "get_connect_params" do
    test "raises when not in mounting state and connected" do
      socket = Utils.post_mount_prune(%{@socket | transport_pid: self()})

      assert_raise RuntimeError, ~r/attempted to read connect_params/, fn ->
        get_connect_params(socket)
      end
    end

    test "raises when not in mounting state and disconnected" do
      socket = Utils.post_mount_prune(%{@socket | transport_pid: nil})

      assert_raise RuntimeError, ~r/attempted to read connect_params/, fn ->
        get_connect_params(socket)
      end
    end

    test "returns nil when disconnected" do
      socket = %{@socket | transport_pid: nil}
      assert get_connect_params(socket) == nil
    end

    test "returns params connected and mounting" do
      socket = %{@socket | transport_pid: self()}
      assert get_connect_params(socket) == %{}
    end
  end

  describe "get_connect_info" do
    test "raises when not in mounting state and connected" do
      socket = Utils.post_mount_prune(%{@socket | transport_pid: self()})

      assert_raise RuntimeError, ~r/attempted to read connect_info/, fn ->
        get_connect_info(socket, :uri)
      end
    end

    test "raises when not in mounting state and disconnected" do
      socket = Utils.post_mount_prune(%{@socket | transport_pid: nil})

      assert_raise RuntimeError, ~r/attempted to read connect_info/, fn ->
        get_connect_info(socket, :uri)
      end
    end

    test "returns params when connected" do
      socket = %{@socket | transport_pid: self(), private: %{connect_info: %{user_agent: "foo"}}}
      assert get_connect_info(socket, :user_agent) == "foo"
    end

    test "returns params when disconnected" do
      conn =
        Plug.Test.conn(:get, "/")
        |> Plug.Conn.put_req_header("user-agent", "custom-client")
        |> Plug.Conn.put_req_header("x-foo", "bar")
        |> Plug.Conn.put_req_header("x-bar", "baz")
        |> Plug.Conn.put_req_header("tracestate", "one")
        |> Plug.Conn.put_req_header("traceparent", "two")

      socket = %{@socket | private: %{connect_info: conn}}

      assert get_connect_info(socket, :user_agent) ==
               "custom-client"

      assert get_connect_info(socket, :x_headers) ==
               [{"x-foo", "bar"}, {"x-bar", "baz"}]

      assert get_connect_info(socket, :trace_context_headers) ==
               [{"tracestate", "one"}, {"traceparent", "two"}]

      assert get_connect_info(socket, :peer_data) ==
               %{address: {127, 0, 0, 1}, port: 111_317, ssl_cert: nil}

      assert get_connect_info(socket, :uri) ==
               %URI{host: "www.example.com", path: "/", port: 80, query: "", scheme: "http"}
    end
  end

  describe "static_changed?" do
    test "raises when not in mounting state and connected" do
      socket = Utils.post_mount_prune(%{@socket | transport_pid: self()})

      assert_raise RuntimeError, ~r/attempted to read static_changed?/, fn ->
        static_changed?(socket)
      end
    end

    test "raises when not in mounting state and disconnected" do
      socket = Utils.post_mount_prune(%{@socket | transport_pid: nil})

      assert_raise RuntimeError, ~r/attempted to read static_changed?/, fn ->
        static_changed?(socket)
      end
    end

    test "returns false when disconnected" do
      socket = %{@socket | transport_pid: nil}
      assert static_changed?(socket) == false
    end

    test "returns true when connected and static do not match" do
      refute static_changed?([], %{})
      refute static_changed?(["foo/bar.css"], nil)

      assert static_changed?(["foo/bar.css"], %{})
      refute static_changed?(["foo/bar.css"], %{"foo/bar.css" => "foo/bar-123456.css"})

      refute static_changed?(
               ["domain.com/foo/bar.css"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      refute static_changed?(
               ["//domain.com/foo/bar.css"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      refute static_changed?(
               ["//domain.com/foo/bar.css?vsn=d"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      refute static_changed?(
               ["//domain.com/foo/bar-123456.css"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      refute static_changed?(
               ["//domain.com/foo/bar-123456.css?vsn=d"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      assert static_changed?(
               ["//domain.com/foo/bar-654321.css"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      assert static_changed?(
               ["foo/bar.css", "baz/bat.js"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      assert static_changed?(
               ["foo/bar.css", "baz/bat.js"],
               %{"foo/bar.css" => "foo/bar-123456.css", "p/baz/bat.js" => "p/baz/bat-123456.js"}
             )

      refute static_changed?(
               ["foo/bar.css", "baz/bat.js"],
               %{"foo/bar.css" => "foo/bar-123456.css", "baz/bat.js" => "baz/bat-123456.js"}
             )
    end

    defp static_changed?(client, latest) do
      socket = %{@socket | transport_pid: self()}
      Process.put(:cache_static_manifest_latest, latest)
      socket = put_in(socket.private.connect_params["_track_static"], client)
      static_changed?(socket)
    end
  end

  describe "redirect/2" do
    test "requires local path on to" do
      assert_raise ArgumentError, ~r"the :to option in redirect/2 expects a path", fn ->
        redirect(@socket, to: "http://foo.com")
      end

      assert_raise ArgumentError, ~r"the :to option in redirect/2 expects a path", fn ->
        redirect(@socket, to: "//foo.com")
      end

      assert redirect(@socket, to: "/foo").redirected == {:redirect, %{to: "/foo"}}
    end

    test "allows external paths" do
      assert redirect(@socket, external: "http://foo.com/bar").redirected ==
               {:redirect, %{external: "http://foo.com/bar"}}

      assert redirect(@socket, external: {:javascript, "alert"}).redirected ==
               {:redirect, %{external: "javascript:alert"}}
    end

    test "disallows insecure external paths" do
      assert_raise ArgumentError, ~r/unsupported scheme given to redirect\/2/, fn ->
        redirect(@socket, external: "javascript:alert('xss');")
      end
    end
  end

  describe "push_navigate/2" do
    test "requires local path on to" do
      assert_raise ArgumentError, ~r"the :to option in push_navigate/2 expects a path", fn ->
        push_navigate(@socket, to: "http://foo.com")
      end

      assert_raise ArgumentError, ~r"the :to option in push_navigate/2 expects a path", fn ->
        push_navigate(@socket, to: "//foo.com")
      end

      assert push_navigate(@socket, to: "/counter/123").redirected ==
               {:live, :redirect, %{kind: :push, to: "/counter/123"}}
    end
  end

  describe "push_patch/2" do
    test "requires local path on to pointing to the same LiveView" do
      assert_raise ArgumentError, ~r"the :to option in push_patch/2 expects a path", fn ->
        push_patch(@socket, to: "http://foo.com")
      end

      assert_raise ArgumentError, ~r"the :to option in push_patch/2 expects a path", fn ->
        push_patch(@socket, to: "//foo.com")
      end

      socket = %{@socket | view: Phoenix.LiveViewTest.ParamCounterLive}

      assert push_patch(socket, to: "/counter/123").redirected ==
               {:live, :patch, %{kind: :push, to: "/counter/123"}}
    end
  end
end
